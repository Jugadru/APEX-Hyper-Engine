#!/usr/bin/env python3
"""Export exact-HEAD metadata for the isolated Hyper longitudinal laboratory.
Static declarations only; native parity is an explicit optional comparison.
No runtime integration, game state, network, or Core 2 dependency.
"""
import argparse
from decimal import Decimal
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

PATHS = (
    "lab/longitudinal/experimental/hyper22/longitudinal_adapter.gd",
    "lab/longitudinal/experimental/hyper22/longitudinal_primitives.gd",
    "lab/longitudinal/tests/hyper22_longitudinal_adapter_test.gd",
)
MAX_BYTES = 256 * 1024
MAX_LOG = 2 * 1024 * 1024
SHA = re.compile(r"[0-9a-f]{40}\Z")


def canonical(obj):
    return json.dumps(obj, sort_keys=True, ensure_ascii=False,
                      separators=(",", ":"), allow_nan=False).encode("utf-8")


def git(root, *args):
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    env.update(GIT_ALLOW_PROTOCOL="", GIT_NO_LAZY_FETCH="1",
               GIT_OPTIONAL_LOCKS="0", GIT_CONFIG_NOSYSTEM="1",
               GIT_CONFIG_GLOBAL=os.devnull, GIT_TERMINAL_PROMPT="0")
    return subprocess.check_output(
        ["git", "--no-replace-objects", "-C", str(root), *args],
        env=env, timeout=20)


def bounded(path, limit):
    if path.is_symlink() or not path.is_file() or not 0 < path.stat().st_size <= limit:
        raise ValueError("expected bounded regular file")
    with path.open("rb") as f:
        raw = f.read(limit + 1)
    if not 0 < len(raw) <= limit:
        raise ValueError("invalid file size")
    return raw


def source(root, revision, path):
    local = root / path
    if any(p.is_symlink() for p in local.parents if p != root and root in p.parents):
        raise ValueError("symlink source directory")
    raw = bounded(local, MAX_BYTES)
    tree = git(root, "ls-tree", "-z", revision, "--", path)
    match = re.fullmatch(rb"100(?:644|755) blob ([0-9a-f]{40})\t"
                         + re.escape(path.encode("ascii")) + rb"\x00", tree)
    actual = hashlib.sha1(b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw).hexdigest()
    if not match or match.group(1).decode("ascii") != actual:
        raise ValueError("source differs from committed regular blob")
    return {"path": path, "git_blob": actual, "size_bytes": len(raw),
            "sha256": hashlib.sha256(raw).hexdigest()}, raw.decode("utf-8")


def literal(text, key, pattern):
    hits = re.findall(r"(?m)^const " + re.escape(key) + r" := (" + pattern + r")[ \t]*$", text)
    if len(hits) != 1:
        raise ValueError("unsupported or ambiguous native declaration: " + key)
    return hits[0]


def integral(value, scale=1):
    number = Decimal(value) * scale
    if number != number.to_integral_value() or not 0 < number <= 10**9:
        raise ValueError("unsupported native numeric constant")
    return int(number)


def project(adapter, primitives):
    dec = r"[0-9]{1,6}(?:\.[0-9]{1,9})?"
    revision = literal(adapter, "REVISION", r'"[a-z0-9_]{1,100}"')[1:-1]
    return {"adapter_revision": revision,
            "step_us": integral(literal(adapter, "STEP_S", dec), 1000000),
            "max_previews": integral(literal(adapter, "MAX_PREVIEWS", r"[0-9]{1,6}")),
            "rounding_tolerance_um": integral(literal(adapter, "ROUNDING_TOLERANCE_M", dec), 1000000),
            "max_speed_mps": integral(literal(primitives, "MAX_MPS", dec))}


def export(root):
    root = Path(root).resolve(strict=True)
    top = Path(git(root, "rev-parse", "--show-toplevel").decode("utf-8").strip()).resolve()
    revision = git(root, "rev-parse", "--verify", "HEAD^{commit}").decode("ascii").strip()
    if top != root or not SHA.fullmatch(revision):
        raise ValueError("expected exact repository root and SHA")
    rows = [source(root, revision, path) for path in PATHS]
    body = {"contract": "hyper-metadata.v1", "engine": "hyper",
            "scope": "isolated-longitudinal-lab", "revision": revision,
            "sources": [row[0] for row in rows],
            "parameters": project(rows[0][1], rows[1][1])}
    return {"body": body, "body_sha256": hashlib.sha256(canonical(body)).hexdigest()}


def pairs(items):
    obj = {}
    for k, v in items:
        if k in obj:
            raise ValueError("duplicate JSON key")
        obj[k] = v
    return obj


def native_parity(report, log):
    lines = bounded(Path(log), MAX_LOG).decode("utf-8").splitlines()
    records = [line.removeprefix("HYPER_METADATA_NATIVE ") for line in lines
               if line.startswith("HYPER_METADATA_NATIVE ")]
    passes = [line for line in lines if re.fullmatch(r"HYPER22_LONGITUDINAL_PASS checks=[1-9][0-9]*", line)]
    if len(records) != 1 or len(passes) != 1 or any(
            re.search(r"SCRIPT ERROR:|Parse Error:|^ERROR:", line) for line in lines):
        raise ValueError("missing or invalid native fixture evidence")
    if canonical(json.loads(records[0], object_pairs_hook=pairs)) != canonical(report["body"]["parameters"]):
        raise ValueError("native metadata mismatch")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--native-log", type=Path)
    args = parser.parse_args()
    try:
        report = export(args.source_root)
        if args.native_log:
            native_parity(report, args.native_log)
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0
    except (ValueError, OSError, UnicodeError, subprocess.SubprocessError, ArithmeticError, RecursionError) as e:
        print("HYPER_METADATA_FAIL: " + str(e)[:250], file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
