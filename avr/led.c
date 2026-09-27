/*
 * SageApple -- boot, status and fault signalling by LED
 *
 * See led.h for the two languages. Everything time-based happens in the
 * watchdog interrupt, so nothing here blocks: the main loop is a 6502
 * emulator and the serial path, and neither can afford to wait on a blink.
 *
 * The watchdog is used as a free-running beat source rather than as a reset
 * watchdog. That is deliberate -- the AVR has no other timer worth spending on
 * an 8MHz part emulating a 1MHz 6502 -- but it means this driver must keep
 * servicing it, and a fault that stopped the beat would look like a watchdog
 * reset on the next boot. Nothing here can block for that reason.
 */
#include "led.h"

#include <avr/io.h>
#include <avr/interrupt.h>

/* ---------------------------------------------------------------------------
 * One beat, and the pulse shapes built from it
 *
 * WDP=0100 divides the 128kHz watchdog oscillator by 8, giving a 125ms beat.
 * A short pulse is one beat, a long pulse three, and a group is followed by a
 * four beat gap. A short pulse is therefore a 125ms flash and the shortest gap
 * is 500ms, which is readable across a room and distinguishable by eye at any
 * distance: the ratio between a long pulse and the gap inside its group is
 * three to one, and a long pulse is three times a short one.
 * ------------------------------------------------------------------------ */
#define BEAT_PULSE_SHORT  2u   /* a short pulse: 250ms on  */
#define BEAT_PULSE_LONG   6u   /* a long pulse:  750ms on  */
#define BEAT_BETWEEN      2u   /* gap inside a group       */
#define BEAT_GROUP_GAP    8u   /* gap after a group: 1s    */

/* Where the LEDs are. Index 0 is the built-in on D13; the rest are on pins this
   firmware does not otherwise use. A build that wires only LED0 runs the
   single-LED language. */
#define LED_MAX 4

typedef struct {
    volatile uint8_t *port;
    volatile uint8_t *ddr;
    volatile uint8_t *pin;     /* active low: writing 1 to the pin lights it */
    uint8_t bit;
} led_pin_t;

/* D13 is PORTB5; D2..D4 are PORTD2..D4. */
static const led_pin_t LED_PINS[LED_MAX] = {
    { &PORTB, &DDRB, &PINB,  PORTB5 },
    { &PORTD, &DDRD, &PIND,  PORTD2 },
    { &PORTD, &DDRD, &PIND,  PORTD3 },
    { &PORTD, &DDRD, &PIND,  PORTD4 },
};

/* How many are actually wired. A stock Nano or Uno R3 sets 1, because D0 and D1
   belong to the UART and cannot serve as indicators without fighting the serial
   port, and the Uno's ON LED is hardwired to the supply. */
#ifndef LED_COUNT
#define LED_COUNT 1
#endif

/* ---------------------------------------------------------------------------
 * State
 * ------------------------------------------------------------------------ */
static uint8_t led_n;                       /* LEDs actually in use        */
static led_visual_t led_state[LED_STAGE_COUNT];

static volatile led_fault_t led_fault_latched = LED_FAULT_NONE;
static led_fault_t led_fault_now = LED_FAULT_NONE;
static uint8_t reset_cause;
static volatile uint8_t monitor_seen;   /* the ROM has spoken on serial */

/* Single-LED sequencer.
 *
 * One phase at a time, never two: a pulse and a gap used to be tracked by two
 * live counters, and re-arming the pulse in the same beat that started the gap
 * meant the pin was painted from whichever counter happened to be non-zero. A
 * "short" pulse ran five beats and a fault was solid on.
 *
 * The phases also separate the two gaps, which have to look different: two
 * beats between pulses inside a group, eight after the group. A long pulse is
 * six beats against an inside-the-group gap of two, so the three are told apart
 * by eye without needing to time anything. */
#define LED_PH_IDLE   0   /* dark: a boot pattern has been shown and ended */
#define LED_PH_PULSE  1   /* lit                                          */
#define LED_PH_GAP    2   /* dark, counting down to the next group        */

#define LED_MODE_IDLE    0   /* steadily lit: booted and healthy */
#define LED_MODE_PATTERN 1   /* following the phases            */

static volatile uint8_t seq_mode;
static volatile uint8_t seq_phase;
static volatile uint8_t seq_pulse;   /* beats left lit          */
static volatile uint8_t seq_beats;   /* length of one pulse     */
static volatile uint8_t seq_left;    /* pulses left this group  */
static volatile uint8_t seq_gap;     /* beats of gap remaining  */
static volatile uint8_t seq_repeat;  /* group length, or 0 to show once */

/* Multi-LED flash phase, so in-progress LEDs blink rather than sitting solid. */
static volatile uint8_t flash_phase;

/* Active low on both boards: clearing the pin lights the LED. */
static inline void led_write(const led_pin_t *p, uint8_t on) {
    if (on) { *p->port &= (uint8_t)~(1 << p->bit); }
    else    { *p->port |=  (uint8_t)(1 << p->bit); }
}

/* Paint the single LED from the current phase. */
static void led_paint_single(void) {
    uint8_t on;
    if (seq_mode == LED_MODE_IDLE) {
        on = 1u;
    } else {
        on = (uint8_t)(seq_phase == LED_PH_PULSE);
    }
    led_write(&LED_PINS[0], on);
}

/* Paint every LED from the progress array. Called once per beat, so a LED left
   in LED_FLASH alternates. */
static void led_paint_multi(void) {
    uint8_t i;
    uint8_t flash_on = (uint8_t)(flash_phase & 1u);
    for (i = 0; i < led_n && i < LED_STAGE_COUNT; i++) {
        uint8_t on;
        switch (led_state[i]) {
            case LED_SOLID: on = 1u; break;
            case LED_FLASH: on = flash_on; break;
            case LED_FAULT: on = (uint8_t)(flash_phase & 1u); break;
            default:        on = 0u; break;   /* LED_OFF */
        }
        led_write(&LED_PINS[i], on);
    }
}

/* ---------------------------------------------------------------------------
 * The beat timer
 * ------------------------------------------------------------------------ */
ISR(WDT_vect) {
    if (led_n == 1u) {
        if (seq_mode == LED_MODE_PATTERN) {
            if (seq_phase == LED_PH_PULSE) {
                if (seq_pulse) {
                    seq_pulse--;
                }
                if (seq_pulse == 0u) {
                    if (seq_left > 1u) {
                        /* another pulse to come in this group: short gap */
                        seq_left--;
                        seq_gap   = BEAT_BETWEEN;
                        seq_phase = LED_PH_GAP;
                    } else {
                        /* the group is finished: long gap before any repeat */
                        seq_left  = 0;
                        seq_gap   = BEAT_GROUP_GAP;
                        seq_phase = LED_PH_GAP;
                    }
                }
            } else if (seq_phase == LED_PH_GAP) {
                if (seq_gap) {
                    seq_gap--;
                }
                if (seq_gap == 0u) {
                    if (seq_left) {
                        /* still inside the group: another pulse */
                        seq_pulse = seq_beats;
                        seq_phase = LED_PH_PULSE;
                    } else if (seq_repeat) {
                        /* the group completed and is to repeat: fault codes */
                        seq_left  = seq_repeat;
                        seq_pulse = seq_beats;
                        seq_phase = LED_PH_PULSE;
                    } else {
                        /* shown once and done: dark from here, which is how a
                           boot that stopped after this stage reads */
                        seq_phase = LED_PH_IDLE;
                    }
                }
            }
        }
        led_paint_single();
    } else {
        flash_phase++;
        led_paint_multi();
    }
}

/* Arm a pattern. beats is the pulse length, count the number of pulses, and
   repeat the group that many times forever when nonzero. */
static void led_arm(uint8_t beats, uint8_t count, uint8_t repeat) {
    seq_mode   = LED_MODE_PATTERN;
    seq_beats  = beats;
    seq_left   = count;
    seq_repeat = repeat;
    seq_pulse  = beats;
    seq_gap    = 0;
    seq_phase  = LED_PH_PULSE;
    led_paint_single();
}

static void led_timer_start(void) {
    /* Interrupt only, never a reset. The WDRF bit is reserved for latching a
       genuine watchdog reset as a fault, so this must never set it. */
    WDTCSR = (1 << WDCE) | (1 << WDE);
    WDTCSR = (1 << WDIE) | (1 << WDP2);
}

/* ---------------------------------------------------------------------------
 * Public interface
 * ------------------------------------------------------------------------ */
void led_init(void) {
    /* Latch the reset source before anything can disturb it. MCUSR is read once
       and its bits clear by writing a 1 to them. */
    reset_cause = MCUSR;

    /* Clear anything latched last time. Without this the first fault of the
       first boot sticks forever and every later boot reports that one, because
       led_fault() keeps the first fault and nothing ever resets the latch. */
    led_fault_latched = LED_FAULT_NONE;
    led_fault_now = LED_FAULT_NONE;

    led_n = (uint8_t)(LED_COUNT > LED_MAX ? LED_MAX : LED_COUNT);

    uint8_t i;
    for (i = 0; i < led_n; i++) {
        *LED_PINS[i].ddr  |= (uint8_t)(1 << LED_PINS[i].bit);
        *LED_PINS[i].port |= (uint8_t)(1 << LED_PINS[i].bit);   /* off */
        led_state[i] = LED_OFF;
    }
    flash_phase = 0;
    monitor_seen = 0;
    seq_mode   = LED_MODE_PATTERN;
    seq_phase  = LED_PH_IDLE;
    seq_pulse  = 0;
    seq_left   = 0;
    seq_gap    = 0;
    seq_repeat = 0;
    seq_beats  = BEAT_PULSE_SHORT;

    led_timer_start();

    /* An abnormal reset is worth showing straight away: a board that rebooted on
       a watchdog or a brownout should say so on this boot rather than look like
       a normal one. A plain power-on is not a fault. */
    if (reset_cause & (1 << BORF))      { led_fault(LED_FAULT_BROWNOUT); }
    else if (reset_cause & (1 << WDRF)) { led_fault(LED_FAULT_WATCHDOG); }
    else if (reset_cause & (1 << EXTRF)) { led_fault(LED_FAULT_EXTERNAL); }
}

uint8_t led_count(void) { return led_n; }

led_fault_t led_fault_code(void) { return led_fault_latched; }

void led_stage_enter(led_stage_t stage) {
    if (stage >= LED_STAGE_COUNT) { return; }
    if (led_n == 1u) { return; }   /* the single-LED view is driven by completions */
    led_state[stage] = LED_FLASH;
}

void led_stage_done(led_stage_t stage) {
    if (stage >= LED_STAGE_COUNT) { return; }
    if (stage == LED_STAGE_MONITOR) { monitor_seen = 1; }
    if (led_n == 1u) {
        /* On one LED, completing a stage is the event worth showing: N short
           pulses, N being the stage just finished counting from 1. */
        led_arm(BEAT_PULSE_SHORT, (uint8_t)(stage + 1), 0);
        return;
    }
    led_state[stage] = LED_SOLID;
}

uint8_t led_stage_is_done(led_stage_t stage) {
    if (stage >= LED_STAGE_COUNT) { return 0; }
    if (led_n != 1u) { return (uint8_t)(led_state[stage] == LED_SOLID); }
    /* With one LED there is no per-stage state, so a separate latch. The stages
       that are announced synchronously are already done by the time anyone asks;
       this exists for the monitor banner, which is observed rather than told. */
    if (stage == LED_STAGE_MONITOR) { return monitor_seen; }
    return 1;
}

void led_idle(void) {
    if (led_n == 1u) {
        seq_mode = LED_MODE_IDLE;
        led_write(&LED_PINS[0], 1);
        return;
    }
    uint8_t i;
    for (i = 0; i < led_n && i < LED_STAGE_COUNT; i++) {
        led_state[i] = LED_SOLID;
    }
    led_paint_multi();
}

void led_fault(led_fault_t fault) {
    if (fault == LED_FAULT_NONE || fault >= LED_FAULT_COUNT) { return; }
    /* First fault wins: one arriving while another is being handled is a
       consequence of it, and reporting both would only add noise. */
    if (led_fault_latched != LED_FAULT_NONE) { return; }
    led_fault_latched = fault;

    if (led_n == 1u) {
        /* The code is both the number of pulses in the group and the number of
           times that group repeats. */
        led_arm(BEAT_PULSE_LONG, (uint8_t)fault, (uint8_t)fault);
    } else {
        /* The LED for the failing stage marks it; the rest go dark so the
           failing stage is unambiguous. */
        uint8_t i;
        for (i = 0; i < led_n; i++) { led_state[i] = LED_OFF; }
        if (fault < led_n) { led_state[fault] = LED_FAULT; }
        led_paint_multi();
    }
}

led_fault_t led_poll(void) {
    /* Serial faults are latched rather than sampled: an overrun has already lost
       a byte by the time it can be read, so noticing it late is the only
       option. */
    if (led_fault_latched == LED_FAULT_NONE) {
        if (UCSR0A & (1 << DOR0))      { led_fault(LED_FAULT_UART_OVERRUN); }
        else if (UCSR0A & (1 << FE0))  { led_fault(LED_FAULT_UART_FRAMING); }
    }
    led_fault_now = led_fault_latched;
    return led_fault_now;
}

const char *led_fault_name(led_fault_t fault) {
    switch (fault) {
        case LED_FAULT_NONE:          return "none";
        case LED_FAULT_BROWNOUT:      return "brownout";
        case LED_FAULT_WATCHDOG:      return "watchdog";
        case LED_FAULT_EXTERNAL:      return "external-reset";
        case LED_FAULT_UART_OVERRUN:  return "uart-overrun";
        case LED_FAULT_UART_FRAMING:  return "uart-framing";
        default:                      return "unknown";
    }
}
