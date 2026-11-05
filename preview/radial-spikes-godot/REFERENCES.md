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
