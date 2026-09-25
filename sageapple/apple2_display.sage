let DEFAULT_PALETTE = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"]

proc default_palette():
    return slice(DEFAULT_PALETTE, 0, len(DEFAULT_PALETTE))

class Apple2Display:
    proc init(self, bus, text, lores, hires):
        self.bus = bus
        self.text = text
        self.lores = lores
        self.hires = hires

    proc text_window_start(self):
        return 20

    proc text_window_rows(self):
        return 4

    proc page(self):
        return self.bus.video_page()

    proc mode(self):
        return self.bus.video_mode()

    proc mixed(self):
        return self.bus.video_snapshot()[1]

    proc snapshot(self):
        return [self.page(), self.mode(), self.mixed()]

    proc _validate_row(self, row):
        if type(row) != "number" or row != int(row) or row < 0 or row > 23:
            raise "Apple2Display row must be 0..23"

    proc is_text_row(self, row):
        self._validate_row(row)
        if self.mode() == "text":
            return true
        if self.mixed() == true and row >= self.text_window_start():
            return true
        return false

    proc row_source(self, row):
        if self.is_text_row(row):
            return "text"
        return "graphics"

    proc row_sources(self):
        var sources = []
        var row = 0
        while row < 24:
            push(sources, self.row_source(row))
            row = row + 1
        return sources

    proc text_lines(self, trim):
        return self.text.render_lines(self.page(), trim)

    proc text_row(self, row):
        self._validate_row(row)
        return self.text.render_lines(self.page(), false)[row]

    proc graphics_row(self, row, palette, on_char, off_char):
        self._validate_row(row)
        if self.mode() == "hires":
            let scanline = row * 8
            var line = ""
            var column = 0
            while column < 40:
                if self.hires.pixel(column * 7, scanline, self.page()):
                    line = line + on_char
                else:
                    line = line + off_char
                column = column + 1
            return line
        return self.lores.render_row(self.page(), row, palette)

    proc render_row(self, row, palette, on_char, off_char):
        if self.is_text_row(row):
            return self.text_row(row)
        return self.graphics_row(row, palette, on_char, off_char)

    proc render_lines(self, palette = DEFAULT_PALETTE, on_char = "#", off_char = "."):
        var lines = []
        var row = 0
        var text_rows = []
        while row < 24:
            if self.is_text_row(row):
                if len(text_rows) == 0:
                    text_rows = self.text.render_lines(self.page(), false)
                push(lines, text_rows[row])
            else:
                push(lines, self.graphics_row(row, palette, on_char, off_char))
            row = row + 1
        return lines

    proc render(self, palette = DEFAULT_PALETTE, on_char = "#", off_char = "."):
        return join(self.render_lines(palette, on_char, off_char), "\n")

    proc render_default(self):
        return join(self.render_lines(default_palette(), "#", "."), "\n")
