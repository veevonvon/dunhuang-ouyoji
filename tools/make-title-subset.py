#!/usr/bin/env python3
"""从原始 Noto Serif SC 制作游戏标题字。需提供来源记录中的官方可变字体。"""
import argparse
import hashlib
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE_HASH = "050080d9255a86808f2945bffac582b31ef32bc36411ce29563b4961670c66f9"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("upstream", type=Path)
    args = parser.parse_args()
    assert hashlib.sha256(args.upstream.read_bytes()).hexdigest() == SOURCE_HASH
    target = ROOT / "assets/fonts/scroll_titles.ttf"
    with TTFont(target) as previous:
        points = set(previous.getBestCmap())
    for directory, pattern in (("scripts","*.gd"),("data","*.json")):
        for path in sorted((ROOT / directory).rglob(pattern)):
            points.update(ord(c) for c in path.read_text())
    font = TTFont(args.upstream, recalcTimestamp=False)
    options = subset.Options()
    options.name_IDs = [0,1,2,3,4,5,6,7,8,9,11,12,13,14,16,17]
    options.layout_features = ["*"]
    cutter = subset.Subsetter(options=options)
    cutter.populate(unicodes=points)
    cutter.subset(font)
    font = instantiateVariableFont(font, {"wght":700}, inplace=True)
    names = {1:"Hexi Scroll Titles", 2:"Bold", 3:"HexiScrollTitles-Bold", 4:"Hexi Scroll Titles Bold",
             6:"HexiScrollTitles-Bold", 16:"Hexi Scroll Titles", 17:"Bold"}
    for record in font["name"].names:
        if record.nameID in names:
            record.string = names[record.nameID].encode(record.getEncoding())
    font.recalcTimestamp = False
    font.save(target)
    print("字数",len(font.getBestCmap()),"字节",target.stat().st_size,"SHA-256",hashlib.sha256(target.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
