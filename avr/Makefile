# SageApple — ATmega328P build (avr-gcc) + flash workflow (PLAN.md M4)
#
#   make            build sageapple.hex
#   make program    flash via serial bootloader (avrdude)
#   make fuse       set device fuses
#   make clean

MC       = atmega328p
B_CPU    = 16000000UL
CC       = avr-gcc
OBJCOPY  = avr-objcopy
OBJDUMP  = avr-objdump
SIZE     = avr-size
AVRDUDE  = avrdude

# Serial port used for flashing. Auto-detected from the attached boards; the
# command line still wins, e.g. `make flash DEVICE=/dev/ttyUSB1`.
PORT_GUESS := $(firstword $(wildcard /dev/ttyUSB*) $(wildcard /dev/ttyACM*))
DEVICE   ?= $(if $(PORT_GUESS),$(PORT_GUESS),/dev/ttyUSB0)
BAUD     = 115200
PROTO    = arduino

# Clone STK500v1 bootloaders drop sync mid-transfer often enough that a single
# avrdude run failing is not evidence the write failed. Retry before giving up.
FLASH_RETRIES ?= 4

AVRDUDE_FLAGS = -p $(MC) -c $(PROTO) -P $(DEVICE) -b $(BAUD)

# $(1) = hex file to write. Retries the whole write-and-verify cycle.
define do_flash
@i=1; while [ $$i -le $(FLASH_RETRIES) ]; do \
	if $(AVRDUDE) $(AVRDUDE_FLAGS) -U flash:w:$(1):i; then exit 0; fi; \
	echo "  attempt $$i/$(FLASH_RETRIES) failed, retrying in 2s"; \
	i=$$((i+1)); sleep 2; \
    done; \
    echo "FLASH FAILED after $(FLASH_RETRIES) attempts on $(DEVICE)"; exit 1
endef

# $(1) = hex file that was written. Reads the chip back in a *fresh* avrdude
# session -- the verify inside a write session shares the same link that can
# drop sync, which is how a stale image survives a "successful" flash.
# $(2) = scratch file for the readback.
define do_verify
	$(AVRDUDE) $(AVRDUDE_FLAGS) -q -U flash:r:$(2):i
	python3 tools_verify.py $(1) $(2)
endef

CFLAGS   = -mmcu=$(MC) -DF_CPU=$(B_CPU) -Os -Wall -Wextra -std=gnu11 -fno-strict-aliasing
ASFLAGS  = -mmcu=$(MC)
LDFLAGS  = -mmcu=$(MC) -T avr.ld

OBJS     = main.o sage6502.o bus.o rom_avr.o
ELF      = sageapple.elf
SAGE     = sage-c
HOST_CC  = gcc
HOST_CFLAGS = -O2 -DHOST -Wall -Wextra -std=gnu11
APPLE2_OBJS = main.o sage6502.o bus_apple2.o rom_apple2.o
APPLE2_ELF = apple2.elf
APPLE2_HEX = apple2.hex
APPLE2_HOST = apple2_host_test

.PHONY: apple2 apple2-gen apple2-host apple2-host-test apple2-flash
.PHONY: verify chip-test apple2-chip-test flash-clean

all: $(ELF) sageapple.hex
	$(SIZE) $(ELF)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.S
	$(CC) $(ASFLAGS) -c -o $@ $<

$(ELF): $(OBJS) avr.ld
	$(CC) $(LDFLAGS) -o $@ $(OBJS)

sageapple.hex: $(ELF)
	$(OBJCOPY) -O ihex -R .eeprom $< $@
	$(OBJDUMP) -d $< > sageapple.lss

$(APPLE2_ELF): apple2-gen $(APPLE2_OBJS) avr.ld
	$(CC) $(LDFLAGS) -o $@ $(APPLE2_OBJS)

$(APPLE2_HEX): $(APPLE2_ELF)
	$(OBJCOPY) -O ihex -R .eeprom $< $@
	$(OBJDUMP) -d $< > apple2.lss

apple2-gen:
	$(SAGE) ../tools/apple2_rom_gen.sage --out=rom_apple2.c

apple2: apple2-gen $(APPLE2_HEX)
	$(SIZE) $(APPLE2_ELF)

apple2-host: apple2-gen
	$(HOST_CC) $(HOST_CFLAGS) -o $(APPLE2_HOST) sage6502.c bus_apple2.c rom_apple2.c apple2_host_main.c

apple2-host-test: apple2-host
	./$(APPLE2_HOST)

apple2-flash: apple2
	$(call do_flash,$(APPLE2_HEX))

# Written by `make verify`; excluded from version control by .gitignore.
READBACK = /tmp/sageapple_readback.hex
APPLE2_READBACK = /tmp/apple2_readback.hex

# First byte of the bootloader on the clone boards. Nothing below this is the
# bootloader, so padding an image out to here is safe.
BOOT_START ?= 0x7E00

build-sage-boot:
	sage ../tools/avr_boot.sage

rom:
	sage ../tools/rom_gen.sage

host: rom_host.c host_cmds.txt
	gcc -O2 -DHOST -o host_test sage6502.c bus.c rom_host.c host_uart.c host_main.c

# Independent check that flash really holds what we just built.
verify: sageapple.hex
	$(call do_verify,sageapple.hex,$(READBACK))

# Flash, read back, then drive the board and diff its transcript against the
# host oracle.
chip-test: sageapple.hex
	$(call do_flash,sageapple.hex)
	$(call do_verify,sageapple.hex,$(READBACK))
	python3 chip_test.py $(CHIP_TEST_ARGS)

# The same for the reduced Apple II profile. Its boot signature is "A2\r\nHI"
# rather than a monitor banner, and the only interaction is a keypress, so the
# oracle is a single command and a configurable banner.
apple2_expected.txt: apple2-host
	./$(APPLE2_HOST) --dump > $@

apple2-chip-test: apple2.hex apple2_expected.txt
	$(call do_flash,$(APPLE2_HEX))
	$(call do_verify,$(APPLE2_HEX),$(APPLE2_READBACK))
	python3 chip_test.py --banner=A2 --cmds apple2_cmds.txt \
	  --expected apple2_expected.txt --terminator= $(CHIP_TEST_ARGS)

# Some clone STK500v1 bootloaders do not erase the whole chip when writing, so a
# plain flash can leave 0x00 fill or fragments of a previously larger image
# above the new one. Padding the image out to the bootloader makes avrdude
# touch every page below it, which erases them.
sageapple_padded.hex: sageapple.elf
	$(OBJCOPY) --gap-fill 0xff --pad-to $(BOOT_START) -O ihex -R .eeprom $< $@

flash-clean: sageapple_padded.hex
	$(call do_flash,sageapple_padded.hex)

host-test: host
	./host_test host_cmds.txt > host_out.txt
	diff host_out.txt host_expected.txt && echo "HOST EQUIVALENCE OK"

flash: sageapple.hex
	$(call do_flash,sageapple.hex)

program-fuse:
	$(AVRDUDE) -p $(MC) -c $(PROTO) -P $(DEVICE) -b $(BAUD) \
	  -U lfuse:w:0xFF:m -U hfuse:w:0xD9:m -U efuse:w:0xFF:m

clean:
	rm -f *.o $(ELF) *.hex *.lss $(APPLE2_ELF) $(APPLE2_HOST) apple2_expected.txt
