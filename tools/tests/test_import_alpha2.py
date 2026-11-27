import io
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import import_alpha2 as migration

class MigrationTest(unittest.TestCase):
    def fixture(self, bad=None):
        stream = io.BytesIO()
        with zipfile.ZipFile(stream, "w") as z:
            for name in ("project.godot", "experimental/hyper2/kernel.gd",
                         "experimental/hyper2/console.gd"):
                z.writestr(migration.EXPECTED_ROOT + "/" + name, "fixture")
            if bad:
                z.writestr(bad, "bad")
        return stream.getvalue()

    def test_stage_synthetic(self):
        with tempfile.TemporaryDirectory() as tmp:
            a = Path(tmp) / "fixture.zip"
            a.write_bytes(self.fixture())
            dest = Path(tmp) / "new"
            with patch.object(migration, "EXPECTED_SHA", migration.digest(a)):
                result = migration.stage(a, dest)
                self.assertEqual(result["files"], 3)
                self.assertEqual(result["publication"], "BLOCKED")
                with self.assertRaises(ValueError):
                    migration.stage(a, dest)

    def test_bad_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            a = Path(tmp) / "fixture.zip"
            a.write_bytes(self.fixture())
            out = Path(tmp) / "new"
            with self.assertRaises(ValueError):
                migration.stage(a, out)
            self.assertFalse(out.exists())

    def test_paths(self):
        for bad in ("../outside", "/absolute", migration.EXPECTED_ROOT + "/../escape",
                    migration.EXPECTED_ROOT + "/x\\evil", "other/project.godot"):
            with self.subTest(bad=bad), zipfile.ZipFile(io.BytesIO(self.fixture(bad))) as z:
                with self.assertRaises(ValueError):
                    migration.inspect(z)

if __name__ == "__main__":
    unittest.main()
