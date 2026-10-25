#!/usr/bin/env python3
"""Checks that the tutorial's solution snippets match the reference files in src/.

Run from anywhere:  python3 scripts/check-snippets.py

A snippet belongs to a reference file when it is preceded by

    <!-- file: src/<path> -->            a piece of the file
    <!-- file: src/<path> complete -->   the whole file
    **In `<path>`:**

and then a fenced code block. For each reference file:

- Every "complete" snippet must equal the file.
- Without a complete snippet, the pieces joined in order must equal the file.
- Every piece must be exact reference code: lines starting with `// ⋯` or `# ⋯` are
  reader notes (placeholders) and are dropped. The code between them must appear in
  the file as contiguous runs of lines, in order.

Blank lines are ignored everywhere. Indentation and every other character must match.

It also checks the <details> panels in docs/*.md: balanced tags, a blank line after
each </summary> and before each </details> (needed for Markdown inside them to render).

Exits 1 on any problem.
"""

import difflib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
CHAPTERS = {
    "src/assets/speedtest.sh": "04-backend-script.md",
    "src/services/SpeedTest.qml": "05-service.md",
    "src/modules/dashboard/SpeedTestTab.qml": "06-dashboard-tab.md",
}

MARKER = re.compile(r"^<!-- file: (src/\S+?)( complete)? -->$")
LABEL = re.compile(r"^\*\*In `(\S+)`:\*\*$")
NOTE = re.compile(r"^\s*(//|#) ⋯")

problems: list[str] = []


def code_lines(lines: list[str]) -> list[str]:
    return [l.rstrip() for l in lines if l.strip() and not NOTE.match(l)]


def segments(lines: list[str]) -> list[list[str]]:
    """Splits a snippet at its reader-note lines into runs of real code."""
    out, cur = [], []
    for l in lines:
        if NOTE.match(l):
            if cur:
                out.append(cur)
            cur = []
        elif l.strip():
            cur.append(l.rstrip())
    if cur:
        out.append(cur)
    return out


def find_run(haystack: list[str], needle: list[str], start: int) -> int:
    for i in range(start, len(haystack) - len(needle) + 1):
        if haystack[i : i + len(needle)] == needle:
            return i
    return -1


def collect(md: Path) -> list[tuple[str, bool, int, list[str]]]:
    """Returns (path, complete, line number, code lines) for each tagged snippet."""
    lines = md.read_text(encoding="utf-8").splitlines()
    found = []
    for n, line in enumerate(lines):
        m = MARKER.match(line.strip())
        if not m:
            continue
        path, complete = m.group(1), bool(m.group(2))
        j = n + 1
        while j < len(lines) and not lines[j].strip():
            j += 1
        label = LABEL.match(lines[j].strip()) if j < len(lines) else None
        if not label or "src/" + label.group(1) != path:
            problems.append(f"{md.name}:{n + 1}: marker for {path} isn't followed by **In `{path[4:]}`:**")
            continue
        j += 1
        while j < len(lines) and not lines[j].strip():
            j += 1
        if j >= len(lines) or not lines[j].lstrip().startswith("```"):
            problems.append(f"{md.name}:{n + 1}: marker for {path} isn't followed by a code block")
            continue
        indent = len(lines[j]) - len(lines[j].lstrip())  # fences inside list items are indented
        k = j + 1
        while k < len(lines) and not lines[k].lstrip().startswith("```"):
            k += 1
        found.append((path, complete, n + 1, [l[indent:] if l[:indent].isspace() else l for l in lines[j + 1 : k]]))
    return found


def check_snippets() -> None:
    by_path: dict[str, list] = {p: [] for p in CHAPTERS}
    for md in sorted(DOCS.glob("*.md")):
        for path, complete, lineno, code in collect(md):
            if CHAPTERS.get(path) != md.name:
                problems.append(f"{md.name}:{lineno}: snippet for {path} belongs in {CHAPTERS.get(path, '(unknown file)')}")
                continue
            by_path[path].append((complete, lineno, code))

    for path, snippets in by_path.items():
        chapter = CHAPTERS[path]
        want = code_lines((ROOT / path).read_text(encoding="utf-8").splitlines())
        if not snippets:
            problems.append(f"{chapter}: no snippets for {path}")
            continue

        for complete, lineno, code in snippets:
            if complete:
                continue
            pos = 0
            for seg in segments(code):
                at = find_run(want, seg, pos)
                if at < 0:
                    problems.append(f"{chapter}:{lineno}: piece isn't exact reference code from {path}, near: {seg[0].strip()!r}")
                    break
                pos = at + len(seg)

        completes = [s for s in snippets if s[0]]
        compared = completes or [(True, snippets[0][1], [l for s in snippets for l in s[2]])]
        how = "complete-file panel" if completes else "pieces joined in order"
        for _, lineno, code in compared:
            got = code_lines(code)
            diff = list(difflib.unified_diff(want, got, f"{path} (reference)", f"{chapter}:{lineno} ({how})", lineterm=""))
            if diff:
                problems.append("\n".join(diff))
            else:
                pieces = sum(1 for s in snippets if not s[0])
                print(f"MATCH {path}: {len(want)} lines ({how}; {pieces} pieces also checked)")


def check_details() -> None:
    for md in sorted(DOCS.glob("*.md")):
        lines = md.read_text(encoding="utf-8").splitlines()
        depth = opened = 0
        in_fence = False
        for n, line in enumerate(lines):
            s = line.strip()
            if s.startswith("```"):
                in_fence = not in_fence
            if in_fence:
                continue
            if s == "<details>":
                depth += 1
                opened += 1
            elif s == "</details>":
                depth -= 1
                if depth < 0:
                    problems.append(f"{md.name}:{n + 1}: </details> without <details>")
                    depth = 0
                if n == 0 or lines[n - 1].strip():
                    problems.append(f"{md.name}:{n + 1}: no blank line before </details>")
            elif s.endswith("</summary>"):
                if n + 1 >= len(lines) or lines[n + 1].strip():
                    problems.append(f"{md.name}:{n + 1}: no blank line after </summary>")
        if depth:
            problems.append(f"{md.name}: {depth} <details> not closed")
        if opened:
            print(f"OK    {md.name}: {opened} <details> panels")


check_snippets()
check_details()

if problems:
    print("\n".join(["", "PROBLEMS:"] + problems))
    sys.exit(1)
print("All checks passed.")
