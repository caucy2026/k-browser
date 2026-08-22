#!/usr/bin/env python3
"""Render the hardware ten-page CSV as a reproducible Markdown report section."""

from __future__ import annotations

import argparse
import csv
import statistics
from pathlib import Path


EXPECTED_FORMATS = 49


def percentile(values: list[int], fraction: float) -> int:
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int((len(ordered) - 1) * fraction + 0.5))]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("csv", type=Path)
    parser.add_argument("--allow-incomplete", action="store_true")
    args = parser.parse_args()

    with args.csv.open(newline="", encoding="utf-8") as source:
        rows = list(csv.DictReader(source))
    formats = {row["format"] for row in rows}
    if len(rows) != len(formats):
        raise SystemExit("duplicate format rows in result CSV")
    if not args.allow_incomplete and len(rows) != EXPECTED_FORMATS:
        raise SystemExit(f"expected {EXPECTED_FORMATS} formats, found {len(rows)}")
    if any(row["result"] != "PASS" or row["pages"] != "10" for row in rows):
        raise SystemExit("CSV contains a failed or incomplete format")

    parse = [int(row["parseMs"]) for row in rows if row["format"] != "pdf"]
    pss = [int(row["pssKiB"]) for row in rows]
    missed = [int(row["totalMissedDelta"]) for row in rows]
    print(
        f"- 格式：{len(rows)}/{EXPECTED_FORMATS}；页面位置：{len(rows) * 10}；"
        f"分析帧：{len(rows) * 20}；"
    )
    print(
        f"- 非 PDF 解析：中位数 {int(statistics.median(parse))}ms，P90 {percentile(parse, 0.9)}ms，"
        f"最大 {max(parse)}ms；"
    )
    print(
        f"- PSS：中位数 {int(statistics.median(pss))}KiB，P90 {percentile(pss, 0.9)}KiB，"
        f"最大 {max(pss)}KiB；"
    )
    print(
        f"- 9 次交替滚动的 Total missed-frame：中位数 {int(statistics.median(missed))}，"
        f"P90 {percentile(missed, 0.9)}，最大 {max(missed)}。\n"
    )
    print("| 格式 | 解析 ms | PSS KiB | Total/HWC/GPU missed | 10页唯一 | 结果 |")
    print("| --- | ---: | ---: | ---: | ---: | --- |")
    for row in sorted(rows, key=lambda item: item["format"]):
        counters = "/".join(
            row[key] for key in ("totalMissedDelta", "hwcMissedDelta", "gpuMissedDelta")
        )
        print(
            f"| `{row['format']}` | {row['parseMs']} | {row['pssKiB']} | {counters} | "
            f"{row['uniqueFrames']} | {row['result']} |"
        )


if __name__ == "__main__":
    main()
