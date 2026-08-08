#########################################################################
## SageApple — application catalog (PLAN.md §22 / M12)
##
## Demo applications loadable from SAGEFS storage:
##   HELLO / COUNTER / BEEP   BASIC source (run through the OS)
##   MACHINE1                 6502 binary (loaded to RAM + executed)
#########################################################################

import compiler.asm6502

## catalog of BASIC apps: name -> numbered source lines
proc basic_apps():
    return [
        ["HELLO", [
            "10 PRINT \"HELLO FROM SAGEAPPLE\"",
            "20 PRINT \"RUNNING ON ATMEGA328P\"",
            "30 END"]],
        ["COUNTER", [
            "10 FOR I = 1 TO 3",
            "20 PRINT \"COUNT \"; I",
            "30 NEXT I",
            "40 END"]],
        ["BEEP", [
            "10 BEEP 2000",
            "20 BEEP 4000",
            "30 END"]],
    ]

## list membership
proc _has(list, v):
    var i = 0
    while i < len(list):
        if list[i] == v:
            return true
        i = i + 1
    return false

## install BASIC apps that are not yet on the storage
proc install_basic_apps(st, names):
    let catalog = basic_apps()
    var installed = 0
    var i = 0
    while i < len(catalog):
        let app = catalog[i]
        var want = false
        if len(names) == 0:
            want = true
        elif _has(names, app[0]):
            want = true
        if want and st.size_of(app[0]) == -1:
            if st.save_text(app[0], app[1]) == 0:
                installed = installed + 1
        i = i + 1
    return installed

## the official 6502 demo app: prints over UART and beeps the speaker
proc build_6502_app():
    let image = asm6502.asm([
        "org $0300",
        "    LDX #$00",
        "loop:",
        "    LDA msg,X",
        "    BEQ done",
        "    JSR tx",
        "    INX",
        "    JMP loop",
        "done:",
        "    LDA #$3C",
        "    STA $2007",           # tone 60Hz on the speaker
        "halt:",
        "    JMP halt",
        "tx:",
        "    PHA",
        "txw:",
        "    LDA $2000",
        "    AND #$02",
        "    BEQ txw",
        "    PLA",
        "    STA $2001",
        "    RTS",
        "msg:",
        "    .byte $36,$35,$30,$32,$20,$41,$50,$50,$20,$4F,$4B,$0D,$0A,$00"],
        0x0300)[0]
    return image

## install the 6502 binary app
proc install_6502_app(st):
    if st.size_of("MACHINE1") != -1:
        return 0
    return st.save_blob("MACHINE1", build_6502_app())