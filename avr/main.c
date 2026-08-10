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

// Heartbeat: LED on PB5 (pin 13) - ON for 1s every 10s
// Uses Watchdog Timer for clock-independent timing (128kHz internal osc)
static volatile uint8_t hb_counter = 0;
static volatile uint8_t hb_state = 0;

static void heartbeat_init(void) {
    DDRB |= (1 << DDB5);
    PORTB &= ~(1 << PORTB5);

    wdt_disable();
    WDTCSR = (1 << WDCE) | (1 << WDE);
    WDTCSR = (1 << WDIE) | (1 << WDP2) | (1 << WDP1);  // ~1s interrupt
}

ISR(WDT_vect) {
    hb_counter++;
    if (hb_counter == 1) {
        PORTB |= (1 << PORTB5);   // LED on
    } else if (hb_counter == 2) {
        PORTB &= ~(1 << PORTB5);  // LED off after 1s
    } else if (hb_counter >= 10) {
        hb_counter = 0;           // Restart 10s cycle
    }
}

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
    heartbeat_init();
    sei();
    cpu_reset();
    for (;;) {
        cpu_step();
    }
}
