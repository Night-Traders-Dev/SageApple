#########################################################################
## SageApple — rom_builder (PLAN tools)
##
##   sage tools/rom_builder.sage
## Emits a 6502 ROM image as Intel HEX from a byte list. This is the host-side
## counterpart that turns a SageApple 6502 program into a flashable ROM.
#########################################################################

proc hex2(v):
    let digs = "0123456789abcdef"
    return digs[(v >> 4) & 0xF] + digs[v & 0xF]

# 16-byte Intel HEX data records from a byte list
proc emit_8_hex(bytes, base):
    let out = []
    var i = 0
    let n = len(bytes)
    while i < n:
        let chunk = n - i
        if chunk > 16:
            chunk = 16
        var rec = ":" + hex2(chunk) + hex2((base >> 8) & 0xFF) + hex2(base & 0xFF) + "00"
        var ck = chunk + ((base >> 8) & 0xFF) + (base & 0xFF)
        var j = 0
        while j < chunk:
            let b = bytes[i + j]
            rec = rec + hex2(b)
            ck = ck + b
            j = j + 1
        rec = rec + hex2((0 - ck) & 0xFF)
        push(out, rec)
        base = base + chunk
        i = i + chunk
    push(out, ":00000001FF")
    var s = ""
    var k = 0
    let m = len(out)
    while k < m:
        if k > 0:
            s = s + "\n"
        s = s + out[k]
        k = k + 1
    return s

# sample: a tiny 6502 ROM at $8000 (page-zero aware) with a "HELLO" loop
let rom = [0xA2, 0x00, 0xBD, 0x30, 0x80, 0xF0, 0x06, 0x8D, 0xD0, 0x30,
           0xE8, 0x4C, 0x02, 0x80, 0x00, 0x48, 0x45, 0x4C, 0x4C, 0x4F]
let hex_txt = emit_8_hex(rom, 0x8000)
print(hex_txt)