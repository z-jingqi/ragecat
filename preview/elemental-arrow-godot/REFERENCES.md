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

## Fire attachment milestone

The fire module adapts the multi-layer tapered tongue method of Sprite Fusion
`fire.ts` and the advected heat/spark separation in PixelFX `fire/fireball.js`.
Unlike the reference fireball, the silhouette stays an arrow with four short
rooted licks. Ember positions are sampled from this component's historical
trajectory; palette, geometry, emission schedule and host interface are new.
Three native render/inspect passes were made. The first exposed degenerate
rounded polygons; duplicate tip vertices were removed and valid continuous
polygon geometry is rasterized without antialiasing on the low-resolution
viewport. The final two captures have no triangulation errors.

## Lightning attachment milestone

The lightning module explicitly adapts Sprite Fusion's recursive midpoint
displacement and dark sheath / bright core separation, with three bounded
subdivisions at arrow scale. PixelFX `lightning/electrified.js` informs re-struck
surface arcs and brief local cross-body jolts. Endpoints remain fixed to the
arrow while seeded shapes change at 20 Hz; wake points use historic poses.
There are no copied actor masks, images or frame atlases.

## Ice attachment milestone

Sprite Fusion `ice.ts` informed the crystal outline, bright ridge and dark
underside. PixelFX `ice/ice-lance.js` informed separation of the attached frozen
body from short vapour and shed glints. This module uses three newly authored
asymmetric arrow-scale crystals rather than replacing the arrow with a lance.
Facet proportions, frost rows, emission schedule and movement are original.
The first motion pass was too quiet at 1×; a second added clearer shaft facets
and a thin, bounded cold ribbon. Final native checks include all eight element
combinations on both light and dark backgrounds.

## Arrowhead fire refinement

Following visual feedback, fire is now concentrated in one compact layered
flame mass at the broadhead. It retains the reference-derived palette/tongue
method but removes shaft-length flame roots and the long ember train. Rear
shaft and fletching stay visible. The new geometry is original.

## Shaft-only lightning refinement

Following feedback, the recursive path method now draws one thin bounded shaft
arc and an occasional short cross-shaft pulse. All historic wake, detached
electric particles and outward branches were removed. Trail length has no
rendering effect for this module. The retained palette separation and seeded
re-striking still derive from the two documented reference implementations.

## Readable shaft arc amplitude

The shaft-only arc now uses three alternating seeded control bends to preserve
its zigzag at 1× raster resolution. This is original geometry within the same
reference-derived palette/core/sheath approach, not an exact Sprite Fusion port.
It keeps the compact shaft anchors and no-tail constraint from the prior revision.

## Current revision: independent transient micro-arcs

This supersedes the two single-arc milestones above. Re-read actual
Sprite Fusion `source/lightning.ts` crackle (lines 273–334) and bolt/stroke
(lines 603–649) at Ragecat base `4fcebcbe`, plus PixelFX
`lightning/electrified.js` and `_lib.js` at the pinned revision above.
Sprite Fusion emits separate 50–90 ms bolts; PixelFX changes endpoint
populations at 15 Hz and re-strikes midpoint-displaced geometry at 30 Hz.
The new arrow adaptation uses independently phased 65–110 ms events with
30 Hz geometry, random perpendicular midpoint offsets (length × 0.42,
then × 0.52), and explicit short forks for tiny arrow-scale paths.
Bright cores stay 1 px; all colored fringes precede bright cores. Roots,
life schedule, bounded micro-forks and configuration are newly authored.
No reference actor art, masks, rendered assets, particle sprays, grounding
or body flashes are used. All arcs use the current pose, never trajectory
history. The existing MIT notices continue to cover adapted methods.
