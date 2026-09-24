class Apple2TextPage:
    proc init(self, bus):
        self.bus = bus

    proc page_base(self, page):
        if type(page) != "number" or page != int(page):
            raise "Apple2TextPage page must be 1 or 2"
        if page == 1:
            return 0x0400
        if page == 2:
            return 0x0800
        raise "Apple2TextPage page must be 1 or 2"

    proc cell_address(self, row, column, page):
        if type(row) != "number" or row != int(row) or row < 0 or row > 23:
            raise "Apple2TextPage row must be 0..23"
        if type(column) != "number" or column != int(column) or column < 0 or column > 39:
            raise "Apple2TextPage column must be 0..39"
        let base = self.page_base(page)
        return base + (row % 8) * 0x80 + int(row / 8) * 0x28 + column

    proc cell(self, row, column, page):
        let value = self.bus.read8(self.cell_address(row, column, page))
        var character = value & 0x7F
        if character == 0:
            character = 0x20
        var mode = "normal"
        if value <= 0x3F:
            mode = "inverse"
        elif value <= 0x7F:
            mode = "flash"
        return [chr(character), mode]

    proc render_lines(self, page, trim):
        self.page_base(page)
        var lines = []
        var row = 0
        while row < 24:
            var line = ""
            var line_end = 0
            var column = 0
            while column < 40:
                let decoded = self.cell(row, column, page)
                let character = decoded[0]
                line = line + character
                if character != " ":
                    line_end = column + 1
                column = column + 1
            if trim:
                push(lines, slice(line, 0, line_end))
            else:
                push(lines, line)
            row = row + 1
        return lines

    proc render_ansi(self, page, trim):
        self.page_base(page)
        var lines = []
        var row = 0
        while row < 24:
            var line = ""
            var line_end = 0
            var column = 0
            while column < 40:
                let decoded = self.cell(row, column, page)
                let character = decoded[0]
                var rendered = character
                if decoded[1] == "inverse":
                    rendered = "\x1b[7m" + character + "\x1b[27m"
                elif decoded[1] == "flash":
                    rendered = "\x1b[5m" + character + "\x1b[25m"
                line = line + rendered
                if character != " ":
                    line_end = len(line)
                column = column + 1
            if trim:
                push(lines, slice(line, 0, line_end))
            else:
                push(lines, line)
            row = row + 1
        return lines
