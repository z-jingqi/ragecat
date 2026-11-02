# VFX-16 Elite Aura

Reusable Godot pixel elite-state cue: a stable elliptical foot halo with paired ground chevrons, asymmetric rising side filaments, and sparse rising motes. The middle of the host stays clear. This is a world-space reinforcement indicator, not a host recolor shader, damage modifier, or shield.

## Run

Open `preview/godot`, run `res://effects/VFX-16_elite_aura/elite_aura.tscn`.
The left view is logical 1× and right view is exact nearest 2×. Presets: gold, violet, moving green guardian, subdued light background. Pause, frame step, replay, stop, reset, seed and Move are live preview controls. Demo sprites are procedural placeholders, not production monster artwork.

## Integration

Instantiate `aura.gd`. Call `play(ground_point, overrides, optional_host, local_foot_offset)`; the ground point is in the effect node coordinate space. With a host, the component follows its foot offset every tick; host deletion clears safely. No host material, texture, transform, or visibility is changed. `automatic=false` permits caller-supplied `tick(dt)`.

`stop()` begins the configured exit; `clear()` immediately cancels. Natural finish/stop emits `finished` once. Reset/replay replaces the current lifecycle. Particles are analytic and bounded, without spawning scene objects each frame.

## Parameters

All configuration is copied and clamped at play/replay. Preview changes replay immediately. Runtime host position is sampled every tick; effect radius does not change gameplay range.

| Key | Default | Range / units | Meaning |
|---|---:|---|---|
| radius | 23 | 8–36 logical px | Foot halo radius |
| height | 48 | 16–68 px | Rising side envelope |
| thickness | 1 | 1–2 px | Ground halo width |
| period | 1.1 | 0.3–4 seconds | Breathing/halo highlight cycle |
| particles | 14 | 0–32 integer | Rising mote slots; zero disables |
| rise_speed | 0.65 | 0.15–2 cycles/s | Mote transit speed |
| brightness | 0.85 | 0.2–1 | Palette luminance multiplier |
| enter | 0.18 | 0.05–1 seconds | Activation envelope |
| sustain | 3 | 0.05–30 seconds | Active state duration |
| exit | 0.35 | 0.08–1 seconds | Natural/manual stop fade |
| seed | 31 | integer | Stable mote phases |
| core/body/edge | gold palette | HTML color | Three configurable colors |

Nonfinite numeric values reset to defaults. Invalid colors use defaults. Rendering uses integer-aligned geometry in a low-resolution viewport, then nearest integer presentation.

## Reference

[ParticleFX Pixel Art Aura](https://particlefx.studio/effects/pixel-art-aura): actual eight-moment image inspected. Borrowed the compositional idea of grounded halo, rising side energy and an unobstructed center. The implementation is independently written code; no reference sprites, production atlas, or proprietary runtime is included. No claim of exact animation reproduction.
