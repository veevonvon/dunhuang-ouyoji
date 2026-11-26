#!/usr/bin/env python3
"""离线核对随源码交付的内容与素材，不依赖原版工程或 Node。"""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
manifest = json.loads((root / "assets/manifest.json").read_text())
for item in manifest["files"]:
    data = (root / item["path"]).read_bytes()
    assert len(data) == item["bytes"], item["path"]
    assert hashlib.sha256(data).hexdigest() == item["sha256"], item["path"]
content = json.loads((root / "data/content.json").read_text())
counts = {"stages": 6, "chapters": 6, "activities": 11, "encounters": 18,
          "facts": 31, "historyEvents": 12, "letters": 3, "decorations": 9, "voiceLines": 122}
for name, count in counts.items():
    assert len(content[name]) == count, name
for collection in ["images", "voices"]:
    for path in content[collection].values():
        assert (root / path.removeprefix("res://")).is_file(), path
font = root / "assets/fonts/chinese.ttf"
assert hashlib.sha256(font.read_bytes()).hexdigest() == "a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da"
for path in ["assets/fonts/OFL.txt", "assets/fonts/TITLE-OFL.txt", "assets/licenses/Godot.txt", "assets/licenses/Godot-third-party.txt"]:
    assert (root / path).stat().st_size > 100, path
title_font = root / "assets/fonts/scroll_titles.ttf"
assert hashlib.sha256(title_font.read_bytes()).hexdigest() == "1805df2fbb46fb8e70e77d7fbf16dfb3eca79937dc258184ae02cbeab8abd8ba"
stops = [item["id"] for item in content["stages"]]
edition = root / "assets/edition"
props = "ball camel card-back drop grain grape leaf lotus phone pipa sapling scroll silk silk-ground star sun water".split()
paintings = [edition / "opening.webp"]
paintings.extend(edition / group / f"{stop}.webp" for group in ("friends", "seals") for stop in stops)
paintings.extend(edition / "props" / f"{item}.webp" for item in props)
assert set(edition.rglob("*.webp")) == set(paintings)
for painting in paintings:
    header = painting.read_bytes()[:12]
    assert header[:4] == b"RIFF" and header[8:] == b"WEBP", painting
tracks = [f"{name}_{layer}" for name in [*stops, "map", "ending"] for layer in ["lead", "motion"]]
tracks.extend(f"seal_{stop}" for stop in stops)
tracks.extend(f"cue_{cue}" for cue in ("step", "hint", "miss", "discover", "win"))
tracks.append("seal_song")
score = root / "assets/score"
assert {f.stem for f in score.glob("*.ogg")} == set(tracks)
for track in tracks:
    header = (score / f"{track}.ogg").read_bytes()[:100]
    assert header.startswith(b"OggS") and b"vorbis" in header, track
for scroll in ("pipa-scroll", "lotus-scroll"):
    assert "<svg" in (root / f"assets/trails/{scroll}.svg").read_text(), scroll
print(f"ASSET_CHECKS: {len(manifest['files'])} 份原始图音哈希一致，{len(paintings)} 张新插画、2 张画带、{len(tracks)} 段新配乐、中文字体和许可齐全。")
