class Apple2LoresPage:
    proc init(self, bus):
        self.bus = bus

    proc page_base(self, page):
        if type(page) != "number" or page != int(page):
            raise "Apple2LoresPage page must be 1 or 2"
        if page == 1:
            return 0x0400
        if page == 2:
            return 0x0800
        raise "Apple2LoresPage page must be 1 or 2"

    proc byte_address(self, row, byte_column, page):
        if type(row) != "number" or row != int(row) or row < 0 or row > 23:
            raise "Apple2LoresPage row must be 0..23"
        if type(byte_column) != "number" or byte_column != int(byte_column) or byte_column < 0 or byte_column > 39:
            raise "Apple2LoresPage byte column must be 0..39"
        let base = self.page_base(page)
        return base + (row % 8) * 0x80 + int(row / 8) * 0x28 + byte_column

    proc color(self, x, y, page):
        if type(x) != "number" or x != int(x) or x < 0 or x > 79:
            raise "Apple2LoresPage x must be 0..79"
        if type(y) != "number" or y != int(y) or y < 0 or y > 23:
            raise "Apple2LoresPage y must be 0..23"
        let byte_column = int(x / 2)
        let value = self.bus.read8(self.byte_address(y, byte_column, page))
        if x % 2 == 0:
            return (value >> 4) & 0x0F
        return value & 0x0F

    proc render_row(self, page, y, palette):
        self.page_base(page)
        if type(y) != "number" or y != int(y) or y < 0 or y > 23:
            raise "Apple2LoresPage y must be 0..23"
        if type(palette) != "array" or len(palette) != 16:
            raise "Apple2LoresPage palette must be an array of exactly 16 entries"
        var line = ""
        var x = 0
        while x < 80:
            line = line + palette[self.color(x, y, page)]
            x = x + 1
        return line

    proc render_lines(self, page, palette):
        self.page_base(page)
        if type(palette) != "array" or len(palette) != 16:
            raise "Apple2LoresPage palette must be an array of exactly 16 entries"
        var lines = []
        var y = 0
        while y < 24:
            push(lines, self.render_row(page, y, palette))
            y = y + 1
        return lines
