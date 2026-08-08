/*
 * SageApple — host UART driver for equivalence tests against the
 * Sage reference. Byte-for-byte replays the same session the oracle
 * ran: each command (without '\r') followed by a separate '\r' burst,
 * the same 60000-step budget between bursts.
 */
#include <stdio.h>
#include <string.h>
#include <stdint.h>

#define RXCAP 512
static uint8_t rx[RXCAP];
static uint16_t rx_head = 0, rx_tail = 0;
static FILE *out = NULL;

void hu_set_out(FILE *f) { out = f; }

void hu_feed(const char *s) {
    while (*s) {
        rx[rx_tail] = (uint8_t)*s;
        rx_tail = (uint16_t)((rx_tail + 1) % RXCAP);
        s++;
    }
}

uint8_t hu_rx_ready(void) { return rx_tail != rx_head; }
uint8_t hu_rx(void) {
    if (rx_head == rx_tail) return 0;
    uint8_t c = rx[rx_head];
    rx_head = (uint16_t)((rx_head + 1) % RXCAP);
    return c;
}
void hu_tx(uint8_t c) {
    if (out) fputc(c, out);
}/* host_uart glue for bus.c */
uint8_t host_uart_rx_ready(void) { return hu_rx_ready(); }
uint8_t host_uart_rx(void) { return hu_rx(); }
void host_uart_tx(uint8_t c) { hu_tx(c); }