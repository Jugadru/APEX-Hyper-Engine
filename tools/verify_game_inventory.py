#!/usr/bin/env python3
"""Verify imported archive bytes against the owner-generated inventory.
For later evolution, require a separately reviewed changed-file manifest.
"""
import hashlib
import json
from pathlib import Path, PurePosixPath

root = Path(__file__).resolve().parents[1]
data = json.loads((root / "docs/ALPHA2_IMPORT_INVENTORY.json").read_text())
expected_sha = "dbb2759f637f702c2dcf6d2f914a325828651cb05e34a86152c9c2b833fdfd6b"
if data["archive_sha256"] != expected_sha or len(data["included"]) != 3134 or data["excluded"]:
    raise SystemExit("unexpected Alpha 2 inventory")
expected = {}
for item in data["included"]:
    p = PurePosixPath(item["path"])
    if p.is_absolute() or ".." in p.parts or str(p) in expected:
        raise SystemExit("invalid inventory path")
    expected[str(p)] = (item["bytes"], item["sha256"])
actual = {p.relative_to(root / "game").as_posix(): p for p in (root / "game").rglob("*") if p.is_file()}
if set(actual) != set(expected):
    raise SystemExit("game file set differs from inventory")
for name, path in actual.items():
    if path.is_symlink() or (path.stat().st_size, hashlib.sha256(path.read_bytes()).hexdigest()) != expected[name]:
        raise SystemExit("game byte mismatch: " + name)
print("HYPER_ALPHA2_INVENTORY_PASS files=%d" % len(actual))
