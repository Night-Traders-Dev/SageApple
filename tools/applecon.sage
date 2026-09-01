#########################################################################
## SageApple — AppleCon (Artistic TUI + SSH shell for SageApple boards)
##
##   sage-c tools/applecon.sage        (run from repo root)
##
## A host-side controller that brings up an artistic TUI animation and a
## "sage> " shell.  From here you can connect to the interactive serial
## shell on any of the SageApple boards:
##
##   con 0   -> og Uno R3   on OrangePi  (/dev/ttyUSB0)
##   con 1   -> Nano R3     on OrangePi  (/dev/ttyUSB1)
##   con 2   -> 2nd Uno R3  on OrangePi  (/dev/ttyUSB2, needs cdc_acm)
##
## All three boards are wired to the OrangePi and reached over SSH.
##
## On `con N` AppleCon hands off to `screen` (a TTY is required) so the
## board's monitor/BASIC shell runs interactively; exit screen (C-a d or
## C-a k) to return to the "sage> " prompt.
##
## NOTE: the RISC-V `sage` interpreter on the OrangePi (self-hosted build)
## is unstable with this script; use the C build (`sage-c`) there.
#########################################################################

import io
import sys

let ESC = "\x1b"

let ORANGEPI_HOST = "orangepi@192.168.254.44"
let ORANGEPI_PASS = "jdy@123"

# All three boards are on the OrangePi
let BOARD0_NAME = "og Uno R3"
let BOARD0_PORT = "/dev/ttyUSB0"
let BOARD1_NAME = "Nano R3"
let BOARD1_PORT = "/dev/ttyUSB1"
let BOARD2_NAME = "2nd Uno R3"
let BOARD2_PORT = "/dev/ttyUSB2"
let BAUD = "9600"

proc sgr(code):
    print(ESC + "[" + str(code) + "m")

proc show_banner():
    sgr(36)
    print("")
    print("     .     .     .     .     .     .     .     .     .")
    print("    ***   ***   ***   ***   ***   ***   ***   ***   ***")
    print("   ***** ***** ***** ***** ***** ***** ***** ***** *****")
    print("    ***   ***   ***   ***   ***   ***   ***   ***   ***")
    print("     .     .     .     .     .     .     .     .     .")
    print("")
    sgr(1)
    print("      _____ _____ _____  ___   __    __   __")
    print("     /  ___|_   _|  _  |/ _ \\  (R)  / /  / /")
    print("     ` --.  | | | | | | /_\\ |      / /  / /")
    print("      ` --. | | | | | |  _  |     / /  / /___")
    print("      /\\__/ |_| |_\\ \\_/ / | |    / /  \\____  |")
    print("      \\____/ \\___/ \\___/\\_| |_/ /_/       /_/")
    print("")
    sgr(0)
    print("   ***** ***** ***** ***** ***** ***** ***** ***** *****")
    print("")

proc show_board_icon():
    sgr(1)
    sgr(35)
    print("         +-----------+")
    print("         |  [SAGE]   |")
    print("         |  .----.   |")
    print("         |  |LED |   |")
    print("         |  '----'   |")
    print("         |  ATmega   |")
    print("         |  328P     |")
    print("         |           |")
    print("         | USB-C     |")
    print("         +-----------+")
    print("          |  |  |  |")
    print("          |__|__|__|")
    print("")
    sgr(0)

proc clr():
    print(ESC + "[2J" + ESC + "[H")

proc port_suffix(port):
    # Extract last char of port path for safe filenames: /dev/ttyUSB0 -> "0"
    return slice(port, len(port) - 1, len(port))

proc probe_remote_port(port):
    let tag = port_suffix(port)
    let script = "/tmp/probe_" + tag + ".sh"
    var body = "#!/bin/sh\n"
    body = body + "sshpass -p '" + ORANGEPI_PASS + "' ssh -o StrictHostKeyChecking=no "
    body = body + ORANGEPI_HOST + " 'ls " + port + " 2>/dev/null' < /dev/null\n"
    io.writebytes(script, chars_of(body))
    let res = sys.shell_exec("/bin/sh " + script)
    return len(strip(res)) > 0

proc run_tui():
    clr()
    show_banner()
    sgr(1)
    sgr(32)
    print("    >>>  Connecting to SageApple network  <<<")
    sgr(0)
    sgr(1)
    print("         Scanning for devices...")

    # Probe each board for real
    let found0 = probe_remote_port(BOARD0_PORT)
    let found1 = probe_remote_port(BOARD1_PORT)
    let found2 = probe_remote_port(BOARD2_PORT)

    if found0:
        sgr(32)
        print("         con 0  -> " + BOARD0_NAME + "  (" + BOARD0_PORT + ")")
    else:
        sgr(31)
        print("         con 0  -> " + BOARD0_NAME + "  (" + BOARD0_PORT + ")  [not found]")

    if found1:
        sgr(32)
        print("         con 1  -> " + BOARD1_NAME + "  (" + BOARD1_PORT + ")")
    else:
        sgr(31)
        print("         con 1  -> " + BOARD1_NAME + "  (" + BOARD1_PORT + ")  [not found]")

    if found2:
        sgr(32)
        print("         con 2  -> " + BOARD2_NAME + "  (" + BOARD2_PORT + ")")
    else:
        sgr(31)
        print("         con 2  -> " + BOARD2_NAME + "  (" + BOARD2_PORT + ")  [not found]")

    if found0 and found1 and found2:
        sgr(32)
        print("         All boards online!")
    else:
        sgr(33)
        print("         Some boards offline. Use 'status' for details.")

    sgr(0)
    print("")
    print("    +-----------------------------------------------+")
    print("    |  AppleCon v1.1 - SageApple Board Controller  |")
    print("    +-----------------------------------------------+")
    print("")
    show_board_icon()

# Allowed chars for sys.exec are: alphanumeric / . - _ ~ space.
# ssh user@host is NOT allowed (no '@'), so we wrap ssh in a shell script.
proc chars_of(s):
    let out = []
    var i = 0
    while i < len(s):
        push(out, ord(s[i]))
        i = i + 1
    return out

proc write_connect_script(script_path, orange_port):
    # Kill any stale screen session on the target port, then connect
    var body = "#!/bin/sh\n"
    body = body + "sshpass -p '" + ORANGEPI_PASS + "' ssh -t -o StrictHostKeyChecking=no "
    body = body + ORANGEPI_HOST + " '"
    body = body + "pkill -f \"SCREEN " + orange_port + "\" 2>/dev/null; "
    body = body + "sleep 1; "
    body = body + "screen " + orange_port + " " + BAUD
    body = body + "'\n"
    io.writebytes(script_path, chars_of(body))

proc bytes_to_str(blob):
    var s = ""
    var i = 0
    while i < len(blob):
        s = s + chr(blob[i])
        i = i + 1
    return s

proc connect_remote(orange_port, board_name):
    sgr(1)
    sgr(36)
    print("    Connecting via SSH to OrangePi: " + board_name + " on " + orange_port + "...")
    sgr(0)
    let script = "/tmp/con_orange_" + slice(orange_port, len(orange_port) - 1, len(orange_port)) + ".sh"
    write_connect_script(script, orange_port)
    sgr(32)
    print("    Connected. (screen: C-a d to detach, C-a k to kill)")
    print("    SageApple shell starting...")
    sgr(0)
    sys.exec("/bin/sh " + script)

proc try_connect(board_num):
    if board_num == 0:
        connect_remote(BOARD0_PORT, BOARD0_NAME)
    elif board_num == 1:
        connect_remote(BOARD1_PORT, BOARD1_NAME)
    elif board_num == 2:
        connect_remote(BOARD2_PORT, BOARD2_NAME)

proc pad(s, width):
    var result = s
    while len(result) < width:
        result = result + " "
    return result

proc show_help():
    sgr(1)
    sgr(33)
    print("")
    print("    Available commands:")
    print("    +--------------------------------------------+")
    print("    | con 0   og Uno R3   (/dev/ttyUSB0)        |")
    print("    | con 1   Nano R3     (/dev/ttyUSB1)        |")
    print("    | con 2   2nd Uno R3  (/dev/ttyUSB2)        |")
    print("    | status  Show board status                  |")
    print("    | help    Show this help                     |")
    print("    | exit    Exit AppleCon                      |")
    print("    +--------------------------------------------+")
    print("")
    sgr(0)

proc show_status():
    sgr(1)
    sgr(36)
    print("")
    print("    Board Status:")
    print("    +------+-------------+------------------+--------+")
    print("    | Port | Board       | Serial port      | Status |")
    print("    +------+-------------+------------------+--------+")
    sgr(0)

    var ports = [BOARD0_PORT, BOARD1_PORT, BOARD2_PORT]
    var names = [BOARD0_NAME, BOARD1_NAME, BOARD2_NAME]
    var idx = 0
    while idx < 3:
        let port = ports[idx]
        let name = names[idx]
        let found = probe_remote_port(port)
        sgr(1)
        if found:
            sgr(32)
            print("    | " + str(idx) + "    | " + pad(name, 12) + " | " + port + " | OK     |")
        else:
            sgr(31)
            print("    | " + str(idx) + "    | " + pad(name, 12) + " | " + port + " | down   |")
        sgr(0)
        idx = idx + 1

    print("    +------+-------------+------------------+--------+")
    print("")

proc shell_loop():
    var line = input()
    while line != nil:
        let trimmed = strip(line)
        if len(trimmed) == 0:
            print("sage> ")
            line = input()
            continue

        let parts = split(trimmed, " ")
        let cmd = parts[0]

        if cmd == "con":
            if len(parts) > 1:
                let num = int(parts[1])
                if num >= 0 and num <= 2:
                    try_connect(num)
                else:
                    sgr(1)
                    sgr(31)
                    print("    Unknown board. Use con 0, con 1, or con 2.")
                    sgr(0)
            else:
                sgr(1)
                sgr(31)
                print("    Usage: con <0|1|2>")
                sgr(0)

        elif cmd == "status":
            show_status()

        elif cmd == "help":
            show_help()

        elif cmd == "exit" or cmd == "quit":
            sgr(1)
            sgr(36)
            print("")
            print("    AppleCon exiting. Goodbye!")
            print("")
            sgr(0)
            break

        else:
            sgr(1)
            sgr(31)
            print("    Unknown command: " + cmd + ". Type 'help' for commands.")
            sgr(0)

        print("sage> ")
        line = input()

proc main():
    run_tui()
    sgr(1)
    print("    Type 'help' for available commands.")
    print("    Type 'exit' to quit.")
    print("")
    sgr(0)
    print("sage> ")
    shell_loop()

main()
