/*
 * sageApple — host equivalence test driver (M13).
 *
 * Replays the exact session the oracle ran in tools/rom_gen.sage:
 *   1. boot burst: 60k steps with no input
 *   2. for each command line: queue line, 60k steps, queue "\r",
 *      60k steps
 * Transcribe the UART output to stdout for a byte-exact diff against
 * avr/host_expected.txt.
 */
#include <stdio.h>
#include <string.h>
#include <stdint.h>

void cpu_reset(void);
void cpu_step(void);
uint8_t cpu_halted(void);
void hu_set_out(FILE *f);
void hu_feed(const char *s);

static void run_budget(void) {
    int32_t i;
    for (i = 0; i < 60000 && !cpu_halted(); i++) cpu_step();
}

int main(int argc, char **argv) {
    (void)argc;
    hu_set_out(stdout);
    cpu_reset();

    run_budget();                       /* boot burst (drive("")) */

    if (argc >= 2) {
        FILE *f = stdin;
        char line[96];
        if (strcmp(argv[1], "-") != 0) {
            f = fopen(argv[1], "r");
            if (!f) return 2;
        }
        while (fgets(line, sizeof line, f)) {
            size_t n = strlen(line);
            while (n && (line[n-1] == '\n' || line[n-1] == '\r')) line[--n] = 0;
            if (n == 0) continue;
            hu_feed(line);
            run_budget();
            hu_feed("\r");
            run_budget();
        }
        if (f != stdin) fclose(f);
    }
    fflush(stdout);
    return 0;
}