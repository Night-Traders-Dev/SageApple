class Apple2HiresPage:
    proc init(self, bus):
        self.bus = bus

    proc page_base(self, page):
        if type(page) != "number" or page != int(page):
            raise "Apple2HiresPage page must be 1 or 2"
        if page == 1:
            return 0x2000
        if page == 2:
            return 0x4000
        raise "Apple2HiresPage page must be 1 or 2"

    proc byte_address(self, row, byte_column, page):
        if type(row) != "number" or row != int(row) or row < 0 or row > 191:
            raise "Apple2HiresPage row must be 0..191"
        if type(byte_column) != "number" or byte_column != int(byte_column) or byte_column < 0 or byte_column > 39:
            raise "Apple2HiresPage byte column must be 0..39"
        let base = self.page_base(page)
        return base + (row % 64) * 0x80 + int(row / 64) * 0x28 + byte_column

    proc read_byte(self, row, byte_column, page):
        return self.bus.read8(self.byte_address(row, byte_column, page))

    proc pixel(self, x, y, page):
        if type(x) != "number" or x != int(x) or x < 0 or x > 279:
            raise "Apple2HiresPage x must be 0..279"
        if type(y) != "number" or y != int(y) or y < 0 or y > 191:
            raise "Apple2HiresPage y must be 0..191"
        let byte_column = int(x / 8)
        let bit = x % 8
        let value = self.read_byte(y, byte_column, page)
        return ((value & 0x7F) & (1 << bit)) != 0

    proc render_row(self, page, y, on_char, off_char):
        self.page_base(page)
        if type(y) != "number" or y != int(y) or y < 0 or y > 191:
            raise "Apple2HiresPage y must be 0..191"
        var line = ""
        var x = 0
        while x < 280:
            if self.pixel(x, y, page):
                line = line + on_char
            else:
                line = line + off_char
            x = x + 1
        return line

    proc render_lines(self, page, on_char, off_char):
        self.page_base(page)
        var lines = []
        var y = 0
        while y < 192:
            push(lines, self.render_row(page, y, on_char, off_char))
            y = y + 1
        return lines
