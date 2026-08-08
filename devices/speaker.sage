#########################################################################
## SageApple — PWM speaker device (PLAN.md §20 / M12)
##
## On the AVR target a timer drives the piezo; on the host we keep a
## transcript of requested tones.  Zero (or negative) frequency silences.
##
## Bus interface (see bus/applebus.sage):
##   $2007  write: start a tone at the given frequency (0 = silence)
#########################################################################

class Speaker:
    proc init(self):
        self.tones = []                # [freq, duration_ms]
        self.freq = 0                  # currently playing

    proc tone(self, freq, duration):
        self.freq = freq
        if freq > 0:
            push(self.tones, [freq, duration])

    proc silence(self):
        self.freq = 0

    proc beep(self):
        self.tone(1000, 100)

    proc count(self):
        return len(self.tones)

    ## host readback of the tone at position i (nil if none)
    proc tone_at(self, i):
        if i >= 0 and i < len(self.tones):
            return self.tones[i]
        return nil

    proc last(self):
        let n = len(self.tones)
        if n == 0:
            return nil
        return self.tones[n - 1]
