"""检查最终 Vorbis 解码信号，并输出各轨采样数、峰值与 RMS。"""
import hashlib
from pathlib import Path

import numpy as np
import soundfile as sf

from score import SCORES, events, pitch

ROOT = Path(__file__).resolve().parents[2] / "assets" / "score"


def validate():
    motifs = set()
    signatures = set()
    for name in SCORES:
        a = inspect(name + "_lead", True)
        b = inspect(name + "_motion", True)
        assert a.shape == b.shape, name + " 两层采样数不符"
        assert np.abs(a + b).max() < .98, name + " 总线峰值余量不足"
        if SCORES[name].stamp:
            motif = inspect("seal_" + name)
            motifs.add(hashlib.sha256(motif.tobytes()).digest())
            score = SCORES[name]
            notes = list(events(score.stamp))
            first_pitch = pitch(score, notes[0][1])
            signatures.add(tuple((onset, pitch(score, degree) - first_pitch, length)
                                 for onset, degree, length in notes))
            assert all(sum(int(token.split(":")[1]) for token in bar.split()) == score.eighths
                       for bar in score.bars), "每小节拍数必须完整"
    assert len(motifs) == len(signatures) == 6
    for kind in ("step", "miss", "hint", "win", "discover"):
        inspect("cue_" + kind)
    finale = inspect("seal_song")
    assert 18 < len(finale) / 24000 < 42
    assert np.sqrt(np.mean(finale[-2400:] ** 2)) < .004, "尾音未消退"


def inspect(name, loop=False):
    path = ROOT / (name + ".ogg")
    assert path.exists(), "缺少实际可播放音频 " + name
    decoded, rate = sf.read(path, dtype="float32", always_2d=True)
    frames, channels = decoded.shape
    assert channels == 2 and rate == 24000
    peak = np.abs(decoded).max()
    rms = np.sqrt(np.mean(decoded ** 2))
    assert .05 < peak < .92 and .008 < rms < .24, name
    assert np.std(decoded[:, 0] - decoded[:, 1]) > .001, name + " 声场退化"
    if loop:
        assert frames > 14 * rate
        assert np.max(np.abs(decoded[0] - decoded[-1])) < .024, name + " 循环接缝"
    print(f"{name:20} {frames:8} {frames/rate:6.2f}s  peak {20*np.log10(peak):6.2f} dBFS  rms {20*np.log10(rms):6.2f} dBFS")
    return decoded


if __name__ == "__main__":
    validate()
