# Stone and arcane VFX source

These assets are original procedural Blender geometry/material animations. No external textures, plugins, cached simulations or online services are required.

Regenerate with Blender 4.3+ and Python with Pillow:

```sh
blender -b -t 2 -P tools/vfx/stone_arcane/render_assets.py -- --output /tmp/ragecat-stone-arcane
python tools/vfx/stone_arcane/pack_assets.py /tmp/ragecat-stone-arcane assets/vfx/blender/stone_arcane
```

The generator uses a top-down orthographic camera, Cycles CPU rendering, 48 samples and 64 transparent bounces. Denoising is deliberately disabled because it is not available in all Blender builds. Each atlas has 24 frames in six columns, with straight alpha. Impact and summon use 256-pixel cells; the four smaller effects are supersampled to 128-pixel cells. `manifest.json` contains the playback settings. Intermediate frames are generated outside the project.

- `stone_impact`: expanding dust and faceted fragments, impact-only.
- `charge_dust`: drifting dust and debris; orient locally to movement.
- `stone_fall`: tumbling stone and short streaks, positioned by the existing falling-rock visual.
- `energy_orb`: seamless animated shell and luminous core. Uses a periodic 24-frame cycle without duplicating its final frame.
- `summon`: fragmented sigil, inward energy sparks and emergence flash. The authoritative warning stays visible independently.
- `lightning_impact`: short branched sparks with a small highlight; does not draw the dynamic chain path.

These are presentation assets only. The engine controls hit timing, warning geometry and damage independently. Do not use sprite alpha as a collision mask or delay gameplay until animation completion.
