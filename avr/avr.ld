


OUTPUT_FORMAT("elf32-avr")
OUTPUT_ARCH(avr:5)

MEMORY
{
  text   (rx)   : ORIGIN = 0x000000, LENGTH = 32K
  data   (rw) : ORIGIN = 0x800100, LENGTH = 2K
  eeprom (rw)  : ORIGIN = 0x810000, LENGTH = 1K
  fusebits       (rw) : ORIGIN = 0, LENGTH = 1
  lockbits       (rw) : ORIGIN = 0, LENGTH = 1
  signature      (rw) : ORIGIN = 0, LENGTH = 1
  user_signatures (rw): ORIGIN = 0, LENGTH = 1
}

SECTIONS
{
  .vector 0x0000 :
  {
    _earliest_start = .;
    KEEP(*(.vector))
  } > text

  .text 0x4 :
  {
    *(.progmem*)
    KEEP(*(.init0))
    KEEP(*(.init1))
    KEEP(*(.init2))
    KEEP(*(.init3))
    KEEP(*(.init4))
    KEEP(*(.init5))
    KEEP(*(.init6))
    KEEP(*(.init7))
    KEEP(*(.init8))
    *(.text)
    *(.text.*)
    _etext = . ;
  } > text

  .data : {
    _data_start = . ;
    *(.data)
    *(.data*)
    _data_end = . ;
  } > data AT> text

  .bss : {
    _bss_start = . ;
    *(.bss)
    *(.bss*)
    *(COMMON)
    _bss_end = . ;
  } > data

  .noinit 0x800100 - 64 : {
    .noinit = . ;
    .noinit = . ;
    *(.noinit)
    KEEP(*(.s_noinit))
  } > data

  .eeprom : {
    _eeprom_start = . ;
    *(.eeprom)
    *(.eeprom*)
    _eeprom_end = . ;
  } > eeprom

  _heap_start = ALIGN(2);
  _heap_end   = 0x800100 + 2K;

  __data_start     = _data_start;
  __data_end       = _data_end;
  __data_load_start = LOADADDR(.data);
  __data_load_end   = LOADADDR(.data) + SIZEOF(.data);
  __bss_start  = _bss_start;
  __bss_end    = _bss_end;
  __heap_start = _heap_start;
  __heap_end   = _heap_end;
}