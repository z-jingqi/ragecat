# Standalone pixel VFX

These experiments are separate from production combat. Each effect owns its config,
behavior sampler and pixel renderer; no shared framework is required.

| Effect | Effect scripts | Lab scripts / scene | Focused test | Controls / capture guide |
|---|---|---|---|---|
| Impact | `impact/` | `scripts/vfx_lab/impact/`, `scenes/vfx_lab/impact/armor_impact_lab.tscn` | `tests/vfx/impact/armor_impact_lab_tests.gd` | [Impact](../../tools/vfx/armor_lab/README.md) |
| Slash | `slash/` | `scripts/vfx_lab/slash/`, `scenes/vfx_lab/slash/slash_lab.tscn` | `tests/vfx/slash/pixel_slash_lab_tests.gd` | [Slash](../../tools/vfx/slash_lab/README.md) |
| Gathering Lines | `gathering_lines/` | `scripts/vfx_lab/components/`, `scenes/vfx_lab/components/character_composition.tscn` | `tests/vfx/components/effect_components_tests.gd` | [Components](../../tools/vfx/components_lab/README.md) |
| Pulsing Orb | `pulsing_orb/` | `scenes/vfx_lab/components/orb_composition.tscn` | same component suite | same guide |
| Character Glow | `character_glow/` | `scenes/vfx_lab/components/character_composition.tscn` | same component suite | same guide |

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
its existing optional demo-helper dependency. The composable components share only small pixel-command/lifecycle helpers; their labs own composition.

Run from the repository root, for example:

```sh
godot --path . res://scenes/vfx_lab/impact/armor_impact_lab.tscn
godot --headless --path . --script tests/vfx/slash/pixel_slash_lab_tests.gd
bash tests/run_all.sh
```

Capture outputs and logs belong outside the repository. Headless checks do not
replace real viewport review.

## Separate cel-shaded track

The independent shield-hit experiment lives in `cel/`, with its reusable scene at
`scenes/vfx/cel/shield_hit.tscn` and preview at
`scenes/vfx_lab/cel/shield_hit_lab.tscn`. It does not depend on or replace the pixel
effects above. See the [cel shield-hit guide](../../tools/vfx/cel/README.md) for
configuration, playback controls, reuse and real-viewport capture.

The second cel study is a single ivory/gold crescent, independently configurable
through `cel/slash_config.gd`, with pure effect scene `scenes/vfx/cel/slash.tscn`
and demo `scenes/vfx_lab/cel/slash_lab.tscn`. Rotation covers a full 360°; reverse,
curvature, length, width and timing are independent. See the [cel slash guide](../../tools/vfx/cel/slash.md).
