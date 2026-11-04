# Reference inspection and original implementation

Inspected 2026-11-04. This is an original weapon visual, not an exact port or a new
member of the 25-family Sprite Fusion parity inventory. No reference sprites,
fonts, actor art, screenshots, videos or rendered frame atlases are redistributed.

## Actual sources read and rendered

- Sprite Fusion's preserved exports and accepted native Godot ports at Ragecat
  base `783f714`: `spritefusion_exact/source/fire.ts` (silhouette-rooted layered
  tongues, motion-induced lean, shed heat), `lightning.ts` (recursive midpoint
  displacement, branches, recolored thin/bright cores), `ice.ts` (`crystal`,
  `shard`, directional light ridge and dark underside).
- The matching native Godot `scripts/effects/fire.gd`, original-source provenance
  and native captures for Fire, Electrified and Crystals were inspected locally.
  The accepted source manifest and native reports remain under `spritefusion_exact/`.
- [Patch-gg PixelFX](https://github.com/patch-gg/pixelfx), revision
  `a84159688af3ca37a4be05a0d422b94451b2e24e`:
  `src/fx/projectiles/arrow.js`, `fire/fireball.js`, `ice/ice-lance.js`,
  `lightning/electrified.js`, `src/core/painter.js`, `docs/AUTHORING.md`,
  `skills/pixelfx/SKILL.md`, LICENSE and NOTICE.md.
- Ran PixelFX's real `tools/list.mjs` queries for arrow/fire/frost/electric;
  rendered the four candidates above using `node tools/render.mjs <id>`;
  inspected their generated contact sheets, not just prose descriptions.
  This work uses the draft/render/inspect/refine method and palette/shape/light
  separation from those tools. The PixelFX files themselves are not a runtime dependency.

## What is borrowed and what is new

The plain arrow borrows the semantic separation of wood shaft, metal bevel,
feather barbs and shed air from PixelFX. Its proportions, silhouette and feather
geometry are original, written as Godot geometry rather than copied sprite rows.
The projectile tip is the anchor, not its center; all attachment roots share its
local frame. Wakes sample historical world poses rather than being rotated as a
single sticker when the current direction turns.

Element modules are authored separately and documented with their own added
milestone. Method-level or algorithmic adaptations retain notices in the source.
Sprite Fusion / Hugo Duprez and PixelFX / Patch MIT terms are included under
`licenses/`. Their code licenses are not treated as permission to copy reference
art or the separately licensed Patch Pixel font. UI uses Godot's fallback font.

Official reference: https://www.spritefusion.com/pixel-art-vfx
