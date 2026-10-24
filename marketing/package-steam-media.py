#!/usr/bin/env python3
"""Package the final media and handoff documents; never include raw captures or saves."""
from pathlib import Path
import hashlib
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / "release/marketing"
OUTPUT = ROOT / "release/Sudoku-Defense-Steam-Media-0.3.9.zip"
entries = {}
for pattern in ("0[1-8]-*.png", "0[1-3]-*-loop.mp4", "0[1-3]-*-loop.gif"):
    for source in sorted(MEDIA.glob(pattern)):
        entries[source.name] = source
for name in ("sudoku-defense-steam-trailer.mp4", "trailer-poster.jpg", "media-manifest.json", "capture-manifest.json", "solve-capture-manifest.json", "asset-checks.json"):
    entries[name] = MEDIA / name
for name in ("header-capsule.png", "small-capsule.png", "main-capsule.png", "vertical-capsule.png", "library-capsule.png", "library-header.png", "library-hero.png", "library-logo.png", "page-background.png", "shortcut-icon.png", "app-icon.jpg", "linux-icons.zip", "capsule-proof.jpg", "asset-manifest.json"):
    entries["capsules/" + name] = MEDIA / "capsules" / name
for name in ("PRESS-KIT.md", "STEAM-STORE-COPY.md", "STEAM-STORE-SETUP.md", "STEAM-RELEASE.md", "STEAM-ASSET-UPLOAD.md", "LAUNCH-RESEARCH.md", "ALPHA-COMMUNITY.md"):
    entries["docs/" + name] = ROOT / "docs" / name
entries["docs/README.md"] = ROOT / "marketing/README.md"
entries["docs/ARTWORK.md"] = ROOT / "marketing/capsules/README.md"
for source in entries.values():
    if not source.is_file():
        raise SystemExit(f"Missing media-kit input: {source}")
with tempfile.NamedTemporaryFile(dir=OUTPUT.parent, suffix=".zip", delete=False) as pending:
    temporary = Path(pending.name)
try:
    with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, source in sorted(entries.items()):
            archive.write(source, name)
    with zipfile.ZipFile(temporary) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(entries)
        for name, source in entries.items():
            assert hashlib.sha256(archive.read(name)).digest() == hashlib.sha256(source.read_bytes()).digest(), name
    temporary.replace(OUTPUT)
finally:
    temporary.unlink(missing_ok=True)
print(OUTPUT)
print(f"{len(entries)} verified files; {OUTPUT.stat().st_size} bytes")
print(hashlib.sha256(OUTPUT.read_bytes()).hexdigest())
