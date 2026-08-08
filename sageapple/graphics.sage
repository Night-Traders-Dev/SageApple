#########################################################################
## SageApple — graphics (video) API (PLAN.md §18 / M10)
##
## Host-side drawing layer that drives the SPI display controller:
##   pixel / line / text rendering without touching the 6502's SRAM.
## The 6502 (or a native Sage host program) reaches the controller via
## bus ports $2002-$2004.
#########################################################################

import devices.display

## 5x7 font, glyphs for ASCII 0x20..0x7A (7 rows of 5 bits each)
let _FONT = [
    [0,0,0,0,0,0,0],
    [8,8,8,8,0,8,8],
    [10,10,10,0,0,0,0],
    [10,31,10,31,10,0,0],
    [8,31,17,30,20,31,8],
    [17,18,8,4,9,17,0],
    [14,17,14,19,18,12,0],
    [8,8,0,0,0,0,0],
    [4,8,8,8,8,8,4],
    [8,4,4,4,4,4,8],
    [0,21,14,21,0,0,0],
    [0,14,4,4,14,0,0],
    [0,0,0,0,12,4,8],
    [0,0,0,8,0,0,0],
    [0,0,0,0,0,8,0],
    [0,2,4,8,16,0,0],
    [14,17,19,21,25,17,14],
    [4,6,4,4,4,4,14],
    [14,17,1,2,4,8,31],
    [31,2,4,2,1,17,14],
    [2,6,10,18,31,2,2],
    [30,16,16,30,1,17,14],
    [2,4,8,14,17,17,14],
    [31,1,2,4,8,8,8],
    [14,17,17,14,17,17,14],
    [14,17,17,15,1,2,12],
    [0,0,8,0,0,8,0],
    [0,0,8,0,0,8,16],
    [0,2,4,8,4,2,0],
    [0,0,12,0,12,0,0],
    [0,4,2,1,2,4,0],
    [14,17,2,4,0,4,0],
    [14,17,19,21,18,16,15],
    [14,17,17,31,17,17,17],
    [30,17,17,30,17,17,30],
    [14,17,16,16,16,17,14],
    [30,17,17,17,17,17,30],
    [31,16,16,30,16,16,31],
    [31,16,16,30,16,16,16],
    [14,17,16,23,17,17,15],
    [17,17,17,31,17,17,17],
    [14,4,4,4,4,4,14],
    [7,2,2,2,2,18,12],
    [17,18,20,24,20,18,17],
    [16,16,16,16,16,16,31],
    [17,27,21,21,17,17,17],
    [17,25,21,19,17,17,17],
    [14,17,17,17,17,17,14],
    [30,17,17,30,16,16,16],
    [14,17,17,17,21,18,13],
    [30,17,17,30,20,18,17],
    [15,16,16,14,1,1,30],
    [31,4,4,4,4,4,4],
    [17,17,17,17,17,17,14],
    [17,17,17,17,17,10,4],
    [17,17,17,21,21,21,10],
    [17,17,10,4,10,17,17],
    [17,17,17,10,4,4,4],
    [31,1,2,4,8,16,31],
    [12,8,8,8,8,8,12],
    [0,16,8,4,2,0,0],
    [12,4,4,4,4,4,12],
    [0,0,10,10,4,0,0],
    [0,0,0,0,0,0,31],
    [8,4,0,0,0,0,0],
    [0,0,14,1,15,17,15],
    [16,16,30,17,17,17,16],
    [0,0,14,1,16,17,14],
    [1,1,15,17,17,17,15],
    [0,0,14,17,31,16,14],
    [6,9,8,28,8,8,8],
    [0,0,15,17,17,15,1],
    [16,16,22,25,17,17,17],
    [4,0,12,4,4,4,14],
    [4,0,4,4,4,12,8],
    [16,16,18,20,24,20,18],
    [12,4,4,4,4,4,14],
    [0,0,26,21,17,17,17],
    [0,0,22,25,17,17,17],
    [0,0,14,17,17,17,14],
    [0,0,22,17,17,22,16],
    [0,0,15,17,17,31,1],
    [0,0,22,25,17,20,0],
    [0,0,15,1,14,16,1],
    [8,8,28,8,8,9,6],
    [0,0,17,17,17,19,13],
    [0,0,17,17,17,10,4],
    [0,0,17,17,21,21,10],
    [0,0,17,10,4,10,17],
    [0,0,17,10,4,4,8],
    [0,0,3,2,4,8,9],
]

class Gfx:
    proc init(self, controller):
        self.disp = controller

    ## direct access to the display framebuffer (host path)
    proc fb(self):
        return self.disp.oled.fb

    proc clear(self, on):
        var i = 0
        while i < 1024:
            self.disp.oled.fb[i] = on
            i = i + 1

    proc put_pixel(self, x, y, on):
        if x < 0 or x > 127 or y < 0 or y > 63:
            return
        let page = y >> 3
        let bit = 1 << (y & 7)
        let idx = page * 128 + x
        if on:
            self.disp.oled.fb[idx] = self.disp.oled.fb[idx] | bit
        else:
            self.disp.oled.fb[idx] = self.disp.oled.fb[idx] & (0xFF - bit)

    proc get_pixel(self, x, y):
        if x < 0 or x > 127 or y < 0 or y > 63:
            return 0
        let idx = ((y >> 3) * 128) + x
        return (self.disp.oled.fb[idx] >> (y & 7)) & 1

    ## Bresenham line drawing
    proc draw_line(self, x0, y0, x1, y1):
        var dx = x1 - x0
        var dy = y1 - y0
        if dx < 0:
            dx = 0 - dx
        if dy < 0:
            dy = 0 - dy
        var sx = 1
        var sy = 1
        if x0 >= x1:
            sx = -1
        if y0 >= y1:
            sy = -1
        var err = dx - dy
        while true:
            self.put_pixel(x0, y0, 1)
            if x0 == x1 and y0 == y1:
                return
            let e2 = 2 * err
            if e2 > 0 - dy:
                err = err - dy
                x0 = x0 + sx
            if e2 < dx:
                err = err + dx
                y0 = y0 + sy

    ## draw one 5x7 glyph at pixel coordinate (x, y)
    proc draw_char(self, x, y, ch):
        var code = ord(ch)
        if code < 0x20 or code > 0x7A:
            code = 0x3F
        let g = _FONT[code - 0x20]
        var r = 0
        while r < 7:
            let row = g[r]
            var c = 0
            while c < 5:
                if (row >> (4 - c)) & 1:
                    self.put_pixel(x + c, y + r, 1)
                c = c + 1
            r = r + 1

    ## render a string, 6px advance per character
    proc draw_text(self, x, y, s):
        var i = 0
        let n = len(s)
        while i < n:
            self.draw_char(x, y, s[i])
            x = x + 6
            i = i + 1