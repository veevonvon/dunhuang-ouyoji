#!/usr/bin/env python3
"""Install the pinned, local macOS Apple Silicon Android export toolchain."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
LOCAL = ROOT / ".toolchain"
DOWNLOADS = LOCAL / "downloads"
MANIFEST = json.loads(Path(__file__).with_suffix(".json").read_text())


def run(*args: str, **kwargs: object) -> subprocess.CompletedProcess:
    return subprocess.run(args, check=True, **kwargs)


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def download(name: str) -> Path:
    item = MANIFEST[name]
    target = DOWNLOADS / item["filename"]
    if not target.exists():
        partial = target.with_name(target.name + ".part")
        print(f"下载 {target.name}", flush=True)
        run("curl", "--fail", "--location", "--retry", "3", "--retry-all-errors", "--output",
            str(partial), item["url"])
        if digest(partial) != item["sha256"]:
            raise RuntimeError(f"下载校验失败：{partial}；未安装此文件")
        partial.replace(target)
    if digest(target) != item["sha256"]:
        raise RuntimeError(f"本地文件校验失败：{target}；请保留文件排查后重新下载")
    return target


def install_zip(name: str, archive_root: str, destination: Path, sentinel: str) -> None:
    archive = download(name)
    if (destination / sentinel).exists():
        return
    if destination.exists():
        raise RuntimeError(f"检测到不完整工具目录，未覆盖：{destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="unpack-", dir=LOCAL) as temporary:
        run("ditto", "-x", "-k", str(archive), temporary)
        shutil.move(str(Path(temporary) / archive_root), str(destination))


def main() -> None:
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise SystemExit("此固定工具链面向 macOS Apple Silicon；其他开发主机请按 docs/toolchain.md 配置。")
    DOWNLOADS.mkdir(parents=True, exist_ok=True)
    (LOCAL / ".gdignore").touch()
    godot_dir = LOCAL / "godot"
    install_zip("godot", "Godot.app", godot_dir / "Godot.app", "Contents/MacOS/Godot")
    (godot_dir / "_sc_").touch()
    run("codesign", "--verify", "--deep", "--strict", str(godot_dir / "Godot.app"))

    archive = download("templates")
    templates = godot_dir / "editor_data/export_templates/4.7.2.stable"
    templates.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as bundle:
        for name in ("android_debug.apk", "android_release.apk", "android_source.zip", "version.txt"):
            if not (templates / name).exists():
                with bundle.open("templates/" + name) as source, (templates / name).open("wb") as target:
                    shutil.copyfileobj(source, target)

    java = LOCAL / "jdk17/Contents/Home"
    archive = download("jdk")
    if not (java / "bin/java").exists():
        destination = LOCAL / "jdk17"
        if destination.exists():
            raise RuntimeError(f"检测到不完整工具目录，未覆盖：{destination}")
        destination.mkdir()
        run("tar", "-xzf", str(archive), "-C", str(destination), "--strip-components=1")

    sdk = LOCAL / "android-sdk"
    install_zip("commandline", "cmdline-tools", sdk / "cmdline-tools/19.0", "bin/sdkmanager")
    install_zip("platform_tools", "platform-tools", sdk / "platform-tools", "adb")
    install_zip("build_tools", "android-16", sdk / "build-tools/36.0.0", "apksigner")
    install_zip("platform", "android-36", sdk / "platforms/android-36", "android.jar")

    environment = os.environ.copy()
    environment.update(JAVA_HOME=str(java), ANDROID_HOME=str(sdk), ANDROID_SDK_ROOT=str(sdk),
                       ANDROID_USER_HOME=str(LOCAL / "android-user"))
    if not (sdk / "licenses/android-sdk-license").exists():
        print("按已授权的开发工具安装范围确认 Android SDK 许可；许可文本保存在本地工具链。", flush=True)
        with (LOCAL / "android-license-acceptance.log").open("w") as log:
            run(str(sdk / "cmdline-tools/19.0/bin/sdkmanager"), "--sdk_root=" + str(sdk),
                "--licenses", input="y\n" * 100, text=True, env=environment,
                stdout=log, stderr=subprocess.STDOUT)

    signing = LOCAL / "signing"
    signing.mkdir(mode=0o700, exist_ok=True)
    key = signing / "debug.keystore"
    if not key.exists():
        run(str(java / "bin/keytool"), "-genkeypair", "-keystore", str(key),
            "-storepass", "android", "-keypass", "android", "-alias", "androiddebugkey",
            "-dname", "CN=Android Debug,O=Android,C=US", "-keyalg", "RSA", "-keysize", "2048",
            "-validity", "10000", "-storetype", "JKS")
        key.chmod(0o600)

    # Keep the project-owned adb server alive while importing or exporting.
    settings = godot_dir / "editor_data/editor_settings-4.7.tres"
    text = settings.read_text() if settings.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    setting = "export/android/shutdown_adb_on_exit"
    lines = [line for line in text.splitlines() if not line.startswith(setting + " =")]
    lines.append(setting + " = false")
    settings.write_text("\n".join(lines) + "\n")

    (LOCAL / "download-manifest.json").write_text(json.dumps(MANIFEST, ensure_ascii=False, indent=2) + "\n")
    run(str(ROOT / "tools/godot.sh"), "--version", env=environment)
    run(str(java / "bin/java"), "-version")
    run(str(sdk / "platform-tools/adb"), "version")
    run(str(sdk / "cmdline-tools/19.0/bin/sdkmanager"), "--version", env=environment)
    print("本地工具链就绪。导出命令：tools/export-android.sh")


if __name__ == "__main__":
    main()
