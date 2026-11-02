# VFX-08 · Sustained electric field

A standalone, realtime pixel area effect. A broken grounded contour establishes the region; short irregular currents cross it at staggered phases, with small endpoint sparks. Fine 1-pixel branches and mostly 1-pixel main currents with occasional 2-pixel early joints. Three solid colour levels, no bloom, no texture/spritesheet, no fullscreen flash. This is distinct from a single strike, chain lightning and instantaneous area burst.

## Preview
Open `preview/godot/effects/VFX-08_electric_field/electric_field.tscn`. Left: actual 1× pixels; right: the same SubViewport texture at exact 2× nearest. Four dummy targets show inside, outside and crossing cases. Hit counters/brief dummy flashes represent events, not game damage implementation.

Restart applies values; Pause freezes all demo time; Stop cancels the field; Move toggles the crossing dummy; Palette/BG/Reset are available. Radius and density sliders restart with changed parameters. Playback defaults to a 3-second field; first damage opportunity is at 0.5 seconds, not immediately on spawn.

## API and integration
Instantiate `field.gd` under an unscaled world parent, call `play(world_center, candidate_nodes, config)`. Positions/radius are world-space pixels; don't scale the gameplay field node. Enlarge the rendered viewport for pixel-art display instead. `set_candidates(nodes)` updates the bounded candidate set without resetting time. `target_tick(target, tick_id, scheduled_time)` is a notification for a caller-owned combat system. The component never changes health or chooses factions. It checks a target's current world-space position at each scheduled tick; deduplicates candidates and never re-hits the same target in a delivered tick. Supply the eligible candidate list externally. A live target leaving and re-entering between ticks does not add extra hits. `completed` fires once; `stop()` cancels without completion.

Use the game's fixed-step update for moving targets: `automatic = false`, advance movement then `tick(delta)`. A large catch-up tick samples current target positions for each due event, not hypothetical historical positions. Candidate updates must be made before the tick. Targets must be live Node2D nodes in the tree. Maximum 64 eligible targets, first unique entries retained. Deleted/invalid targets are skipped. Reentrant stop/play from an event aborts the old event generation.

## Configuration (captured on play)
| Parameter | Default | Range / unit |
|---|---:|---|
| radius | 42 | 8–90 world px; gameplay-authoritative |
| duration | 3 | 0.1–30 seconds; gameplay-authoritative |
| tick_interval | 0.5 | 0.05–5 seconds; gameplay-authoritative |
| arc_interval | 0.10 | 0.05–0.5 seconds; visual only |
| arc_life | 0.18 | 0.06–0.3 seconds; visual only |
| density | 3 | 1–5 staggered visual currents per slot |
| width | 1.2 | 1–2 source pixels; per-segment variation, no added outline |
| seed | 81 | 0–65535, integer |
| boundary | true | optional contour; does not alter gameplay radius |
| core / body / edge | f4f0e5 / c1b8ef / 6a6098 | opaque RGB colors |

Nonfinite numeric input falls back to defaults; other numbers clamp. Stop and completion clear arcs and target references. No visual controls silently change damage interval or range.

## Checks
Run `godot --headless --path preview/godot --script res://effects/VFX-08_electric_field/test_field.gd`, then `test_demo.gd`. State tests cover frame rates, boundaries, deduplication, target loss, callbacks, reuse, capacity, finite geometry and deterministic visuals. Native preview and exact-nearest render checks are part of visual review, separate from unit tests.
