# Independent Repository Migration — Hyper 2.1

Status: **PARTIAL / BLOCKED for full source import**. Owner authorized independent development. Original ZIP was previously delivered as `APEX_MOTORSPORT_MANAGER_NEXT_ENGINE_2.1_HYPER_EVOLUTION_ALPHA2_COMPLETO.zip` (122219930 bytes, SHA256 dbb2759f637f702c2dcf6d2f914a325828651cb05e34a86152c9c2b833fdfd6b). This session could identify the file but could not recover its bytes: materialization limit 104857600 bytes, local execution unavailable. The SHA is the recorded expected value, not a newly measured checksum.

## Safe recovery

On a machine with the original ZIP, run:
```sh
python3 tools/import_alpha2.py /path/to/APEX_MOTORSPORT_MANAGER_NEXT_ENGINE_2.1_HYPER_EVOLUTION_ALPHA2_COMPLETO.zip /tmp/hyper-alpha2-staging
```
The tool verifies the exact archive hash, rejects unsafe paths, symlinks, duplicates, excessive sizes and unexpected root, and extracts in a new staging directory. It writes an inventory with file hashes outside the extracted project. It does not upload, install, run project code, or remove existing directories. The exact full project is preserved in staging, not automatically committed. Inspect inventory and licenses; review original photos, liveries, logos, models and binaries before any public push. Keep unreviewed assets local or in an authorized private store. Do not silently strip content and call it equivalent. Never commit .godot caches or personal saves.

## Acceptance gates
1. Verify archive and inventory; establish baseline with original paths and Godot 4.7.2.
2. Review rights and determine private/public source & asset boundaries; preserve original archive.
3. Import source via Git, record any exclusions, verify clean import, menu, Alpha 1/2, checkpoint/replay, manual wet V21. Match seeds and climate exactly.
4. Validate 24-car dry Monza and heavy-rain Silverstone, plus career and representative traffic. A previous 2.1 report calls Silverstone final heavy rain; the prior run argument was recorded as "Chuva", so do not compare 62 passes against heavy-rain Alpha 1 without repeating identical weather. Check original logs.
5. Only after baseline passes, integrate candidate with one proposal/settle point. Preserve sporting revision and old checkpoint isolation. Compare A/B, then version 2.2.

The existing isolated lab and its FAST workflow are not full game baseline. The original PR #185 in APEX-Simulation stays as historical evidence; no merge or closure is required for this bootstrap. CI failure 45924213279 occurred before Godot because the Core 2 base changed between event and merge checkout. Do not disable that project's guard.
