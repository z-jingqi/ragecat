# Fire flipbook source

Blender 4.3.2 / Cycles CPU, 128 samples for the volumetric burst and 32 for other clips, orthographic camera, straight-alpha RGBA PNG. The burst uses a fused, displaced metaball volume with animated 3D density/color noise and a short local heat core; other clips use layered fire ribbons. All meshes and animation are authored by `render_fire.py`; no external textures or simulation cache are required. `pack_fire.py` requires Pillow and copies RGBA without multiplying alpha.

From the project root, render 24 frames to a temporary folder, then pack:

    blender -b --factory-startup -t 2 --python tools/vfx/fire/render_fire.py -- --effect burst --out /tmp/fire_burst
    python tools/vfx/fire/pack_fire.py /tmp/fire_burst assets/vfx/blender/fire/fire_burst.png

Other mappings: `burn` → `fire_loop`, `ground` → `fire_ground`, `skyfire` → `skyfire`. For `ring` → `fire_ring`, use `pack_fire.py --crop-y 80 176`; this is a horizontally periodic strip, not a fixed-radius ring image. All loops sample `[0, 1)`; the burst samples `[0, 1]` and ends fully transparent. Playback duration and size are runtime configuration, never damage timers.
