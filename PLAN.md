# `PLAN.md` — SageApple: 6502 Retrocomputer on ATmega328P

## 1. Project Overview

**SageApple** is an Apple II-inspired retrocomputer implemented primarily in **pure SageLang**, designed to run on an inexpensive **ATmega328P / Arduino UNO R3-compatible board**.

The project is built around a reusable **Sage6502 CPU core** and a future **SageLang-to-6502 compiler backend**.

The initial implementation will prioritize a **UART terminal interface** rather than a graphical display. This allows the project to become a functional, interactive computer while minimizing the ATmega328P's severe SRAM and I/O constraints.

The long-term goal is to evolve SageApple into a small, self-contained retrocomputer with:

* 6502 CPU emulation
* Memory bus
* ROM
* RAM
* Interactive monitor
* BASIC interpreter
* Graphics
* Keyboard
* Speaker
* External storage
* SPI LCD/OLED
* Optional SD/SPI Flash
* Native SageLang application support
* SageLang-to-6502 compilation

The project should **not initially attempt to reproduce every Apple II hardware quirk**.

Instead, SageApple will be an **Apple II-inspired, Sage-defined 6502 computer** that can later grow toward higher Apple II compatibility.

---

# 2. Core Concept

The complete architecture is:

```text
                         SageLang
                            │
             ┌──────────────┴──────────────┐
             │                             │
             ▼                             ▼
      Sage6502 Application          Sage6502 Emulator
             │                             │
             ▼                             ▼
        6502 Machine Code             AVR Machine Code
                                           │
                                           ▼
                                      ATmega328P
                                           │
                                           ▼
                                     Executes 6502
                                           │
                                           ▼
                                  Runs 6502 Program
```

The physical system becomes:

```text
                      ATmega328P
                           │
                           ▼
                     Sage6502 Core
                           │
                           ▼
                    SageApple Computer
                           │
          ┌────────────────┼────────────────┐
          │                │                │
          ▼                ▼                ▼
         RAM              ROM             I/O
          │                │                │
          │                │       ┌────────┼────────┐
          │                │       │        │        │
          ▼                ▼       ▼        ▼        ▼
       Memory           Program   UART     SPI     GPIO
       System             Code      │        │        │
                                    │        │        │
                                    ▼        ▼        ▼
                               Chromebook  LCD    Buttons
                                Terminal
```

---

# 3. Project Goals

## Primary Goals

1. Implement a reusable **Sage6502** CPU core in SageLang.
2. Compile Sage6502 to native AVR machine code.
3. Run Sage6502 on an ATmega328P.
4. Create a virtual 6502 memory bus.
5. Create the SageApple memory map.
6. Boot a SageApple ROM.
7. Implement UART-based terminal I/O.
8. Build an interactive machine monitor.
9. Create a minimal operating environment.
10. Implement a Tiny BASIC-style interpreter.
11. Add optional graphics hardware.
12. Add external storage.
13. Develop a SageLang-to-6502 backend.
14. Run native SageLang-generated 6502 programs inside SageApple.

---

# 4. Non-Goals

The initial project will **not** attempt to:

* Fully emulate every Apple II model.
* Reproduce exact Apple II timing.
* Implement the Apple II Disk II protocol initially.
* Emulate the original Apple II keyboard electrically.
* Implement cycle-perfect video.
* Implement a full Apple II DOS immediately.
* Implement a full Apple II BASIC clone initially.
* Run arbitrary commercial Apple II software in Phase 1.
* Use an Arduino framework/runtime.
* Require an operating system on the ATmega328P.
* Require dynamic memory allocation.

The project will prioritize **SageLang-native implementation and architectural clarity** over historical accuracy.

---

# 5. Hardware Target

## Primary Target

**ATmega328P UNO R3-compatible board**

Expected characteristics:

```text
CPU:             ATmega328P
Architecture:    8-bit AVR
Clock:           16 MHz
Flash:           32 KB
SRAM:            2 KB
EEPROM:          1 KB
Logic:           5 V
UART:            1
SPI:             1
I²C/TWI:         1
ADC:             10-bit
GPIO:            14 digital
PWM:             6 channels
```

The exact AliExpress board should be electrically verified after arrival.

---

# 6. Development Environment

## Primary Development Machine

Chromebook.

The Chromebook will be used for:

* SageLang development
* Sage6502 development
* Cross-compilation
* Unit tests
* Emulator development
* ROM generation
* UART terminal
* Git repository management
* Documentation

## Target Hardware

ATmega328P UNO R3-compatible board.

## Optional Development Hardware

* USB programmer / USBasp
* Logic analyzer
* SPI LCD/OLED
* Push buttons
* Breadboard
* Jumper wires
* Speaker or piezo buzzer
* SPI Flash
* SD card module

---

# 7. Repository Structure

Recommended repository:

```text
SageApple/
│
├── PLAN.md
├── README.md
├── LICENSE
├── CHANGELOG.md
│
├── docs/
│   ├── architecture.md
│   ├── memory-map.md
│   ├── 6502.md
│   ├── avr.md
│   ├── uart.md
│   ├── graphics.md
│   ├── storage.md
│   └── sageapple-os.md
│
├── sage6502/
│   ├── cpu.sage
│   ├── registers.sage
│   ├── flags.sage
│   ├── addressing.sage
│   ├── instructions.sage
│   ├── interrupts.sage
│   └── cycles.sage
│
├── bus/
│   ├── bus.sage
│   ├── memory.sage
│   ├── rom.sage
│   ├── ram.sage
│   └── io.sage
│
├── devices/
│   ├── uart.sage
│   ├── gpio.sage
│   ├── timer.sage
│   ├── keyboard.sage
│   ├── display.sage
│   ├── speaker.sage
│   └── storage.sage
│
├── sageapple/
│   ├── machine.sage
│   ├── boot.sage
│   ├── monitor.sage
│   ├── console.sage
│   └── io.sage
│
├── basic/
│   ├── tokenizer.sage
│   ├── parser.sage
│   ├── interpreter.sage
│   └── runtime.sage
│
├── compiler/
│   └── 6502/
│       ├── backend.sage
│       ├── registers.sage
│       ├── instructions.sage
│       ├── emitter.sage
│       └── linker.sage
│
├── rom/
│   ├── boot.sage
│   ├── monitor.sage
│   └── basic.sage
│
├── tests/
│   ├── 6502/
│   ├── memory/
│   ├── bus/
│   ├── uart/
│   └── compiler/
│
├── tools/
│   ├── rom_builder.sage
│   ├── hex_dump.sage
│   └── monitor_client.sage
│
└── examples/
    ├── hello.sage
    ├── counter.sage
    └── graphics.sage
```

---

# 8. Phase 1 — Sage6502 CPU Core

## Objective

Create a reusable 6502 CPU implementation in SageLang.

The CPU should initially model:

```text
A   Accumulator
X   X Index
Y   Y Index
SP  Stack Pointer
PC  Program Counter
P   Processor Status
```

Status flags:

```text
N  Negative
V  Overflow
B  Break
D  Decimal
I  Interrupt Disable
Z  Zero
C  Carry
```

## CPU Interface

Conceptually:

```text
CPU
├── reset()
├── step()
├── run()
├── interrupt()
├── nmi()
└── brk()
```

## Instruction Categories

Implement:

### Load / Store

```text
LDA
LDX
LDY
STA
STX
STY
```

### Register Transfers

```text
TAX
TAY
TXA
TYA
TSX
TXS
```

### Stack

```text
PHA
PHP
PLA
PLP
```

### Arithmetic

```text
ADC
SBC
```

### Logical

```text
AND
ORA
EOR
BIT
```

### Compare

```text
CMP
CPX
CPY
```

### Increment / Decrement

```text
INC
INX
INY
DEC
DEX
DEY
```

### Shifts / Rotates

```text
ASL
LSR
ROL
ROR
```

### Branches

```text
BCC
BCS
BEQ
BMI
BNE
BPL
BVC
BVS
```

### Jumps

```text
JMP
JSR
RTS
```

### System

```text
BRK
RTI
NOP
```

### Flags

```text
CLC
CLD
CLI
CLV
SEC
SED
SEI
```

---

# 9. Phase 2 — 6502 Validation

Before running on the ATmega328P, validate Sage6502 on the Chromebook.

Required tests:

* All legal opcodes
* All addressing modes
* Register behavior
* Flag behavior
* Stack behavior
* Branch behavior
* Page crossing behavior
* Interrupt behavior
* Reset behavior

Use known 6502 functional test ROMs where practical.

Success criteria:

```text
6502 CPU
    │
    ▼
Automated Test Suite
    │
    ├── Opcode Tests
    ├── Flag Tests
    ├── Addressing Tests
    ├── Stack Tests
    └── Interrupt Tests
            │
            ▼
          PASS
```

Do not move to the ATmega target until the CPU core passes the basic validation suite.

---

# 10. Phase 3 — Sage6502 Memory Bus

Implement an abstract memory bus.

```text
6502 CPU
    │
    ▼
Memory Bus
    │
    ├── read(address)
    └── write(address, value)
```

The CPU should never directly depend on physical AVR memory.

This abstraction allows the same Sage6502 core to run:

```text
Chromebook
ATmega328P
RP2040
RP2350
RISC-V
```

The bus will support:

```text
read8()
write8()
```

and eventually:

```text
read16()
write16()
```

---

# 11. Phase 4 — SageApple Memory Architecture

Initial SageApple memory map:

```text
$0000 ────────────────┐
                      │
                      │ 2 KB RAM
                      │
$07FF ────────────────┘

$0800 ────────────────┐
                      │
                      │ Reserved
                      │
$1FFF ────────────────┘

$2000 ────────────────┐
                      │
                      │ I/O
                      │
$3FFF ────────────────┘

$4000 ────────────────┐
                      │
                      │ Expansion
                      │
$7FFF ────────────────┘

$8000 ────────────────┐
                      │
                      │ Program ROM
                      │
$FFFF ────────────────┘
```

The initial physical implementation will use:

```text
ATmega SRAM
    │
    ▼
Virtual 6502 RAM

ATmega Flash
    │
    ▼
Virtual 6502 ROM
```

Memory usage must be carefully optimized.

---

# 12. Phase 5 — SageApple Boot ROM

Implement a minimal boot sequence.

```text
Power On
    │
    ▼
ATmega Reset
    │
    ▼
AVR Startup
    │
    ▼
Initialize UART
    │
    ▼
Initialize Sage6502
    │
    ▼
6502 Reset Vector
    │
    ▼
SageApple ROM
    │
    ▼
Monitor
```

Expected output:

```text
SageApple Computer
Sage6502 CPU
ATmega328P

Memory: 2 KB
ROM: Internal Flash

SageApple OS

>
```

---

# 13. Phase 6 — UART Terminal

UART is the first I/O device.

Do not initially implement an LCD.

Connect:

```text
ATmega328P
     │
     │ UART
     ▼
USB Serial
     │
     ▼
Chromebook
     │
     ▼
Terminal
```

The virtual SageApple machine will expose:

```text
Keyboard ← UART RX
Display  → UART TX
```

This creates a functional computer using only the UNO and Chromebook.

Required functionality:

* Character input
* Character output
* Backspace
* Carriage return
* Line feed
* Command input
* Command history if memory allows

---

# 14. Phase 7 — SageApple Monitor

Implement a low-level monitor.

Example:

```text
SageApple Monitor

> help

Commands:

help
dump
peek
poke
regs
run
load
reset
basic
```

Example:

```text
> regs

A: 00
X: 00
Y: 00
SP: FF
PC: 8000
P:  24
```

Memory inspection:

```text
> dump 0000 00FF
```

Memory modification:

```text
> poke 0200 FF
```

Execution:

```text
> run 8000
```

This is the first point where SageApple becomes a useful **6502 development machine**.

---

# 15. Phase 8 — SageApple BASIC

Implement a small BASIC interpreter.

Initial commands:

```text
PRINT
LET
GOTO
IF
THEN
FOR
NEXT
INPUT
LIST
RUN
NEW
```

Example:

```text
10 PRINT "HELLO FROM SAGEAPPLE"
20 GOTO 10
```

Later:

```text
10 FOR I = 1 TO 10
20 PRINT I
30 NEXT I
```

The BASIC interpreter should initially run as a native Sage/AVR component rather than as 6502 code if this produces a significant performance or memory advantage.

Later versions can move the interpreter into the virtual 6502 environment.

---

# 16. Phase 9 — SageLang-to-6502 Backend

Develop a backend allowing SageLang programs to compile into 6502 machine code.

Architecture:

```text
Sage Source
    │
    ▼
Sage Parser
    │
    ▼
Sage AST
    │
    ▼
Sage IR
    │
    ▼
6502 Backend
    │
    ▼
6502 Assembly
    │
    ▼
6502 Binary
    │
    ▼
SageApple ROM
```

Example source:

```sage
fn main():
    print("Hello from 6502")
```

Target:

```text
6502 Binary
```

The binary can then be loaded into:

```text
SageApple
    │
    ▼
Sage6502
    │
    ▼
ATmega328P
```

This becomes the core compiler demonstration.

---

# 17. Phase 10 — Three-Level Execution Model

The finished demonstration should support:

```text
Level 1
SageLang
    │
    ▼
6502 Program
```

Level 2:

```text
SageLang
    │
    ▼
Sage6502 Emulator
    │
    ▼
AVR Machine Code
```

Level 3:

```text
ATmega328P
    │
    ▼
Runs Sage6502
    │
    ▼
Executes 6502 Program
    │
    ▼
Runs SageLang-generated application
```

Final architecture:

```text
                 SageLang Source
                        │
                        ▼
                 SageLang Compiler
                        │
                        ▼
                  6502 Backend
                        │
                        ▼
                  6502 Binary
                        │
                        ▼
                    SageApple
                        │
                   6502 Emulator
                        │
                        ▼
                   ATmega328P
                        │
                        ▼
                 Physical Computer
```

---

# 18. Phase 11 — Graphics

Once the UART implementation is stable, add graphics.

Initial target:

```text
ATmega328P
    │
    │ SPI
    ▼
SPI LCD / OLED
```

Start with:

* Text mode
* Basic bitmap mode
* Pixel plotting
* Line drawing
* Character rendering

Avoid full Apple II video compatibility initially.

Recommended architecture:

```text
SageApple
    │
    ▼
Video API
    │
    ▼
Scanline / Tile Renderer
    │
    ▼
SPI Driver
    │
    ▼
LCD/OLED
```

The display framebuffer should **not** consume the entire 2 KB SRAM.

Prefer:

* Scanline rendering
* Tile rendering
* Partial buffers
* External display RAM
* Direct display streaming

---

# 19. Phase 12 — Keyboard

Initial keyboard:

```text
Chromebook
    │
    │ UART
    ▼
SageApple
```

Later physical keyboard:

```text
Keyboard
    │
    ▼
GPIO Matrix
    │
    ▼
ATmega328P
```

Optional:

```text
USB Host
    │
    ▼
External Controller
    │
    ▼
SageApple
```

---

# 20. Phase 13 — Speaker

Use PWM.

```text
ATmega328P
    │
    ▼
PWM
    │
    ▼
Piezo / Speaker
```

Initial functionality:

* Beep
* Tone
* Simple music
* BASIC `BEEP`

Later:

```text
SageApple Audio
├── Square Wave
├── Frequency
├── Duration
└── Volume
```

---

# 21. Phase 14 — External Storage

Add SPI Flash first.

```text
ATmega328P
      │
      │ SPI
      ▼
 SPI Flash
      │
      ▼
SageApple Storage
```

Possible filesystem:

```text
SAGEFS-6502
```

or a minimal custom filesystem.

Files:

```text
HELLO
PROGRAM1
BASIC1
CONFIG
```

Later support:

```text
SD Card
```

This enables:

* Program storage
* BASIC programs
* ROM images
* User files
* Applications

---

# 22. Phase 15 — Full SageApple Hardware

Final physical configuration:

```text
                       SageApple
                           │
                 ┌─────────┼─────────┐
                 │         │         │
                 ▼         ▼         ▼
               UART       SPI       GPIO
                 │         │         │
                 ▼         ▼         ▼
            Chromebook    LCD     Keyboard
                           │
                           ▼
                         Video

                       SPI Bus
                          │
                          ▼
                      SPI Flash
                          │
                          ▼
                       Storage

                      PWM Timer
                          │
                          ▼
                       Speaker
```

The goal is a small standalone retrocomputer.

---

# 23. Resource Budget

The ATmega328P has extremely limited resources.

Target budget:

```text
Flash: 32 KB
SRAM:  2 KB
CPU:   16 MHz
```

Suggested SRAM allocation:

```text
2,048 bytes total
│
├── 256–512 bytes
│   Sage6502 state
│
├── 512–1024 bytes
│   Virtual 6502 RAM
│
├── 128–256 bytes
│   UART buffers
│
├── 128–256 bytes
│   Stack / runtime
│
└── Remaining
    I/O and system state
```

This is an initial estimate and must be adjusted after profiling.

The project must avoid:

* Heap allocation
* Large dynamic arrays
* Full framebuffer storage
* Large strings
* Recursive algorithms
* Heavy runtime abstractions

Prefer:

* Static allocation
* Fixed-size buffers
* Compile-time constants
* Compact data structures
* Flash-resident strings
* Bit packing

---

# 24. Performance Optimization

Optimization priorities:

1. Eliminate unnecessary abstraction overhead.
2. Use compile-time constants.
3. Inline small hot functions.
4. Optimize memory access.
5. Minimize 6502 emulator dispatch overhead.
6. Use direct AVR instructions where appropriate.
7. Optimize opcode dispatch.
8. Use computed dispatch if Sage/AVR backend supports it.
9. Avoid unnecessary virtual function calls.
10. Keep the 6502 state in AVR registers when practical.

Potential optimization:

```text
Generic Sage6502
      │
      ▼
Compile-Time Specialization
      │
      ▼
SageApple AVR Build
      │
      ▼
ATmega328P-specific optimized code
```

---

# 25. Testing Strategy

## Unit Tests

Test:

* CPU registers
* Flags
* Arithmetic
* Memory
* Stack
* Addressing modes
* Branches
* Interrupts

## Integration Tests

Test:

* CPU + bus
* CPU + RAM
* CPU + ROM
* CPU + UART
* CPU + monitor

## Hardware Tests

Test:

```text
UART
GPIO
SPI
Timer
PWM
EEPROM
```

## End-to-End Test

The ultimate initial test:

```text
Chromebook
    │
    ▼
Sage Compiler
    │
    ▼
6502 Binary
    │
    ▼
SageApple ROM
    │
    ▼
ATmega328P
    │
    ▼
Sage6502
    │
    ▼
6502 Program
    │
    ▼
UART Terminal
    │
    ▼
"Hello from SageApple!"
```

---

# 26. Milestones

## Milestone 1 — Repository

* [x] Create SageApple repository.
* [x] Add PLAN.md.
* [x] Add README.md.
* [x] Define project license.
* [x] Define SageLang version.
* [x] Define supported AVR toolchain.

## Milestone 2 — Sage6502

* [x] CPU state.
* [x] Registers.
* [x] Flags.
* [x] Addressing modes.
* [x] All legal instructions.
* [x] Reset.
* [x] IRQ.
* [x] NMI.
* [x] BRK/RTI.

## Milestone 3 — Validation

* [x] Unit tests.
* [x] Opcode tests.
* [x] Functional 6502 test ROM.
* [x] Memory tests.
* [x] Stack tests.

## Milestone 4 — AVR Target

* [x] AVR backend.
* [x] AVR startup.
* [x] AVR linker configuration.
* [x] ATmega328P target.
* [x] HEX generation.
* [x] Flashing workflow.

## Milestone 5 — SageApple Boot

* [x] Boot ROM.
* [x] 6502 reset.
* [x] Memory bus.
* [x] RAM.
* [x] ROM.

## Milestone 6 — UART

* [x] AVR UART.
* [x] 6502 UART device.
* [x] Character input.
* [x] Character output.
* [x] Terminal interface.

## Milestone 7 — Monitor

* [x] `help`.
* [x] `dump`.
* [x] `peek`.
* [x] `poke`.
* [x] `regs`.
* [x] `run`.
* [x] `reset`.

## Milestone 8 — BASIC

* [x] Tokenizer.
* [x] Parser.
* [x] Variables.
* [x] PRINT.
* [x] LET.
* [x] GOTO.
* [x] IF/THEN.
* [x] FOR/NEXT.
* [x] INPUT.
* [x] LIST.
* [x] RUN.

## Milestone 9 — 6502 Compiler Backend

* [x] Sage AST lowering.
* [x] 6502 instruction selection.
* [x] Register allocation.
* [x] Stack model.
* [x] Assembly emitter.
* [x] Binary generation.

## Milestone 10 — Graphics

* [x] SPI driver.
* [x] Display initialization.
* [x] Text rendering.
* [x] Pixel rendering.
* [x] Basic graphics.

## Milestone 11 — Storage

* [x] SPI Flash.
* [x] Storage abstraction.
* [x] File format.
* [x] Program loading.
* [x] BASIC program persistence.

## Milestone 12 — Standalone SageApple

* [x] Physical keyboard.
* [x] LCD/OLED.
* [x] Speaker.
* [x] Storage.
* [x] Boot menu.
* [x] BASIC.
* [x] Monitor.
* [x] Application loading.

---

# 27. Final Architecture

The completed project should look like:

```text
                            SageLang
                               │
              ┌────────────────┴────────────────┐
              │                                 │
              ▼                                 ▼
      SageLang Application              Sage6502 Backend
              │                                 │
              ▼                                 ▼
         6502 Binary                    AVR Machine Code
              │                                 │
              └────────────────┬────────────────┘
                               │
                               ▼
                         ATmega328P
                               │
                               ▼
                         Sage6502 Core
                               │
                               ▼
                         SageApple Bus
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
        ▼                      ▼                      ▼
       RAM                    ROM                    I/O
        │                      │                      │
        │                      │          ┌───────────┼───────────┐
        │                      │          │           │           │
        ▼                      ▼          ▼           ▼           ▼
    6502 RAM             SageApple OS   UART        SPI         GPIO
                                               │           │
                                               │           ├── LCD
                                               │           ├── Flash
                                               │           └── SD
                                               │
                                               ▼
                                          Chromebook
```

---

# 28. Definition of Done

The initial SageApple project is considered successful when the following sequence works:

```text
1. Write SageLang source
          │
          ▼
2. Compile Sage6502
          │
          ▼
3. Generate 6502 binary
          │
          ▼
4. Embed/load binary into SageApple ROM
          │
          ▼
5. Compile SageApple/Sage6502 to AVR
          │
          ▼
6. Flash ATmega328P
          │
          ▼
7. Power on UNO
          │
          ▼
8. SageApple boots
          │
          ▼
9. 6502 emulator initializes
          │
          ▼
10. 6502 program executes
          │
          ▼
11. Program interacts with UART
          │
          ▼
12. Chromebook displays output
```

The first canonical demonstration should be:

```text
SageApple Computer
------------------

Sage6502 CPU ........ OK
Memory .............. 2048 bytes
ROM ................. OK
UART ................ OK

SageApple OS 0.1

> run hello

HELLO FROM SAGEAPPLE
RUNNING ON ATMEGA328P

>
```

The long-term objective is to turn the **$1.05 UNO R3-compatible board into a complete SageLang-powered retrocomputer**, with **Sage6502 serving as the reusable foundation** and **SageApple serving as the first complete machine built on top of it**.
