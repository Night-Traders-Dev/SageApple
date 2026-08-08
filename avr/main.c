/*
 * SageApple — ATmega328P runtime (M13): real 6502 emulator on the UNO.
 *
 * Boots the chip, drives UART0 at 9600 baud, then runs the 6502 core
 * forever with the monitor ROM at $E000-$FFFF (PROGMEM). The monitor
 * communicates over the same UART: help / dump / peek / poke / regs /
 * run / reset, exactly as on the host emulation.
 */
#include <stdint.h>
#include <avr/io.h>
#include <avr/interrupt.h>

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

void cpu_reset(void);
void cpu_step(void);

int main(void) {
    cli();
    uart_init();
    sei();
    cpu_reset();
    for (;;) {
        cpu_step();
    }
}