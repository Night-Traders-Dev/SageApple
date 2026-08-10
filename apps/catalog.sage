#########################################################################
## SageApple — application catalog (PLAN.md §22 / M12)
##
## Demo applications loadable from SAGEFS storage:
##   HELLO / COUNTER / BEEP   BASIC source (run through the OS)
##   MACHINE1                 6502 binary (loaded to RAM + executed)
##
## Classic Apple II software library (DOS 3.3 compatible):
##   MASTER CREATE        Disk initialization utility
##   FID                  File developer utility  
##   COPYA                Disk copy utility
##   DISK RECOVERY        File recovery utility
##   APPLESOFT TUTORIAL   Programming tutorial
##   COLOR DEMO           Graphics demonstration
##   SHAPE DEMO           Shape table demonstration
##   MUSIC DEMO           Music/sound demonstration
##   HELLO WORLD          Classic hello world
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
        ["MASTERCRT", [
            "10 PRINT \"MASTER CREATE - DISK INITIALIZATION\"",
            "20 PRINT \"SAGEAPPLE DOS 3.3 COMPATIBLE\"",
            "30 PRINT \"\"",
            "40 PRINT \"THIS UTILITY INITIALIZES A BLANK DISK\"",
            "41 PRINT \"WITH DOS 3.3 AND CREATES A HELLO PROGRAM.\"",
            "42 PRINT \"\"",
            "43 INPUT \"DISK VOLUME NUMBER (1-254): \";V",
            "44 IF V < 1 OR V > 254 THEN PRINT \"INVALID VOLUME\": GOTO 43",
            "45 PRINT \"INITIALIZING VOLUME \";V",
            "46 PRINT \"VOLUME \";V;\" INITIALIZED\"",
            "47 PRINT \"HELLO PROGRAM CREATED\"",
            "48 END"]],
        ["FID", [
            "10 PRINT \"FID - FILE DEVELOPER UTILITY\"",
            "20 PRINT \"COPY, DELETE, RENAME, LOCK, UNLOCK\"",
            "30 PRINT \"CATALOG, VERIFY, STATUS\"",
            "40 PRINT \"\"",
            "50 PRINT \"COMMANDS:\"",
            "60 PRINT \"  C - COPY FILE\"",
            "70 PRINT \"  D - DELETE FILE\"",
            "80 PRINT \"  R - RENAME FILE\"",
            "90 PRINT \"  L - LOCK FILE\"",
            "100 PRINT \"  U - UNLOCK FILE\"",
            "110 PRINT \"  V - VERIFY FILE\"",
            "120 PRINT \"  S - STATUS\"",
            "130 PRINT \"  Q - QUIT\"",
            "140 PRINT \"\"",
            "150 INPUT \"COMMAND: \";C$",
            "160 IF C$ = \"Q\" THEN END",
            "170 PRINT \"FID COMMAND: \";C$",
            "180 GOTO 150"]],
        ["COPYA", [
            "10 PRINT \"COPYA - DISK COPY UTILITY\"",
            "20 PRINT \"SECTOR-BY-SECTOR DISK DUPLICATION\"",
            "30 PRINT \"\"",
            "40 PRINT \"THIS PROGRAM MAKES AN EXACT COPY\"",
            "50 PRINT \"OF ONE DISK TO ANOTHER.\"",
            "60 PRINT \"\"",
            "70 PRINT \"INSERT SOURCE DISK AND PRESS RETURN\"",
            "80 INPUT \"\";A$",
            "85 PRINT \"READING SOURCE...\"",
            "90 PRINT \"INSERT DESTINATION DISK AND PRESS RETURN\"",
            "100 INPUT \"\";A$",
            "105 PRINT \"WRITING DESTINATION...\"",
            "110 PRINT \"COPY COMPLETE\"",
            "120 END"]],
        ["DISKRECOV", [
            "10 PRINT \"DISK RECOVERY - FILE RECOVERY UTILITY\"",
            "20 PRINT \"RECOVER DELETED FILES FROM DISK\"",
            "30 PRINT \"\"",
            "40 PRINT \"SCANNING DIRECTORY FOR DELETED ENTRIES...\"",
            "50 PRINT \"NO DELETED FILES FOUND\"",
            "60 END"]],
        ["APPLESOFT", [
            "10 PRINT \"APPLESOFT BASIC TUTORIAL\"",
            "20 PRINT \"LESSON 1: VARIABLES AND PRINT\"",
            "30 PRINT \"\"",
            "35 A = 10",
            "40 B = 20",
            "50 PRINT \"A = \";A",
            "60 PRINT \"B = \";B",
            "70 PRINT \"A + B = \";A+B",
            "80 PRINT \"\"",
            "90 PRINT \"LESSON 2: LOOPS\"",
            "100 FOR I = 1 TO 5",
            "110 PRINT \"ITERATION \";I",
            "120 NEXT I",
            "130 PRINT \"\"",
            "140 PRINT \"LESSON 3: STRINGS\"",
            "150 A$ = \"HELLO\"",
            "160 B$ = \"WORLD\"",
            "170 PRINT A$;\" \";B$",
            "180 PRINT \"LENGTH: \";LEN(A$) + LEN(B$)",
            "190 PRINT \"\"",
            "200 PRINT \"TUTORIAL COMPLETE\"",
            "210 END"]],
        ["COLOR.DEMO", [
            "10 PRINT \"COLOR DEMO - LORES GRAPHICS\"",
            "20 GR",
            "30 FOR C = 0 TO 15",
            "40 COLOR= C",
            "50 FOR X = 0 TO 39",
            "60 PLOT X, C*2",
            "70 NEXT X",
            "80 NEXT C",
            "90 PRINT \"COLOR BARS DISPLAYED\"",
            "100 TEXT",
            "110 END"]],
        ["SHAPE.DEMO", [
            "10 PRINT \"SHAPE DEMO - HIRES SHAPES\"",
            "20 HGR",
            "30 HCOLOR= 3",
            "40 SCALE= 2",
            "50 ROT= 0",
            "60 XDRAW 1 AT 140,80",
            "70 FOR R = 0 TO 64",
            "80 ROT= R",
            "90 XDRAW 1 AT 140,80",
            "100 NEXT R",
            "110 TEXT",
            "120 END"]],
        ["MUSIC.DEMO", [
            "10 PRINT \"MUSIC DEMO - APPLE II SOUND\"",
            "20 FOR N = 1 TO 8",
            "30 READ P,D",
            "40 FOR I = 1 TO D",
            "50 BEEP P",
            "60 NEXT I",
            "70 NEXT N",
            "80 DATA 261,4, 293,4, 329,4, 349,4, 392,4, 440,4, 493,4, 523,4",
            "90 PRINT \"SCALE PLAYED\"",
            "100 END"]],
        ["HELLO.WORLD", [
            "10 PRINT \"HELLO WORLD\"",
            "20 PRINT \"FROM SAGEAPPLE\"",
            "30 PRINT \"APPLE II COMPATIBLE\"",
            "40 END"]],
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
            if st.save_applesoft(app[0], app[1]) == 0:
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