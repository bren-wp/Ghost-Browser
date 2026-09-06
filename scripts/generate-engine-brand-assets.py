#!/usr/bin/env python3
"""Generate deterministic Ghosium product PNG/ICO assets.

The default mode writes Chromium source-tree brand resources. ``--icon-only``
can generate the same canonical multi-resolution ICO for the native launcher,
Setup and Portable executables without storing duplicate binary assets in Git.

Uses only the Python standard library so builders do not need Pillow,
ImageMagick or browser-runtime dependencies.
"""

from __future__ import annotations

import argparse
import math
import struct
import zlib
from pathlib import Path

TOP = (0x8A, 0xF0, 0xC7)
MID = (0x62, 0xE7, 0xD5)
BOT = (0x49, 0xD5, 0xF2)
INK = (0x11, 0x10, 0x16)


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def gradient(t: float) -> tuple[int, int, int]:
    if t <= 0.55:
        return mix(TOP, MID, t / 0.55)
    return mix(MID, BOT, (t - 0.55) / 0.45)


def inside_ghost(x: float, y: float) -> bool:
    # Rounded dome and body inspired by the canonical Ghosium ghost mark.
    dome = ((x - 0.5) / 0.35) ** 2 + ((y - 0.40) / 0.31) ** 2 <= 1.0
    body = 0.15 <= x <= 0.85 and 0.36 <= y <= 0.73
    if not (dome or body):
        return False
    if y < 0.70:
        return True

    # Five soft scallops on the lower edge.
    phase = (x - 0.15) / 0.70
    bottom = 0.78 + 0.055 * math.sin(phase * math.pi * 5.0) ** 2
    return y <= bottom


def inside_eye(x: float, y: float, cx: float) -> bool:
    return ((x - cx) / 0.043) ** 2 + ((y - 0.455) / 0.066) ** 2 <= 1.0


def on_mouth(x: float, y: float) -> bool:
    # Upward-curved smile centred under the eyes.
    if not 0.38 <= x <= 0.62:
        return False
    dx = (x - 0.5) / 0.12
    target = 0.605 + 0.035 * (dx * dx)
    return abs(y - target) <= 0.016


def render_rgba(size: int) -> bytes:
    scale = 4
    hi = size * scale
    pixels = bytearray(size * size * 4)

    for py in range(size):
        for px in range(size):
            acc_r = acc_g = acc_b = acc_a = 0
            for sy in range(scale):
                for sx in range(scale):
                    x = (px * scale + sx + 0.5) / hi
                    y = (py * scale + sy + 0.5) / hi
                    if not inside_ghost(x, y):
                        continue

                    if inside_eye(x, y, 0.385) or inside_eye(x, y, 0.615) or on_mouth(x, y):
                        r, g, b = INK
                    else:
                        r, g, b = gradient((x + y) / 2.0)
                    acc_r += r
                    acc_g += g
                    acc_b += b
                    acc_a += 255

            samples = scale * scale
            off = (py * size + px) * 4
            if acc_a:
                pixels[off] = round(acc_r / samples)
                pixels[off + 1] = round(acc_g / samples)
                pixels[off + 2] = round(acc_b / samples)
                pixels[off + 3] = round(acc_a / samples)

    return bytes(pixels)


def png_bytes(size: int) -> bytes:
    rgba = render_rgba(size)
    raw = bytearray()
    stride = size * 4
    for y in range(size):
        raw.append(0)
        raw.extend(rgba[y * stride : (y + 1) * stride])

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def ico_bytes(sizes: tuple[int, ...] = (16, 24, 32, 48, 64, 128, 256)) -> bytes:
    images = [png_bytes(size) for size in sizes]
    header = struct.pack("<HHH", 0, 1, len(images))
    directory = bytearray()
    offset = 6 + len(images) * 16
    for size, data in zip(sizes, images):
        wh = 0 if size == 256 else size
        directory.extend(struct.pack("<BBBBHHII", wh, wh, 0, 0, 1, 32, len(data), offset))
        offset += len(data)
    return header + bytes(directory) + b"".join(images)


def write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    print(f"generated {path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path, nargs="?")
    parser.add_argument(
        "--icon-output",
        type=Path,
        help="Optional path for the canonical multi-resolution Ghosium ICO.",
    )
    parser.add_argument(
        "--icon-only",
        action="store_true",
        help="Generate only --icon-output and skip Chromium source-tree assets.",
    )
    args = parser.parse_args()

    icon = ico_bytes()
    if args.icon_output is not None:
        write(args.icon_output.resolve(), icon)

    if args.icon_only:
        if args.icon_output is None:
            parser.error("--icon-only requires --icon-output")
        return 0

    if args.source_root is None:
        parser.error("source_root is required unless --icon-only is used")

    root = args.source_root.resolve()

    png_targets = {
        "chrome/app/theme/chromium/product_logo_16.png": 16,
        "chrome/app/theme/chromium/product_logo_24.png": 24,
        "chrome/app/theme/chromium/product_logo_32.png": 32,
        "chrome/app/theme/chromium/product_logo_48.png": 48,
        "chrome/app/theme/chromium/product_logo_64.png": 64,
        "chrome/app/theme/chromium/product_logo_128.png": 128,
        "chrome/app/theme/chromium/product_logo_256.png": 256,
        "chrome/app/theme/default_100_percent/chromium/product_logo_16.png": 16,
        "chrome/app/theme/default_100_percent/chromium/product_logo_32.png": 32,
        "chrome/app/theme/default_200_percent/chromium/product_logo_16.png": 32,
        "chrome/app/theme/default_200_percent/chromium/product_logo_32.png": 64,
        "chrome/app/theme/chromium/win/tiles/Logo.png": 256,
        "chrome/app/theme/chromium/win/tiles/SmallLogo.png": 64,
    }
    for rel, size in png_targets.items():
        write(root / rel, png_bytes(size))

    for rel in (
        "chrome/app/theme/chromium/win/chromium.ico",
        "chrome/app/theme/chromium/win/chromium_doc.ico",
        "chrome/app/theme/chromium/win/chromium_pdf.ico",
        "chrome/app/theme/chromium/win/app_list.ico",
        "chrome/app/theme/chromium/win/incognito.ico",
        "chrome/app/theme/chromium/win/isolated.ico",
    ):
        write(root / rel, icon)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
