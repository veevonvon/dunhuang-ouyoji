#!/usr/bin/env python3
"""离线检查现场画、四时小像和现场声音，标准 Python 即可运行。"""
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/landmarks"
SITES = json.loads((ROOT / "data/landmarks.json").read_text())["sites"]


def webp_dimensions(data):
    assert data[:4] == b"RIFF" and data[8:12] == b"WEBP"
    tag = data[12:16]
    if tag == b"VP8X":
        return tuple(1 + int.from_bytes(data[i:i+3], "little") for i in (24, 27))
    if tag == b"VP8L":
        assert data[20] == 0x2f
        packed = int.from_bytes(data[21:25], "little")
        return (packed & 0x3fff) + 1, ((packed >> 14) & 0x3fff) + 1
    assert tag == b"VP8 " and data[23:26] == b"\x9d\x01\x2a"
    return tuple(int.from_bytes(data[i:i+2], "little") & 0x3fff for i in (26, 28))


def main():
    drawings = set()
    for site in SITES:
        name = site["id"] + ".webp"
        for season in ("spring", "summer", "autumn", "winter"):
            folder = ART / "paintings"
            if season != "summer":
                folder /= season
            data = (folder / name).read_bytes()
            width, height = webp_dimensions(data)
            assert width >= 960 and height >= 540 and abs(width / height - 16/9) < .015, (name, season, width, height)
            digest = hashlib.sha256(data).digest()
            assert digest not in drawings, (name, season, "重复底图")
            drawings.add(digest)
        assert webp_dimensions((ART / "prints" / name).read_bytes()) == (1024, 576), name
    for sound in ("birds","court","insects","leaves","sand","water","wind"):
        data = (ART / "sounds" / f"{sound}.ogg").read_bytes()
        assert data.startswith(b"OggS") and len(data) > 4000, sound
        offset = data.index(b"\x01vorbis") + 7
        assert data[offset+4] == 2 and int.from_bytes(data[offset+5:offset+9], "little") == 24000, sound
    print(f"FIELD_ASSETS: {len(drawings)} 幅独立季节底图、{len(SITES)*16} 格时景小像、7 段双声道环境声。")


if __name__ == "__main__":
    main()
