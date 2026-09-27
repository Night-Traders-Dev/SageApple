/*
 * Minimal <avr/io.h> for the host LED test.
 *
 * led.c is firmware and belongs on the chip, but its pattern logic is the part
 * worth testing, and the only way to test that without a scope is to run it
 * somewhere the registers are just memory. This header provides exactly the
 * registers led.c touches, as ordinary variables, so the test can set a reset
 * cause or read a pin back after stepping the sequencer.
 *
 * The register names and bit positions are the ATmega328P's, so the code under
 * test is the code that ships.
 */
#ifndef SAGEAPPLE_TEST_AVR_IO_H
#define SAGEAPPLE_TEST_AVR_IO_H

#include <stdint.h>

/* Port B and D, as the chip's memory-mapped registers. */
extern volatile uint8_t PORTB, DDRB, PINB;
extern volatile uint8_t PORTD, DDRD, PIND;

/* Reset cause. */
extern volatile uint8_t MCUSR;

/* USART control and status. */
extern volatile uint8_t UCSR0A, UCSR0B, UCSR0C;
extern volatile uint8_t UBRR0H, UBRR0L;

/* Watchdog. */
extern volatile uint8_t WDTCSR;

/* MCUSR bits. */
#define BORF  0
#define EXTRF 1
#define WDRF  3

/* UCSR0A bits. */
#define FE0   4
#define DOR0  3
#define RXC0  7

/* WDTCSR bits. */
#define WDP2  2
#define WDE   3
#define WDIE  6
#define WDCE  4

/* Port B bit 5, port D bits 2..4. */
#define PORTB5 5
#define DDB5   5
#define PORTD2 2
#define PORTD3 3
#define PORTD4 4

#endif /* SAGEAPPLE_TEST_AVR_IO_H */
