# APEX Hyper Engine

Independent experimental development repository, authorized by the owner. The game remains Godot-based. **Migration stage 0: isolated longitudinal laboratory, not the playable Alpha 2 archive.** No release is implied.

- [Migration guide](docs/MIGRATION.md)
- [Hyper roadmap](docs/ROADMAP.md)
- [Source provenance](docs/PROVENANCE.md)
- [Agent instructions](AGENTS.md)

The source of truth for the playable baseline is the original Hyper 2.1 Evolution Alpha 2 ZIP (SHA-256 recorded in the migration guide). Do not replace it with the small laboratory. The public repository contains only already-public APEX code and original development tooling; review rights before uploading any game assets.

Run the independent fixture:
```sh
godot --headless --path lab/longitudinal --script res://tests/hyper22_longitudinal_adapter_test.gd
```
The CI runs bounded tests against the exact candidate HEAD and never checks out Core 2 main. The fixture is not a Grand Prix or a migration certification.
