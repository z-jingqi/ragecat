# VFX-18 · Attached status effects

Four independent, combinable **visual** statuses: `burning`, `poison`, `frozen`, and `shock`. This is the attached-character family, not the world poison zone, ice-spike attack or fire explosion. No damage, stun, movement lock or resistance calculation is performed.

## Visual design

- Burning: short warm tongues travel upward along the host and taper out.
- Poison: staggered green bubbles rise and contract; slower than flame.
- Frozen: asymmetric cold crystal edges and sparse glints, with a low cyan tint. It does not stop animation or implement gameplay freezing.
- Shock: thin, staggered paths grow and recede without a full-body white flash.
- Combinations retain each attached motion. Body tint is the weighted average, not additive brightness. Defaults deliberately avoid dazzling crowds.

## Host integration

`bind_host(Sprite2D)` attaches to an existing host. The component never replaces or edits its material, shader, texture, animation frame, pose, visibility or transform. A bounded multiplicative RGB tint is applied through `self_modulate`, retaining its exact alpha. Thus any original shader that honors CanvasItem COLOR remains active. A custom shader that intentionally ignores modulation needs a game-specific adapter; this is not a promise to wrap arbitrary shader logic.

The component notices external `self_modulate` changes and treats them as the new base before applying the status tint. Removing/clearing statuses and deleting the component restore the latest base, unless another system has already taken over the value. The effects use the current frame's Sprite2D rectangle and world transform for attachment. The supplied character is an original procedural test fixture from VFX-05, not production art.

`apply_status(kind, seconds, stacks)` refreshes remaining duration while retaining visual age/phase. Stacks are a caller-owned value, clamped to 1–5, not accumulated by the renderer. `remove_status(kind)` performs a short visual exit; `remove_status(kind, true)` removes immediately. `clear_all()` clears everything immediately. Host destruction clears states safely. Death/game cleanup should call `clear_all()` or free the component.

The game calls `tick(delta)` exactly once per simulation update. Pause by not ticking. `status_finished(kind)` fires when a timed or requested visual exit finishes; it does not award damage or change game statuses. Reset/reapply inside callbacks is generation-guarded.

## Parameters

| Name | Default | Range / units | Application |
|---|---:|---|---|
| intensity | 0.22 | 0–0.65 RGB tint blend, also attached-layer opacity | Live; 0 suppresses both layers |
| density | 6 | 0–16 base details per state | Live; 0 turns off attached shapes |
| enter_time | 0.14 | 0.03–1 second | Live envelope |
| exit_time | 0.22 | 0.03–1 second | Live envelope |
| seed | 18 | Integer | Replay recommended; changes fixed phase arrangement |
| `<kind>_color` | Per palette | HTML color | Live; derives darker and lighter shades |
| duration (apply argument) | 3 | 0.01–60 seconds, positive required | Refresh resets remaining time, not phase |
| stacks (apply argument) | 1 | Integer 1–5 | Refresh supplied visual amount, bounded |

Invalid state names and nonpositive/nonfinite durations are rejected. Numeric visual values are clamped; nonfinite values retain prior values. Lifetime and motion use seconds. Only drawing is quantized to logical pixels.

## Preview and tests

Run `godot --path preview/godot res://effects/VFX-18_status_effects/status.tscn` from repository root. The preview shows normal-speed 1× and identical 2× nearest views, separate and combined states, movement, refresh, removal, pause, step, reset, backgrounds, and intensity. `presets.json` mirrors the engine-neutral config.

Run the headless state and demo checks with `tests/run_checks.py`. `test_render.gd` requires a rendering display and checks exact alpha and restoration while an existing custom material remains installed. The recording is actual Godot-rendered frames at fixed 60 Hz, not an exported sprite animation.

## References

Viewed the public eight-moment strips before implementation:
- [Pixel Art Burning Status](https://particlefx.studio/effects/pixel-art-burning-status): contour flames, rising embers.
- [Pixel Art Poison Status](https://particlefx.studio/effects/pixel-art-poison-status): bubbles and attached toxin.
- [Pixel Art Frozen Status](https://particlefx.studio/effects/pixel-art-frozen-status): local crystals and outline frost.

Reference visual ideas only. No third-party image, sprite sheet, runtime or code is included. Electrified motion follows this repository's reviewed thin, growing/receding lightning vocabulary.
