#########################################################################
## SageApple — Boot ROM (PLAN.md §12)
##
## Builds the 32KB program ROM image containing a 6502 boot program that
## writes the startup banner out the UART device at $2001, then loops.
## Reset vector installed at $FFFC -> $8000.
#########################################################################

proc chars(s):
    let r = []
    for i in range(len(s)):
        push(r, ord(s[i]))
    return r

proc crlf():
    return [13, 10]

proc msg_bytes():
    var msg = []
    let lines = ["SageApple Computer", "Sage6502 CPU", "ATmega328P",
                 "", "SageApple OS", "", "> "]
    var k = 0
    let n = len(lines)
    while k < n:
        let text = lines[k]
        if len(text) > 0:
            for b in chars(text):
                push(msg, b)
        if k < n - 1:
            for b in crlf():
                push(msg, b)
        k = k + 1
    return msg

# 32KB ROM image as a byte list
proc build_boot_rom():
    let img = []
    var i = 0
    while i < 32768:
        push(img, 0x00)
        i = i + 1

    # program at image offset 0x0000 (address $8000)
    img[0x0000] = 0xA2
    img[0x0001] = 0x00          # LDX #$00
    img[0x0002] = 0xBD
    img[0x0003] = 0x40
    img[0x0004] = 0x80          # LDA $8040,X
    img[0x0005] = 0xF0
    img[0x0006] = 0x07          # BEQ +7  -> halt
    img[0x0007] = 0x8D
    img[0x0008] = 0x01
    img[0x0009] = 0x20          # STA $2001 (UART TX)
    img[0x000A] = 0xE8          # INX
    img[0x000B] = 0x4C
    img[0x000C] = 0x02
    img[0x000D] = 0x80          # JMP $8002
    img[0x000E] = 0x4C
    img[0x000F] = 0x0E
    img[0x0010] = 0x80          # JMP $800E (halt)

    # message at offset 0040 (address $8040)
    let msg = msg_bytes()
    var p = 0
    let m = len(msg)
    while p < m:
        img[0x0040 + p] = msg[p]
        p = p + 1

    # reset vector -> $8000
    img[0x7FFC] = 0x00
    img[0x7FFD] = 0x80
    return img