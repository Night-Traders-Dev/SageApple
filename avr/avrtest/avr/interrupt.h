/*
 * Minimal <avr/interrupt.h> for the host LED test.
 *
 * On the chip ISR(x) places the handler in the vector table with a reti. Here it
 * is just a plain function, so the test can call WDT_vect() to advance the beat
 * by hand. That is the whole trick: the sequencer is a state machine driven once
 * per beat, and stepping it directly makes the pattern deterministic to assert
 * on rather than something to watch.
 */
#ifndef SAGEAPPLE_TEST_AVR_INTERRUPT_H
#define SAGEAPPLE_TEST_AVR_INTERRUPT_H

#define ISR(vec) void vec(void)

/* The watchdog handler led.c installs, named so a test can advance the beat
   by calling it. Declared here because the shim, not led.c, is what gives
   the handler its name. */
void WDT_vect(void);

#endif /* SAGEAPPLE_TEST_AVR_INTERRUPT_H */
