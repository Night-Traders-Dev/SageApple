#########################################################################
## SageApple — hex_dump (PLAN tools)
##
##   sage tools/hex_dump.sage
## Prints a byte-oriented hex dump of ./build/boot.bin (create one to view).
#########################################################################

import io

proc hx(v):
    let digs = "0123456789abcdef"
    return digs[(v >> 4) & 0xF] + digs[v & 0xF]

proc main():
    let file = "build/boot.bin"
    if io.exists(file) == false:
        print("missing " + file + "; run tools/avr_boot.sage to make a HEX first")
        return
    let bytes = io.readbytes(file)
    var i = 0
    let n = len(bytes)
    while i < n:
        var hexs = ""
        var j = 0
        while j < 16 and (i + j) < n:
            hexs = hexs + hx(bytes[i + j]) + " "
            j = j + 1
        print(hx(i) + "  " + hexs)
        i = i + 16

main()