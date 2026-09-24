import bus.apple2bus
import sage6502.cpu

class Apple2Machine:
    proc init(self):
        self.bus = apple2bus.Apple2Bus()
        self.cpu = cpu.CPU(self.bus)
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
