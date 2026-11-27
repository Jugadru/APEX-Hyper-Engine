#!/usr/bin/env python3
"""Prepare an exact Alpha 2 source-import branch from a user-owned local archive.

Default: prepare and stage a new local branch, no remote write.
--push explicitly commits and pushes that branch, never main or force.
"""
import argparse
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tempfile

from import_alpha2 import EXPECTED_ROOT, EXPECTED_SHA, stage

BRANCH = "migration/alpha2-full-baseline"
MAX_GIT_FILE = 95 * 1024 * 1024
CACHE_DIRS = {".godot", "__pycache__", ".git"}
SENSITIVE_NAMES = {".env", ".netrc", ".git-credentials", "credentials.json", "secrets.json", "id_rsa", "id_ed25519"}

def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()

def disposition(relative, size):
    p = PurePosixPath(relative)
    parts = [x.casefold() for x in p.parts]
    if any(x in CACHE_DIRS for x in parts):
        return "cache_or_git_metadata"
    if any(x in SENSITIVE_NAMES or x.startswith(".env.") for x in parts) or p.suffix.casefold() in {".pem", ".key", ".p12", ".pfx"}:
        raise ValueError("possible credential file; review separately: " + relative)
    if size > MAX_GIT_FILE:
        raise ValueError("oversized Git file; requires separate handling: " + relative)
    return "include"

def prepare(archive, root, push=False):
    root = root.resolve(strict=True)
    if Path(git(root, "rev-parse", "--show-toplevel")).resolve() != root:
        raise ValueError("run from repository root")
    remote = git(root, "remote", "get-url", "origin")
    allowed = {"https://github.com/Jugadru/APEX-Hyper-Engine.git",
               "https://github.com/Jugadru/APEX-Hyper-Engine",
               "git@github.com:Jugadru/APEX-Hyper-Engine.git",
               "ssh://git@github.com/Jugadru/APEX-Hyper-Engine.git"}
    if remote not in allowed:
        raise ValueError("unexpected origin; use a clean clone of APEX-Hyper-Engine")
    if git(root, "status", "--porcelain", "--untracked-files=all"):
        raise ValueError("working tree must be clean")
    if git(root, "branch", "--show-current") != "main":
        raise ValueError("start on main in a fresh clone")
    if git(root, "rev-parse", "HEAD") != git(root, "rev-parse", "origin/main"):
        raise ValueError("local main must equal origin/main; fetch first")
    if git(root, "branch", "--list", BRANCH):
        raise ValueError("import branch already exists; do not overwrite")
    if (root / "game").exists() or (root / "docs" / "ALPHA2_IMPORT_INVENTORY.json").exists():
        raise ValueError("migration paths already exist")
    with tempfile.TemporaryDirectory(prefix="apex-alpha2-") as temp:
        staging = Path(temp) / "verified"
        report = stage(archive.resolve(strict=True), staging)
        source = staging / EXPECTED_ROOT
        include, excluded = [], []
        for entry in report["entries"]:
            rel = PurePosixPath(entry["path"]).relative_to(EXPECTED_ROOT)
            reason = disposition(str(rel), entry["bytes"])
            record = {**entry, "path": str(rel)}
            if reason == "include":
                include.append(record)
            else:
                excluded.append({**record, "reason": reason})
        git(root, "switch", "-c", BRANCH)
        for entry in include:
            target = root / "game" / entry["path"]
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source / entry["path"], target)
        inventory = {"schema": 1, "archive_sha256": EXPECTED_SHA,
                     "included": include, "excluded": excluded,
                     "rights_review": "owner_review_required_before_push",
                     "godot_import": "NOT_RUN", "runtime_integration": "NOT_RUN"}
        path = root / "docs" / "ALPHA2_IMPORT_INVENTORY.json"
        path.write_text(json.dumps(inventory, indent=2)+"\n", encoding="utf-8")
        git(root, "add", "-f", "--", "game", "docs/ALPHA2_IMPORT_INVENTORY.json")
        staged = set(git(root, "-c", "core.quotepath=false", "diff", "--cached", "--name-only", "-z").split("\0"))
        staged.discard("")
        expected = {"game/" + x["path"] for x in include} | {"docs/ALPHA2_IMPORT_INVENTORY.json"}
        if staged != expected:
            raise ValueError("staged paths differ from verified inventory; inspect manually")
        print("ALPHA2_READY included=%d excluded=%d branch=%s" % (len(include), len(excluded), BRANCH))
        if push:
            git(root, "commit", "-m", "Import verified Hyper 2.1 Alpha 2 baseline")
            git(root, "push", "-u", "origin", BRANCH)
            print("ALPHA2_PUSHED " + git(root, "rev-parse", "HEAD"))
        else:
            print("Review staged files and inventory; no commit or upload performed.")

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("archive", type=Path)
    p.add_argument("--push", action="store_true", help="commit and push the new branch after owner has reviewed redistribution rights")
    a = p.parse_args()
    prepare(a.archive, Path(__file__).resolve().parents[1], a.push)

if __name__ == "__main__":
    main()
