# Reference methods and licenses

Original visual proposal, based on Ragecat main `7f98a66b9b733bdc1b99a39828f08f947bde7fa0`.
No design image was supplied for this task; this work does not claim approved-image matching or exact port parity.

- Sprite Fusion: locally preserved `spritefusion_exact/source/ice.ts` (sequential eruption sites,
  crystal facets, seeded dimensions and independently timed emergence) and `lightning.ts`
  (jagged short-lived channels and branched cores), plus their accepted Godot counterparts.
  Reference: https://www.spritefusion.com/pixel-art-vfx
- Patch-gg PixelFX: the repository's earlier documented inspection at
  `preview/elemental-arrow-godot/REFERENCES.md`, pinned upstream revision
  `a84159688af3ca37a4be05a0d422b94451b2e24e`, informed the separate geometry / palette /
  light treatment and draft-render-inspect-refine workflow. This task did not re-download
  or re-render PixelFX upstream. Reference: https://github.com/patch-gg/pixelfx

The radial scheduler, erosion-style earth silhouettes, host interface, previews and test fixtures
are new Godot code. No upstream artwork, rendered atlas, font, screenshot or video is packaged.
Godot's bundled fallback font is used. Source-method attribution is kept here and the upstream
MIT notices are retained in `licenses/`; code licenses are not treated as asset licenses.

## 2026-11-05 impact, residue, direction and fire revision

This revision actually used the connected Sprite Fusion MCP's free list_vfx/get_vfx references
for ice, lightning and fire. get_credits reported 15 credits before work; no generate/edit/style/
animate request was made and no credits were spent. Methods read: layered ice facets and shatter
pieces; anchored primary lightning stroke with subordinate branches; nested hot-to-cool fire tongues,
detached licks and embers. It is an original adaptation, not a source-faithful port.

PixelFX has no dedicated connected effect tool in this environment. Its source was read through
GitHub at the same pinned revision a84159688af3ca37a4be05a0d422b94451b2e24e:

- src/fx/nature/earth-spike.js: quick overshooting rise, separate splitting and falling pieces,
  ground grit/dust. https://github.com/patch-gg/pixelfx/blob/a84159688af3ca37a4be05a0d422b94451b2e24e/src/fx/nature/earth-spike.js
- src/fx/ice/ice-shatter.js: crack-and-burst fragments, shallow bounce/skid and ground splinters.
  https://github.com/patch-gg/pixelfx/blob/a84159688af3ca37a4be05a0d422b94451b2e24e/src/fx/ice/ice-shatter.js
- src/fx/lightning/lightning-strike.js and chain-lightning.js: same-channel re-strike, progressing
  leader and distinct landing. https://github.com/patch-gg/pixelfx/blob/a84159688af3ca37a4be05a0d422b94451b2e24e/src/fx/lightning/lightning-strike.js

No reference artwork, screenshot, atlas or animation file was copied. Existing SpriteFusion and
PixelFX MIT notices remain intact. The four Godot renderers, shape sampler, UI and tests are new
procedural code or revisions to this project's earlier original implementation.
