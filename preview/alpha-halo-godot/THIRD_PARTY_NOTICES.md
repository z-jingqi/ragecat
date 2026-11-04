# Consulted methods, not an exact port

The actual Sprite Fusion `get_vfx("power-up")` source was consulted on
2026-11-04: https://www.spritefusion.com/pixel-art-vfx/power-up . Source is
preserved independently under `spritefusion_exact/source/power-up.ts`.

The actual Patch PixelFX authoring guidance and status mask helper were read at
https://github.com/patch-gg/pixelfx , pinned revision
`a84159688af3ca37a4be05a0d422b94451b2e24e`, especially
`src/fx/status/_lib.js` (`shape`, transparent neighbor/outline sampling),
`rage.js`, `haste.js`, and `docs/AUTHORING.md`.

Their alpha-derived body/silhouette approach and explicit time/state control
informed this study. The live 16-direction, three-radius Godot halo is original
code. No stock actors, pre-rendered VFX sheets, floor marks, afterimages or attack
poses were copied. No parity claim or unmodified upstream preset is implied.
Relevant reference code is MIT, Copyright (c) 2026 Hugo Duprez; license retained.
User-approved artwork has separate provenance in assets/README.md.
