#!/usr/bin/env python3
"""Analyze an Android screencap PNG using only the Python standard library."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import zlib


def paeth(a: int, b: int, c: int) -> int:
    value = a + b - c
    distance_a = abs(value - a)
    distance_b = abs(value - b)
    distance_c = abs(value - c)
    if distance_a <= distance_b and distance_a <= distance_c:
        return a
    return b if distance_b <= distance_c else c


def decode_png(path: Path) -> tuple[int, int, int, bytes]:
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"not a PNG: {path}")
    offset = 8
    compressed = bytearray()
    width = height = color_type = bit_depth = 0
    while offset < len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        kind = data[offset + 4 : offset + 8]
        payload = data[offset + 8 : offset + 8 + length]
        offset += length + 12
        if kind == b"IHDR":
            width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(
                ">IIBBBBB", payload
            )
            if bit_depth != 8 or compression != 0 or filtering != 0 or interlace != 0:
                raise ValueError("unsupported PNG encoding")
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            break
    channels = {0: 1, 2: 3, 4: 2, 6: 4}.get(color_type)
    if channels is None:
        raise ValueError(f"unsupported PNG color type {color_type}")
    raw = zlib.decompress(bytes(compressed))
    stride = width * channels
    output = bytearray(height * stride)
    source = 0
    previous = bytearray(stride)
    for y in range(height):
        filter_type = raw[source]
        source += 1
        scanline = bytearray(raw[source : source + stride])
        source += stride
        for index in range(stride):
            left = scanline[index - channels] if index >= channels else 0
            up = previous[index]
            upper_left = previous[index - channels] if index >= channels else 0
            if filter_type == 1:
                scanline[index] = (scanline[index] + left) & 0xFF
            elif filter_type == 2:
                scanline[index] = (scanline[index] + up) & 0xFF
            elif filter_type == 3:
                scanline[index] = (scanline[index] + ((left + up) // 2)) & 0xFF
            elif filter_type == 4:
                scanline[index] = (scanline[index] + paeth(left, up, upper_left)) & 0xFF
            elif filter_type != 0:
                raise ValueError(f"unsupported PNG filter {filter_type}")
        output[y * stride : (y + 1) * stride] = scanline
        previous = scanline
    return width, height, channels, bytes(output)


def analyze(path: Path, crop: tuple[int, int, int, int], step: int) -> dict[str, object]:
    width, height, channels, pixels = decode_png(path)
    x, y, crop_width, crop_height = crop
    x = max(0, min(x, width - 1))
    y = max(0, min(y, height - 1))
    crop_width = max(1, min(crop_width, width - x))
    crop_height = max(1, min(crop_height, height - y))
    stride = width * channels
    luminance: list[int] = []
    quantized = bytearray()
    for sample_y in range(y, y + crop_height, step):
        row = sample_y * stride
        for sample_x in range(x, x + crop_width, step):
            offset = row + sample_x * channels
            if channels in (1, 2):
                value = pixels[offset]
            else:
                red, green, blue = pixels[offset : offset + 3]
                value = (54 * red + 183 * green + 19 * blue) >> 8
            luminance.append(value)
            quantized.append(value >> 4)
    mean = sum(luminance) / len(luminance)
    variance = sum((value - mean) ** 2 for value in luminance) / len(luminance)
    return {
        "path": str(path),
        "width": width,
        "height": height,
        "mean": round(mean, 2),
        "stdev": round(math.sqrt(variance), 2),
        "darkPercent": round(100 * sum(value < 24 for value in luminance) / len(luminance), 2),
        "lightPercent": round(100 * sum(value > 242 for value in luminance) / len(luminance), 2),
        "fingerprint": hashlib.sha256(quantized).hexdigest(),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("png", type=Path)
    parser.add_argument("--crop", default="80,170,1760,950", help="x,y,width,height")
    parser.add_argument("--step", type=int, default=8)
    parser.add_argument("--tsv", action="store_true")
    args = parser.parse_args()
    crop = tuple(int(value) for value in args.crop.split(","))
    if len(crop) != 4:
        raise SystemExit("--crop needs x,y,width,height")
    result = analyze(args.png, crop, max(1, args.step))
    if args.tsv:
        print(
            "\t".join(
                str(result[key])
                for key in ("fingerprint", "mean", "stdev", "darkPercent", "lightPercent")
            )
        )
    else:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
