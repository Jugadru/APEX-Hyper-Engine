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
changed = ["experimental/apex2/vehicle_dynamics.gd","experimental/hyper/kernel.gd","experimental/apex2/vehicle_kernel_11.gd","experimental/hyper2/kernel.gd","experimental/hyper2/console.gd","tests/hyper2/test_manual_wet.gd","tests/hyper2/full_race.gd","experimental/hyper/traffic.gd","experimental/hyper2/career.gd","experimental/hyper2/view_3d.gd","tests/hyper2/test_career.gd","experimental/apex2/command_queue.gd"]
added = ["experimental/hyper2/powertrain_22.gd","tests/hyper2/test_hyper22.gd","experimental/hyper2/dynamics_23.gd","tests/hyper2/test_hyper23.gd","experimental/hyper2/mega_30.gd","tests/hyper2/test_hyper30.gd","experimental/hyper2/energy_301.gd","tests/hyper2/test_energy301.gd"]
if not set(changed) <= set(expected) or set(added) & set(expected):
    raise SystemExit("invalid evolution allowlist")
if set(actual) != set(expected) | set(added):
    raise SystemExit("game file set differs from inventory")
for name, path in actual.items():
    if name in changed or name in added:
        if path.is_symlink(): raise SystemExit("symlink in changed source")
        continue
    if path.is_symlink() or (path.stat().st_size, hashlib.sha256(path.read_bytes()).hexdigest()) != expected[name]:
        raise SystemExit("game byte mismatch: " + name)
print("HYPER_EVOLUTION_INVENTORY_PASS unchanged=%d changed=%d added=%d" % (len(expected)-len(changed),len(changed),len(added)))
