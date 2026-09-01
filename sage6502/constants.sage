#########################################################################
## Sage6502 - Named Instruction Constants
#########################################################################

let LDA    = 0
let LDX    = 1
let LDY    = 2
let STA    = 3
let STX    = 4
let STY    = 5

let TAX    = 6
let TXA    = 7
let TAY    = 8
let TYA    = 9
let TSX    = 10
let TXS    = 11

let PHA    = 12
let PHP    = 13
let PLA    = 14
let PLP    = 15

let ADC    = 16
let SBC    = 17
let AND    = 18
let ORA    = 19
let EOR    = 20
let BIT    = 21

let CMP    = 22
let CPX    = 23
let CPY    = 24

let INC    = 25
let DEC    = 26

let INX    = 27
let INY    = 28
let DEX    = 29
let DEY    = 30

let ASL    = 31
let LSR    = 32
let ROL    = 33
let ROR    = 34

let BCC    = 35
let BCS    = 36
let BEQ    = 37
let BMI    = 38
let BNE    = 39
let BPL    = 40
let BVC    = 41
let BVS    = 42

let JMP    = 43
let JSR    = 44
let RTS    = 45

let BRK    = 46
let RTI    = 47
let NOP    = 48

let CLC    = 49
let CLD    = 50
let CLI    = 51
let CLV    = 52
let SEC    = 53
let SED    = 54
let SEI    = 55

let M_IMM  = 0
let M_ZP   = 1
let M_ZPX  = 2
let M_ZPY  = 3
let M_ABS  = 4
let M_ABSX = 5
let M_ABSY = 6
let M_INDX = 7
let M_INDY = 8
let M_ACC  = 9
let M_IND  = 10
let M_REL  = 11
let M_IMP  = 12
