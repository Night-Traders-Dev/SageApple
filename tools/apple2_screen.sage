import sageapple.apple2_machine
import sageapple.apple2_shell
import sys

let argv = sys.args()
var steps = 0
var i = 2
while i < len(argv):
    let a = argv[i]
    if startswith(a, "--steps="):
        steps = int(slice(a, len("--steps="), len(a)))
    i = i + 1

let shell = apple2_shell.Apple2Shell(apple2_machine.Apple2Machine())
if steps > 0:
    shell.steps = steps
shell.boot()
sys.stdout_write(shell.drain())

var line = input()
while line != nil:
    let result = shell.command(line)
    sys.stdout_write(shell.drain())
    if result == "exit":
        break
    line = input()

sys.stdout_write("\r\n")
