#!/usr/bin/env python3
"""Verify and stage the exact historical Alpha 2 ZIP; no upload or execution."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import stat
import zipfile

EXPECTED_SHA = "dbb2759f637f702c2dcf6d2f914a325828651cb05e34a86152c9c2b833fdfd6b"
EXPECTED_ROOT = "APEX_NEXT_ENGINE_2.1_HYPER_EVOLUTION_ALPHA2"
MAX_TOTAL = 2 * 1024**3
MAX_FILES = 20000

def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

def inspect(z, expected_root=EXPECTED_ROOT):
    entries, seen = [], set()
    total = 0
    for item in z.infolist():
        raw = item.filename
        p = PurePosixPath(raw)
        mode = (item.external_attr >> 16) & 0xffff
        kind = stat.S_IFMT(mode)
        if (not raw or p.is_absolute() or "\\" in raw or ":" in raw or
                ".." in p.parts or "." in p.parts or not p.parts or
                p.parts[0] != expected_root or str(p) != raw.rstrip("/") or
                kind not in (0, stat.S_IFREG, stat.S_IFDIR)):
            raise ValueError("unsafe archive member: " + repr(raw))
        key = str(p).casefold()
        if key in seen:
            raise ValueError("duplicate archive member: " + raw)
        seen.add(key)
        total += item.file_size
        if total > MAX_TOTAL or len(seen) > MAX_FILES:
            raise ValueError("archive limits exceeded")
        if not item.is_dir():
            entries.append((item, p))
    required = {expected_root + "/project.godot",
                expected_root + "/experimental/hyper2/kernel.gd",
                expected_root + "/experimental/hyper2/console.gd"}
    if not required <= {str(p) for _, p in entries}:
        raise ValueError("missing Alpha 2 entry points")
    return entries

def stage(archive, output):
    archive, output = Path(archive), Path(output)
    if output.exists() or output.is_symlink():
        raise ValueError("staging directory must not exist")
    if digest(archive) != EXPECTED_SHA:
        raise ValueError("archive SHA256 mismatch")
    with zipfile.ZipFile(archive) as z:
        entries = inspect(z)
        output.mkdir(parents=False, exist_ok=False)
        records = []
        for item, path in entries:
            dest = output.joinpath(*path.parts)
            dest.parent.mkdir(parents=True, exist_ok=True)
            with z.open(item) as source, dest.open("xb") as target:
                shutil.copyfileobj(source, target, 1024 * 1024)
            records.append({"path": str(path), "bytes": dest.stat().st_size,
                            "sha256": digest(dest)})
    report = {"schema": 1, "archive_sha256": EXPECTED_SHA,
              "files": len(records), "entries": records,
              "rights_review": "NOT_RUN", "godot_import": "NOT_RUN",
              "publication": "BLOCKED"}
    (output / "inventory.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    return report

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("archive", type=Path)
    p.add_argument("staging", type=Path)
    a = p.parse_args()
    result = stage(a.archive, a.staging)
    print("ALPHA2_STAGED files=%d; rights and Godot QA NOT_RUN" % result["files"])

if __name__ == "__main__":
    main()
