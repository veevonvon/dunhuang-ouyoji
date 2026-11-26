#!/usr/bin/env python3
"""制作可独立导入的源码包，明确排除工具链、存档、缓存和密钥。"""
import hashlib
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

root = Path(__file__).resolve().parent.parent
output = root / "builds/ouyoji-godot-source-4.3.0.zip"
output.parent.mkdir(exist_ok=True)
roots = ["scripts", "scenes", "assets", "data", "docs", "tests", "tools"]
files = [root / name for name in ["project.godot", "export_presets.cfg", "README.md", "AGENTS.md", ".gitignore"]]
for folder in roots:
    files.extend(path for path in (root / folder).rglob("*") if path.is_file())
files = [path for path in files if "__pycache__" not in path.parts and path.name != ".DS_Store" and path.suffix not in [".pyc", ".pyo"]]
with ZipFile(output, "w", ZIP_DEFLATED, compresslevel=9) as archive:
    for path in sorted(files):
        archive.write(path, Path("ouyoji-godot-4.3.0") / path.relative_to(root))
with ZipFile(output) as archive:
    assert archive.testzip() is None
    names = archive.namelist()
    assert all(not any(part in name.split("/") for part in [".godot", ".toolchain", "test-results", "builds"]) for name in names)
    assert all(not name.endswith((".keystore", ".jks", ".env")) for name in names)
checksum = hashlib.sha256(output.read_bytes()).hexdigest()
output.with_suffix(output.suffix + ".sha256").write_text(f"{checksum}  {output.name}\n")
print(f"源码包：{output.name}；{len(files)} 个文件；{output.stat().st_size:,} 字节")
