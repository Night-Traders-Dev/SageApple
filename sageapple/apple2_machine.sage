import bus.apple2bus
import sage6502.cpu
import sageapple.apple2_hires
import sageapple.apple2_text

class Apple2Machine:
    proc init(self):
        self.bus = apple2bus.Apple2Bus()
        self.cpu = cpu.CPU(self.bus)
        self.text = apple2_text.Apple2TextPage(self.bus)
        self.hires = apple2_hires.Apple2HiresPage(self.bus)
        self.booted = false

    proc load_rom(self, image):
        let result = self.bus.load_rom(image)
        if result != 0:
            return result
        self.cpu.reset()
        self.booted = true
        return 0

    proc reset(self):
        self.bus.reset()
        self.cpu.reset()
        self.booted = true

    proc run(self, steps):
        self.cpu.run(steps)

    proc serial_input(self, value):
        self.bus.serial_input(value)

    proc keyboard_input(self, value):
        self.bus.keyboard_input(value)

    proc serial_text(self):
        return self.bus.serial_text()

    proc render_text(self, page, trim):
        return join(self.text.render_lines(page, trim), "\n")

    proc hires_pixel(self, page, x, y):
        return self.hires.pixel(x, y, page)

    proc render_hires(self, page, on_char, off_char):
        return join(self.hires.render_lines(page, on_char, off_char), "\n")

    proc video_snapshot(self):
        return self.bus.video_snapshot()

    proc video_mode(self):
        return self.bus.video_mode()

    proc video_page(self):
        return self.bus.video_page()
