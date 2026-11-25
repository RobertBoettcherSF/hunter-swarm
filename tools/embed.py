#!/usr/bin/env python3
"""Embed the wasm module into one HTML file and write the D-005 stamp.

Stamp: vMAJOR.MINOR bYYYYMMDD-HHMM <short-sha>[+]
The clock is Europe/Berlin. A trailing + means the source tree was dirty.
docs/ and version.txt are the build products, so they do not count as dirty.
"""
import base64
import datetime
import subprocess
import sys
from pathlib import Path
from zoneinfo import ZoneInfo

wasm_path, template_path, html_path, version_path = sys.argv[1:5]
root = Path(__file__).resolve().parent.parent

def dirty():
    out = subprocess.check_output(["git", "status", "--porcelain"], cwd=root, text=True)
    for line in out.splitlines():
        path = line[3:].strip()
        if path.startswith("docs/") or path in ("version.txt", "docs/version.txt"):
            continue
        if path.startswith("obj/"):
            continue
        return True
    return False

sha = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=root, text=True).strip()
if dirty():
    sha += "+"
when = datetime.datetime.now(ZoneInfo("Europe/Berlin")).strftime("%Y%m%d-%H%M")
stamp = f"v0.6 b{when} {sha}"

html = Path(template_path).read_text()
wasm = Path(wasm_path).read_bytes()
html = html.replace("__WASM_BASE64__", base64.b64encode(wasm).decode("ascii"))
html = html.replace("__STAMP__", stamp)
if "__WASM_BASE64__" in html or "__STAMP__" in html:
    raise SystemExit("template placeholders left unreplaced")
Path(html_path).parent.mkdir(parents=True, exist_ok=True)
Path(html_path).write_text(html)
Path(version_path).write_text(stamp + "\n")
root_version = root / "version.txt"
root_version.write_text(stamp + "\n")
print(f"Built {html_path} ({len(wasm)} bytes of WebAssembly), {stamp}")
