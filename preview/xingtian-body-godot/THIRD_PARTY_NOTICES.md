# Reference methods and attribution

## Sprite Fusion

Actual `get_vfx("power-up")` response consulted on 2026-11-04:
https://www.spritefusion.com/pixel-art-vfx/power-up

Copyright (c) 2026 Hugo Duprez, MIT. The source is separately preserved in the
repository's `spritefusion_exact/source/power-up.ts`. Its actor-silhouette sampling,
stepped color roles, deterministic timed envelope, and attached tint informed this
study. No whole-body flash, outside aura, ground shock/light, dust, default figure,
shake, or stock animation was ported. This study makes no exact-parity claim.

## Patch PixelFX

Source: https://github.com/patch-gg/pixelfx
Pinned revision: `a84159688af3ca37a4be05a0d422b94451b2e24e`.
Read actual `skills/pixelfx/SKILL.md`, `docs/AUTHORING.md`, and
`src/fx/status/{_lib,rage,haste}.js`. Its body-mask sampling, brightness-aware body
color treatment, seeded timing and draft→render→inspect workflow were consulted.
The rage/haste floor marks, actors, poses, dust and afterimages were explicitly
excluded. `tools/pixelfx-body-draft.js` is an original path/timing study using its
painter primitives; the standalone Godot implementation requires no JS runtime.

Both libraries attribute relevant original techniques to Hugo Duprez. Their MIT
license is retained in `LICENSE`. No Patch fonts or proprietary artwork are used.
The approved user portrait has separate provenance in `assets/README.md` and is
not covered by these code-license statements.
