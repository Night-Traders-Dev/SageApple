#########################################################################
## Sage6502 - NMOS Decimal Arithmetic Helpers
#########################################################################
##
## These are pure helper functions for decimal arithmetic.
## The CPU class delegates to these from its adc/sbc methods.
##
## NMOS decimal flag behavior:
##
##   ADC:  A + M + C, BCD corrected
##     V = binary overflow
##     N = bit 7 of binary intermediate result
##     Z = binary intermediate result == 0
##     C = decimal carry
##
##   SBC:  A - M - (1 - C), BCD corrected
##     V = binary subtraction overflow
##     N = bit 7 of binary intermediate result
##     Z = binary intermediate result == 0
##     C = decimal no-borrow condition
#########################################################################


proc compute_adc_decimal_nmos(a, b, c):

    let binary_sum = a + b + c

    let binary_result = binary_sum & 0xFF

    let overflow = (~(a ^ b) & (a ^ binary_result) & 0x80)

    let decimal_sum = binary_sum

    if ((a & 0x0F) + (b & 0x0F) + c) > 9:
        decimal_sum = decimal_sum + 0x06

    if decimal_sum > 0x99:
        decimal_sum = decimal_sum + 0x60

    let carry = 0
    if decimal_sum > 0xFF:
        carry = 1

    return [
        decimal_sum & 0xFF,
        binary_result,
        overflow,
        carry
    ]


proc compute_sbc_decimal_nmos(a, b, c):

    let borrow = 1 - c

    let binary_diff = a - b - borrow

    let binary_result = binary_diff & 0xFF

    let overflow = ((a ^ binary_result) & (a ^ b) & 0x80)

    var low = (a & 0x0F) - (b & 0x0F) - borrow
    var high = ((a >> 4) & 0x0F) - ((b >> 4) & 0x0F)

    if low < 0:
        low = low + 10
        high = high - 1

    let carry = 0
    if high < 0:
        high = high + 10
        carry = 0
    else:
        carry = 1

    return [
        ((high << 4) | low) & 0xFF,
        binary_result,
        overflow,
        carry
    ]


proc compute_adc_binary(a, b, c):

    let sum = a + b + c
    let result = sum & 0xFF
    let carry = 0
    if sum > 0xFF:
        carry = 1

    let overflow = (~(a ^ b) & (a ^ result) & 0x80)

    return [result, overflow, carry]


proc compute_sbc_binary(a, b, c):

    let borrow = 1 - c
    let diff = a - b - borrow
    let result = diff & 0xFF
    let carry = 0
    if diff >= 0:
        carry = 1

    let overflow = ((a ^ result) & (a ^ b) & 0x80)

    return [result, overflow, carry]
