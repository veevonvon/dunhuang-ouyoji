"""为山河写生合成七段可循环的双声道自然声，使用与场景分谱相同的编码器。"""
from pathlib import Path

import numpy as np
import soundfile as sf


RATE = 24000
LENGTH = 12
FRAMES = RATE * LENGTH
TIME = np.arange(FRAMES) / RATE
OUT = Path(__file__).resolve().parents[2] / "assets/landmarks/sounds"


def band(rng, low, high):
    frequencies = np.fft.rfftfreq(FRAMES, 1 / RATE)
    envelope = (1 - np.exp(-(frequencies / low) ** 2)) * np.exp(-(frequencies / high) ** 2)
    samples = np.fft.irfft(np.fft.rfft(rng.normal(size=FRAMES)) * envelope, n=FRAMES)
    return samples / np.sqrt(np.mean(samples * samples))


def sprinkle(track, when, sound):
    start = int(when * RATE)
    np.add.at(track, (start + np.arange(len(sound))) % FRAMES, sound)


def make_channel(kind, rng, side):
    breath = .60 + .25 * np.cos(2 * np.pi * TIME / LENGTH + side * .22)
    if kind in ("wind", "sand", "leaves", "court"):
        low, high = {"wind":(75,760), "sand":(250,1750), "leaves":(1100,4400), "court":(80,470)}[kind]
        sound = band(rng, low, high) * breath * .078
        if kind in ("leaves", "sand"):
            grain = .5 + .5 * np.sin(2 * np.pi * TIME * 7 / LENGTH + side * .17)
            sound += band(rng, 2100, 6800) * grain ** 6 * .032
        return sound
    if kind == "water":
        sound = band(rng, 450, 2300) * breath * .038
        for at in (0.6, 1.72, 3.12, 5.62, 6.04, 8.5, 10.63):
            t = np.arange(RATE // 3) / RATE
            f = rng.uniform(430, 700)
            drop = np.sin(2 * np.pi * (f * t + 270 * t * t)) * (1 - np.exp(-t * 210)) * np.exp(-t * 19)
            sprinkle(sound, at + side * .019, drop * .14)
        return sound
    sound = np.zeros(FRAMES)
    if kind == "birds":
        for at, start, glide, duration in ((1.1,2050,1800,.19), (1.40,2490,-1250,.28), (5.7,1880,1500,.23), (8.0,2380,1650,.22), (8.32,2600,-900,.31)):
            t = np.arange(int(RATE * duration)) / RATE
            chirp = np.sin(2 * np.pi * (start * t + glide * t ** 2)) * np.sin(np.pi * t / duration) ** 2
            sprinkle(sound, at + side * .012, chirp * .19)
    else:
        for at in (1.8,2.23,3.07,6.70,7.14,9.85):
            t = np.arange(int(RATE * .22)) / RATE
            trill = np.sin(2 * np.pi * (2770 + side * 4) * t) * (.5 + .5 * np.cos(2 * np.pi * 37 * t)) ** 4
            sprinkle(sound, at + side * .015, trill * np.sin(np.pi * t / .22) ** 2 * .13)
    return sound


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for index, kind in enumerate(("wind","sand","leaves","court","water","birds","insects")):
        # 用固定种子、整周期频谱与回绕的短脉冲生成首尾连续的底声。
        rng = np.random.default_rng(4280 + index)
        channels = [make_channel(kind, rng, side) for side in (0, 1)]
        audio = np.column_stack(channels)
        assert np.isfinite(audio).all() and .03 < np.abs(audio).max() < .9
        sf.write(OUT / f"{kind}.ogg", audio.astype("float32"), RATE, format="OGG", subtype="VORBIS", compression_level=.45)


if __name__ == "__main__":
    main()
