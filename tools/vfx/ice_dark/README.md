# Natural ice and dark-material flipbooks

These original assets are authored and rendered in Blender 4.3.2 with deterministic
native meshes, lights and procedural roughness. No external textures, downloaded
models, generated raster artwork, fluid caches or add-ons are used. The Python
source is the editable master; no binary `.blend` or cache is needed.

## Regenerate

From the project root, with Blender and Pillow installed:

```
blender -b --factory-startup -t 3 --python tools/vfx/ice_dark/render_assets.py -- --effect all --loop-boundary --output /tmp/ragecat_ice_dark_frames
python tools/vfx/ice_dark/pack_assets.py --input /tmp/ragecat_ice_dark_frames --output assets/vfx/blender/ice_dark
python tools/vfx/ice_dark/verify_assets.py --frames /tmp/ragecat_ice_dark_frames
```

The 24-frame atlases use 6 columns and 4 rows. Ice has 128-pixel cells, downsampled
from 256-pixel Cycles renders in premultiplied-alpha space before returning to
straight alpha. Dark matter retains 256-pixel cells. Decoded memory is 10.5 MiB.
The textures use normal alpha blending, not additive emission. Transparent borders
are required; no authored material reaches a neighboring cell.

`--preview` renders five representative frames without packing. `--frames` permits
retakes, `--size` changes authoring resolution, and `--samples` changes the explicit
Cycles CPU sample count (64 by default, no denoiser). Production packing requires
256-pixel source frames. `--loop-boundary` renders the extra dark frame 24 solely
for exact loop-endpoint verification; it is not packed.

## Appearance and registration

- `ice_shell` is broad irregular gray-blue faceted ice with small matte root deposits
  and a few short white face catches. It has no emissive wireframe, bloom, polygon
  outline or circular halo. Two translucent central planes make body frost legible
  without hiding the actor. Roots grow on staggered phases, then hold the last frame.
- `ice_shatter` starts with exactly the held shell, then separates into solid tumbling
  chips with a few small fragments. It neither flashes into a white disk nor changes
  its image-space center. The last frame is transparent.
- `ice_thaw` also starts with the held shell, then quietly shrinks and fades. It is not
  an impact. The last frame is transparent.
- `dark_vortex` consists of open short folded shreds drifting inward and uneven dense
  core material. There is no closed event-horizon ring or neon spiral. Its dark neutral
  color is intentionally restrained. This historical atlas is retained for provenance,
  but the current continuous-body shader does not use it at runtime.

Shell, shatter and thaw share camera, geometry and registration. Their atlas scale
must stay identical. The dark clip size multiplier is 1.0; do not use its transparent
padding or a larger quad as a substitute for the damage boundary.

## Runtime integration

`GravityField` owns a bounded ground-refraction pass. In the production arena,
its copy/surface pair lives in `RageArena.ground_distortions`, which is inserted
before the enemy, arrow, effect and player containers. The pass is above the floor
at relative Z zero. Actors and HUD are drawn afterward and are never sampled or
moved. The gameplay field remains an unchanged child of the arrow tip; only its
visual sibling is registered in the ground layer and it has no back-reference.
Retirement disables the copy immediately; field removal frees both visual nodes.
Standalone non-arena fixtures keep their visual pair as field children.

Each pair executes `BackBufferCopy.COPY_MODE_RECT` immediately before the screen
shader. The copied rectangle is the true attraction square, padded by
`hypot(pull, swirl)` local pixels, transformed into render-target pixels and then
grown by a two-screen-pixel linear-filter guard. Godot 4.6 Compatibility consumes
`BackBufferCopy.rect` directly in screen coordinates, ignoring the node transform;
using a local rect instead produces a black buffer. Every moving/rotated arrow
updates the explicit screen AABB, so displaced reads remain inside the capture. There is no viewport copy or mipmap generation.
The shader reads real ground pixels at `SCREEN_UV + screen_offset`; outward radial
sampling makes the visible grid bend inward, with a smaller tangential offset.
Displacement peaks near the core, vanishes smoothly at the true outer radius and
is exactly discarded outside it. Gameplay attraction and damage radii remain unchanged.

The black hole itself is one continuous advected density material. Log-radius
shear produces differential rotation; radial texture advection moves folded matter
inward. Broad open arms emerge from density, while anisotropic low-light detail
continues between them and breaks uniform highlights. The centre is not a separate
black disk, and no line, circle or atlas decoration is drawn by `GravityField`.
Cold grey-violet faces and dark troughs are part of the same moving material.
Its density tapers before the true outer boundary; the screen-space lensing is a
secondary cue, not the whole effect.

`VfxAtlasLibrary`'s Dark Ground Refraction group controls pull, swirl and subtle
breathing (13 local pixels radial, 4 tangential, 0.65 radians/second, 4% amplitude).
The Dark Continuous Body group controls opacity, extent, spatial detail, shear,
flow speed and the restrained material colours. Obsolete standalone black-core,
line and atlas switches were removed; every exposed dark field has a consumer.
The old `dark_vortex` clip/asset and generator remain as historical source, but
have no production draw caller. Its 1536×1024 RGBA texture is 6 MiB decoded;
registry retention/removal is deliberately a separate asset-management decision.

Both clocks derive only from `GravityField.age`, so pause freezes the complete
material and refraction. A pause-safe callback updates only the cached screen
capture rectangle if viewport stretch or camera transforms change. No force,
damage, duration, collision, random stream or radius is driven by art.

Godot 4.6 official references:
- [Screen-reading shaders / Back-buffer logic](https://docs.godotengine.org/en/4.6/tutorials/shaders/screen-reading_shaders.html):
  explicit local copies prevent the automatic first-reader full-screen copy;
  reads outside a copied region are undefined, so padding is mandatory.
- [Godot 4.6 Compatibility renderer source](https://github.com/godotengine/godot/blob/4.6-stable/drivers/gles3/rasterizer_canvas_gles3.cpp#L377-L384):
  the local-copy branch reads `copy_back_buffer->rect` directly; see also
  [maintainer clarification](https://github.com/godotengine/godot/issues/111096).
- [BackBufferCopy](https://docs.godotengine.org/en/4.6/classes/class_backbuffercopy.html):
  `COPY_MODE_RECT` limits the copied region. Copy and surface are sibling nodes,
  not Controls with unsupported anchors under a BackBufferCopy.

Structural checks: `tests/dark_distortion_contracts.gd` and
`tests/ice_dark_presentation_contracts.gd`. These are not visual certification.
Run `tests/dark_distortion_render_fixture.gd` on a real Compatibility display with
`-- --capture-dir=/tmp/dark-refraction --size=960x600`. It captures actual production
floor, arrow, player, enemy and HUD. Its neutral A/B explicitly sets `dark_body_opacity = 0`, isolating actual UV
displacement from the entire continuous body. `proof.json` reports observed ground
grid-line movement and curvature, changed pixels outside the radius, HUD changes,
and unchanged opaque actor pixels. It also captures 48 fixed-step moving-arrow
frames and the complete production effect. Repeat at 1280x800 before release. Use `--angle=0.65` to test a rotated arrow
and `--edge` to test a partially offscreen field overlapping the HUD area.

The sprite frost shader preserves source alpha and uses the actor's own UVs. The
procedural fallback uses disconnected shaded facets, not a bright geometric cage.
The continuous dark body is independent of atlas decoration and quad budgets.

For a quick art-direction motion sample, run `tests/dark_body_motion_fixture.gd`
with `-- --capture-dir=/tmp/dark-body-single --size=960x600`; add `--dense` for a
crowd with moving production enemy orbs and held-stage boss warnings. Both are
48 frames at a fixed 24 Hz, not a synthetic noise-only preview.

Run `tests/ice_dark_presentation_contracts.gd`, the existing element/atlas/gravity
contracts, then the rendered fixtures and actual full-game Compatibility capture.
Headless tests and offline atlases alone do not certify visual release quality.
Keep rendered previews, screenshots and test outputs outside the repository.
