/*
 * SageApple — ATmega328P runtime.
 *
 * Minimal C entry: sets up the UART, prints a banner, then enters the
 * machine loop. On the AVR port the 6502 emulator's memory bus is backed
 * by SRAM/Flash; the UART device maps to the real 16MHz UART.
 *
 * This file is intentionally portable: wrap the bus with AVR-backed storage
 * once Milestone 6 lands.
 */
#include <stdint.h>
#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/pgmspace.h>

#define BAUD 9600UL
#include <util/setbaud.h>

static void uart_init(void) {
    UBRR0H = UBRRH_VALUE;
    UBRR0L = UBRRL_VALUE;
#if USE_2X
    UCSR0A |= (1 << U2X0);
#endif
    UCSR0B = (1 << RXEN0) | (1 << TXEN0);
    UCSR0C = (1 << UCSZ01) | (1 << UCSZ00);
}

static void uart_putc(char ch) {
    while (!(UCSR0A & (1 << UDRE0))) { }
    UDR0 = (uint8_t)ch;
}

static void uart_puts(const char *s) {
    while (*s) uart_putc(*s++);
}

static void machine_loop(void) {
    /* Placeholder: boots SageApple. Milestones 5-7 replace this with the
       boot ROM + monitor driven by the Sage6502 core. */
    uart_puts("\r\nSageApple Computer\r\nSage6502 CPU\r\nATmega328P\r\n\r\n> ");
    for (;;) { }
}

int main(void) {
    cli();
    uart_init();
    sei();
    machine_loop();
    return 0;
}