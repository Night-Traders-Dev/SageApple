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
#include <avr/wdt.h>

#define BAUD 9600UL
#include <util/setbaud.h>

#include "led.h"

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
void bus_reset(void);

int main(void) {
    cli();
    led_init();                 /* first: latches the reset source */
    led_stage_enter(LED_STAGE_POWER);
    led_stage_done(LED_STAGE_POWER);

    uart_init();
    led_stage_enter(LED_STAGE_UART);
    led_stage_done(LED_STAGE_UART);

    bus_reset();
    cpu_reset();
    led_stage_enter(LED_STAGE_CPU);
    led_stage_done(LED_STAGE_CPU);

    sei();

    for (;;) {
        cpu_step();
        /* The monitor ROM announces itself on the serial port, so the last boot
           stage is observed rather than assumed. Watched in the main loop to
           keep the interrupt short. */
        if (!led_stage_is_done(LED_STAGE_MONITOR) && (UCSR0A & (1 << RXC0))) {
            led_stage_done(LED_STAGE_MONITOR);
            led_idle();
        }
        led_poll();             /* latches serial overrun or framing faults */
    }
}
