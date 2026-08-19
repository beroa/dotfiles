#!/usr/bin/env python3
"""Interactive stdin byte logger for paste debugging."""
from __future__ import annotations

import sys
import termios
import tty


def classify(data: bytes) -> str:
    if not data:
        return "EMPTY"
    if data == b"\x16":
        return "CTRL_V_ONLY"
    if data.startswith(b"\x1b[200~") and data.endswith(b"\x1b[201~"):
        return "BRACKETED_PASTE"
    if data in (b"^", b"V", b"^V"):
        return "CARET_V"
    if b"PASTE_TEST_" in data:
        return "CLIPBOARD_TEXT"
    if data.isascii() and all(32 <= b < 127 or b in (9, 10, 13) for b in data):
        return "PRINTABLE_TEXT"
    return "OTHER_BYTES"


def main() -> int:
    out_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/paste-probe-bytes.log"
    print("paste-probe: press Ctrl+V (or paste any way), then Enter. Ctrl+C to quit.", flush=True)
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        chunks: list[bytes] = []
        while True:
            ch = sys.stdin.buffer.read(1)
            if not ch:
                break
            chunks.append(ch)
            if ch == b"\r" or ch == b"\n":
                break
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)

    data = b"".join(chunks)
    label = classify(data)
    rep = data.decode("utf-8", errors="backslashreplace")
    line = f"class={label} len={len(data)} repr={data!r} text={rep!r}\n"
    with open(out_path, "a", encoding="utf-8") as fh:
        fh.write(line)
    print(line, end="", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
