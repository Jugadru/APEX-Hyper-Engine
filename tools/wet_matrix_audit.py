#!/usr/bin/env python3
"""Explicit bounded diagnostic; never force pass counts or use future weather."""
import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path
from statistics import mean

def parse_record(output, prefix):
    rows = [json.loads(line[len(prefix):]) for line in output.splitlines() if line.startswith(prefix)]
    if len(rows) != 1:
        raise ValueError(f"expected one {prefix} record, got {len(rows)}")
    return rows[0]

def run_case(godot, game, mode, weather, seed, output_dir):
    with tempfile.TemporaryDirectory(prefix="apex-wet-") as home:
        env = dict(os.environ, XDG_DATA_HOME=home)
        cmd = [godot, "--headless", "--path", str(game), "--rendering-method", "gl_compatibility", "--script", "res://tests/hyper2/full_race.gd", "--", "GBR", weather, mode, f"seed={seed}"]
        result = subprocess.run(cmd, text=True, capture_output=True, env=env, timeout=420)
    output = result.stdout + "\n" + result.stderr
    path = output_dir / f"{mode}-{seed}-{'mixed' if weather == 'Variável' else 'heavy'}.log"
    path.write_text(output, encoding="utf-8")
    if result.returncode or any(line.startswith(("ERROR:", "SCRIPT ERROR:", "FAIL ")) for line in output.splitlines()):
        raise RuntimeError(f"failed case: {path}")
    row = parse_record(output, "HYPER_FULL ")
    if row["status"] != "PASS" or row["seed"] != seed or row["track"] != "GBR" or row["weather"] != weather or not row["checkpoint_parity"]:
        raise ValueError(f"invalid evidence: {path}")
    return {"mode":mode,"seed":seed,"weather":weather,"race":row,"blockers":parse_record(output,"WET_ATTACK_REASONS "),"pit_orders":parse_record(output,"PIT_REASON_COUNTS ")}

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--godot", required=True)
    p.add_argument("--game", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--seeds", nargs="+", type=int, default=[2026,2027,2028])
    a=p.parse_args()
    if len(a.seeds)>5 or len(set(a.seeds))!=len(a.seeds) or any(s<0 or s>2147483647 for s in a.seeds):
        p.error("supply 1–5 distinct nonnegative seeds")
    a.output.mkdir(parents=True,exist_ok=True)
    rows=[]
    for seed in a.seeds:
        for weather in ("Chuva intensa","Variável"):
            for mode in ("hyper306","hyper3061"):
                rows.append(run_case(a.godot,a.game.resolve(),mode,weather,seed,a.output))
                (a.output/"observations.json").write_text(json.dumps(rows,indent=2,ensure_ascii=False),encoding="utf-8")
    summary=[]
    for mode in ("hyper306","hyper3061"):
        for weather in ("Chuva intensa","Variável"):
            subset=[r for r in rows if r["mode"]==mode and r["weather"]==weather]
            summary.append({"mode":mode,"weather":weather,"n":len(subset),"mean_passes":mean(r["race"]["passes"] for r in subset),"mean_stops":mean(r["race"]["stops"] for r in subset),"mean_attempts":mean(r["race"]["attempts"] for r in subset),"blockers":{key:sum(r["blockers"].get(key,0) for r in subset) for key in subset[0]["blockers"]}})
    (a.output/"summary.json").write_text(json.dumps(summary,indent=2,ensure_ascii=False),encoding="utf-8")
    print(json.dumps(summary,ensure_ascii=False))
if __name__=="__main__":
    main()
