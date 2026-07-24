#!/usr/bin/env python3
import re
from pathlib import Path

ROOT = Path("/Users/amin/formocracy")
GD_FILES = sorted(ROOT.rglob("*.gd"))

for path in GD_FILES:
    lines = path.read_text(encoding="utf-8").splitlines()
    func_lines = []
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("func "):
            func_lines.append((i, stripped))

    missing = []
    for i, func_line in func_lines:
        has_comment = False
        for j in range(i - 1, max(-1, i - 10), -1):
            s = lines[j].strip()
            if s == "":
                continue
            if s.startswith("#"):
                has_comment = True
            break
        if not has_comment:
            missing.append((i + 1, func_line))

    if missing:
        print(f"\n=== {path} ({len(missing)}/{len(func_lines)} missing) ===")
        for line_no, func in missing:
            print(f"  L{line_no}: {func}")
