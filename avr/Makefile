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

DEVICE   = /dev/ttyUSB0
BAUD     = 115200
PROTO    = arduino

CFLAGS   = -mmcu=$(MC) -DF_CPU=$(B_CPU) -Os -Wall -Wextra -std=gnu11 -fno-strict-aliasing
ASFLAGS  = -mmcu=$(MC)
LDFLAGS  = -mmcu=$(MC) -T avr.ld

OBJS     = main.o start.o
ELF      = sageapple.elf

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

build-sage-boot:
	sage ../tools/avr_boot.sage

flash: sageapple.hex
	$(AVRDUDE) -p $(MC) -c $(PROTO) -P $(DEVICE) -b $(BAUD) \
	  -U flash:w:sageapple.hex:i

program-fuse:
	$(AVRDUDE) -p $(MC) -c $(PROTO) -P $(DEVICE) -b $(BAUD) \
	  -U lfuse:w:0xFF:m -U hfuse:w:0xD9:m -U efuse:w:0xFF:m

clean:
	rm -f *.o $(ELF) *.hex *.lss