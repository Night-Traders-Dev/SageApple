import devices.uart

## The Apple II serial bridge is UART TX on $C080 and UART RX on $C081.
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
        self.uart = uart.UART()
        self.events = []
        self.video_events = []
        self.video_switches = [false, false, false, false, false, false, false, false]
        self.video_values = [0, 0, 0, 0, 0, 0, 0, 0]
        self.keyboard_queue = []
        self.keyboard_latch = 0x00
        self.keyboard_strobe = false
        self.speaker_on = false
        self.speaker_toggles = 0

    proc reset(self):
        self.events = []
        self.video_events = []
        var i = 0
        while i < 8:
            self.video_switches[i] = false
            self.video_values[i] = 0
            i = i + 1
        self.keyboard_queue = []
        self.keyboard_latch = 0x00
        self.keyboard_strobe = false
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

    proc _queue_keyboard(self, value):
        push(self.keyboard_queue, value & 0xFF)
        if self.keyboard_strobe == false:
            self.keyboard_latch = pop(self.keyboard_queue)
            self.keyboard_strobe = true

    proc keyboard_input(self, value):
        if type(value) == "string":
            var i = 0
            while i < len(value):
                self._queue_keyboard(ord(value[i]))
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
        if self.keyboard_strobe == false:
            return 0x00
        self.keyboard_strobe = false
        if len(self.keyboard_queue) > 0:
            self.keyboard_latch = pop(self.keyboard_queue)
            self.keyboard_strobe = true
        return 0x80

    proc _toggle_speaker(self):
        if self.speaker_on:
            self.speaker_on = false
        else:
            self.speaker_on = true
        self.speaker_toggles = self.speaker_toggles + 1

    proc _set_video_switch(self, addr, value):
        let index = addr - 0xC050
        self.video_switches[index] = true
        self.video_values[index] = value & 0xFF
        push(self.video_events, [addr, value & 0xFF])

    proc read8(self, addr):
        addr = addr & 0xFFFF
        if addr < 0xC000:
            return self.ram[addr]
        if addr >= 0xD000:
            return self.rom[addr - 0xD000]
        if addr == 0xC000:
            return self.keyboard_latch & 0xFF
        if addr == 0xC010:
            return self._read_keyboard_strobe()
        if addr == 0xC030:
            self._toggle_speaker()
            if self.speaker_on:
                return 0x80
            return 0x00
        if addr >= 0xC050 and addr <= 0xC057:
            let index = addr - 0xC050
            if self.video_switches[index]:
                return 0x80
            return 0x00
        if addr == 0xC081:
            if self.uart.rx_ready() == 1:
                return 0x80 | self.uart.rx_read()
            return 0x00
        return 0x00

    proc write8(self, addr, value):
        addr = addr & 0xFFFF
        value = value & 0xFF
        if addr < 0xC000:
            self.ram[addr] = value
            self._record_event(addr, value)
            return
        if addr >= 0xD000:
            return
        if addr == 0xC010:
            self._read_keyboard_strobe()
            return
        if addr == 0xC030:
            self._toggle_speaker()
            return
        if addr >= 0xC050 and addr <= 0xC057:
            self._set_video_switch(addr, value)
            return
        if addr == 0xC080:
            self.uart.tx_write(value)
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
