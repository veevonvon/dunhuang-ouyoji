#!/usr/bin/env python3
"""Check the deliverable APK's native structure and offline content contract."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
STATIONS = ("wuwei", "zhangye", "jiuquan", "jiayuguan", "guazhou", "dunhuang")
PROPS = ("ball", "camel", "card-back", "drop", "grain", "grape", "leaf", "lotus", "phone", "pipa",
         "sapling", "scroll", "silk-ground", "silk", "star", "sun", "water")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit("APK 校验失败：" + message)


def main() -> None:
    apk = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "builds/ouyoji-4.3.0-android.apk"
    aapt = ROOT / ".toolchain/android-sdk/build-tools/36.0.0/aapt"

    def dump(kind: str, *args: str) -> str:
        return subprocess.check_output([str(aapt), "dump", kind, str(apk), *args], text=True)

    badging = dump("badging")
    manifest = dump("xmltree", "AndroidManifest.xml")
    permissions = dump("permissions")
    require("name='org.ouyoji.dunhuang' versionCode='40300' versionName='4.3.0'" in badging,
            "包名或版本不符合交付约定")
    require("sdkVersion:'24'" in badging and "targetSdkVersion:'36'" in badging,
            "Android API 范围与官方模板不一致")
    require(re.search(r"android:screenOrientation[^\n]*=\(type 0x10\)0x0\b", manifest) is not None,
            "主 Activity 未设置横屏")
    require(re.search(r"android:appCategory[^\n]*=\(type 0x10\)0x0\b", manifest) is not None,
            "Android 应用类别不是游戏")
    require("com.godot.game.GodotAppLauncher" in manifest, "缺少可启动的原生 Godot Activity 别名")
    require("uses-permission:" not in permissions, "离线游戏声明了不需要的应用权限")

    with zipfile.ZipFile(apk) as archive:
        require(archive.testzip() is None, "ZIP 内容 CRC 校验失败")
        names = archive.namelist()
        name_set = set(names)

        def require_import(resource: str, resource_type: str) -> None:
            mapping = "assets/" + resource + ".import"
            require(mapping in name_set, "缺少离线资源导入映射：" + resource)
            imported = archive.read(mapping).decode("utf-8")
            require('type="' + resource_type + '"' in imported, "资源类型错误：" + resource)
            paths = re.findall(r'^path(?:\.[\w]+)?="res://([^"]+)"', imported, re.MULTILINE)
            require(bool(paths), "资源未配置导入目标：" + resource)
            require(any("assets/" + path in name_set for path in paths),
                    "缺少离线资源实际二进制：" + resource)

        for name in ("AndroidManifest.xml", "classes.dex", "assets/data/content.json"):
            require(name in names, "缺少 " + name)
        abis = sorted({name.split("/")[1] for name in names if name.startswith("lib/")})
        require(abis == ["arm64-v8a", "armeabi-v7a"], "原生架构不是 ARM64 + ARM32")
        for abi in abis:
            require("lib/" + abi + "/libgodot_android.so" in names, "缺少 Godot 原生运行时：" + abi)
        require_import("assets/fonts/chinese.ttf", "FontFile")
        require_import("assets/fonts/scroll_titles.ttf", "FontFile")
        for name in ("assets/assets/fonts/OFL.txt", "assets/assets/fonts/PROVENANCE.md",
                     "assets/assets/fonts/TITLE-OFL.txt",
                     "assets/assets/licenses/Godot.txt", "assets/assets/licenses/Godot-third-party.txt"):
            require(name in names, "缺少再分发许可或来源记录：" + name)
            require(archive.read(name) == (ROOT / name.removeprefix("assets/")).read_bytes(),
                    "许可或来源记录与工程不一致：" + name)
        legacy = json.loads((ROOT / "assets/manifest.json").read_text())
        offline_counts = {"images": 0, "notes": 0, "voice": 0}
        for entry in legacy["files"]:
            resource = entry["path"]
            group = resource.split("/")[1]
            if group in offline_counts:
                offline_counts[group] += 1
                require_import(resource, "CompressedTexture2D" if group == "images" else "AudioStreamMP3")
        require(offline_counts == {"images": 13, "notes": 15, "voice": 122},
                "原有离线插画、音符或旁白清单数量不符")
        edition = ["assets/edition/opening.webp"]
        edition += ["assets/edition/" + group + "/" + station + ".webp"
                    for group in ("seals", "friends") for station in STATIONS]
        props = ["assets/edition/props/" + prop + ".webp" for prop in PROPS]
        for resource in edition + props:
            require_import(resource, "CompressedTexture2D")
        score = ["assets/score/" + station + "_" + part + ".ogg"
                 for station in (*STATIONS, "map", "ending") for part in ("lead", "motion")]
        score += ["assets/score/seal_" + station + ".ogg" for station in (*STATIONS, "song")]
        score += ["assets/score/cue_" + cue + ".ogg" for cue in ("step", "hint", "miss", "discover", "win")]
        for resource in score:
            require_import(resource, "AudioStreamOggVorbis")
        require(sum(name.startswith("assets/assets/score/") and name.endswith(".ogg.import")
                    for name in names) == 28, "原创 Ogg 乐谱数量不是 28")
        for illustration in ("lotus", "pipa"):
            require_import("assets/trails/" + illustration + "-scroll.svg", "CompressedTexture2D")
        for script in ("trail_board", "trail_canvas", "trail_catalog", "trail_guide", "trail_ink",
                       "trail_state", "trail_view"):
            require("assets/scripts/trails/" + script + ".gdc" in name_set,
                    "缺少寻纹原生 GDScript：" + script)
        require("assets/scripts/ui/seal_album.gdc" in name_set, "缺少纹印谱")
        for station in (*STATIONS, "map", "ending"):
            old_import = (ROOT / ("assets/music/" + station + ".mp3.import")).read_text()
            old_paths = re.findall(r'^path="res://([^"]+)"', old_import, re.MULTILINE)
            require(bool(old_paths), "缺少旧背景音乐源映射，无法确认排除：" + station)
            require(not any("assets/" + path in name_set for path in old_paths),
                    "APK 仍包含已停用的背景音乐：" + station)
        require(not any(name.startswith("assets/assets/music/") for name in names),
                "APK 仍包含旧背景音乐目录")
        forbidden = (".toolchain", "tools", "tests", "docs", "test-results", "builds")
        for name in names:
            require(not any("/" + folder + "/" in name for folder in forbidden), "APK 包含开发目录：" + name)
            require(not name.endswith((".keystore", ".sh", ".py", ".html", ".js", ".wasm")),
                    "APK 包含不应分发的文件：" + name)
        content = json.loads(archive.read("assets/data/content.json"))
        expected = {"stages": 6, "activities": 11, "facts": 31, "historyEvents": 12,
                    "chapters": 6, "encounters": 18, "letters": 3, "decorations": 9}
        for key, count in expected.items():
            require(len(content.get(key, [])) == count, "内容集合数量不符：" + key)
        path = "data/landmarks.json"
        require("assets/" + path in name_set and archive.read("assets/" + path) == (ROOT / path).read_bytes(),
                "景点考据与写生题与交付源文件不一致")
        sites = json.loads(archive.read("assets/" + path))["sites"]
        require(len(sites) == 19 and sum(len(site["details"]) for site in sites) == 57, "景点或活动数有误")
        for site in sites:
            for sub in ("", "spring/", "autumn/", "winter/"):
                require_import("assets/landmarks/paintings/" + sub + site["id"] + ".webp", "CompressedTexture2D")
                require_import("scripts/landmarks/scenic_masks/" + sub + site["id"] + ".png", "CompressedTexture2D")
            require_import("assets/landmarks/prints/" + site["id"] + ".webp", "CompressedTexture2D")
        for kind in ("birds", "court", "insects", "leaves", "sand", "water", "wind"):
            require_import("assets/landmarks/sounds/" + kind + ".ogg", "AudioStreamOggVorbis")
        for plate in ("detail_motifs", "detail_specimens", "detail_shared_ears"):
            require_import("scripts/landmarks/" + plate + ".svg", "CompressedTexture2D")
        require_import("scripts/landmarks/detail_rubbings.png", "CompressedTexture2D")
        for component in ("landmarks/catalog","landmarks/field_notes","landmarks/scenery","landmarks/detail_board",
                          "landmarks/detail_view","landmarks/detail_reference","landmarks/detail_folio",
                          "ui/atlas_screen","ui/landmark_screen","ui/site_journal","ui/scenic_print","ui/field_loupe"):
            require("assets/scripts/" + component + ".gdc" in name_set, "缺少景点原生脚本：" + component)

        character_art = sorted(p for p in (ROOT / "assets/characters").rglob("*")
                               if p.suffix in (".webp", ".png", ".svg"))
        require(any(p.parent.name == "boy" for p in character_art), "缺少欧哟几分层画稿")
        require(any(p.parent.name == "deer" for p in character_art), "缺少鹿铃分层画稿")
        for art in character_art:
            require_import(art.relative_to(ROOT).as_posix(), "CompressedTexture2D")
        for clip in ("shoe_sand","shoe_grass","shoe_stone","hoof_sand","hoof_grass","hoof_stone","brush","collar"):
            require_import("assets/foley/" + clip + ".wav", "AudioStreamWAV")
        components = sorted((ROOT / "scripts/characters").glob("*.gd"))
        components.append(ROOT / "scripts/audio/companion_foley.gd")
        components.extend(ROOT / f"scripts/ui/{name}.gd" for name in
                          ("companion_screen", "companion_stage", "actor_portrait"))
        for component in components:
            entry = "assets/" + component.relative_to(ROOT).with_suffix(".gdc").as_posix()
            require(entry in name_set, "缺少原生旅伴脚本 " + entry)

    digest = hashlib.sha256()
    with apk.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    report = {"package": "org.ouyoji.dunhuang", "version": "4.3.0", "version_code": 40300,
              "minimum_api": 24, "target_api": 36, "orientation": "landscape",
              "category": "game", "abis": abis, "permissions": [], "content_counts": expected,
              "bytes": apk.stat().st_size, "sha256": digest.hexdigest(), "native": True,
              "chinese_font": True, "title_font": True, "edition_images": len(edition),
              "prop_images": len(props), "score_ogg": len(score), "trail_scripts": 7,
              "offline_resources": offline_counts,
              "landmarks": len(sites), "site_details": 57, "season_paintings": 76, "sky_combinations": 304,
              "character_art": len(character_art), "character_components": len(components),
              "field_commissions": 19, "field_ambient_tracks": 7,
              "excluded_legacy_music": True, "excluded_development_files": True}
    (ROOT / ".toolchain/apk-structure-4.3.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print("APK 4.3 原生结构、签名配套资源、19 处景点、四季画、环境掩模、写生页、音画、旅伴骨骼与分层画稿检查通过。")


if __name__ == "__main__":
    main()
