#include <stdint.h>
#include <stdio.h>
#include <string.h>

void cpu_reset(void);
void cpu_step(void);
uint8_t cpu_halted(void);
uint16_t cpu_pc(void);
void bus_reset(void);
uint8_t bus_read(uint16_t address);
void bus_write(uint16_t address, uint8_t value);

#define HOST_RX_CAPACITY 64
#define HOST_TX_CAPACITY 256

static uint8_t rx_fifo[HOST_RX_CAPACITY];
static uint8_t rx_head;
static uint8_t rx_tail;
static uint8_t tx_bytes[HOST_TX_CAPACITY];
static size_t tx_length;

uint8_t host_uart_rx_ready(void) {
    return rx_head != rx_tail;
}

uint8_t host_uart_rx(void) {
    uint8_t value;
    if (rx_head == rx_tail) {
        return 0;
    }
    value = rx_fifo[rx_head];
    rx_head = (uint8_t)((rx_head + 1) % HOST_RX_CAPACITY);
    return value;
}

void host_uart_tx(uint8_t value) {
    if (tx_length < HOST_TX_CAPACITY) {
        tx_bytes[tx_length++] = value;
    }
}

static void host_uart_feed(uint8_t value) {
    uint8_t next = (uint8_t)((rx_tail + 1) % HOST_RX_CAPACITY);
    if (next != rx_head) {
        rx_fifo[rx_tail] = value;
        rx_tail = next;
    }
}

static void run_steps(uint32_t count) {
    uint32_t i;
    for (i = 0; i < count && !cpu_halted(); i++) {
        cpu_step();
    }
}

static int check(int condition, const char *name) {
    if (condition) {
        printf("PASS: %s\n", name);
        return 0;
    }
    printf("FAIL: %s\n", name);
    return 1;
}

static int run_keyboard_checks(void) {
    int failures = 0;
    bus_reset();
    failures += check(bus_read(0xC010) == 0x00,
                      "C010 reports no keyboard key before UART input");
    host_uart_feed('a');
    failures += check(bus_read(0xC010) == 0x80,
                      "C010 polls an encoded UART keyboard key");
    failures += check(bus_read(0xC000) == 0x41,
                      "C000 retains the encoded A key data");
    failures += check(bus_read(0xC000) == 0x41,
                      "C000 remains stable after acknowledgement");
    failures += check(bus_read(0xC010) == 0x00,
                      "C010 read acknowledges the current key");

    host_uart_feed('B');
    failures += check(bus_read(0xC010) == 0x80,
                      "C010 polls a second encoded UART key");
    failures += check(bus_read(0xC000) == 0x42,
                      "C000 retains the encoded B key data");
    bus_write(0xC010, 0x00);
    failures += check(bus_read(0xC000) == 0x42,
                      "C010 write acknowledges and clears the latch");
    failures += check(bus_read(0xC010) == 0x00,
                      "C010 write leaves no pending key");

    host_uart_feed('0');
    host_uart_feed(' ');
    host_uart_feed('\r');
    failures += check(bus_read(0xC010) == 0x80 &&
                      bus_read(0xC000) == 0x30,
                      "keyboard UART order starts with encoded zero");
    failures += check(bus_read(0xC010) == 0x80 &&
                      bus_read(0xC000) == 0x20,
                      "keyboard UART order advances to space");
    failures += check(bus_read(0xC010) == 0x80 &&
                      bus_read(0xC000) == 0x0D,
                      "keyboard UART order advances to return");
    failures += check(bus_read(0xC010) == 0x00,
                      "C010 read acknowledges the return key");

    host_uart_feed('Q');
    failures += check(bus_read(0xC081) == 0xD1,
                      "C081 retains direct serial input");
    return failures;
}

static int run_banking_checks(void) {
    uint8_t rom_d000;
    int failures = 0;
    bus_reset();
    rom_d000 = bus_read(0xD000);
    bus_write(0xD000, 0x3C);
    failures += check(bus_read(0xD000) == rom_d000,
                      "language card starts in ROM read mode");
    bus_read(0xC300);
    bus_write(0xD000, 0xA1);
    failures += check(bus_read(0xD000) == 0x00,
                      "C300 read RAM mode rejects writes");
    bus_read(0xC302);
    failures += check(bus_read(0xD000) == rom_d000,
                      "C302 keeps ROM reads visible");
    bus_write(0xD000, 0xB2);
    bus_read(0xC300);
    failures += check(bus_read(0xD000) == 0xB2,
                      "C300 exposes prewritten bank 1 RAM");
    bus_read(0xC303);
    bus_write(0xD000, 0x55);
    failures += check(bus_read(0xD000) == rom_d000,
                      "C303 keeps RAM write-protected");
    bus_read(0xC308);
    failures += check(bus_read(0xD000) == 0x3C,
                      "C308 selects the second bank");
    bus_read(0xC300);
    failures += check(bus_read(0xD000) == 0xB2,
                      "language card banks remain independent");
    bus_read(0xC301);
    bus_read(0xC301);
    bus_write(0xE000, 0xD4);
    bus_read(0xC300);
    failures += check(bus_read(0xE000) == 0xD4,
                      "shared language-card RAM is writable");
    return failures;
}

int main(void) {
    static const uint8_t signature[] = {
        0x41, 0x32, 0x0D, 0x0A, 0x48, 0x49, 0x0D, 0x0A
    };
    int failures = 0;

    bus_reset();
    cpu_reset();
    failures += check(cpu_pc() == 0xD000, "reset PC is $D000");

    run_steps(200);
    failures += check(tx_length == sizeof(signature) &&
                      memcmp(tx_bytes, signature, sizeof(signature)) == 0,
                      "serial signature is A2\\r\\nHI\\r\\n");
    failures += run_keyboard_checks();

    host_uart_feed('X');
    run_steps(2000);
    failures += check(tx_length == sizeof(signature) + 1 &&
                      tx_bytes[sizeof(signature)] == 'X',
                      "serial input is echoed");
    failures += run_banking_checks();

    if (failures != 0) {
        printf("APPLE2 HOST TEST FAILED\n");
        return 1;
    }
    printf("APPLE2 HOST TEST OK\n");
    return 0;
}
