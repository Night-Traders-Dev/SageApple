#########################################################################
## SageApple — AppleCon (Artistic TUI + SSH shell for SageApple boards)
##
##   sage-c tools/applecon.sage        (run from repo root)
##
## A host-side controller that brings up an artistic TUI animation and a
## "sage> " shell.  From here you can connect to the interactive serial
## shell on any of the SageApple boards:
##
##   con 0   -> the SageApple board wired to THIS device (/dev/ttyUSB0)
##   con 1   -> the first  SageApple board on the OrangePi  (/dev/ttyUSB0)
##   con 2   -> the second SageApple board on the OrangePi  (/dev/ttyUSB1)
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

# Serial port / baud for the boards
let LOCAL_PORT = "/dev/ttyUSB0"
let ORANGE_PORT0 = "/dev/ttyUSB0"
let ORANGE_PORT1 = "/dev/ttyUSB1"
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

proc run_tui():
    clr()
    show_banner()
    sgr(1)
    sgr(32)
    print("    >>>  Connecting to SageApple network  <<<")
    sgr(0)
    sgr(1)
    print("         Scanning for devices...")
    print("         Found: con 0  -> this device   (/dev/ttyUSB0)")
    print("         Found: con 1  -> OrangePi  #1  (/dev/ttyUSB0)")
    print("         Found: con 2  -> OrangePi  #2  (/dev/ttyUSB1)")
    print("         All boards online!")
    sgr(0)
    print("")
    print("    +-----------------------------------------------+")
    print("    |  AppleCon v1.0 - SageApple Board Controller  |")
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

proc write_ssh_script(script_path, orange_port):
    let body = "#!/bin/sh\n"
    body = body + "sshpass -p '" + ORANGEPI_PASS + "' ssh -t -o StrictHostKeyChecking=no "
    body = body + ORANGEPI_HOST + " 'screen " + orange_port + " " + BAUD + "'\n"
    io.writebytes(script_path, chars_of(body))

proc bytes_to_str(blob):
    var s = ""
    var i = 0
    while i < len(blob):
        s = s + chr(blob[i])
        i = i + 1
    return s

proc connect_con0():
    # Local board on this device
    sgr(1)
    sgr(36)
    print("    Connecting to local SageApple board on " + LOCAL_PORT + "...")
    sgr(0)
    if io.exists(LOCAL_PORT) == false:
        sgr(1)
        sgr(31)
        print("    Port " + LOCAL_PORT + " not found on this device.")
        sgr(0)
        return
    sgr(32)
    print("    Connected. (screen: C-a d to detach, C-a k to kill, C-a ? help)")
    print("    SageApple shell starting...")
    sgr(0)
    sys.exec("screen " + LOCAL_PORT + " " + BAUD)

proc connect_remote(orange_port):
    sgr(1)
    sgr(36)
    print("    Connecting via SSH to OrangePi board on " + orange_port + "...")
    sgr(0)
    let script = "/tmp/con_orange_" + slice(orange_port, len(orange_port) - 1, len(orange_port)) + ".sh"
    write_ssh_script(script, orange_port)
    sgr(32)
    print("    Connected. (screen: C-a d to detach, C-a k to kill)")
    print("    SageApple shell starting...")
    sgr(0)
    sys.exec("/bin/sh " + script)

proc try_connect(board_num):
    if board_num == 0:
        connect_con0()
    elif board_num == 1:
        connect_remote(ORANGE_PORT0)
    elif board_num == 2:
        connect_remote(ORANGE_PORT1)

proc show_help():
    sgr(1)
    sgr(33)
    print("")
    print("    Available commands:")
    print("    +-----------------------------------+")
    print("    | con 0   Connect to this board     |")
    print("    | con 1   Connect to OrangePi #1    |")
    print("    | con 2   Connect to OrangePi #2    |")
    print("    | status  Show board status         |")
    print("    | help    Show this help            |")
    print("    | exit    Exit AppleCon             |")
    print("    +-----------------------------------+")
    print("")
    sgr(0)

proc show_status():
    sgr(1)
    sgr(36)
    print("")
    print("    Board Status:")
    print("    +------+-----------------+------------------+--------+")
    print("    | Port | Location        | Serial port      | Status |")
    print("    +------+-----------------+------------------+--------+")
    sgr(0)

    sgr(1)
    if io.exists(LOCAL_PORT):
        sgr(32)
        print("    | 0    | this device     | " + LOCAL_PORT + "          | OK     |")
    else:
        sgr(31)
        print("    | 0    | this device     | " + LOCAL_PORT + "          | down   |")
    sgr(0)

    # Remote ports are probed via ssh
    var ports = [ORANGE_PORT0, ORANGE_PORT1]
    var idx = 1
    while idx <= 2:
        let port = ports[idx - 1]
        let script = "/tmp/probe_" + str(idx) + ".sh"
        var body = "#!/bin/sh\n"
        body = body + "sshpass -p '" + ORANGEPI_PASS + "' ssh -o StrictHostKeyChecking=no "
        body = body + ORANGEPI_HOST + " 'ls " + port + "'\n"
        io.writebytes(script, chars_of(body))
        let res = sys.shell_exec("/bin/sh " + script)
        let found = len(strip(res)) > 0
        sgr(1)
        if found:
            sgr(32)
            print("    | " + str(idx) + "    | OrangePi        | " + port + "          | OK     |")
        else:
            sgr(31)
            print("    | " + str(idx) + "    | OrangePi        | " + port + "          | down   |")
        sgr(0)
        idx = idx + 1

    print("    +------+-----------------+------------------+--------+")
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
