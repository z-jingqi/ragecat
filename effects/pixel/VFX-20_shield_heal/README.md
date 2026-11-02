# VFX-20 Shield and Heal

Two independent support visual modes. Shield: formation, sustained thin elliptical boundary, localized hit ripple, graceful exit or segmented break. Heal: subdued foot ring, rising motes and sparse plus shapes. No health, damage, invulnerability or gameplay range is changed. The demo automatically illustrates a shield hit; real integrations call `hit()` explicitly.

## Run and integration

Open `preview/godot`, run `effects/VFX-20_shield_heal/support.tscn`. Left is logical 1×; right is the same low-resolution render at exact nearest 2×. Use Hit/Break, Pause/Frame, Replay/Stop/Reset and Move. Four presets cover cyan protection, violet break, moving green heal and subdued healing on a light background. Placeholder hero is procedurally drawn, not production artwork.

Instantiate `support.gd`; `play(point, overrides, optional_host, local_offset)` starts a copied configuration. Point is in component-local coordinates. If a host is supplied, its offset is sampled each tick; the host's material, texture, alpha, transform and visibility are never changed. `automatic=false` allows caller-supplied `tick(dt)`. `hit(direction, strength)` creates a bounded local shield response, `break_shield()` switches the same boundary into outward fragments, `stop()` begins the configured exit, `clear()` cancels immediately. `finished` emits once at completion. `phase_changed` reports enter/sustain/exit/break; host deletion safely cancels. Replay cancels the old lifecycle. Shield and heal can be composed using two separate instances.

## Configuration

All values apply at play/replay; the preview sliders immediately replay. No change to shader files or sprite atlas is needed.

| Parameter | Default | Valid range/unit | Meaning |
|---|---|---|---|
| mode | shield | shield / heal | Independent visual family |
| radius | 23 | 8–34 logical px | Shield width / healing ground spread |
| height | 29 | 12–38 px | Shield vertical radius and center offset |
| enter | .18 | .06–1 s | Forming envelope |
| sustain | 2.4 | .1–30 s | Visual hold duration |
| exit | .28 | .08–1 s | Exit/break duration |
| intensity | .60 | 0–1 | Alpha intensity; 0 disables visible light |
| particles | 12 | 0–32 integer | Healing slots; zero disables motes |
| rise_speed | 26 | 8–60 px/s | Healing upward speed |
| seed | 41 | integer | Stable mote/break variation |
| body/core/edge | cyan palette | HTML RGB color | Three independent colors |

Hit strength is clamped 0–1; no additive hit stacking. Negative/nonfinite time steps are ignored; numeric configuration is clamped and nonfinite values fall back to defaults. Colors fall back if invalid. All geometry is bounded; rendering occurs on the logical pixel grid. Heal particles are analytic slots, not dynamically spawned nodes.

## References

Actual eight-moment previews inspected: [Aegis Shield](https://particlefx.studio/effects/aegis-shield) and [Heal](https://particlefx.studio/effects/heal). Their thin shield contour/local ripple and upward healing composition informed this original procedural implementation. No downloaded asset or third-party runtime is shipped. Sparse samples are not claimed to be full animation reconstruction.

## Checks

Run `godot --headless --path preview/godot -s res://effects/VFX-20_shield_heal/test_support.gd`. Covers both modes, 30/60/144Hz, 2000 reuse cycles, follow offsets, host deletion, break/stop, malformed parameters, reentrant cancellation and single completion. Preview and rendered validation are recorded with the delivery.
