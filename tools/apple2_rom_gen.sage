import sageapple.apple2_rom
import io
import sys

var output = "avr/rom_apple2.c"
let argv = sys.args()
var arg_index = 2
while arg_index < len(argv):
    let arg = argv[arg_index]
    if startswith(arg, "--out="):
        output = slice(arg, len("--out="), len(arg))
    arg_index = arg_index + 1

let image = apple2_rom.build()
if len(image) != 0x3000:
    raise "Apple II replacement ROM must be 12288 bytes"

var text = "#include <stdint.h>\n"
text = text + "#ifndef HOST\n"
text = text + "#include <avr/pgmspace.h>\n"
text = text + "#endif\n"
text = text + "const uint8_t APPLE2ROM[12288]\n"
text = text + "#ifdef HOST\n"
text = text + "= {\n"
text = text + "#else\n"
text = text + "PROGMEM = {\n"
text = text + "#endif\n"
let digits = "0123456789ABCDEF"
var i = 0
while i < len(image):
    if i % 16 == 0:
        text = text + "  "
    text = text + "0x" + digits[(image[i] >> 4) & 0xF] + digits[image[i] & 0xF]
    if i + 1 < len(image):
        text = text + ","
    if i % 16 == 15 or i + 1 == len(image):
        text = text + "\n"
    i = i + 1
text = text + "};\n"
io.writefile(output, text)
print("wrote " + output + " (" + str(len(image)) + " bytes)")
