#########################################################################
## SageApple — BASIC test (Milestone 8)
##
## Run:  sage tests/basic/test_basic.sage   (from the repo root)
#########################################################################

import basic.basic

var failures = 0
var passes = 0
proc check(cond, msg):
    if cond:
        passes = passes + 1
        print("  PASS:", msg)
    else:
        failures = failures + 1
        print("  FAIL:", msg)

proc contains(hay, needle):
    let hn = len(hay)
    let nn = len(needle)
    if nn == 0: return true
    if nn > hn: return false
    var i = 0
    while i <= hn - nn:
        if slice(hay, i, i + nn) == needle:
            return true
        i = i + 1
    return false

proc not_contains(hay, needle):
    if contains(hay, needle):
        return false
    return true

var b = basic.Basic()

print("== immediate ==")
b.input_line("PRINT 1+2")
check(contains(b.out, "3\r\n"), "PRINT 1+2 shows 3")
b.reset_out()
b.input_line("PRINT (3+4)*2")
check(contains(b.out, "14\r\n"), "parenthesised arithmetic")
b.reset_out()
b.input_line("PRINT 10/3")
check(contains(b.out, "3\r\n"), "integer division truncates")
b.reset_out()
b.input_line("10 LET A=5")
b.input_line("20 PRINT A*2")
b.input_line("RUN")
check(contains(b.out, "10\r\n"), "LET + variable PRINT")
b.reset_out()

print("== PRINT strings/numbers/negatives ==")
b.new()
b.input_line("10 PRINT \"HELLO\"")
b.input_line("20 LET A = -7")
b.input_line("30 PRINT A")
b.input_line("RUN")
check(contains(b.out, "HELLO"), "PRINT string literal")
check(contains(b.out, "-7"), "PRINT negative number")

print("== GOTO / IF-THEN loop ==")
b.new()
b.input_line("10 LET I=1")
b.input_line("20 PRINT I")
b.input_line("30 LET I=I+1")
b.input_line("40 IF I<4 GOTO 20")
b.input_line("50 PRINT \"DONE\"")
b.input_line("RUN")
check(contains(b.out, "1\r\n2\r\n3\r\n"), "loop body printed")
check(contains(b.out, "DONE"), "loop exits to statement")

print("== IF/THEN with equality ==")
b.new()
b.input_line("10 LET Q=7")
b.input_line("20 IF Q=7 THEN PRINT \"YES\"")
b.input_line("30 IF Q=8 THEN PRINT \"NOPE\"")
b.input_line("RUN")
check(contains(b.out, "YES"), "IF-THEN true branch")
check(not_contains(b.out, "NOPE"), "IF-THEN false branch")

print("== FOR/NEXT ==")
b.new()
b.input_line("10 FOR I=1 TO 3")
b.input_line("20 PRINT I")
b.input_line("30 NEXT I")
b.input_line("40 PRINT \"END\"")
b.input_line("RUN")
check(contains(b.out, "1\r\n2\r\n3\r\n"), "FOR loop counts up")
check(contains(b.out, "END"), "program continues after NEXT")

print("== FOR/NEXT with STEP ==")
b.new()
b.input_line("10 FOR I=5 TO 1 STEP -1")
b.input_line("20 PRINT I")
b.input_line("30 NEXT I")
b.input_line("RUN")
check(contains(b.out, "5\r\n4\r\n3\r\n2\r\n1\r\n"), "STEP -1 counts down")

print("== INPUT ==")
b.new()
b.input_line("10 INPUT A")
b.input_line("20 PRINT A")
b.input_line("RUN")
check(contains(b.out, "OK"), "INPUT runs")
b.reset_out()
push(b.inq, "42")
b.new()
b.input_line("10 INPUT A")
b.input_line("20 PRINT A")
b.input_line("RUN")
check(contains(b.out, "42"), "INPUT reads queued value")

print("== LIST/NEW ==")
b.new()
b.input_line("10 PRINT 1")
b.input_line("20 PRINT 2")
b.input_line("LIST")
check(contains(b.out, "10 PRINT 1"), "LIST shows line 10")
b.input_line("NEW")
b.reset_out()
b.input_line("LIST")
check(not_contains(b.out, "10"), "NEW clears program")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")