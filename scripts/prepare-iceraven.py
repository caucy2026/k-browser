#!/usr/bin/env python3

"""Apply Iceraven's Android Components preparation portably on Linux/macOS."""

from __future__ import annotations

import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path


def replace(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise RuntimeError(f"expected source text not found in {path}: {old!r}")
    path.write_text(text.replace(old, new), encoding="utf-8")


def run(*args: str, cwd: Path) -> None:
    subprocess.run(args, cwd=cwd, check=True)


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: prepare-iceraven.py /absolute/path/to/iceraven-browser", file=sys.stderr)
        return 2

    root = Path(sys.argv[1]).resolve()
    assets = root / "automation/iceraven/assets"
    search_assets = root / "android-components/components/feature/search/src/main/assets"
    searchplugins = search_assets / "searchplugins"
    searchplugins.mkdir(parents=True, exist_ok=True)
    for source in assets.glob("*.xml"):
        shutil.copy2(source, searchplugins / source.name)
    shutil.copy2(assets / "list.json", search_assets / "search/list.json")

    reader = root / (
        "android-components/components/feature/search/src/main/java/"
        "mozilla/components/feature/search/storage/SearchEngineReader.kt"
    )
    replace(
        reader,
        '    "ddg",\n',
        '    "brave",\n    "startpage",\n    "ddg",\n',
    )

    components = root / "android-components"
    for path in components.rglob("*.gradle"):
        text = path.read_text(encoding="utf-8")
        text = text.replace("gleanPythonEnvDir", "// gleanPythonEnvDir")
        text = text.replace(
            "../../../../../gradle/libs.versions.toml",
            "../../../gradle/libs.versions.toml",
        )
        path.write_text(text, encoding="utf-8")
    for path in components.rglob("*.kts"):
        text = path.read_text(encoding="utf-8").replace(
            "../../../../../gradle/libs.versions.toml",
            "../../../gradle/libs.versions.toml",
        )
        path.write_text(text, encoding="utf-8")

    replace(
        root / "gradle/libs.versions.toml",
        ', version.ref = "python-envs-plugin"',
        "",
    )
    integrity = components / "components/lib/integrity-googleplay/build.gradle"
    replace(
        integrity,
        "plugins {\n",
        "plugins {\n    alias(libs.plugins.python.envs.plugin)\n",
    )
    replace(
        components / "plugins/config/src/main/java/ConfigPlugin.kt",
        "mobile/android/version.txt",
        "version.txt",
    )
    replace(
        components / "components/lib/crash/build.gradle",
        "mobile/android/",
        "",
    )

    for patch_name in ("top_sites_no_most_visted_sites.patch", "toolbar.patch"):
        patch = root / f"automation/iceraven/patches/{patch_name}"
        run("git", "apply", str(patch), cwd=components)

    run(
        sys.executable,
        "automation/iceraven/toolkit/crashreporter/generate_crash_reporter_sources.py",
        cwd=root,
    )

    version = (root / "version.txt").read_text(encoding="utf-8").strip().replace(".", "_")
    psl = root / "netwerk/dns/effective_tld_names.dat"
    psl.parent.mkdir(parents=True, exist_ok=True)
    url = (
        "https://raw.githubusercontent.com/mozilla-firefox/firefox/refs/tags/"
        f"FIREFOX-ANDROID_{version}_RELEASE/netwerk/dns/effective_tld_names.dat"
    )
    with urllib.request.urlopen(url, timeout=60) as response:
        psl.write_bytes(response.read())

    print("ICERAVEN SOURCE PREPARE PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
