# Arena-scale readability presets

These opt-in presets address thin, brief feedback at 1280×720 with 64–76px-tall
hosts. Canonical effect defaults and runtime modules are unchanged.

- Thunder: width 3px, total 0.36s. The five-link presentation reserves a 0.10s
  native hold for each link before mapping it to the caller's visual duration.
  With five links, every fully extended link receives five or six frames at
  >=75% strength at 60fps, versus one with the baseline. All damage/selection must
  already be resolved by the caller; this preset cannot delay or repeat damage.
- Level-up: a 2× output pixel grid with height68, core2 and radius23 produces a
  136px-tall column, 4px core and 46px radius. The 18-particle/5-glint budget and
  1.6s lifetime remain unchanged. The host foot offset is not scaled.
- Keep both below hostile warnings and retain arena clipping. Pause, caps and
  cleanup remain caller-owned. A readable cue is not a larger gameplay hitbox.

Source-only checks: `godot --headless --path preview/godot -s res://effects/combat_readability/test_readability.gd` (23 assertions).
Native game-scale proof and real host integration are separate acceptance steps.

## Verified comparison

The native 1280×720 probe passes 13 checks. Five selected segment footprints
increase from 98/114/114/99/100 pixels to 246/248/246/218/234 pixels. Visible
upgrade pixels around a 38×76 opaque host mask increase from 102 to 858;
the host remains in front. Hiding the preset render fails exactly six visibility
checks. The full-path bright-frame assertion is separate from these pixel counts.
An 8.0167-second, 481-frame, 60fps comparison movie was rendered with all source
files byte-identical. Original defaults/runtime files are unchanged. This is
library evidence only; actual game host/danger/lifecycle review is still required.
