/*
 * SageApple -- boot, status and fault signalling by LED
 *
 * Two related languages, chosen automatically by how many LEDs are wired up.
 *
 * MULTI-LED (2 or more). One LED per boot stage, read as a progress bar:
 *
 *   off      the stage has not been reached
 *   flashing the stage is in progress right now
 *   solid    the stage completed
 *
 * So a board that stops flashing at stage 3 with stages 1 and 2 solid is
 * telling you it died in stage 3 without saying a word. That is the whole
 * debugging story: the array of LEDs *is* the trace.
 *
 * SINGLE-LED (1). The same information as blink patterns, distinguished by
 * pulse width so a decoder needs no timing precision:
 *
 *   steady            booted and idle
 *   N short pulses    a boot stage completed, N being the stage number
 *   N long pulses     fault code N, repeating
 *
 * A short pulse is one beat long, a long pulse three, and groups are separated
 * by a four-beat gap. One beat is 125ms, from the watchdog, so a stage is one
 * 125ms flash and the shortest gap is 500ms -- readable across a room and
 * distinguishable by eye at any viewing distance.
 *
 * Pin notes. D13 (PORTB5) is the built-in LED on both a Nano and an Uno R3 and
 * is the only LED either board gives you that is safe to drive: an Uno's other
 * two are on D0 and D1, which belong to the UART, and its ON LED is wired to
 * the supply. So a stock Uno and a stock Nano both run the single-LED language.
 * The extra stages of the multi-LED language need LEDs on free pins -- D2 to
 * D6 are unused by this firmware and carry no SPI or UART function.
 */
#ifndef SAGEAPPLE_LED_H
#define SAGEAPPLE_LED_H

#include <stdint.h>

/* Boot stages, in the order they happen. On a four-LED build each has its own
   LED; with fewer, the count is what the single-LED language reports. */
typedef enum {
    LED_STAGE_POWER = 0,   /* MCU out of reset, reset source read      */
    LED_STAGE_UART,        /* serial port configured                   */
    LED_STAGE_CPU,         /* 6502 reset, vector fetched, running      */
    LED_STAGE_MONITOR,     /* monitor banner seen on the serial port   */
    LED_STAGE_COUNT
} led_stage_t;

/* Per-LED state in the progress display. */
typedef enum {
    LED_OFF = 0,
    LED_FLASH,              /* in progress          */
    LED_SOLID,              /* completed            */
    LED_FAULT               /* this stage failed    */
} led_visual_t;

/*
 * Fault codes. Every one of these is something this firmware can actually
 * observe; there is no code here for a condition it cannot detect.
 *
 * The reset-source codes are the useful ones in practice. They are latched from
 * MCUSR before anything else runs, so a board that rebooted on a watchdog or a
 * brownout says so on the next boot instead of looking like a normal one.
 */
typedef enum {
    LED_FAULT_NONE = 0,
    LED_FAULT_BROWNOUT,     /* power dipped below the operating floor   */
    LED_FAULT_WATCHDOG,     /* a reset came from the watchdog           */
    LED_FAULT_EXTERNAL,     /* reset pin, or a powered-down brownout   */
    LED_FAULT_UART_OVERRUN, /* a byte arrived while the last was unread */
    LED_FAULT_UART_FRAMING, /* the line was not framed as expected      */
    LED_FAULT_COUNT
} led_fault_t;

/* Call once, first thing in main, before any other initialisation: it latches
   the reset source and starts the beat timer. */
void led_init(void);

/* Progress. led_stage_enter leaves the stage flashing, led_stage_done leaves it
   solid. Both are idempotent and cheap, so the boot code can call them
   unconditionally. */
void led_stage_enter(led_stage_t stage);
void led_stage_done(led_stage_t stage);

/* Whether a stage has already completed, so the boot code can detect a
   one-shot event like the monitor banner without repeating it. */
uint8_t led_stage_is_done(led_stage_t stage);

/* Healthy running state. On one LED this is steady on; with several it is all
   solid, which is the picture of a boot that got all the way through. */
void led_idle(void);

/* Latch a fault. The first one wins, because a fault that arrives during the
   handling of an earlier fault is a consequence, not news. */
void led_fault(led_fault_t fault);

/* Poll for a serial overrun or framing error. Cheap; call it from the main
   loop. Returns the latched fault, LED_FAULT_NONE when there is nothing wrong. */
led_fault_t led_poll(void);

/* The latched fault, for anything that wants to read it rather than see it. */
led_fault_t led_fault_code(void);

/* How many LEDs are wired up, for the host tools and for the docs' benefit. */
uint8_t led_count(void);

/* Names, for a crash-code table the tools can print. Indexed by fault. */
const char *led_fault_name(led_fault_t fault);

#endif /* SAGEAPPLE_LED_H */
