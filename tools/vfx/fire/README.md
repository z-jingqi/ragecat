# Original fire material source

Blender 4.3.2 / Cycles CPU, 32 samples, orthographic camera, straight-alpha RGBA PNG. `render_fire.py` builds original bent 3D flame sheets with turbulent convection, emissive filament noise and dissolving edges. Skyfire adds an actual irregular basalt mesh with warped, intermittent molten fissures. No external textures, simulation caches, painted sprites, compositor bloom or copied game assets are used.

The fire burst is a compact ignition: a short local gold core cools to dark red torn folds, then embers. Burn status stays small. Boss ground flames are low, irregularly clustered patches rather than a grid of candles. Skyfire is a falling charred mass with a short flame wrap, not a long bright comet. The ring is a horizontally periodic fire strip with a continuous textured ember bed, not a fixed-radius ring image or disconnected particles. A periodic world-coordinate material mask erodes only the outer few pixels into short irregular fringes; the central band remains continuous and the silhouette never expands beyond its original width.

From the project root, render 24 frames to a temporary folder and pack:

    blender -b --factory-startup -t 2 --python tools/vfx/fire/render_fire.py -- --effect burst --out /tmp/fire_burst
    python tools/vfx/fire/pack_fire.py /tmp/fire_burst assets/vfx/blender/fire/fire_burst.png

Other mappings: `burn` → `fire_loop`, `ground` → `fire_ground`, `skyfire` → `skyfire`. For `ring` → `fire_ring`, use `pack_fire.py --crop-y 80 176`. All frame cells are 256×256 except the cropped ring's 256×96 strip. All loops sample `[0, 1)`; the burst samples `[0, 1]` and ends transparent. `--sample` renders eight inspection frames; do not pack an inspection subset as production. `--samples` and `--size` are render settings; production defaults are 32 and 256.

`pack_fire.py` requires Pillow and preserves RGBA without multiplying alpha. Run `python tools/vfx/fire/check_fire_assets.py` to check atlas dimensions, burst endpoint alpha/white-flash limits and every ring frame's full-width coverage. It requires Pillow and NumPy. These are data contracts, not a visual release gate.

## Runtime integration and safety footprint

`fire_ground_surface.gdshader` is a continuous textured heat/ash density gradient exactly inside the existing Skyfire radius. The same owned ground layer becomes scorch at impact and remains readable for the entire original burn duration. The falling mass and low flame/impact layers use the Blender atlas; their alpha, timing/size presentation and budgets come from existing visual resources. `fire_ring_surface.gdshader` retains the exact unchanged annular width as a continuous textured density bed beneath the optional atlas flames, even if atlas detail budgets are exhausted or disabled. The Wildfire launch warning uses the same restrained ember-band material at the locked center and exact initial radius/width, replacing its former filled disk and bright outline. Neither shader uses wall-clock time, hard outline strokes, timer arcs, flat color disks or gameplay RNG.

The surface layers are bounded safety cues, not decorative particle systems, so they are never culled by decorative quad budgets. There is one owned surface quad per hazard, no per-mote child nodes. The quad and sprite layers both clip against the actual arena. Decorative flame art never changes collision, warning length, damage, targeting, target radius, tick schedule, or the swept-ring hit test.

`tests/fire_material_visual_contracts.gd` verifies the unchanged clocks, inclusive radii, swept-band edge safety, pause behavior, resource reads, lifetime/cleanup and no outline strokes. Production Compatibility render captures at actual gameplay size remain required; headless tests cannot certify visual release quality. Keep previews, rendered frames, logs and reports outside the repository.
