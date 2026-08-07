#########################################################################
## SageApple — UART echo terminal ROM (M6)
##
## A 6502 program polled as the host terminal: reads the UART status
## register ($2000), and when a char is ready reads RX data ($2001) and
## echoes it back to TX ($2001). Reset vector -> $8000.
#########################################################################

proc build_echo_rom():
    let img = []
    var i = 0
    while i < 32768:
        push(img, 0x00)
        i = i + 1

    # offset 0x0000 ($8000)
    img[0x0000] = 0xAD
    img[0x0001] = 0x00
    img[0x0002] = 0x20          # LDA $2000
    img[0x0003] = 0x29
    img[0x0004] = 0x01          # AND #$01
    img[0x0005] = 0xF0
    img[0x0006] = 0xF9          # BEQ $8000
    img[0x0007] = 0xAD
    img[0x0008] = 0x01
    img[0x0009] = 0x20          # LDA $2001
    img[0x000A] = 0x8D
    img[0x000B] = 0x01
    img[0x000C] = 0x20          # STA $2001
    img[0x000D] = 0x4C
    img[0x000E] = 0x00
    img[0x000F] = 0x80          # JMP $8000

    img[0x7FFC] = 0x00
    img[0x7FFD] = 0x80
    return img