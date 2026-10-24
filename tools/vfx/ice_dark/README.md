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
  color is intentionally restrained; runtime shader density defines the readable core.

Shell, shatter and thaw share camera, geometry and registration. Their atlas scale
must stay identical. The dark clip size multiplier is 1.0; do not use its transparent
padding or a larger quad as a substitute for the damage boundary.

## Runtime integration

`GravityField` owns one local normal-blend material surface. It stays at relative
Z zero with `show_behind_parent`, not negative Z that would hide it behind the
actual arena floor. The shader masks use
unwarped positions and the existing exact outer/inner radii, so noise cannot expand
or contract gameplay. Short inward trails are bounded by the attraction radius.
Continuous outer density and local fold color are separate from the dense core;
only uneven folded planes carry increased contrast, never a closed bright rim.
Material opacity, grain, warp, density, trail dimensions/colors and frost-shader
strength are configured in `VfxAtlasLibrary`; existing speed/count/growth settings
remain in `ElementVisualDefinition`. No gameplay clock, force, damage, duration,
collision, random stream or radius is driven by the art.

The sprite frost shader preserves source alpha and uses the actor's own UVs. The
procedural fallback uses disconnected shaded facets, not a bright geometric cage.
Disabling or exhausting atlas decoration preserves the dark material footprint.

Run `tests/ice_dark_presentation_contracts.gd`, the existing element/atlas/gravity
contracts, then the rendered fixtures and actual full-game Compatibility capture.
Headless tests and offline atlases alone do not certify visual release quality.
Keep rendered previews, screenshots and test outputs outside the repository.
