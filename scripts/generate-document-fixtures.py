#!/usr/bin/env python3
"""Generate deterministic, privacy-free document fixtures for device acceptance tests."""

from __future__ import annotations

from pathlib import Path
import csv
import io
import json
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts" / "document-fixtures"
OUT.mkdir(parents=True, exist_ok=True)
for stale in OUT.glob("kemi-sample.*"):
    stale.unlink()

# Keep every generated document comfortably longer than ten 1920x1280 viewports. The device
# acceptance script advances by roughly one viewport nine times and rejects a repeated frame,
# so a short fixture cannot accidentally be reported as a ten-page pass.
LONG_LINE_COUNT = 420
PDF_PAGE_COUNT = 12


def long_text(fmt: str) -> str:
    lines = [f"KEMI-DOC-TOP-{fmt}", "中文 English 123：这是可以选择、复制和朗读的唯一测试句子。"]
    lines += [f"第 {i:03d} 行 · {fmt} 双屏连续阅读样例 · https://kemi.newlinksz.com/kd/" for i in range(1, LONG_LINE_COUNT + 1)]
    lines.insert(LONG_LINE_COUNT // 2, f"KEMI-DOC-SEAM-{fmt}")
    return "\n".join(lines)


def write(name: str, text: str) -> None:
    (OUT / name).write_text(text, encoding="utf-8")


def archive(name: str, entries: dict[str, str | bytes], stored_first: str | None = None) -> None:
    with zipfile.ZipFile(OUT / name, "w") as zf:
        for path, value in entries.items():
            method = zipfile.ZIP_STORED if path == stored_first else zipfile.ZIP_DEFLATED
            zf.writestr(path, value.encode("utf-8") if isinstance(value, str) else value, compress_type=method)


write("kemi-sample.txt", long_text("TXT"))
write("kemi-sample.log", "2026-08-22 INFO start\n" + long_text("LOG"))
write("kemi-sample.md", "# KEMI-DOC-TOP-MARKDOWN\n\n**双屏文档阅读**\n\n```kotlin\nfun main() = println(\"KEMI\")\n```\n\n" + long_text("MARKDOWN"))
write("kemi-sample.markdown", "# KEMI-DOC-TOP-MARKDOWN-LONG\n\n" + long_text("MARKDOWN-LONG"))
write("kemi-sample.kt", "// KEMI-DOC-TOP-KOTLIN\nclass DualScreenDocument\n" + long_text("KOTLIN"))
for extension, label in {
    "java": "JAVA", "kts": "KOTLIN-SCRIPT", "c": "C", "h": "C-HEADER",
    "cpp": "CPP", "hpp": "CPP-HEADER", "go": "GO", "rs": "RUST", "py": "PYTHON",
    "js": "JAVASCRIPT", "jsx": "JSX", "ts": "TYPESCRIPT", "tsx": "TSX", "css": "CSS",
    "scss": "SCSS", "sh": "SHELL", "sql": "SQL", "graphql": "GRAPHQL",
    "toml": "TOML", "ini": "INI", "properties": "PROPERTIES",
}.items():
    write(f"kemi-sample.{extension}", f"/* KEMI-DOC-TOP-{label} */\n" + long_text(label))
write("kemi-sample.json", json.dumps({"marker": "KEMI-DOC-TOP-JSON", "items": long_text("JSON").splitlines()}, ensure_ascii=False, indent=2))
write("kemi-sample.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<document>\n  <title>KEMI-DOC-TOP-XML</title>\n" + "".join(f"  <p>XML 第 {i} 行 中文</p>\n" for i in range(LONG_LINE_COUNT)) + "</document>\n")
write("kemi-sample.yaml", "marker: KEMI-DOC-TOP-YAML\nitems:\n" + "".join(f"  - YAML 第 {i} 行 中文\n" for i in range(LONG_LINE_COUNT)))
write("kemi-sample.yml", "marker: KEMI-DOC-TOP-YML\nitems:\n" + "".join(f"  - YML 第 {i} 行 中文\n" for i in range(LONG_LINE_COUNT)))
write("kemi-sample.rtf", r"{\rtf1\ansi\ansicpg65001\uc1\fs28 KEMI-DOC-TOP-RTF\par " + "".join(rf"RTF line {i} 中文\par " for i in range(LONG_LINE_COUNT)) + "}")
write("kemi-sample.html", "<!doctype html><meta charset=utf-8><h1>KEMI-DOC-TOP-HTML</h1>" + "".join(f"<p>HTML 第 {i} 行 中文</p>" for i in range(LONG_LINE_COUNT)) + "<script>document.body.innerHTML='UNSAFE'</script>")
write("kemi-sample.xhtml", "<?xml version='1.0'?><html xmlns='http://www.w3.org/1999/xhtml'><body><h1>KEMI-DOC-TOP-XHTML</h1>" + "".join(f"<p>XHTML 第 {i} 行 中文</p>" for i in range(LONG_LINE_COUNT)) + "</body></html>")
write("kemi-sample.mmd", "flowchart TD\n  A[KEMI-DOC-TOP-MERMAID] --> B[双屏阅读]\n" + long_text("MERMAID"))
write("kemi-sample.puml", "@startuml\ntitle KEMI-DOC-TOP-PLANTUML\nAlice -> Bob: 双屏阅读\n@enduml\n" + long_text("PLANTUML"))

csv_buffer = io.StringIO()
writer = csv.writer(csv_buffer)
writer.writerow(["marker", "说明", "含逗号字段"])
writer.writerow(["KEMI-DOC-TOP-CSV", "中文", "a,b"])
for i in range(LONG_LINE_COUNT):
    writer.writerow([i, f"CSV 第 {i} 行", "可复制"])
write("kemi-sample.csv", csv_buffer.getvalue())
write("kemi-sample.tsv", "marker\t说明\t数值\n" + "\n".join(f"KEMI-DOC-TOP-TSV-{i}\t中文第 {i} 行\t{i}" for i in range(LONG_LINE_COUNT)))

docx_entries = {
    "[Content_Types].xml": '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>',
    "word/document.xml": '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>' + "".join(f"<w:p><w:r><w:t>{line}</w:t></w:r></w:p>" for line in long_text("DOCX").splitlines()) + "</w:body></w:document>",
}
archive("kemi-sample.docx", docx_entries)

shared = ["KEMI-DOC-TOP-XLSX"] + [f"XLSX 第 {i} 行 中文" for i in range(LONG_LINE_COUNT)]
xlsx_entries = {
    "[Content_Types].xml": '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>',
    "xl/sharedStrings.xml": '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' + "".join(f"<si><t>{value}</t></si>" for value in shared) + "</sst>",
    "xl/worksheets/sheet1.xml": '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>' + "".join(f'<row r="{i + 1}"><c t="s"><v>{i}</v></c><c><v>{i}</v></c></row>' for i in range(len(shared))) + "</sheetData></worksheet>",
}
archive("kemi-sample.xlsx", xlsx_entries)

pptx_entries = {"[Content_Types].xml": '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>'}
for slide in range(1, 25):
    marker = "KEMI-DOC-TOP-PPTX" if slide == 1 else f"幻灯片 {slide}"
    details = "".join(f"<a:t>{marker} · 第 {line:02d} 段中文双屏阅读内容</a:t>" for line in range(1, 13))
    pptx_entries[f"ppt/slides/slide{slide}.xml"] = '<p:sld xmlns:p="p" xmlns:a="a"><p:cSld>' + details + "</p:cSld></p:sld>"
archive("kemi-sample.pptx", pptx_entries)

odt_content = '<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"><office:body><office:text>' + "".join(f"<text:p>{line}</text:p>" for line in long_text("ODT").splitlines()) + "</office:text></office:body></office:document-content>"
archive("kemi-sample.odt", {"mimetype": "application/vnd.oasis.opendocument.text", "content.xml": odt_content}, stored_first="mimetype")
for extension, mime in {
    "ods": "application/vnd.oasis.opendocument.spreadsheet",
    "odp": "application/vnd.oasis.opendocument.presentation",
}.items():
    content = odt_content.replace("ODT", extension.upper())
    archive(f"kemi-sample.{extension}", {"mimetype": mime, "content.xml": content}, stored_first="mimetype")

epub_entries = {
    "mimetype": "application/epub+zip",
    "META-INF/container.xml": '<?xml version="1.0"?><container><rootfiles><rootfile full-path="OEBPS/package.opf"/></rootfiles></container>',
    "OEBPS/package.opf": '<package><manifest><item id="second" href="b.xhtml"/><item id="first" href="a.xhtml"/></manifest><spine><itemref idref="first"/><itemref idref="second"/></spine></package>',
    "OEBPS/a.xhtml": '<html><body><h1>KEMI-DOC-TOP-EPUB</h1>' + "".join(f"<p>EPUB 第一章第 {i} 行</p>" for i in range(LONG_LINE_COUNT // 2)) + "</body></html>",
    "OEBPS/b.xhtml": '<html><body><h1>KEMI-DOC-SEAM-EPUB</h1>' + "".join(f"<p>EPUB 第二章第 {i} 行</p>" for i in range(LONG_LINE_COUNT // 2)) + "</body></html>",
}
archive("kemi-sample.epub", epub_entries, stored_first="mimetype")

# Minimal uncompressed PalmDOC database used to exercise the MOBI/PalmDOC path.
book = long_text("MOBI").encode("utf-8")
record0 = struct.pack(">HHIHHHH", 1, 0, len(book), 1, 4096, 0, 0)
name = b"KEMI PalmDOC".ljust(32, b"\0")
header = name + b"\0" * 44 + struct.pack(">H", 2)
offset0 = 78 + 16
offset1 = offset0 + len(record0)
records = struct.pack(">I4sI4s", offset0, b"\0\0\0\0", offset1, b"\0\0\0\1")
(OUT / "kemi-sample.mobi").write_bytes(header + records + record0 + book)

# Legacy Office compatibility fixtures intentionally exercise printable-string extraction,
# not proprietary binary layout fidelity.
for extension in ("doc", "xls", "ppt"):
    payload = ("KEMI-DOC-TOP-" + extension.upper() + "\n" + long_text(extension.upper()))
    ole_magic = bytes.fromhex("d0cf11e0a1b11ae1")
    (OUT / f"kemi-sample.{extension}").write_bytes(ole_magic + bytes(64) + payload.encode("utf-16le"))


def minimal_pdf() -> bytes:
    page_ids = list(range(3, 3 + PDF_PAGE_COUNT))
    content_ids = list(range(3 + PDF_PAGE_COUNT, 3 + PDF_PAGE_COUNT * 2))
    font_id = 3 + PDF_PAGE_COUNT * 2
    kids = " ".join(f"{page_id} 0 R" for page_id in page_ids)
    objects: list[bytes] = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        f"<< /Type /Pages /Kids [{kids}] /Count {PDF_PAGE_COUNT} >>".encode("ascii"),
    ]
    for page_id, content_id in zip(page_ids, content_ids):
        del page_id
        objects.append(
            f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
            f"/Resources << /Font << /F1 {font_id} 0 R >> >> /Contents {content_id} 0 R >>".encode("ascii")
        )
    contents: list[bytes] = []
    for page in range(1, PDF_PAGE_COUNT + 1):
        content = f"BT /F1 20 Tf 72 760 Td (KEMI PDF PAGE {page:02d}) Tj 0 -30 Td /F1 12 Tf "
        content += " ".join(
            f"(Page {page:02d} line {line:03d} - KEMI document reader) Tj 0 -14 Td"
            for line in range(1, 43)
        )
        content += " ET"
        encoded = content.encode("ascii")
        contents.append(f"<< /Length {len(encoded)} >>\nstream\n".encode("ascii") + encoded + b"\nendstream")
    objects.extend(contents)
    objects.append(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
    result = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for index, obj in enumerate(objects, 1):
        offsets.append(len(result))
        result.extend(f"{index} 0 obj\n".encode("ascii") + obj + b"\nendobj\n")
    xref = len(result)
    result.extend(f"xref\n0 {len(objects) + 1}\n0000000000 65535 f \n".encode("ascii"))
    for offset in offsets[1:]:
        result.extend(f"{offset:010d} 00000 n \n".encode("ascii"))
    result.extend(f"trailer << /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode("ascii"))
    return bytes(result)


(OUT / "kemi-sample.pdf").write_bytes(minimal_pdf())

print(f"Generated {len(list(OUT.iterdir()))} fixtures in {OUT}")
