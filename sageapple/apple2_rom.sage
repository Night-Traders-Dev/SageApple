import compiler.asm6502

## The language card's own 12 KiB ROM, covering $D000-$F7FF. The main ROM only
## occupies $F800-$FFFF, so a card in ROM mode has to supply this range itself
## rather than borrowing the firmware.
##
## What lives in it is a signature program at $D000, which is the honest minimum:
## it identifies the card, and the rest is zero rather than pretending to be
## something. A guest can therefore tell a card from no card, which is the whole
## point of switching the card to read-ROM.
proc build_card():
    let card_source = [
        "org $D000",
        "; --- language card signature ---",
        "    LDA #$A2",
        "    STA $C080",
        "    LDA #$4C",
        "    STA $C080",
        "    LDA #$43",
        "    STA $C080",
        "    LDA #$0D",
        "    STA $C080",
        "    LDA #$0A",
        "    STA $C080",
        "; --- the card is 4 KiB at $D000 and 8 KiB at $E000 ---",
        "    LDA #$01",
        "    STA $C300",
        "idle:",
        "    JMP idle",
    ]
    let code = asm6502.asm(card_source, 0xD000)[0]
    var card_rom = []
    var i = 0
    while i < 0x3000:
        push(card_rom, 0x00)
        i = i + 1
    i = 0
    while i < len(code) and i < 0x3000:
        card_rom[i] = code[i] & 0xFF
        i = i + 1
    return card_rom


proc build():
    let source = [
        "org $D000",
        "; --- publish the autostart entry in the boot vector at $3F4 ---",
        "; Real firmware does this, and RESET reads it to decide where to jump.",
        "; $3F4 is inside the write-protected $0200-$03FF page, so RAMWR has to be",
        "; cleared first or the store is discarded -- which is the protection",
        "; working, not a fault.",
        "start:",
        "    LDA #$00",
        "    STA $C0EB",
        "    LDA #$62",
        "    STA $3F4",
        "    LDA #$FA",
        "    STA $3F5",
        "; --- boot banner over the serial console ---",
        "    LDA #$41",
        "    STA $C080",
        "    LDA #$32",
        "    STA $C080",
        "    LDA #$0D",
        "    STA $C080",
        "    LDA #$0A",
        "    STA $C080",
        "; --- seed the text page with HI and show it on the console ---",
        "    LDA #$C8",
        "    STA $0400",
        "    LDA #$C9",
        "    STA $0401",
        "    LDA #$48",
        "    STA $C080",
        "    LDA #$49",
        "    STA $C080",
        "    LDA #$0D",
        "    STA $C080",
        "    LDA #$0A",
        "    STA $C080",
        "; --- cursor starts just past HI ---",
        "    LDA #$02",
        "    STA $10",
        "    LDA #$04",
        "    STA $11",
        "    LDA #$00",
        "    STA $13",
        "; --- keyboard loop ---",
        "poll:",
        "    LDA $C010",
        "    BPL poll",
        "    LDA $C000",
        "    AND #$7F",
        "    CMP #$0D",
        "    BEQ newline",
        "    CMP #$0A",
        "    BEQ newline",
        "    CMP #$08",
        "    BEQ backsp",
        "    CMP #$7F",
        "    BEQ backsp",
        "    CMP #$20",
        "    BCC poll",
        "; --- printable: echo, store high-bit char, advance the cursor ---",
        "    STA $C080",
        "    ORA #$80",
        "    STA $12",
        "    LDY #$00",
        "    LDA $12",
        "    STA ($10),Y",
        "    INC $10",
        "    BNE nocarry",
        "    INC $11",
        "nocarry:",
        "    INC $13",
        "    LDA $13",
        "    CMP #$28",
        "    BNE poll",
        "    LDA #$00",
        "    STA $13",
        "    JMP poll",
        "; --- Return / Line Feed: start of the next 40-column row ---",
        "newline:",
        "    LDA #$0D",
        "    STA $C080",
        "    LDA #$0A",
        "    STA $C080",
        "    SEC",
        "    LDA $10",
        "    SBC $13",
        "    STA $10",
        "    LDA $11",
        "    SBC #$00",
        "    STA $11",
        "    CLC",
        "    LDA $10",
        "    ADC #$28",
        "    STA $10",
        "    LDA $11",
        "    ADC #$00",
        "    STA $11",
        "    LDA #$00",
        "    STA $13",
        "    JMP poll",
        "; --- backspace: step back, clear the cell, echo BS SP BS ---",
        "backsp:",
        "    LDA $13",
        "    BEQ bsp_row",
        "    DEC $13",
        "    DEC $10",
        "    BNE bsp_go",
        "    DEC $11",
        "    JMP bsp_go",
        "bsp_row:",
        "    SEC",
        "    LDA $10",
        "    SBC #$28",
        "    STA $10",
        "    LDA $11",
        "    SBC #$00",
        "    STA $11",
        "    LDA #$27",
        "    STA $13",
        "bsp_go:",
        "    LDA #$A0",
        "    LDY #$00",
        "    STA ($10),Y",
        "    LDA #$08",
        "    STA $C080",
        "    LDA #$20",
        "    STA $C080",
        "    LDA #$08",
        "    STA $C080",
        "    JMP poll",
    ]
    ## The autostart monitor, entered when RESET is held while any video
    ## soft-switch is written. Assembled on its own because the assembler ignores
    ## a second `org`, and spliced in at $FA62.
    let autostart_source = [
        "org $FA62",
        "autostart:",
        "; --- text mode, page 1, no mixed ---",
        "    LDA #$00",
        "    STA $C050",
        "    LDA #$00",
        "    STA $C054",
        "    LDA #$00",
        "    STA $C052",
        "    LDA #$00",
        "    STA $C051",
        "; --- clear the 960-byte text page to screen spaces ---",
        "; Three whole 256-byte pages, then the remaining 192.",
        "    LDA #$00",
        "    STA $10",
        "    LDA #$04",
        "    STA $11",
        "    LDX #$03",
        "clpage:",
        "    LDY #$00",
        "clcell:",
        "    LDA #$A0",
        "    STA ($10),Y",
        "    INY",
        "    BNE clcell",
        "    INC $10",
        "    DEX",
        "    BNE clpage",
        "    LDY #$00",
        "cltail:",
        "    LDA #$A0",
        "    STA ($10),Y",
        "    INY",
        "    CPY #$C0",
        "    BNE cltail",
        "; --- banner over the serial console ---",
        "    LDA #$41",
        "    STA $C080",
        "    LDA #$55",
        "    STA $C080",
        "    LDA #$54",
        "    STA $C080",
        "    LDA #$4F",
        "    STA $C080",
        "    LDA #$53",
        "    STA $C080",
        "    LDA #$54",
        "    STA $C080",
        "    LDA #$41",
        "    STA $C080",
        "    LDA #$52",
        "    STA $C080",
        "    LDA #$54",
        "    STA $C080",
        "    LDA #$0D",
        "    STA $C080",
        "    LDA #$0A",
        "    STA $C080",
        "; --- keyboard loop: echo printable keys, handle Return ---",
        "poll:",
        "    LDA $C010",
        "    BPL poll",
        "    LDA $C000",
        "    AND #$7F",
        "    CMP #$0D",
        "    BEQ newline",
        "    CMP #$0A",
        "    BEQ newline",
        "    CMP #$20",
        "    BCC poll",
        "    STA $C080",
        "    JMP poll",
        "newline:",
        "    LDA #$0D",
        "    STA $C080",
        "    LDA #$0A",
        "    STA $C080",
        "    JMP poll",
    ]
    let assembled = asm6502.asm(source, 0xD000)
    let code = assembled[0]
    let autostart = asm6502.asm(autostart_source, 0xFA62)[0]
    var rom = []
    var i = 0
    while i < 0x3000:
        push(rom, 0x00)
        i = i + 1
    i = 0
    while i < len(code) and i < 0x3000:
        rom[i] = code[i] & 0xFF
        i = i + 1
    let autostart_offset = 0xFA62 - 0xD000
    var ai = 0
    while ai < len(autostart) and autostart_offset + ai < 0x3000:
        rom[autostart_offset + ai] = autostart[ai] & 0xFF
        ai = ai + 1
    rom[0x2FFA] = 0x00
    rom[0x2FFB] = 0xD0
    rom[0x2FFC] = 0x00
    rom[0x2FFD] = 0xD0
    rom[0x2FFE] = 0x00
    rom[0x2FFF] = 0xD0
    return rom
