# Hyper 3.0 — integrated experimental increment (2.4–3.0)

Baseline 75eee189d99eedbfbcc6ca71bc96b20f79ab3e62: #6 exact-head FAST and paired complete races PASS. New opt-in sporting revision 5. Older revisions 2/3/4 remain selectable, independent checkpoint and career save. Scope accepted by owner as one integrated update. First implementation, not completion of the seven full roadmap systems.

| Department | Implemented | Explicit limits |
|---|---|---|
| 2.4 | Bounded continuous visual lane displacement, pitch and lateral load proxy using existing 2.3 dynamics | No physical steering, suspension, 3D path or lateral collision solver |
| 2.5 | Existing corridor decisions respect virtual neutralization, abort attacks, visual lane continuity | No new spatial solver; no guaranteed no-pass enforcement |
| 2.6 | Damage from existing driver errors, aero/power effects, condition wear, mechanical retirement, partial service repair | No collision detection, no real reliability curve, repair shares existing pit time |
| 2.7 | Timed virtual neutralization after severe spin, green return, speed target and DRS/KERS restrictions | No physical safety car, sectors, restart ordering or full flag rules |
| 2.8 | Existing three pit windows ranked by position, traffic, observed wear and damage; protected manual plan | Advisory, not Monte Carlo or new autonomous strategy |
| 2.9 | Context-sensitive radio with cooldown, existing driver traits and manual controls | No new voice assets or simulated human personality model |
| 3.0 | Separate career using revision 5, factory report, existing P&D/staff/workshop, component condition into race and back on result | No full-season certification or new supplier/manufacturing economy |

Exact-head game FAST, rev5 fixture, manual wet V21, paired GPs Monza dry and Silverstone heavy rain with same broad guard as previous. No global FULL, native GPU, Architect changes or release. Preserve original assets. Current integration candidate only until tests pass. Rollback by choosing physics 2.3 and old career.
