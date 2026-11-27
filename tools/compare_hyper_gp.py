#!/usr/bin/env python3
"""Compare two complete GP logs on a fixed seed and identical climate.
Experimental progression gate, not validation against real F1 telemetry.
"""
import argparse
import json
from pathlib import Path

def load(path):
    rows = [json.loads(line.split("HYPER_FULL ", 1)[1]) for line in Path(path).read_text().splitlines() if line.startswith("HYPER_FULL ")]
    if len(rows) != 1:
        raise ValueError("Expected exactly one completed-race report")
    return rows[0]

def compare(old, new, track, weather):
    failures = []
    for name, row in (("legacy", old), ("new", new)):
        if row["track"] != track or row["weather"] != weather:
            failures.append(name + ": scenario mismatch")
        if row["status"] != "PASS" or not row["checkpoint_parity"]:
            failures.append(name + ": race or replay failure")
        if row["complete"] != 24 or row["retired"] != 0:
            failures.append(name + ": not all 24 cars completed")
        if row["stops"] <= 0 or row["ticks"] <= 0:
            failures.append(name + ": invalid race metrics")
    ratio = new["ticks"] / max(1, old["ticks"])
    # Predeclared broad progression guard, not an empirical lap-time target.
    if not 0.85 <= ratio <= 1.25:
        failures.append("race clock ratio outside [0.85, 1.25]")
    if old["passes"] > 0 and new["passes"] == 0:
        failures.append("overtaking collapsed to zero")
    return {"status": "FAIL" if failures else "PASS", "track": track,
            "weather": weather, "seed": 2026, "clock_ratio": ratio,
            "legacy": old, "candidate": new, "failures": failures}

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("old")
    p.add_argument("new")
    p.add_argument("track")
    p.add_argument("weather")
    a = p.parse_args()
    report = compare(load(a.old), load(a.new), a.track, a.weather)
    print("HYPER_GP_COMPARE " + json.dumps(report, ensure_ascii=False, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1

if __name__ == "__main__":
    raise SystemExit(main())
