#!/usr/bin/env python3
"""生成原创的布鞋、偶蹄、笔锋和颈铃效果音。只用 Python 标准库。"""
import array
import math
from pathlib import Path
import random
import sys
import wave


OUT = Path(__file__).resolve().parents[2] / "assets/foley"
RATE = 24000
TAU = math.tau


def write_clip(name, samples):
    peak = max(abs(value) for value in samples)
    pcm = array.array("h", (int(23900 * value / max(.15, peak)) for value in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(OUT / (name + ".wav")), "wb") as stream:
        stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        stream.writeframes(pcm.tobytes())


def foot(terrain, hoof):
    lengths = {"sand": .23, "grass": .19, "stone": .145}
    seed = {"sand": 19, "grass": 37, "stone": 71}[terrain] + (5 if hoof else 0)
    noise = random.Random(seed)
    samples = []
    soft = 0
    grain = 0
    for i in range(int(lengths[terrain] * RATE)):
        t = i / RATE
        raw = noise.uniform(-1, 1)
        soft += .13 * (raw - soft)
        grain = .87 * grain + .13 * noise.uniform(-1, 1)
        strike = math.exp(-t * (59 if hoof else 38))
        if hoof and t > .023:
            strike += .62 * math.exp(-(t - .023) * 69)
        thud = math.sin(TAU * (178 if hoof else 89) * t + .6 * math.sin(t * 65))
        if terrain == "stone":
            click = math.sin(TAU * 970 * t) * .26 + math.sin(TAU * 1640 * t) * .12
            sample = strike * (thud * .60 + click + soft * .27)
        elif terrain == "grass":
            leaves = (.2 + .8 * math.sin(43 * t + .5) ** 4) * (raw - soft) * math.exp(-t * 24)
            sample = .3 * leaves + strike * (.48 * thud + .5 * soft)
        else:
            scuff = math.sin(math.pi * t / lengths[terrain]) ** .8
            sample = strike * (.33 * thud + soft) + .78 * scuff * soft * (.6 + abs(grain))
        edge = min(1, t / .003, (lengths[terrain] - t) / .018)
        samples.append(sample * edge)
    return samples


def brush():
    rng = random.Random(327)
    soft = 0
    samples = []
    for i in range(int(RATE * .47)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        soft += (.10 + .17 * t) * (noise - soft)
        slide = math.sin(math.pi * t / .47) ** 1.15
        pressure = .4 + .6 * math.sin(math.pi * min(1, t / .23)) ** 2
        samples.append(slide * pressure * (.78 * soft + .045 * noise))
    return samples


def bell():
    samples = []
    for i in range(int(RATE * .92)):
        t = i / RATE
        value = 0
        for start, strength in ((0, .65), (.115, .35)):
            dt = t - start
            if dt < 0:
                continue
            for hz, gain, decay in ((987.77, .56, 4.8), (2458, .22, 8.1), (3599, .12, 13)):
                value += strength * gain * math.sin(TAU * hz * dt) * math.exp(-decay * dt) * min(1, dt / .004)
        samples.append(value * min(1, (.92 - t) / .07))
    return samples


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for ground in ("sand", "grass", "stone"):
        for animal in (False, True):
            write_clip(("hoof_" if animal else "shoe_") + ground, foot(ground, animal))
    write_clip("brush", brush())
    write_clip("collar", bell())
