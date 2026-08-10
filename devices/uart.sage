#########################################################################
## SageApple — 6502 UART device (PLAN.md §13 / M6)
##
## Memory-mapped at $2000-$2001 on the Apple bus:
##   $2000  status  read: bit0 RX-ready, bit1 TX-ready
##   $2001  read: RX data (FIFO) ; write: TX data
##
## On the AVR target these registers drive the real 16MHz UART. On the host
## the device is FIFO-backed so a terminal (or tests) can feed/read chars.
#########################################################################

class UART:
    proc init(self):
        self.rx = []
        self.rx_head = 0
        self.tx = []
        self.tx_rendered = 0
        self.tx_str = ""

    ## flag a byte received (keyboard -> RX FIFO)
    proc receive(self, ch):
        push(self.rx, ch & 0xFF)

    ## feed a whole string (byte stream) into the RX FIFO
    proc receive_str(self, s):
        var i = 0
        let n = len(s)
        while i < n:
            push(self.rx, ord(s[i]) & 0xFF)
            i = i + 1

    proc status(self):
        var s = 0x02              # TX always ready
        if self.rx_ready() == 1:
            s = s | 0x01
        return s

    proc rx_ready(self):
        if self.rx_head < len(self.rx):
            return 1
        return 0

    proc tx_write(self, char):
        push(self.tx, char & 0xFF)
        return 0

    proc rx_read(self):
        if self.rx_head < len(self.rx):
            let v = self.rx[self.rx_head]
            self.rx_head = self.rx_head + 1
            return v
        return 0x00

    ## host-side readback of transmitted bytes
    proc tx_len(self):
        return len(self.tx)

    proc tx_text(self):
        var i = self.tx_rendered
        let n = len(self.tx)
        var chunk = ""
        while i < n:
            let b = self.tx[i]
            if b == 13:
                chunk = chunk + "\r"
            elif b == 10:
                chunk = chunk + "\n"
            else:
                chunk = chunk + _printable(b)
            i = i + 1
        self.tx_rendered = n
        self.tx_str = self.tx_str + chunk
        return self.tx_str

proc _printable(v):
    let ch = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
    if v >= 32 and v < 127:
        return ch[v - 32]
    return " "