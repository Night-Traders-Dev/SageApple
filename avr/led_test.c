/*
 * SageApple -- LED language, tested on the host.
 *
 * An LED that blinks is the one thing in this firmware the transcript oracle
 * cannot check, because it never touches the serial port. Rather than ship the
 * patterns untested and leave them to be eyeballed on a board, the sequencer runs
 * here against ordinary memory standing in for the port registers (see
 * avrtest/avr/io.h), and the beat is advanced by calling the watchdog handler
 * directly. led.c is compiled unmodified.
 *
 * A pattern is checked as a string of lit and unlit beats:
 *
 *   .  one beat with the LED off
 *   #  one beat with the LED on
 *
 * Expectations are built from the stage and fault *values* rather than written
 * out beside their names. Hardcoding a count next to a name is how the first
 * version of this test came to expect one pulse for a stage that emits two, and
 * five pulses for a fault whose code is four.
 */
#include <stdio.h>
#include <string.h>

#include "avr/io.h"
#include "avr/interrupt.h"
#include "led.h"

/* The registers led.c drives. */
volatile uint8_t PORTB, DDRB, PINB;
volatile uint8_t PORTD, DDRD, PIND;
volatile uint8_t MCUSR;
volatile uint8_t UCSR0A, UCSR0B, UCSR0C;
volatile uint8_t UBRR0H, UBRR0L;
volatile uint8_t WDTCSR;

static int failures = 0;
static int passes = 0;

static void check(int cond, const char *msg) {
    if (cond) { passes++; printf("  PASS: %s\n", msg); }
    else      { failures++; printf("  FAIL: %s\n", msg); }
}

/* D13 is PORTB5 and the LED is active low, so lit means the bit is clear. */
static int led_lit(void) { return (PORTB & (1 << PORTB5)) == 0; }

/* The beat constants, restated here so the test is checking the numbers it
   documents rather than trusting the implementation to agree with itself. */
#define T_SHORT_PULSE  2
#define T_LONG_PULSE   6
#define T_BETWEEN      2
#define T_GROUP_GAP    8

/* Run n beats, recording the pattern as it goes. */
static void trace(int beats, char *out, int cap) {
    int i;
    for (i = 0; i < beats && i < cap - 1; i++) {
        out[i] = led_lit() ? '#' : '.';
        WDT_vect();
    }
    out[i] = '\0';
}

static char last_pattern[1024];

/* The pattern a group of `count` pulses should make: each `pulse` beats lit, a
   short gap between pulses, and a long gap after the group.
 *
 * The trailing gap is part of the expectation on purpose. Leaving it out meant
 * nothing asserted its length, so shortening it to the between-pulse gap still
 * passed every check here -- the pulses were unchanged and the extra dots were
 * simply never compared. */
static void expect_group(char *out, int cap, unsigned count, unsigned pulse) {
    int n = 0;
    unsigned i;
    for (i = 0; i < count && n < cap - 1; i++) {
        unsigned b;
        if (i) {
            if (n < cap - 1) { out[n++] = '.'; }
            if (n < cap - 1) { out[n++] = '.'; }
        }
        for (b = 0; b < pulse && n < cap - 1; b++) { out[n++] = '#'; }
    }
    for (i = 0; i < T_GROUP_GAP && n < cap - 1; i++) { out[n++] = '.'; }
    out[n] = '\0';
}

static void check_pat(const char *want, const char *msg) {
    if (strncmp(last_pattern, want, strlen(want)) == 0) {
        passes++; printf("  PASS: %s\n", msg);
    } else {
        failures++;
        printf("  FAIL: %s\n", msg);
        printf("        want: %s\n", want);
        printf("        got : %s\n", last_pattern);
    }
}

/* Does the trace contain the same group more than once? That is what "it
   repeats" means, and it cannot be checked by aligning the start of a window. */
static void check_repeats(const char *group, const char *msg) {
    const char *first = strstr(last_pattern, group);
    if (first && strstr(first + 1, group)) { passes++; printf("  PASS: %s\n", msg); }
    else {
        failures++;
        printf("  FAIL: %s\n", msg);
        printf("        group: %s\n", group);
        printf("        got  : %s\n", last_pattern);
    }
}

static void quiet(void) {
    char sink[1024];
    trace(96, sink, (int)sizeof(sink));
}

/* --dump prints one pattern per line as "name<TAB>beats", for diffing against
   led_decode.py. The decoder is a separate implementation of the same language,
   and the two agreeing is the only reason to trust either of them. */
static int dump_mode = 0;

static void dump(const char *name, const char *pat) {
    if (dump_mode) { printf("%s\t%s\n", name, pat); }
}

int main(int argc, char **argv) {
    char pat[1024];
    char want[1024];

    if (argc > 1 && strcmp(argv[1], "--dump") == 0) { dump_mode = 1; }

    printf("== power-on: dark until a stage lands, and not a fault ==\n");
    MCUSR = 0;                        /* an ordinary power-on */
    led_init();
    quiet();
    check(!led_lit(), "nothing is lit before any stage completes");
    check(led_fault_code() == LED_FAULT_NONE, "a power-on is not reported as a fault");
    check(led_count() == 1, "this build has one LED, so the single-LED language is in use");

    printf("== a stage completing is a burst one pulse longer each time ==\n");
    check(LED_STAGE_POWER + 1 == 1 && LED_STAGE_UART + 1 == 2
          && LED_STAGE_CPU + 1 == 3 && LED_STAGE_MONITOR + 1 == 4,
          "a stage's burst is stage + 1 pulses, so the counts ascend");

    led_stage_done(LED_STAGE_UART);
    trace(40, pat, (int)sizeof(pat));
    dump("stage UART", pat);
    snprintf(last_pattern, sizeof(last_pattern), "%s", pat);
    expect_group(want, (int)sizeof(want), (unsigned)LED_STAGE_UART + 1u, T_SHORT_PULSE);
    check_pat(want, "stage UART shows its burst, then a long gap");

    led_stage_done(LED_STAGE_CPU);
    trace(44, pat, (int)sizeof(pat));
    dump("stage CPU", pat);
    snprintf(last_pattern, sizeof(last_pattern), "%s", pat);
    expect_group(want, (int)sizeof(want), (unsigned)LED_STAGE_CPU + 1u, T_SHORT_PULSE);
    check_pat(want, "stage CPU shows one more pulse than UART");

    led_stage_done(LED_STAGE_MONITOR);
    trace(48, pat, (int)sizeof(pat));
    dump("stage MONITOR", pat);
    snprintf(last_pattern, sizeof(last_pattern), "%s", pat);
    expect_group(want, (int)sizeof(want), (unsigned)LED_STAGE_MONITOR + 1u, T_SHORT_PULSE);
    check_pat(want, "stage MONITOR shows the longest boot burst");

    quiet();
    check(!led_lit(), "the LED goes dark once the boot pattern has been shown");

    printf("== idle is a steady light ==\n");
    led_idle();
    trace(24, pat, (int)sizeof(pat));
    check(strspn(pat, "#") == 24, "idle holds the LED on");

    printf("== a fault is that many long pulses, and the group repeats ==\n");
    MCUSR = 0; led_init();
    led_fault(LED_FAULT_WATCHDOG);
    trace(64, pat, (int)sizeof(pat));
    { char nm[16]; snprintf(nm, sizeof(nm), "fault %u", (unsigned)LED_FAULT_WATCHDOG); dump(nm, pat); }
    MCUSR = 0; led_init();
    led_fault(LED_FAULT_WATCHDOG);
    snprintf(last_pattern, sizeof(last_pattern), "%s", pat);
    expect_group(want, (int)sizeof(want), (unsigned)LED_FAULT_WATCHDOG, T_LONG_PULSE);
    check_pat(want, "a fault's group is as many long pulses as the code");
    check_repeats(want, "the fault group repeats after its long gap rather than showing once");

    check(led_fault_code() == LED_FAULT_WATCHDOG, "the fault is latched for reading");
    led_fault(LED_FAULT_BROWNOUT);
    check(led_fault_code() == LED_FAULT_WATCHDOG, "a second fault does not displace the first");

    printf("== a longer code is a longer group of the same pulses ==\n");
    MCUSR = 0;
    led_init();
    led_fault(LED_FAULT_UART_FRAMING);
    trace(80, pat, (int)sizeof(pat));
    { char nm[16]; snprintf(nm, sizeof(nm), "fault %u", (unsigned)LED_FAULT_UART_FRAMING); dump(nm, pat); }
    snprintf(last_pattern, sizeof(last_pattern), "%s", pat);
    expect_group(want, (int)sizeof(want), (unsigned)LED_FAULT_UART_FRAMING, T_LONG_PULSE);
    check_pat(want, "a higher code is a longer group of the same long pulses");
    check(LED_FAULT_UART_FRAMING == 5, "and the framing fault is indeed the fifth code");

    printf("== an abnormal reset is reported on the next boot without being told ==\n");
    MCUSR = (uint8_t)(1 << BORF);
    led_init();
    check(led_fault_code() == LED_FAULT_BROWNOUT, "a brownout in MCUSR becomes the fault");
    trace(16, pat, (int)sizeof(pat));
    snprintf(last_pattern, sizeof(last_pattern), "%s", pat);
    check_pat("######", "a fault is lit from the first beat, for its full length");

    MCUSR = (uint8_t)(1 << WDRF);
    led_init();
    check(led_fault_code() == LED_FAULT_WATCHDOG, "a watchdog reset in MCUSR has its own code");

    MCUSR = (uint8_t)(1 << EXTRF);
    led_init();
    check(led_fault_code() == LED_FAULT_EXTERNAL, "an external reset has its own code");

    MCUSR = 0;
    led_init();
    check(led_fault_code() == LED_FAULT_NONE, "a plain power-on after a fault is clean again");

    printf("== serial faults are latched from the status register ==\n");
    MCUSR = 0;
    led_init();
    led_idle();
    UCSR0A = (uint8_t)(1 << DOR0);
    check(led_poll() == LED_FAULT_UART_OVERRUN, "a data overrun is noticed by led_poll");
    UCSR0A = 0;
    check(led_poll() == LED_FAULT_UART_OVERRUN, "and stays latched once the flag clears");

    MCUSR = 0;
    led_init();
    led_idle();
    UCSR0A = (uint8_t)(1 << FE0);
    check(led_poll() == LED_FAULT_UART_FRAMING, "a framing error is noticed by led_poll");

    MCUSR = 0;
    led_init();
    UCSR0A = 0;
    check(led_poll() == LED_FAULT_NONE, "a clean port reports no fault");

    printf("== the driver names its own faults ==\n");
    check(strcmp(led_fault_name(LED_FAULT_BROWNOUT), "brownout") == 0, "brownout has a name");
    check(strcmp(led_fault_name(LED_FAULT_WATCHDOG), "watchdog") == 0, "watchdog has a name");
    check(strcmp(led_fault_name(LED_FAULT_EXTERNAL), "external-reset") == 0, "external reset has a name");
    check(strcmp(led_fault_name(LED_FAULT_UART_OVERRUN), "uart-overrun") == 0, "overrun has a name");
    check(strcmp(led_fault_name(LED_FAULT_UART_FRAMING), "uart-framing") == 0, "framing has a name");
    check(strcmp(led_fault_name(LED_FAULT_NONE), "none") == 0, "no fault has a name");

    printf("== passing no fault does nothing ==\n");
    MCUSR = 0;
    led_init();
    led_fault(LED_FAULT_NONE);
    check(led_fault_code() == LED_FAULT_NONE, "LED_FAULT_NONE is not latched");

    if (dump_mode) { return failures ? 1 : 0; }
    printf("\nLED language: %d passed, %d failed\n", passes, failures);
    return failures ? 1 : 0;
}
