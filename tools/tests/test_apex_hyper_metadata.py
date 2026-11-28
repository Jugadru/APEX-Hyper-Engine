import json
import os
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import apex_hyper_metadata as m


class MetadataTest(unittest.TestCase):
    def setUp(self):
        self.tmp = TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        texts = ['const REVISION := "test_candidate"\nconst STEP_S := 0.2\n'
                 'const MAX_PREVIEWS := 128\nconst ROUNDING_TOLERANCE_M := 0.001\n',
                 'const MAX_MPS := 100.0\n', 'extends SceneTree\n']
        for path, data in zip(m.PATHS, texts):
            p = self.root / path
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(data, encoding="utf-8")
        self.git("add", ".")
        self.git("commit", "-qm", "fixture")

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args])

    def test_exact_and_deterministic(self):
        a = m.export(self.root)
        self.assertEqual(a, m.export(self.root))
        self.assertEqual(a["body"]["parameters"]["step_us"], 200000)
        self.assertEqual(a["body"]["parameters"]["rounding_tolerance_um"], 1000)
        self.assertEqual(a["body"]["engine"], "hyper")
        self.assertEqual(len(a["body"]["sources"]), 3)

    def test_modified_source_rejected(self):
        (self.root / m.PATHS[0]).write_text("changed", encoding="utf-8")
        with self.assertRaises(ValueError):
            m.export(self.root)

    def test_git_env_ignored(self):
        expected = m.export(self.root)
        with patch.dict(os.environ, {"GIT_DIR": "/nonexistent", "GIT_WORK_TREE": "/nonexistent"}):
            self.assertEqual(expected, m.export(self.root))

    def test_nonregular_committed_source(self):
        p = self.root / m.PATHS[2]
        p.unlink()
        p.symlink_to(self.root / m.PATHS[0])
        self.git("add", ".")
        self.git("commit", "-qm", "symlink")
        with self.assertRaises(ValueError):
            m.export(self.root)

    def test_native_parity(self):
        report = m.export(self.root)
        log = self.root / "native.log"
        prefix = "HYPER22_LONGITUDINAL_PASS checks=24\nHYPER_METADATA_NATIVE "
        values = report["body"]["parameters"]
        log.write_text(prefix + json.dumps(values), encoding="utf-8")
        m.native_parity(report, log)
        log.write_text(prefix + json.dumps(dict(values, step_us=1)), encoding="utf-8")
        with self.assertRaises(ValueError):
            m.native_parity(report, log)

    def test_invalid_declaration(self):
        with self.assertRaises(ValueError):
            m.project("const STEP_S := NAN\n", "")
