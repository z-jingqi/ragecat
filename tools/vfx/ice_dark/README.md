# Ice and gravity flipbooks

These original assets are authored and rendered in Blender 4.3.2, using deterministic Python geometry and materials. They do not use external textures, downloaded models, simulated-fluid caches, or AI raster artwork.

## Regenerate

From the project root, with Blender and Pillow installed:

```
blender -b --factory-startup -t 2 --python tools/vfx/ice_dark/render_assets.py -- --effect all --output /tmp/ragecat_ice_dark_frames
python tools/vfx/ice_dark/pack_assets.py --input /tmp/ragecat_ice_dark_frames --output assets/vfx/blender/ice_dark
```

Each atlas contains 24 frames, 6 columns by 4 rows, with 128-pixel cells for ice and 256-pixel cells for the vortex, with generous transparent padding. Ice is rendered at 256 pixels and downsampled in premultiplied-alpha space before returning to straight-alpha RGBA. The four decoded atlases occupy 10.5 MiB before engine overhead. PNG RGBA is straight-alpha and intended for ordinary alpha blending, not mandatory additive rendering. The render script is the editable source of truth; there is no `.blend` file or cache needed for regeneration.

## Animation contract

- `ice_shell`: play by normalized freeze-visual growth, then hold its last frame. Translucent faces and narrow luminous edges leave the actor silhouette visible.
- `ice_shatter`: a brief impact increase followed by outward tumbling, shrinking crystal splinters. The opening material matches the held shell; its final frame is transparent.
- `ice_thaw`: shrinking, fading crystals and rising frost motes. This is not an impact or damage event; the final frame is transparent.
- `dark_vortex`: seamless cyclic inward highlights and particle travel around irregular layered accretion ribbons. Follow the arrow's world position. The image is not the authoritative gravity or damage radius.

The renderer uses Cycles CPU with explicit sample count and no unavailable denoiser. `--preview` renders representative frames only; the packer intentionally requires all 24 frames. `--size` is available for authoring previews, while production packing checks the 256-pixel input contract. Shell, shatter and thaw preserve the same image-space scale and center. Runtime lifecycle, damage, status duration, pause, and effect budgets stay controlled by Godot.
