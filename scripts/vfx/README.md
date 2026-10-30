# Standalone pixel VFX

These experiments are separate from production combat. Each effect owns its config,
behavior sampler and pixel renderer; no shared framework is required.

| Effect | Effect scripts | Lab scripts / scene | Focused test | Controls / capture guide |
|---|---|---|---|---|
| Impact | `impact/` | `scripts/vfx_lab/impact/`, `scenes/vfx_lab/impact/armor_impact_lab.tscn` | `tests/vfx/impact/armor_impact_lab_tests.gd` | [Impact](../../tools/vfx/armor_lab/README.md) |
| Slash | `slash/` | `scripts/vfx_lab/slash/`, `scenes/vfx_lab/slash/slash_lab.tscn` | `tests/vfx/slash/pixel_slash_lab_tests.gd` | [Slash](../../tools/vfx/slash_lab/README.md) |
| Charge | `charge/` | `scripts/vfx_lab/charge/`, `scenes/vfx_lab/charge/charge_lab.tscn` | `tests/vfx/charge/pixel_charge_lab_tests.gd` | [Charge](../../tools/vfx/charge_lab/README.md) |

Paths in the table are repository-relative except the effect-script folders, which
are relative to this directory. Existing `.gd.uid` identities move with their scripts.

- `*_config.gd`: Inspector parameters and safe ranges.
- `*_behavior.gd`: deterministic timing / motion, independent of a scene.
- `pixel_*.gd`: pixel drawing, not damage or collision.
- `scripts/vfx_lab/<effect>/`: preview controllers and dedicated demo helpers.
- `scenes/vfx_lab/<effect>/`: independent F6 entry points; F5 still runs the game.
- `tests/vfx/<effect>/`: focused tests, included by `bash tests/run_all.sh`.
- `tools/vfx/*_lab/`: effect-specific documentation and export utilities.

This is a file-organization boundary, not a visual rewrite: the slash renderer still
contains its accepted practice-mannequin composition; the impact renderer retains
its existing optional demo-helper dependency. No generic utility layer has been
introduced for merely similar drawing code.

Run from the repository root, for example:

```sh
godot --path . res://scenes/vfx_lab/impact/armor_impact_lab.tscn
godot --headless --path . --script tests/vfx/slash/pixel_slash_lab_tests.gd
bash tests/run_all.sh
```

Capture outputs and logs belong outside the repository. Headless checks do not
replace real viewport review.
