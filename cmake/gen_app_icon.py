#!/usr/bin/env python3
"""Build AppIcon.icns using sips + iconutil (macOS only).

With one argument, uses a built-in placeholder color. With two arguments,
uses the given image (PNG or JPEG) as the master square source.
"""

from __future__ import annotations

import pathlib
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib


def _png_chunk(chunk_type: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(chunk_type + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + chunk_type + data + struct.pack(">I", crc)


def write_png_rgba(path: pathlib.Path, width: int, height: int, rgba: tuple[int, int, int, int]) -> None:
    """Write an 8-bit RGBA PNG (color type 6) with no interlace."""
    r, g, b, a = rgba
    row = bytes([0]) + bytes([r, g, b, a]) * width
    raw = row * height
    compressed = zlib.compress(raw, 9)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    blob = (
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", ihdr)
        + _png_chunk(b"IDAT", compressed)
        + _png_chunk(b"IEND", b"")
    )
    path.write_bytes(blob)


def _sips_resize(src: pathlib.Path, px: int, dst: pathlib.Path) -> None:
    subprocess.run(
        ["sips", "-z", str(px), str(px), str(src), "--out", str(dst)],
        check=True,
        stdout=subprocess.DEVNULL,
    )


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print("usage: gen_app_icon.py <output.icns> [source.png|source.jpg]", file=sys.stderr)
        return 2

    out_icns = pathlib.Path(sys.argv[1]).resolve()
    out_icns.parent.mkdir(parents=True, exist_ok=True)

    tmp = pathlib.Path(tempfile.mkdtemp(prefix="tmux-bar-appicon-"))
    try:
        master = tmp / "master.png"
        if len(sys.argv) == 3:
            src = pathlib.Path(sys.argv[2]).resolve()
            if not src.is_file():
                print(f"source image not found: {src}", file=sys.stderr)
                return 1
            # Normalize to PNG for a consistent sips pipeline.
            subprocess.run(
                ["sips", "-s", "format", "png", str(src), "--out", str(master)],
                check=True,
                stdout=subprocess.DEVNULL,
            )
        else:
            # tmux-adjacent green placeholder when no source image is provided
            write_png_rgba(master, 1024, 1024, (45, 120, 90, 255))

        iconset = tmp / "AppIcon.iconset"
        iconset.mkdir()

        # Names and pixel widths required by iconutil.
        spec: list[tuple[str, int]] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024),
        ]

        for name, px in spec:
            _sips_resize(master, px, iconset / name)

        subprocess.run(
            ["iconutil", "-c", "icns", str(iconset), "-o", str(out_icns)],
            check=True,
            stdout=subprocess.DEVNULL,
        )
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
