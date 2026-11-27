import sys
from pathlib import Path
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from compare_hyper_gp import compare

class ComparisonTest(unittest.TestCase):
    def fixture(self):
        return dict(track="ITA", weather="Seco", status="PASS", checkpoint_parity=True,
                    complete=24, retired=0, stops=48, ticks=26000, passes=20)
    def test_ok(self):
        a = self.fixture()
        b = dict(a, ticks=29000, passes=10)
        self.assertEqual(compare(a,b,"ITA","Seco")["status"],"PASS")
    def test_reject(self):
        a = self.fixture()
        for change in (dict(ticks=40000), dict(passes=0), dict(retired=1,complete=23),
                       dict(checkpoint_parity=False), dict(weather="Chuva")):
            with self.subTest(change=change):
                self.assertEqual(compare(a,dict(a,**change),"ITA","Seco")["status"],"FAIL")
