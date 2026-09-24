#include <stdint.h>

#ifndef HOST
#include <avr/io.h>
#include <avr/pgmspace.h>
extern const uint8_t APPLE2ROM[12288] PROGMEM;
#else
extern const uint8_t APPLE2ROM[12288];
#endif

static uint8_t ram[1024];
static uint8_t language_card_ram[512];
static uint8_t keyboard_latch;
static uint8_t keyboard_strobe;
static uint8_t speaker_on;
static uint8_t video_switches[8];
static uint8_t video_values[8];
static uint16_t video_event_count;
static uint16_t video_last_address;
static uint8_t video_last_value;
static uint8_t language_card_bank;
static uint8_t language_card_read_ram;
static uint8_t language_card_write_ram;
static uint8_t language_card_prewrite;

#define LANGUAGE_CARD_BANK_SIZE 0x80
#define LANGUAGE_CARD_BANK2_BASE 0x80
#define LANGUAGE_CARD_SHARED_BASE 0x100

#ifndef HOST
static uint8_t uart_rx_ready(void) {
    return (UCSR0A & (1 << RXC0)) ? 1 : 0;
}

static uint8_t uart_rx(void) {
    return UDR0;
}

static void uart_tx(uint8_t value) {
    while (!(UCSR0A & (1 << UDRE0))) {
    }
    UDR0 = value;
}
#else
uint8_t host_uart_rx_ready(void);
uint8_t host_uart_rx(void);
void host_uart_tx(uint8_t value);

static uint8_t uart_rx_ready(void) {
    return host_uart_rx_ready();
}

static uint8_t uart_rx(void) {
    return host_uart_rx();
}

static void uart_tx(uint8_t value) {
    host_uart_tx(value);
}
#endif

static uint8_t is_video_write(uint16_t address) {
    return (uint8_t)(((address >= 0x0400 && address <= 0x0BFF) ||
                      (address >= 0x2000 && address <= 0x5FFF)) ? 1 : 0);
}

static void record_video_write(uint16_t address, uint8_t value) {
    if (video_event_count != 0xFFFF) {
        video_event_count++;
    }
    video_last_address = address;
    video_last_value = value;
}

static void toggle_speaker(void) {
    speaker_on = (uint8_t)(!speaker_on);
}

static uint8_t read_rom(uint16_t offset) {
#ifndef HOST
    return pgm_read_byte(&APPLE2ROM[offset]);
#else
    return APPLE2ROM[offset];
#endif
}

static uint16_t language_card_offset(uint16_t address) {
    if (address >= 0xD000 && address < 0xD000 + LANGUAGE_CARD_BANK_SIZE) {
        return language_card_bank == 1 ? 0 : LANGUAGE_CARD_BANK2_BASE;
    }
    if (address >= 0xE000 && address < 0xE200) {
        return LANGUAGE_CARD_SHARED_BASE + (uint16_t)(address - 0xE000);
    }
    return 0xFFFF;
}

static void language_card_switch(uint16_t address, uint8_t writing) {
    uint8_t mode = (uint8_t)(address & 0x03);
    language_card_bank = (address & 0x08) == 0 ? 1 : 2;
    if (writing) {
        language_card_prewrite = 0;
        language_card_write_ram = 0;
    } else if ((address & 0x01) == 0) {
        language_card_prewrite = 0;
        language_card_write_ram = mode == 1 || mode == 2;
    } else if (language_card_prewrite == 0) {
        language_card_prewrite = 1;
        language_card_write_ram = 0;
    } else {
        language_card_write_ram = mode == 1 || mode == 2;
    }
    language_card_read_ram = mode == 0 || mode == 1;
}

static uint8_t language_card_read(uint16_t address) {
    uint16_t offset = language_card_offset(address);
    return offset == 0xFFFF ? 0 : language_card_ram[offset];
}

static void language_card_write(uint16_t address, uint8_t value) {
    uint16_t offset = language_card_offset(address);
    if (offset != 0xFFFF) {
        language_card_ram[offset] = value;
    }
}

void bus_reset(void) {
    uint8_t i;
    keyboard_latch = 0;
    keyboard_strobe = 0;
    speaker_on = 0;
    for (i = 0; i < 8; i++) {
        video_switches[i] = 0;
        video_values[i] = 0;
    }
    video_event_count = 0;
    video_last_address = 0;
    video_last_value = 0;
    language_card_bank = 2;
    language_card_read_ram = 0;
    language_card_write_ram = 1;
    language_card_prewrite = 0;
}

uint8_t bus_read(uint16_t address) {
    if (address < 0x0400) {
        return ram[address];
    }
    if (address >= 0xD000) {
        if (address >= 0xF800) {
            return read_rom((uint16_t)(address - 0xD000));
        }
        if (language_card_read_ram) {
            return language_card_read(address);
        }
        return read_rom((uint16_t)(address - 0xD000));
    }
    if (address == 0xC000) {
        return keyboard_latch;
    }
    if (address == 0xC010) {
        uint8_t value = keyboard_strobe ? 0x80 : 0x00;
        keyboard_strobe = 0;
        return value;
    }
    if (address == 0xC030) {
        toggle_speaker();
        return speaker_on ? 0x80 : 0x00;
    }
    if (address >= 0xC050 && address <= 0xC057) {
        uint8_t index = (uint8_t)(address - 0xC050);
        return video_switches[index] ? 0x80 : 0x00;
    }
    if (address == 0xC081) {
        if (uart_rx_ready()) {
            return (uint8_t)(0x80 | uart_rx());
        }
        return 0x00;
    }
    if ((address >= 0xC300 && address <= 0xC303) ||
        (address >= 0xC308 && address <= 0xC30B)) {
        language_card_switch(address, 0);
        return 0x00;
    }
    return 0x00;
}

void bus_write(uint16_t address, uint8_t value) {
    if (address < 0x0400) {
        ram[address] = value;
        return;
    }
    if (address >= 0xD000) {
        if (address < 0xF800 && language_card_write_ram) {
            language_card_write(address, value);
        }
        return;
    }
    if (is_video_write(address)) {
        record_video_write(address, value);
        return;
    }
    if (address == 0xC010) {
        keyboard_strobe = 0;
        return;
    }
    if (address == 0xC030) {
        toggle_speaker();
        return;
    }
    if (address >= 0xC050 && address <= 0xC057) {
        uint8_t index = (uint8_t)(address - 0xC050);
        video_switches[index] = 1;
        video_values[index] = value;
        return;
    }
    if (address == 0xC080) {
        uart_tx(value);
        return;
    }
    if ((address >= 0xC300 && address <= 0xC303) ||
        (address >= 0xC308 && address <= 0xC30B)) {
        language_card_switch(address, 1);
    }
}

void bus_poke(uint16_t address, uint8_t value) {
    bus_write(address, value);
}

uint16_t bus_video_event_count(void) {
    return video_event_count;
}

uint16_t bus_video_last_address(void) {
    return video_last_address;
}

uint8_t bus_video_last_value(void) {
    return video_last_value;
}

uint8_t bus_video_value(uint8_t index) {
    return index < 8 ? video_values[index] : 0;
}
