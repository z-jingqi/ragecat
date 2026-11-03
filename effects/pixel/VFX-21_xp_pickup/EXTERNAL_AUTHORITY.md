# VFX-21 external-authority cosmetic adapter

Use `preview/godot/effects/VFX-21_xp_pickup/xp_external.gd` when the game already owns XP pickups. The original `xp_state.gd` remains a standalone motion demonstration, **not** the gameplay integration API.

The adapter reproduces the canonical VFX-21 short, three-tone green pixel trail and 0.14-second four-way arrival glint. It never renders a crystal or shadow, owns a target, moves an actor, infers arrival, grants XP, expires a living pickup, emits a gameplay callback or frees any node. It has no `_process`/`_physics_process`, timers or tweens. Integer rounding occurs only during drawing; externally supplied positions are kept exact.

## Host API

One fixed-coordinate `Node2D` per observed pickup:

- `sample_position(at: Vector2)` after the game's movement step. Positions are local to the effect node, which should not itself follow the actor. Use `effect.to_local(pickup.global_position)` when coordinate spaces differ. Repeated identical samples do not generate stationary sparkles. Teleports over 17 pixels break the trail rather than drawing an artificial connector.
- `tick(dt: float)` from the host simulation clock. Ages only cosmetics. No clamped catch-up or time scale is applied. Nonpositive/nonfinite deltas are ignored.
- `collect(at: Vector2) -> bool` only from the actual game collection event, at the actual collection coordinate. Returns true exactly once until `clear()`, removes the trail and starts the four-way glint. Subsequent samples and collection calls are ignored.
- `set_paused(bool)` freezes sample/collect acceptance and cosmetic ages. The game should not issue collection events while its simulation is paused.
- `is_finished() -> bool` allows the host to remove the effect after collection plus 0.14 seconds, or after clear. It remains false indefinitely for a living observed pickup, even if its trail is empty. No automatic cleanup is performed.
- `is_visually_active() -> bool` reports whether there are visible trail segments or a glint; this is **not** pickup lifetime.
- `clear()` immediately removes all visuals and resets the adapter for explicit reuse, including pause and one-shot state. The host may delete it instead.

Trail budget: at most 48 points, 17 pixels of supplied path and 0.12 seconds of sample history. Draw work is bounded. Four radial pixel segments have radius 2→8 pixels and length 3→1, using the original VFX-21 light/body palette. The central region is left open.

## Mountains and Seas boundary review

Inspected `scripts/actors/xp_pickup.gd` and `scripts/systems/arena.gd` from Mountains and Seas. The pickup's existing magnet radius, configured movement speed, pickup radius, `claimed` guard, `collected` signal and `queue_free()` remain game-owned. Arena remains the only XP grant path. The adapter must be a separate cosmetic node so collection does not delete its brief glint along with the actor. Keep the game's `assets/items/xp-crystal.png` and `Rect2(-8,-8,16,16)` unchanged.

The demo can load this existing texture from an explicit `--xp-texture=/absolute/path/xp-crystal.png` argument. It does not import, copy, replace or distribute the game sprite. Its driver supplies a short illustrative path; that path is never part of the adapter.

## References and verification

- Canonical source inspected: `xp_view.gd`, `xp_state.gd`, `default.json`. Palette, trail pattern and radial glint math are preserved; only gameplay authority is removed.
- [Godot 4.6 custom drawing](https://docs.godotengine.org/en/4.6/tutorials/2d/custom_drawing_in_2d.html): `queue_redraw()` on changed state and `_draw()` for custom canvas rendering. No external assets/code copied.
- `test_xp_external.gd`: exact positions, duplicate samples, no autonomous movement/collection/expiry after 900 seconds, unchanged living host, bounded samples, teleport discontinuity, pause/resume, explicit once-only collection, invalid inputs and clear/reuse.
- `test_xp_external_render.gd`: native renderer pixel assertions for trail, no collectible geometry, four separate glint arms, open center and full expiry.

Run the behavioral test with `godot --headless --path preview/godot --script res://effects/VFX-21_xp_pickup/test_xp_external.gd`. Run the render test without `--headless` on a native desktop. Launch the demo with `godot --path preview/godot res://effects/VFX-21_xp_pickup/xp_external_demo.tscn -- --xp-texture=/absolute/path/xp-crystal.png`. Space pauses; R resets; the four-second cycle runs automatically.

### Verified 2026-11-03

Behavior and existing regression suite passed (canonical XP: 6,259 assertions; existing demo: 8 assertions; external adapter: all checks). Native Godot 4.6.3 OpenGL Compatibility render probe passed on Mesa llvmpipe, including real framebuffer pixel checks. This is native renderer proof, not a physical-GPU performance claim. Only the environment's unsupported VSync warning was emitted.

A new 12-second, 1280×720, 60-fps (720-frame) movie was recorded using byte-identical scripts in a capture-only project with an integer 2× presentation wrapper. The runtime and demo scripts were not changed for capture. Inspected idle, movement, four-way glint and clear frames, as well as fresh original VFX-21 movement/arrival frames: the canonical pixel trail/glint language is retained and the game's unchanged original crystal remains readable. No character artwork was introduced.

- Capture artifact: `xp-preview/xp-external.mp4` (workspace artifact outside the repository).
- Frame artifacts: `xp-preview/xp-external-{idle,move,glint,clear}.png`.
- Native proof: `xp-preview/render-tests.log`; capture log: `xp-preview/xp-external.log`.
- Runtime SHA-256: `7efc4125c655673fb370a2eda8c2652766731ce0568b11ee3a20c45c42297d76`.
- Demo SHA-256: `f3fb8f9ec9b369efbfad918eaefa2dc23f317bcda2e3af0a128e549151038f0e`.

Visual inspection is implementation QA, not user acceptance.
