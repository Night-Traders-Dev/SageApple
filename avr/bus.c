/*
 * SageApple — AppleBus for the ATmega328P port (M13)
 *
 * Maps the 6502 address space exactly like bus/applebus.sage:
 *   $0000-$03FF  RAM (1KB — the 328P's 2KB SRAM also holds the emulator)
 *   $2000        UART status: bit0 RX-ready, bit1 TX-ready
 *   $2001        read: RX data / write: TX data
 *   $E000-$FFFF  8KB PROGMEM ROM (was $8000-$FFFF on the host)
 * Everything else reads 0xFF / ignores writes.
 *
 * On the host build the UART and ROM are provided by the harness
 * (bus.c/host_uart.c compiled with -DHOST_UART_DRIVER).
 */
#include <stdint.h>

#ifndef HOST
#include <avr/io.h>
#include <avr/pgmspace.h>
extern const uint8_t MONROM[8192] PROGMEM;
#else
extern const uint8_t MONROM[8192];
#endif

static uint8_t ram[1024];

/* UART device hooks provided by the platform (uart.c / host_uart.c) */
#ifndef HOST
static uint8_t uart_rx_ready(void) { return (UCSR0A & (1 << RXC0)) ? 1 : 0; }
static uint8_t uart_rx(void) { return UDR0; }
static void uart_tx(uint8_t c) { while (!(UCSR0A & (1 << UDRE0))) { } UDR0 = c; }
static uint8_t uart_tx_ready(void) { return 1; }
#else
uint8_t host_uart_rx_ready(void);
uint8_t host_uart_rx(void);
void host_uart_tx(uint8_t c);
static uint8_t uart_rx_ready(void) { return host_uart_rx_ready(); }
static uint8_t uart_rx(void) { return host_uart_rx(); }
static void uart_tx(uint8_t c) { host_uart_tx(c); }
static uint8_t uart_tx_ready(void) { return 1; }
#endif

uint8_t bus_read(uint16_t addr) {
    if (addr < 0x0400) return ram[addr];
    if (addr >= 0x2000 && addr <= 0x2001) {
        if (addr == 0x2000) return (uart_rx_ready() ? 0x01 : 0x00) | (uart_tx_ready() ? 0x02 : 0x00);
        {
#ifdef HOST
            return uart_rx();
#else
            return uart_rx();
#endif
        }
    }
    if (addr >= 0xE000) {
#ifndef HOST
        return pgm_read_byte(&MONROM[addr - 0xE000]);
#else
        return MONROM[addr - 0xE000];
#endif
    }
    return 0xFF;
}

void bus_write(uint16_t addr, uint8_t v) {
    if (addr < 0x400) ram[addr] = v;
    else if (addr == 0x2001) uart_tx(v);
    /* ROM + layout: reads-only; ignore writes */
}

void bus_poke(uint16_t addr, uint8_t v) { bus_write(addr, v); }

