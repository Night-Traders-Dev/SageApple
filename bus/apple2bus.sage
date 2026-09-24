import devices.uart

## The Apple II serial bridge is UART TX on $C080 and UART RX on $C081.
##
## The language-card model has 16 KiB of physical RAM: two 4 KiB $D000
## banks and a shared 8 KiB region at $E000-$F7FF. This byte-bus model
## tracks prewrite across explicit odd reads; it cannot expose a 6502 read
## phase hidden inside write8. ROM mode uses the flat main ROM as a
## deterministic fallback rather than modeling language-card ROM banking.
class Apple2Bus:
    proc init(self):
        self.ram = []
        var i = 0
        while i < 0xC000:
            push(self.ram, 0x00)
            i = i + 1
        self.rom = []
        i = 0
        while i < 0x3000:
            push(self.rom, 0x00)
            i = i + 1
        self.language_card_ram = []
        var lc_index = 0
        while lc_index < 0x4000:
            push(self.language_card_ram, 0x00)
            lc_index = lc_index + 1
        self.language_card_flat_rom_fallback = true
        self._reset_language_card_state()
        self.slot_roms = []
        var slot = 0
        while slot < 8:
            let slot_rom = []
            var slot_index = 0
            while slot_index < 0x100:
                push(slot_rom, 0x00)
                slot_index = slot_index + 1
            push(self.slot_roms, slot_rom)
            slot = slot + 1
        self.expansion_rom = []
        var expansion_index = 0
        while expansion_index < 0x800:
            push(self.expansion_rom, 0x00)
            expansion_index = expansion_index + 1
        self.uart = uart.UART()
        self.events = []
        self.video_events = []
        self.video_switches = [false, false, false, false, false, false, false, false]
        self.video_values = [0, 0, 0, 0, 0, 0, 0, 0]
        self._reset_video_state()
        self.keyboard_queue = []
        self.keyboard_latch = 0x00
        self.keyboard_strobe = false
        self.keyboard_latch_valid = false
        self.speaker_on = false
        self.speaker_toggles = 0

    proc _reset_language_card_state(self):
        self.language_card_bank = 2
        self.language_card_read_ram = false
        self.language_card_write_ram = true
        self.language_card_prewrite = false

    proc reset(self):
        self.events = []
        self._reset_language_card_state()
        self.video_events = []
        self._reset_video_state()
        var i = 0
        while i < 8:
            self.video_switches[i] = false
            self.video_values[i] = 0
            i = i + 1
        self.keyboard_queue = []
        self.keyboard_latch = 0x00
        self.keyboard_strobe = false
        self.keyboard_latch_valid = false
        self.speaker_on = false
        self.speaker_toggles = 0
        self.uart.rx = []
        self.uart.rx_head = 0
        self.uart.tx = []
        self.uart.tx_rendered = 0
        self.uart.tx_str = ""

    proc _record_event(self, addr, value):
        if (addr >= 0x0400 and addr <= 0x0BFF) or (addr >= 0x2000 and addr <= 0x5FFF):
            push(self.events, [addr, value])

    proc _encode_keyboard_char(self, value):
        var code = ord(value)
        if code >= 0x61 and code <= 0x7A:
            code = code - 0x20
        if code >= 0x41 and code <= 0x5A:
            return code | 0x80
        if code >= 0x30 and code <= 0x39:
            return code | 0x80
        if code == 0x20:
            return 0xA0
        if code == 0x0D or code == 0x0A:
            return 0x8D
        return code | 0x80

    proc _promote_keyboard(self):
        self.keyboard_latch = self.keyboard_queue[0]
        self.keyboard_queue = slice(self.keyboard_queue, 1, len(self.keyboard_queue))
        self.keyboard_strobe = true
        self.keyboard_latch_valid = true

    proc _queue_keyboard(self, value):
        push(self.keyboard_queue, value & 0xFF)
        if self.keyboard_strobe == false and self.keyboard_latch_valid == false:
            self._promote_keyboard()

    proc keyboard_input(self, value):
        if type(value) == "string":
            var i = 0
            while i < len(value):
                self._queue_keyboard(self._encode_keyboard_char(value[i]))
                i = i + 1
        elif type(value) == "array":
            var i = 0
            while i < len(value):
                self._queue_keyboard(value[i])
                i = i + 1
        else:
            self._queue_keyboard(value)

    proc inject_keyboard(self, value):
        return self.keyboard_input(value)

    proc keyboard_feed(self, value):
        return self.keyboard_input(value)

    proc _read_keyboard_strobe(self):
        if self.keyboard_strobe == true:
            self.keyboard_strobe = false
            self.keyboard_latch = self.keyboard_latch & 0x7F
            return 0x80
        if self.keyboard_latch_valid == true:
            return 0x00
        if len(self.keyboard_queue) > 0:
            self._promote_keyboard()
            return 0x80
        return 0x00

    proc _toggle_speaker(self):
        if self.speaker_on:
            self.speaker_on = false
        else:
            self.speaker_on = true
        self.speaker_toggles = self.speaker_toggles + 1

    proc _reset_video_state(self):
        self.text = true
        self.mixed = false
        self.page2 = false
        self.hires = false

    proc _apply_video_switch(self, addr):
        let index = addr - 0xC050
        if index == 0:
            self.text = false
        elif index == 1:
            self.text = true
        elif index == 2:
            self.mixed = false
        elif index == 3:
            self.mixed = true
        elif index == 4:
            self.page2 = false
        elif index == 5:
            self.page2 = true
        elif index == 6:
            self.hires = false
        elif index == 7:
            self.hires = true

    proc _set_video_switch(self, addr, value):
        let index = addr - 0xC050
        self.video_switches[index] = true
        self.video_values[index] = value & 0xFF
        push(self.video_events, [addr, value & 0xFF])

    proc _language_card_soft_switch(self, addr, writing):
        let mode = addr & 0x03
        if (addr & 0x08) == 0:
            self.language_card_bank = 1
        else:
            self.language_card_bank = 2
        if writing:
            self.language_card_prewrite = false
            self.language_card_write_ram = false
        elif (addr & 0x01) == 0:
            self.language_card_prewrite = false
            self.language_card_write_ram = mode == 1 or mode == 2
        elif self.language_card_prewrite == false:
            self.language_card_prewrite = true
            self.language_card_write_ram = false
        else:
            self.language_card_write_ram = mode == 1 or mode == 2
        self.language_card_read_ram = mode == 0 or mode == 1

    proc _language_card_ram_offset(self, addr):
        if addr < 0xE000:
            if self.language_card_bank == 1:
                return addr - 0xD000
            return 0x1000 + addr - 0xD000
        return 0x2000 + addr - 0xE000

    proc read8(self, addr):
        addr = addr & 0xFFFF
        if addr < 0xC000:
            return self.ram[addr]
        if addr >= 0xD000:
            if addr >= 0xF800:
                return self.rom[addr - 0xD000]
            if self.language_card_read_ram:
                return self.language_card_ram[self._language_card_ram_offset(addr)]
            return self.rom[addr - 0xD000]
        if addr == 0xC000:
            if self.keyboard_strobe == false and self.keyboard_latch_valid == true:
                let value = self.keyboard_latch & 0x7F
                self.keyboard_latch_valid = false
                if len(self.keyboard_queue) > 0:
                    self._promote_keyboard()
                return value
            return self.keyboard_latch & 0xFF
        if addr == 0xC010:
            return self._read_keyboard_strobe()
        if addr == 0xC030:
            self._toggle_speaker()
            if self.speaker_on:
                return 0x80
            return 0x00
        if addr >= 0xC050 and addr <= 0xC057:
            self._apply_video_switch(addr)
            let index = addr - 0xC050
            if self.video_switches[index]:
                return 0x80
            return 0x00
        if addr == 0xC081:
            if self.uart.rx_ready() == 1:
                return 0x80 | self.uart.rx_read()
            return 0x00
        if (addr >= 0xC300 and addr <= 0xC303) or (addr >= 0xC308 and addr <= 0xC30B):
            self._language_card_soft_switch(addr, false)
            return 0x00
        if addr >= 0xC100 and addr <= 0xC7FF:
            let slot_number = (addr >> 8) - 0xC0
            return self.slot_roms[slot_number][addr & 0xFF]
        if addr >= 0xC800:
            return self.expansion_rom[addr - 0xC800]
        return 0x00

    proc write8(self, addr, value):
        addr = addr & 0xFFFF
        value = value & 0xFF
        if addr < 0xC000:
            self.ram[addr] = value
            self._record_event(addr, value)
            return
        if addr >= 0xD000:
            if addr < 0xF800 and self.language_card_write_ram:
                self.language_card_ram[self._language_card_ram_offset(addr)] = value
            return
        if addr == 0xC010:
            self._read_keyboard_strobe()
            return
        if addr == 0xC030:
            self._toggle_speaker()
            return
        if addr >= 0xC050 and addr <= 0xC057:
            self._apply_video_switch(addr)
            self._set_video_switch(addr, value)
            return
        if addr == 0xC080:
            self.uart.tx_write(value)
            return
        if (addr >= 0xC300 and addr <= 0xC303) or (addr >= 0xC308 and addr <= 0xC30B):
            self._language_card_soft_switch(addr, true)
            return

    proc read16(self, addr):
        return self.read8(addr) | (self.read8(addr + 1) << 8)

    proc write_ram(self, addr, value):
        addr = addr & 0xFFFF
        if addr < 0xC000:
            self.write8(addr, value)

    proc load_rom(self, image):
        if len(image) != 0x3000:
            raise "Apple2Bus ROM image must be exactly 12288 bytes"
        var i = 0
        while i < 0x3000:
            self.rom[i] = image[i] & 0xFF
            i = i + 1
        return 0

    proc load_slot_rom(self, slot, image):
        if type(slot) != "number" or slot != int(slot):
            raise "Apple2Bus slot ROM number must be an integer"
        if slot < 1 or slot > 7:
            raise "Apple2Bus slot ROM is only available for slots 1-7"
        if type(image) != "array" or len(image) != 0x100:
            raise "Apple2Bus slot ROM image must be exactly 256 bytes"
        var slot_byte_index = 0
        while slot_byte_index < 0x100:
            self.slot_roms[slot][slot_byte_index] = image[slot_byte_index] & 0xFF
            slot_byte_index = slot_byte_index + 1
        return 0

    proc load_expansion_rom(self, image):
        if type(image) != "array" or len(image) != 0x800:
            raise "Apple2Bus expansion ROM image must be exactly 2048 bytes"
        var expansion_byte_index = 0
        while expansion_byte_index < 0x800:
            self.expansion_rom[expansion_byte_index] = image[expansion_byte_index] & 0xFF
            expansion_byte_index = expansion_byte_index + 1
        return 0

    proc language_card_state(self):
        return [
            self.language_card_bank,
            self.language_card_read_ram,
            self.language_card_write_ram,
            self.language_card_prewrite,
        ]

    proc serial_input(self, value):
        if type(value) == "string":
            self.uart.receive_str(value)
        elif type(value) == "array":
            var i = 0
            while i < len(value):
                self.uart.receive(value[i])
                i = i + 1
        else:
            self.uart.receive(value)

    proc serial_receive(self, value):
        return self.serial_input(value)

    proc serial_feed(self, value):
        return self.serial_input(value)

    proc serial_read(self):
        return self.uart.rx_read()

    proc read_serial(self):
        return self.serial_read()

    proc serial_text(self):
        return self.uart.tx_text()

    proc serial_output(self):
        return self.serial_text()

    proc video_snapshot(self):
        return [self.text, self.mixed, self.page2, self.hires]

    proc video_mode(self):
        if self.text:
            return "text"
        if self.hires:
            return "hires"
        return "lores"

    proc video_page(self):
        if self.page2:
            return 2
        return 1

    proc video_state(self, index):
        if index >= 0 and index < 8:
            return self.video_switches[index]
        return false

    proc video_value(self, index):
        if index >= 0 and index < 8:
            return self.video_values[index]
        return 0

    proc speaker_state(self):
        return self.speaker_on

    proc speaker_enabled(self):
        return self.speaker_on

    proc clear_events(self):
        self.events = []
        self.video_events = []
