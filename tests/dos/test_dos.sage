#########################################################################
## SageApple — DOS 3.3 command processor
##
## sageapple/dos.sage is 762 lines and is wired into both os.sage and
## basic.sage, but no assertion-based test covered it: scratch/parity_dos.sage
## only printed the output for a human to eyeball, so every behaviour below was
## unchecked. These are real assertions against the verbs.
##
## Run:  sage tests/dos/test_dos.sage   (from the repo root)
#########################################################################

import sageapple.machine
import sageapple.os

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
    if nn == 0:
        return true
    if nn > hn:
        return false
    var i = 0
    while i <= hn - nn:
        if slice(hay, i, i + nn) == needle:
            return true
        i = i + 1
    return false

## Small non-negative int to decimal, so buffer numbers can be spliced into a
## command string. dos.sage has its own intstr, but it is module private. This
## mirrors it: modulo for the digit, int() to truncate the quotient.
proc num(n):
    if n == 0:
        return "0"
    var v = n
    var r = ""
    while v > 0:
        r = r + "0123456789"[v % 10]
        v = int(v / 10)
    var s = ""
    var i = len(r) - 1
    while i >= 0:
        s = s + r[i]
        i = i - 1
    return s

## Run a DOS verb and return everything it printed.
proc dos(m, o, cmd):
    o.dos.command(cmd)
    return o.dos.drain()

let m = machine.SageApple()
let o = os.OS(m)
m.bus.storage.format()
o.boot()
o.drain()
let d = o.dos

#########################################################################
print("== CATALOG on a formatted volume ==")
let cat0 = dos(m, o, "CATALOG")
check(contains(cat0, "DISK VOLUME 254"), "CATALOG reports the volume number")
check(contains(cat0, "\r\n\r\n"), "CATALOG separates the header from the listing")
check(len(d.st.list()) == 0, "a freshly formatted volume is empty")

#########################################################################
print("== SAVE / CATALOG / LOAD round trip ==")
o.basic.new()
o.basic.set_line(10, "PRINT \"HELLO\"")
o.basic.set_line(20, "PRINT \"WORLD\"")
let saved = dos(m, o, "SAVE GREET")
check(saved == "", "SAVE is silent on success")
check(d.st.find("GREET") >= 0, "SAVE creates the file")
check(d.st.file_type("GREET") == 0x41, "SAVE stores it as an Applesoft (A) file")

let cat1 = dos(m, o, "CATALOG")
# An unlocked Applesoft file renders as " A 002 GREET": space prefix, type
# letter, three-digit sector count, then the name. A one-line program is 2
# sectors, and the count is zero padded to three digits.
check(contains(cat1, " A 002 GREET"), "CATALOG renders an unlocked A file in the expected layout")

# LOAD must repopulate the program from the numbered lines on disk.
o.basic.new()
check(len(o.basic.prog) == 0, "NEW clears the program before LOAD")
let loaded = dos(m, o, "LOAD GREET")
check(loaded == "", "LOAD is silent on success")
check(len(o.basic.prog) == 2, "LOAD restores both program lines")
check(o.basic.prog[0][0] == 10, "LOAD restores line number 10")
check(o.basic.prog[0][1] == "PRINT \"HELLO\"", "LOAD restores the line text")

#########################################################################
print("== LOCK / UNLOCK are visible in CATALOG ==")
let lk = dos(m, o, "LOCK GREET")
check(lk == "", "LOCK is silent on success")
check(d.st.is_locked("GREET") == 1, "LOCK sets the lock flag")
let cat2 = dos(m, o, "CATALOG")
# The lock replaces the leading space, so the line is "*A 002 GREET" with no
# space between the marker and the type letter.
check(contains(cat2, "*A 002 GREET"), "a locked file is marked with * in place of the space")

# A locked file must refuse a destructive verb.
o.basic.set_line(30, "PRINT \"NOPE\"")
let blocked = dos(m, o, "SAVE GREET")
check(contains(blocked, "FILE LOCKED"), "SAVE refuses to overwrite a locked file")
check(d.st.is_locked("GREET") == 1, "the refused SAVE left the lock alone")

let ulk = dos(m, o, "UNLOCK GREET")
check(ulk == "", "UNLOCK is silent on success")
check(d.st.is_locked("GREET") == 0, "UNLOCK clears the lock flag")
let after_unlock = dos(m, o, "SAVE GREET")
check(after_unlock == "", "SAVE succeeds once the file is unlocked")

#########################################################################
print("== RENAME ==")
let rn = dos(m, o, "RENAME GREET,GREET2")
check(rn == "", "RENAME is silent on success")
check(d.st.find("GREET") < 0, "RENAME removes the old name")
check(d.st.find("GREET2") >= 0, "RENAME creates the new name")
check(contains(dos(m, o, "CATALOG"), "GREET2"), "CATALOG shows the new name")

#########################################################################
print("== VERIFY ==")
let vf = dos(m, o, "VERIFY GREET2")
check(vf == "", "VERIFY of a present file is silent")
let vmiss = dos(m, o, "VERIFY NOSUCH")
check(contains(vmiss, "FILE NOT FOUND"), "VERIFY reports a missing file")

#########################################################################
print("== DELETE ==")
let de = dos(m, o, "DELETE GREET2")
check(de == "", "DELETE is silent on success")
check(d.st.find("GREET2") < 0, "DELETE removes the directory entry")
check(not contains(dos(m, o, "CATALOG"), "GREET2"), "the deleted file leaves CATALOG")

#########################################################################
print("== error paths ==")
check(contains(dos(m, o, "SAVE"), "SYNTAX ERROR"), "SAVE with no name is a syntax error")
check(contains(dos(m, o, "LOAD NOSUCH"), "FILE NOT FOUND"), "LOAD of a missing file is reported")
check(contains(dos(m, o, "DELETE NOSUCH"), "FILE NOT FOUND"), "DELETE of a missing file is reported")
check(contains(dos(m, o, "BOGUSVERB"), "SYNTAX ERROR"), "an unknown verb is a syntax error")
check(dos(m, o, "   ") == "", "a blank line is ignored quietly")

#########################################################################
print("== LOAD refuses a binary file ==")
d.st.save_binary("BLOB1", [1, 2, 3, 4])
check(d.st.file_type("BLOB1") == 0x42, "save_binary stores a B file")
check(contains(dos(m, o, "LOAD BLOB1"), "FILE TYPE MISMATCH"), "LOAD refuses a B file")

#########################################################################
print("== text buffers: OPEN / READ / WRITE / APPEND / CLOSE ==")
d.st.save_text("LOG", ["ALPHA", "BETA", "GAMMA"])
check(d.st.file_type("LOG") == 0x54, "save_text stores a T file")

let op = dos(m, o, "OPEN LOG")
check(op == "", "OPEN is silent on success")
check(len(d.buffers) == 1, "OPEN allocates one buffer")
check(d.buffers[0]["name"] == "LOG", "the buffer remembers the file name")
check(d.buffers[0]["mode"] == "r", "OPEN defaults to read mode")
check(len(d.buffers[0]["lines"]) == 3, "the buffer holds the three lines")

check(contains(dos(m, o, "READ 1"), ""), "READ 1 is silent on success")
check(d.active_read == 0, "READ makes that buffer the active read source")

# INPUT pulls a line from the active read buffer.
let first = d.input_line()
check(first == "ALPHA", "INPUT yields the first line of the file")
let second = d.input_line()
check(second == "BETA", "INPUT advances to the second line")

# POSITION rewinds, so the next INPUT starts over. This used to be impossible:
# the verb sliced the record number from the separator itself, so the digit scan
# always came up empty and every call was a syntax error.
check(dos(m, o, "POSITION 1,0") == "", "POSITION 1,0 is accepted")
check(d.buffers[0]["pos"] == 0, "POSITION rewinds the read position")
check(d.input_line() == "ALPHA", "after POSITION the first line reads again")
check(dos(m, o, "POSITION 1,1") == "", "POSITION 1,1 is accepted")
check(d.input_line() == "BETA", "POSITION 1,1 skips to the second line")
check(contains(dos(m, o, "POSITION 1"), "SYNTAX ERROR"), "POSITION with no record number is a syntax error")

# WRITE mode captures BASIC PRINT output into the buffer on close.
d.st.save_text("OUT", [])
check(contains(dos(m, o, "OPEN OUT"), ""), "OPEN a T file for writing")
d.buffers[1]["mode"] = "w"
check(contains(dos(m, o, "WRITE 2"), ""), "WRITE 2 is silent on success")
check(d.active_write == 1, "WRITE makes that buffer the active write target")
d.print_line("CAPTURED")
check(contains(dos(m, o, "CLOSE 2"), ""), "CLOSE 2 is silent on success")
check(len(d.buffers) == 1, "closing one buffer leaves the other open")
let reread = d.st.load_text("OUT")
check(len(reread) == 1 and reread[0] == "CAPTURED", "the captured line was committed to disk on CLOSE")

#########################################################################
print("== buffer error paths ==")
check(contains(dos(m, o, "OPEN LOG"), "FILE ALREADY OPEN"), "reopening an open file is refused")
check(contains(dos(m, o, "CLOSE 9"), "FILE NOT OPEN"), "CLOSE of an unopened number is refused")
check(contains(dos(m, o, "READ 9"), "FILE NOT OPEN"), "READ of an unopened number is refused")
check(contains(dos(m, o, "READ"), "SYNTAX ERROR"), "READ with no buffer number is a syntax error")
check(contains(dos(m, o, "OPEN NOSUCH"), "FILE NOT FOUND"), "OPEN of a missing file is refused")
check(contains(dos(m, o, "OPEN BLOB1"), "FILE TYPE MISMATCH"), "OPEN of a B file is refused")
check(contains(dos(m, o, "OPEN"), "SYNTAX ERROR"), "OPEN with no name is a syntax error")

# MAXFILES caps how many buffers can be open at once.
d.st.save_text("T2", ["X"])
d.st.save_text("T3", ["Y"])
let before = len(d.buffers)
check(contains(dos(m, o, "MAXFILES 1"), ""), "MAXFILES 1 is accepted")
check(d.maxfiles == 1, "MAXFILES updates the limit")
check(contains(dos(m, o, "OPEN T2"), "NO BUFFERS AVAILABLE"), "a full buffer table is refused")
dos(m, o, "MAXFILES 3")
check(d.maxfiles == 3, "MAXFILES can be raised again")
check(dos(m, o, "OPEN T2") == "", "raising MAXFILES lets the OPEN through")
check(len(d.buffers) == before + 1, "the buffer count grew by one")

# CLOSE with no argument closes everything.
check(contains(dos(m, o, "CLOSE"), ""), "bare CLOSE is silent")
check(len(d.buffers) == 0, "bare CLOSE releases every buffer")
check(d.active_read == nil, "bare CLOSE clears the active read buffer")
check(d.active_write == nil, "bare CLOSE clears the active write buffer")

#########################################################################
print("== slot selection and MON ==")
check(contains(dos(m, o, "PR# 1"), ""), "PR# 1 is accepted")
check(d.outslot == 1, "PR# sets the output slot")
check(contains(dos(m, o, "IN# 2"), ""), "IN# 2 is accepted")
check(d.inslot == 2, "IN# sets the input slot")
check(contains(dos(m, o, "MON"), ""), "MON is accepted")
check(d.mon_c > 0, "MON turns on the character counter")
check(contains(dos(m, o, "NOMON"), ""), "NOMON is accepted")
check(d.mon_c == 0, "NOMON turns the counters off")

#########################################################################
print("== APPEND extends an existing text file ==")
check(contains(dos(m, o, "APPEND NOLOG"), ""), "APPEND can create a file that does not exist yet")
check(len(d.buffers) == 1, "APPEND opened one buffer")
check(d.buffers[0]["mode"] == "a", "APPEND puts the buffer in append mode")
d.print_line("FIRST")
check(contains(dos(m, o, "CLOSE"), ""), "closing the append buffer is silent")
let af = d.st.load_text("NOLOG")
check(len(af) == 1 and af[0] == "FIRST", "APPEND created the file with the captured line")

# A second APPEND must keep what is already on disk.
d.st.save_text("TWICE", ["EXISTING"])
check(contains(dos(m, o, "APPEND TWICE"), ""), "APPEND on an existing file is accepted")
d.print_line("ADDED")
check(contains(dos(m, o, "CLOSE"), ""), "closing the second append buffer is silent")
let tf = d.st.load_text("TWICE")
check(len(tf) == 2, "APPEND grew the file to two lines")
check(tf[0] == "EXISTING", "APPEND kept the original line")
check(tf[1] == "ADDED", "APPEND put the new line after it")
check(contains(dos(m, o, "APPEND BLOB1"), "FILE TYPE MISMATCH"), "APPEND refuses a binary file")
check(contains(dos(m, o, "APPEND"), "SYNTAX ERROR"), "APPEND with no name is a syntax error")

#########################################################################
print("== POSITION past end of file is safe ==")
d.st.save_text("SHORT", ["ONLY"])
check(contains(dos(m, o, "OPEN SHORT"), ""), "OPEN a one-line file")
# Buffer numbers are the monotonically increasing id handed out at OPEN, not the
# slot index, so ask for the number this buffer was actually given.
let short_id = d.buffers[0]["id"]
check(contains(dos(m, o, "READ " + num(short_id)), ""), "READ selects the buffer by its number")
check(contains(dos(m, o, "POSITION " + num(short_id) + ",99"), ""), "POSITION past the end is accepted")
check(d.buffers[0]["pos"] == 99, "the position is stored as given")
# input_line and input_eof both clamp on pos >= len(lines), so an out-of-range
# record must read as end of file rather than indexing past the line list.
check(d.input_eof() == 1, "input_eof reports end of file past the last record")
check(d.input_line() == nil, "input_line yields nil past the last record")
check(contains(dos(m, o, "CLOSE"), ""), "the buffer still closes cleanly")
check(contains(dos(m, o, "READ " + num(short_id)), "FILE NOT OPEN"), "a closed buffer number is reported gone")

#########################################################################
print("== BSAVE / BLOAD / BRUN move raw bytes ==")
m.bus.write8(0x0300, 0x01)
m.bus.write8(0x0301, 0x02)
m.bus.write8(0x0302, 0x03)
m.bus.write8(0x0303, 0x04)
check(contains(dos(m, o, "BSAVE RAWBIN,A768,L4"), ""), "BSAVE of four bytes at $300 is accepted")
check(d.st.find("RAWBIN") >= 0, "BSAVE creates the file")
check(d.st.file_type("RAWBIN") == 0x42, "BSAVE stores it as a binary (B) file")
let raw = d.st.load_blob("RAWBIN")
check(len(raw) == 4, "BSAVE wrote four bytes")
check(raw[0] == 0x01 and raw[3] == 0x04, "BSAVE preserved the byte values")
check(contains(dos(m, o, "BSAVE"), "SYNTAX ERROR"), "BSAVE with no name is a syntax error")

# Wipe memory, then BLOAD must put the bytes back at their address.
m.bus.write8(0x0300, 0x00)
m.bus.write8(0x0301, 0x00)
check(contains(dos(m, o, "BLOAD RAWBIN"), ""), "BLOAD is accepted")
check(m.bus.read8(0x0300) == 0x01, "BLOAD restored the first byte at $300")
check(m.bus.read8(0x0303) == 0x04, "BLOAD restored the last byte at $303")
check(contains(dos(m, o, "BLOAD NOSUCH"), "FILE NOT FOUND"), "BLOAD of a missing file is reported")

# BRUN loads then executes at $300, so the CPU must stop rather than run away.
let before_pc = m.cpu.regs.pc
check(contains(dos(m, o, "BRUN NOSUCH"), ""), "BRUN of a missing file is quiet")
check(m.cpu.regs.pc == before_pc, "a failed BRUN does not move the PC")
check(contains(dos(m, o, "BRUN"), "SYNTAX ERROR"), "BRUN with no name is a syntax error")

#########################################################################
print("== INIT reformats the volume and installs HELLO ==")
d.st.save_text("GONER", ["X"])
check(d.st.find("GONER") >= 0, "a file exists before INIT")
o.basic.new()
o.basic.set_line(10, "PRINT \"FROM HELLO\"")
check(contains(dos(m, o, "INIT"), ""), "bare INIT is silent on success")
check(d.st.find("GONER") < 0, "INIT wiped the previous directory")
check(d.st.find("HELLO") >= 0, "INIT installed the HELLO program")
check(d.st.file_type("HELLO") == 0x41, "HELLO is an Applesoft file")
# DOS treats trailing text as a volume name; it must still be accepted.
check(contains(dos(m, o, "INIT VOLNAME"), ""), "INIT with a trailing volume name is accepted")
check(d.st.find("HELLO") >= 0, "the volume name did not disturb the HELLO program")
check(len(d.buffers) == 0, "INIT left no buffers behind")

#########################################################################
print("== EXEC is bounded ==")
check(contains(dos(m, o, "EXEC"), "SYNTAX ERROR"), "EXEC with no name is a syntax error")
check(contains(dos(m, o, "EXEC NOSUCH"), ""), "EXEC of a missing file is quiet")
check(d.exec_depth == 0, "exec_depth is back to zero after EXEC returns")

#########################################################################
print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")

