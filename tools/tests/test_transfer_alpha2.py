import sys
from pathlib import Path
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from transfer_alpha2 import disposition, MAX_GIT_FILE

class TransferTest(unittest.TestCase):
    def test_includes_game_source(self):
        self.assertEqual(disposition("experimental/hyper2/kernel.gd", 200), "include")
        self.assertEqual(disposition("assets/car.glb", 2000), "include")

    def test_excludes_cache(self):
        for p in (".godot/editor/cache", ".git/config", "tools/__pycache__/x.pyc"):
            self.assertEqual(disposition(p, 100), "cache_or_git_metadata")

    def test_block_credentials_or_large_files(self):
        for p in (".env", "nested/id_rsa", "a/cert.pem", "data/secrets.json"):
            with self.assertRaises(ValueError):
                disposition(p, 100)
        with self.assertRaises(ValueError):
            disposition("big.glb", MAX_GIT_FILE+1)
