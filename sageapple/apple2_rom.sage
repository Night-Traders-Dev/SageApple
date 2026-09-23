import compiler.asm6502

proc build():
    let source = [
        "org $D000",
        "start:",
        "    LDA #$41",
        "    STA $C080",
        "    LDA #$32",
        "    STA $C080",
        "    LDA #$0D",
        "    STA $C080",
        "    LDA #$0A",
        "    STA $C080",
        "    LDA #$48",
        "    STA $0400",
        "    LDA #$49",
        "    STA $0401",
        "    LDA #$48",
        "    STA $C080",
        "    LDA #$49",
        "    STA $C080",
        "    LDA #$0D",
        "    STA $C080",
        "    LDA #$0A",
        "    STA $C080",
        "poll:",
        "    LDA $C081",
        "    BPL poll",
        "    AND #$7F",
        "    STA $C080",
        "    STA $0402",
        "    JMP poll",
    ]
    let assembled = asm6502.asm(source, 0xD000)
    let code = assembled[0]
    var rom = []
    var i = 0
    while i < 0x3000:
        push(rom, 0x00)
        i = i + 1
    i = 0
    while i < len(code) and i < 0x3000:
        rom[i] = code[i] & 0xFF
        i = i + 1
    rom[0x2FFA] = 0x00
    rom[0x2FFB] = 0xD0
    rom[0x2FFC] = 0x00
    rom[0x2FFD] = 0xD0
    rom[0x2FFE] = 0x00
    rom[0x2FFF] = 0xD0
    return rom
