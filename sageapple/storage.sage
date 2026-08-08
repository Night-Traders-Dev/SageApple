#########################################################################
## SageApple — SAGEFS-6502 filesystem (PLAN.md §21 / M11)
##
## Minimal flash filesystem on top of the SPI flash chip:
##   block 0      directory: magic "SF", version, then 16 entries
##   entry        name(12 NUL-padded) size(u16 LE) start-block(u16 LE)
##   blocks 1..   file data, contiguous, first-fit allocation
##
## Text files are saved as lines joined by CRLF.  All access is via the
## host-side Storage class; the 6502 reaches the chip through $2005/$2006.
#########################################################################

import devices.flash

let _BLOCK = 256
let _ENTRIES = 16
let _BLOCKS = 256

## render a byte as a printable character
proc _printable(v):
    let ch = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
    if v >= 32 and v < 127:
        return ch[v - 32]
    return " "

## list membership
proc _has(list, v):
    var i = 0
    while i < len(list):
        if list[i] == v:
            return 1
        i = i + 1
    return 0

class Storage:
    proc init(self, chip):
        self.chip = chip

    ## ---- byte access to the chip's array (host driver) ----
    proc read_byte(self, a):
        return self.chip.mem[a & (self.chip.size - 1)]

    proc write_byte(self, a, b):
        self.chip.mem[a & (self.chip.size - 1)] = b & 0xFF

    ## wipe the filesystem: data erased to $FF, directory zeroed.
    ## The directory spans block 0 plus 16 bytes of block 1, so
    ## allocations start at block 2.
    proc format(self):
        var b = 1
        while b < _BLOCKS:
            var j = 0
            while j < _BLOCK:
                self.write_byte(b * _BLOCK + j, 0xFF)
                j = j + 1
            b = b + 1
        var i = 0
        while i < 16 + _ENTRIES * 16:
            self.write_byte(i, 0x00)
            i = i + 1
        self.write_byte(0, 0x53)     # "S"
        self.write_byte(1, 0x46)     # "F"
        self.write_byte(2, 0x01)     # format version
        return 0

    proc dir_off(self, i):
        return 16 + i * 16

    ## directory entry name ("" = empty slot)
    proc name_at(self, i):
        var s = ""
        let o = self.dir_off(i)
        var j = 0
        while j < 12:
            let c = self.read_byte(o + j)
            if c == 0:
                break
            s = s + _printable(c)
            j = j + 1
        return s

    proc size_of(self, name):
        var i = 0
        while i < _ENTRIES:
            if self.name_at(i) == name:
                let o = self.dir_off(i)
                return self.read_byte(o + 12) | (self.read_byte(o + 13) << 8)
            i = i + 1
        return -1

    ## first-fit run of `need` consecutive free data blocks
    proc find_free_run(self, need):
        var used = []
        var i = 0
        while i < _ENTRIES:
            if self.name_at(i) != "":
                let o = self.dir_off(i)
                let sz = self.read_byte(o + 12) | (self.read_byte(o + 13) << 8)
                let st = self.read_byte(o + 14) | (self.read_byte(o + 15) << 8)
                let nb = int((sz + _BLOCK - 1) / _BLOCK)
                var b = st
                while b < st + nb and b < _BLOCKS:
                    push(used, b)
                    b = b + 1
            i = i + 1
        var blk = 2
        while blk < _BLOCKS:
            var run = 0
            while run < need:
                if _has(used, blk + run):
                    break
                run = run + 1
            if run == need:
                return blk
            blk = blk + run + 1
        return -1

    ## save raw bytes under a name (overwrites an existing file)
    proc save_blob(self, name, blob):
        let n = len(name)
        if n > 12:
            n = 12
        if n == 0:
            return -1
        var slot = -1
        var i = 0
        while i < _ENTRIES:
            let nm = self.name_at(i)
            if nm == name:
                slot = i
                break
            if nm == "" and slot == -1:
                slot = i
            i = i + 1
        if slot == -1:
            return -1
        let need = int((len(blob) + _BLOCK - 1) / _BLOCK) + 1
        let start = self.find_free_run(need)
        if start == -1:
            return -1
        let o = self.dir_off(slot)
        var j = 0
        while j < 12:
            if j < n:
                self.write_byte(o + j, ord(name[j]))
            else:
                self.write_byte(o + j, 0)
            j = j + 1
        let sz = len(blob)
        self.write_byte(o + 12, sz & 0xFF)
        self.write_byte(o + 13, (sz >> 8) & 0xFF)
        self.write_byte(o + 14, start & 0xFF)
        self.write_byte(o + 15, (start >> 8) & 0xFF)
        var k = 0
        while k < sz:
            self.write_byte(start * _BLOCK + k, blob[k])
            k = k + 1
        return 0

    ## load raw bytes back ([] if missing)
    proc load_blob(self, name):
        var slot = -1
        var i = 0
        while i < _ENTRIES:
            if self.name_at(i) == name:
                slot = i
                break
            i = i + 1
        if slot == -1:
            return []
        let o = self.dir_off(slot)
        let sz = self.read_byte(o + 12) | (self.read_byte(o + 13) << 8)
        let st = self.read_byte(o + 14) | (self.read_byte(o + 15) << 8)
        var blob = []
        var k = 0
        while k < sz:
            push(blob, self.read_byte(st * _BLOCK + k))
            k = k + 1
        return blob

    ## store text lines (CRLF-joined)
    proc save_text(self, name, lines):
        var blob = []
        var i = 0
        while i < len(lines):
            if i > 0:
                push(blob, 13)
                push(blob, 10)
            let ln = lines[i]
            var j = 0
            while j < len(ln):
                push(blob, ord(ln[j]))
                j = j + 1
            i = i + 1
        return self.save_blob(name, blob)

    ## load text lines back
    proc load_text(self, name):
        var blob = self.load_blob(name)
        var s = ""
        var i = 0
        while i < len(blob):
            let b = blob[i]
            if b == 10:
                s = s + "\n"
            elif b == 13:
                s = s + "\r"
            else:
                s = s + _printable(b)
            i = i + 1
        var lines = []
        var cur = ""
        var j = 0
        while j < len(s):
            if j + 1 < len(s) and s[j] == "\r" and s[j + 1] == "\n":
                push(lines, cur)
                cur = ""
                j = j + 2
            else:
                cur = cur + s[j]
                j = j + 1
        if cur != "":
            push(lines, cur)
        return lines

    proc delete(self, name):
        var slot = -1
        var i = 0
        while i < _ENTRIES:
            if self.name_at(i) == name:
                slot = i
                break
            i = i + 1
        if slot == -1:
            return -1
        let o = self.dir_off(slot)
        var j = 0
        while j < 16:
            self.write_byte(o + j, 0)
            j = j + 1
        return 0

    ## list of stored file names
    proc list(self):
        var names = []
        var i = 0
        while i < _ENTRIES:
            let nm = self.name_at(i)
            if nm != "":
                push(names, nm)
            i = i + 1
        return names
