# APEX Hyper Engine — engineering rules

- This repository is independent of Core 2. Do not modify Jugadru/APEX-Simulation or Architect unless explicitly requested. Cross-project inputs must be pinned to immutable SHA and reviewed.
- Preserve Alpha 2 as the playable baseline, including 200 ms sporting ticks, manual BOX V21, solver authority, independent saves, replay hashes, and read-only presentation. Never claim parity without actual tests.
- Current lab is a standalone fixture, not a replacement game. Do not enable new physics before actual baseline audit and integration. No duplicate kernel or arbitrary reorganizing of res:// paths.
- One main sporting change per increment; isolate changes on branches, exact-head CI, regressions and no merge before evidence. FULL races optional and explicitly scoped. No weakening gates because main moves.
- No secrets, credentials, arbitrary remote commands, self-hosted runner installation, auto-merge or publication of unreviewed assets. Repository is public at bootstrap. Rights/authorization for redistribution must be reviewed separately from development permission.
- Architect may analyze reviewed snapshots using approved capabilities. Foundation and Asset Factory share contracts, not mutable runtime state. Consult the existing APEX Foundation reference library and approved Hyper roadmap.
- Status vocabulary: PASS, FAIL, NOT_RUN, BLOCKED, INCONCLUSIVE. Report exact SHA, fixtures, scope, and limitations. No automatic background agent is installed.
