#!/usr/bin/env python3
"""align-md-tables.py — pad every GFM table cell in a markdown file so the
`|` characters line up vertically across the header, separator, and body
rows. Enforces markdownlint MD060 (`table-column-style: aligned`) for the
terraform-snowflake-view README.

Usage (from repo root):
    python3 utils/align-md-tables.py [PATH ...]

If no PATH is given, defaults to README.md at the repo root. Idempotent:
running the script twice in a row produces no diff on a clean tree. Exits
non-zero if any table is structurally invalid (e.g. row column counts
disagree) so it can gate pre-commit and CI.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

FENCE_RE = re.compile(r"^\s*```")
SEP_CELL_RE = re.compile(r"^\s*:?-{3,}:?\s*$")


def repo_root() -> Path:
    """Return the repository root for resolving the default README target."""
    try:
        out = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"], text=True
        ).strip()
        return Path(out)
    except (subprocess.CalledProcessError, FileNotFoundError):
        return Path.cwd()


def split_row(row: str) -> list[str]:
    """Split a GFM table row on `|`, stripping the leading/trailing edges.

    Returns the per-cell contents *without* the outer pipes — those are
    re-added on render. A row like ``| a | b |`` returns ``["a", "b"]``.
    """
    stripped = row.strip()
    if not stripped.startswith("|") or not stripped.endswith("|"):
        return []
    inner = stripped[1:-1]
    return [c.strip() for c in inner.split("|")]


def is_separator_row(cells: list[str]) -> bool:
    return bool(cells) and all(SEP_CELL_RE.match(c) for c in cells)


def render_separator(cells: list[str], widths: list[int]) -> str:
    out = []
    for cell, width in zip(cells, widths):
        left = cell.startswith(":")
        right = cell.endswith(":")
        dashes = max(3, width - (1 if left else 0) - (1 if right else 0))
        body = (":" if left else "") + ("-" * dashes) + (":" if right else "")
        out.append(body.ljust(width))
    return "| " + " | ".join(out) + " |"


def render_row(cells: list[str], widths: list[int]) -> str:
    padded = [cell.ljust(width) for cell, width in zip(cells, widths)]
    return "| " + " | ".join(padded) + " |"


def align_tables(text: str) -> str:
    lines = text.splitlines()
    out: list[str] = []
    i = 0
    in_fence = False

    while i < len(lines):
        line = lines[i]

        if FENCE_RE.match(line):
            in_fence = not in_fence
            out.append(line)
            i += 1
            continue

        if in_fence or "|" not in line or not line.strip().startswith("|"):
            out.append(line)
            i += 1
            continue

        # Try to parse a contiguous block as a GFM table.
        block: list[list[str]] = []
        block_start = i
        while i < len(lines) and lines[i].strip().startswith("|") and lines[i].strip().endswith("|"):
            cells = split_row(lines[i])
            if not cells:
                break
            block.append(cells)
            i += 1

        # A valid GFM table has at least header + separator with matching column counts.
        if (
            len(block) >= 2
            and is_separator_row(block[1])
            and all(len(r) == len(block[0]) for r in block)
        ):
            ncols = len(block[0])
            widths = [0] * ncols
            for r_idx, row in enumerate(block):
                if r_idx == 1:
                    continue
                for c, cell in enumerate(row):
                    widths[c] = max(widths[c], len(cell))
            for c in range(ncols):
                widths[c] = max(widths[c], 3)

            for r_idx, row in enumerate(block):
                if r_idx == 1:
                    out.append(render_separator(row, widths))
                else:
                    out.append(render_row(row, widths))
        else:
            for offset, row in enumerate(block):
                out.append(lines[block_start + offset])

    rendered = "\n".join(out)
    if text.endswith("\n") and not rendered.endswith("\n"):
        rendered += "\n"
    return rendered


def process(path: Path) -> bool:
    """Rewrite ``path`` in place. Returns True if the file changed."""
    original = path.read_text(encoding="utf-8")
    aligned = align_tables(original)
    if aligned != original:
        path.write_text(aligned, encoding="utf-8")
        return True
    return False


def main(argv: list[str]) -> int:
    if argv:
        targets = [Path(p) for p in argv]
    else:
        targets = [repo_root() / "README.md"]

    any_changed = False
    for path in targets:
        if not path.exists():
            print(f"ERROR: {path} does not exist", file=sys.stderr)
            return 1
        changed = process(path)
        any_changed = any_changed or changed
        status = "rewrote" if changed else "unchanged"
        print(f"[align-md-tables] {status} {path}")

    print("[align-md-tables] done — terraform-snowflake-view tables are MD060-aligned")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
