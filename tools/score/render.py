"""离线合成与混音。所有乐音均由振荡器、噪声、指数衰减与延迟生成。"""
from pathlib import Path

import numpy as np
import soundfile as sf

from score import SCORES, events, pitch

RATE = 24000
TAU = np.pi * 2
OUTPUT = Path(__file__).resolve().parents[2] / "assets" / "score"


def instrument(name, midi, seconds, rng):
    hz = 440 * 2 ** ((midi - 69) / 12)
    sustained = name in ("flute", "reed", "bow")
    release = .34 if sustained else {"glass": 1.65, "zither": 1.05, "lute": .65, "bass": .48, "wood": .12, "skin": .14}[name]
    t = np.arange(round((seconds + release) * RATE)) / RATE
    phase = TAU * hz * t
    signal = np.zeros_like(t)
    after = np.maximum(0, t - seconds)
    if sustained:
        # Slow pitch drift, developing vibrato, very slight attack scoop.
        cents = {"flute": 8, "reed": 4, "bow": 13}[name]
        phase += (TAU * hz * .003 * .06 * np.exp(-t / .06)
                  + hz * (.000578 * cents) / 4.9 * np.sin(TAU * 4.9 * t) * (1 - np.exp(-t / .23)))
        partials = {"flute": (1, .26, .11, .036), "reed": (1, .19, .38, .08, .17, .04, .03),
                    "bow": (.88, .59, .34, .2, .17, .12, .065, .04)}[name]
        for h, weight in enumerate(partials, 1):
            signal += weight * np.sin(h * phase + h * .06) * (1 + .075 * np.sin(TAU * (.8 + h * .13) * t))
        air = np.convolve(rng.normal(size=len(t)), np.ones(5) / 5, mode="same")
        signal += (.018 + .07 * np.exp(-t / .075)) * air
        attack = {"flute": .065, "reed": .048, "bow": .105}[name]
        signal *= (1 - np.exp(-t / attack)) * (.84 + .16 * np.sin(np.pi * np.minimum(1, t / seconds)))
        signal *= np.exp(-after / .054)
    elif name in ("lute", "zither", "bass"):
        pick, decay, strings = {"lute": (.22, .44, 2), "zither": (.16, .84, 2), "bass": (.34, .51, 1)}[name]
        for h in range(1, 14):
            if hz * h >= RATE * .45: break
            weight = np.sin(np.pi * h * pick) / (h ** 1.15)
            partial = np.sin(phase * h * (1 + .000045 * h * h))
            if strings == 2:
                partial = .71 * partial + .29 * np.sin(phase * h * 1.0018 + .13)
            signal += weight * partial * np.exp(-t * (1 + h * .30) / decay)
        signal *= (1 - np.exp(-t / .0035)) * np.exp(-after / (.26 if name == "zither" else .17))
    elif name == "glass":
        for ratio, weight, decay in [(1, .78, 1.18), (2.003, .27, .69), (2.72, .16, .24), (4.12, .08, .14)]:
            signal += weight * np.sin(ratio * phase) * np.exp(-t / decay)
        signal *= (1 - np.exp(-t / .006)) * np.exp(-after / .39)
    else:
        # Felt drum / woodblock, softened attacks for close phone speakers.
        for ratio, weight, decay in [(1, 1, .078), (1.52, .32, .041), (2.91, .20, .034)]:
            signal += weight * np.sin(phase * ratio + (2.1 if name == "skin" else .3) * (1 - np.exp(-t / .018))) * np.exp(-t / decay)
        signal *= 1 - np.exp(-t / .004)
    signal[-min(192, len(t)):] *= np.linspace(1, 0, min(192, len(t)))
    return signal


class Mix:
    def __init__(self, seconds, seed):
        self.duration = round(seconds * RATE)
        self.samples = np.zeros((self.duration + 3 * RATE, 2))
        self.rng = np.random.default_rng(seed)

    def note(self, when, name, midi, seconds, gain, pan):
        start = max(0, round(when * RATE))
        signal = instrument(name, midi, seconds, self.rng)
        length = min(len(signal), len(self.samples) - start)
        if length <= 0: return
        angle = (pan + 1) * np.pi / 4
        self.samples[start:start + length] += signal[:length, None] * gain * np.array([np.cos(angle), np.sin(angle)])

    def finish(self, loop=False):
        dry = self.samples
        stereo = dry.copy()
        for milliseconds, gain, cross in [(27, .12, True), (49, .09, False), (81, .065, True), (127, .045, False), (193, .028, True), (281, .016, True)]:
            delay = round(milliseconds * RATE / 1000)
            stereo[delay:] += dry[:-delay, ::-1 if cross else 1] * gain
        out = stereo[:self.duration].copy()
        if loop:
            tail = stereo[self.duration:]
            out[:min(len(tail), len(out))] += tail[:len(out)]
        # The longest release is allowed to ring before a short zero crossing taper.
        fade = min(192, len(out) // 2)
        out[:fade] *= np.linspace(0, 1, fade)[:, None]
        out[-fade:] *= np.linspace(1, 0, fade)[:, None]
        return out


def phrase(bus, score, bar, start, eighth, instrument_name, gain, pan):
    notes = list(events(bar))
    for i, (pos, degree, length) in enumerate(notes):
        cadence = i == len(notes) - 1
        duration = eighth * length * (.87 if cadence else .79)
        velocity = (1 if i == 0 else .89) * (.92 + .08 * np.sin(np.pi * (i + .5) / len(notes)))
        bus.note(start + pos * eighth + bus.rng.uniform(.002, .014), instrument_name,
                 pitch(score, degree), duration, gain * velocity, pan + bus.rng.uniform(-.06, .06))


def save(name, signal, peak=.64):
    normalized = signal / np.abs(signal).max()
    if name.endswith("_lead") or name.startswith("seal_"):
        # Round the strongest pick transients, then match energy across wind and string solos.
        normalized = np.tanh(1.55 * normalized) / np.tanh(1.55)
        target_rms = .113 if name == "seal_song" else .094
        peak = min(peak, target_rms / np.sqrt(np.mean(normalized ** 2)))
    signal = normalized * peak
    sf.write(OUTPUT / (name + ".ogg"), signal.astype("float32"), RATE, format="OGG", subtype="VORBIS", compression_level=.55)


def make_scene(name, score, seed):
    eighth = 30 / score.bpm
    measure = score.eighths * eighth
    lead = Mix(8 * measure, seed)
    layer = Mix(8 * measure, seed + 100)
    for i, bar in enumerate(score.bars):
        start = i * measure
        root = pitch(score, score.bass[i]) - 12
        if name in ("wuwei", "jiuquan"): root -= 12 if root > 54 else 0
        phrase(lead, score, bar, start, eighth, score.lead, .78, -.12)
        lead.note(start + .036, "bass", root, measure * .58, .47, -.16)
        if i in (1, 3, 5, 7):
            # Answers fill the breath at the end of even bars.
            lead.note(start + (score.eighths - 2) * eighth, score.answer, root + 12, eighth * .86, .29, .39)
            if i != 7: lead.note(start + (score.eighths - 1) * eighth, score.answer, root + 19, eighth * .75, .24, .33)
        for j, pulse in enumerate(score.pulse):
            moment = start + pulse * eighth + (.007 if j else .0)
            register = (0, 7, 12, 7, 12)[j % 5]
            layer.note(moment, "zither" if name in ("zhangye", "dunhuang") else "lute",
                       root + register, eighth * 1.35, .49 if j == 0 else .31, -.39 + .20 * (j % 4))
            if i != 7 or j < 2:
                layer.note(moment + .011, "skin" if j == 0 else "wood", 41 if j == 0 else 75,
                           .08, .18 if j == 0 else .075, -.22 if j == 0 else .47)
    save(name + "_lead", lead.finish(True), .65)
    save(name + "_motion", layer.finish(True), .29)
    if score.stamp:
        bus = Mix((score.eighths + 1) * eighth + 1.2, seed + 200)
        phrase(bus, score, score.stamp, .06, eighth * .80, score.lead, .82, -.10)
        bus.note(.048, "zither", score.tonic - 12, .66, .37, .37)
        last = list(events(score.stamp))[-1]
        bus.note(.07 + last[0] * eighth * .80, "glass", pitch(score, last[1]) + 12, .31, .12, .33)
        save("seal_" + name, bus.finish(), .59)


def make_song():
    # Introduction, six timbral solos over alternating plucks, shared reprise, tonic cadence.
    eighth = .31
    bar = 8 * eighth
    bus = Mix(10 * bar + 1.6, 909)
    home = SCORES["map"]
    phrase(bus, home, "r:1 0:2 1:1 3:3", 0, eighth, "zither", .63, -.23)
    bus.note(.04, "glass", 62, .6, .32, .33)
    for i, score in enumerate(s for s in SCORES.values() if s.stamp):
        start = (i + 1) * bar
        phrase(bus, score, score.stamp, start, eighth, score.lead, .87, -.24 + .09 * i)
        bus.note(start + .02, "bass", score.tonic - 24, 1.2, .49, -.15)
        for j, interval in enumerate((0, 7, 12)):
            bus.note(start + (.42 + j * 2.3) * eighth, "zither", score.tonic - 12 + interval, .33, .29, .39)
        if i >= 2: bus.note(start + 4.05 * eighth, "wood", 70, .10, .105, -.47)
    for i, line in enumerate(("0:2 1:1 3:3 5:2", "4:2 3:2 2:2 1:2", "0:6 r:2")):
        start = (i + 7) * bar
        phrase(bus, home, line, start, eighth, "flute", .72, -.20)
        phrase(bus, home, line, start + .035, eighth, "lute", .48, .24)
        bus.note(start, "bass", (50, 45, 50)[i], 1.45, .55, -.14)
        bus.note(start + .14, "bow", (57, 55, 57)[i], 1.35, .27, .34)
        if i == 2:
            for j, midi in enumerate((50, 57, 62, 69)):
                bus.note(start + j * .13, "zither", midi, .8, .36 - j * .045, -.36 + j * .23)
    save("seal_song", bus.finish(), .72)


def make_cues():
    # name, timbre, (time, MIDI, held seconds)… ; the retry gently folds downward.
    lines = {
        "step": ("wood", [(0, 70, .08), (.075, 77, .09)]),
        "hint": ("flute", [(0, 69, .13), (.19, 74, .28)]),
        "miss": ("lute", [(0, 67, .13), (.18, 64, .27)]),
        "discover": ("glass", [(0, 62, .20), (.15, 69, .18), (.34, 76, .39)]),
        "win": ("zither", [(0, 62, .19), (.14, 66, .18), (.28, 69, .19), (.53, 74, .4)]),
    }
    for i, (kind, (name, notes)) in enumerate(lines.items()):
        last = notes[-1]
        bus = Mix(last[0] + last[2] + (.28 if name == "wood" else .72), 610 + i)
        for j, (onset, midi, duration) in enumerate(notes):
            bus.note(.015 + onset, name, midi, duration, .62 - .045 * j, -.30 + .17 * j)
        save("cue_" + kind, bus.finish(), .36 if kind in ("step", "miss") else .54)


if __name__ == "__main__":
    OUTPUT.mkdir(exist_ok=True)
    for index, (identifier, score) in enumerate(SCORES.items()):
        make_scene(identifier, score, 427 + index)
    make_cues()
    make_song()
