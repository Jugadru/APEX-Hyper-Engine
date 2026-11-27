# Hyper 2.2 — MEGA candidate 01

Real Alpha 2 source audit: existing integer 200 ms vehicle model already owns drag, fuel, grip, wear, geometry and motion. No second integrator, no replacement by SI lab. Extend it with opt-in revision 3 (Alpha 2 default revision 2 remains unchanged). Original 3134-file archive inventory retained; evolution verifier enumerates only explicitly modified and new paths. No Core 2 external dependency.

- Seven overall ratios, interpolated integer V8 torque, RPM, 60ms averaged torque interruption, existing per-car power ceiling.
- Existing KERS allocator and reservoir: debit only estimated delivered wheel work share in new mode, never a second reservoir. Fuel ledger uses V8 delivered wheel power, same existing efficiency and idle. This is an estimate based on start-of-tick speed, not BSFC.
- Conservative braking preview uses lower-speed grip; drag/rolling included during braking. Existing spatial target, manual pit, wear, tyre temperature, wet setup, DRS and driver logic remain authoritative.
- GP free mode opt-in checkbox, gear/RPM/V8 power/mass read-only telemetry, independent 2.2 checkpoint path. Career retains 2.1 physics until calibrated. Revision 3 replay uses same factory with revision-aware restore, legacy 2 remains accepted. Old 2.1 binary rejects rev 3.
- Existing mechanics and coefficients are experimental. No full CFD, load transfer, advanced suspension, real tyre calibration, full championship or native GPU certification. No change to main game identity/Core 2 menu. No new asset imports.
- Tests: old real game FAST plus revision 3 isolated force checks, 24-car movement, save/replay and UI, manual BOX V21 wet. Exact SHA native evidence required. Two GP complete comparisons remain separate until explicitly authorized/available; no claim of balance or performance.
- Candidate based on baseline PR #3; do not merge before baseline and candidate evidence. Rollback: keep checkbox disabled; revert candidate commit. Architect integration still pending a reviewed bridge; not falsely reported active.
