# Shield fracture and smoke dissolve

Original Blender 4.3+ authoring scripts. Smoke uses a noise-filled deformed volumetric mesh,
not a flat disk. The shield uses seven irregular three-dimensional translucent facets and
a thin broken wave. No external art, physics simulation cache or scene-specific gameplay data.

Regenerate from the repository root (Blender and Pillow required):

    blender -b --factory-startup --python tools/vfx/impact_fade/render_assets.py -- --effect death_smoke --out /tmp/impact_fade
    blender -b --factory-startup --python tools/vfx/impact_fade/render_assets.py -- --effect shield_break --out /tmp/impact_fade
    python tools/vfx/impact_fade/pack_assets.py /tmp/impact_fade assets/vfx/blender/impact_fade
    python tools/vfx/build_library.py

Both sheets contain 256px cells, four columns, straight alpha. Death smoke is 12 frames
at 24 fps (0.5s); shield fracture is eight frames at 24 fps (0.333s). Both finish with an
empty transparent frame. Frame counts, playback, size and opacity are presentation only.
There is substantial transparent padding for expansion: tune the runtime rectangle using
the visible smoke/shards, not the cell border. Use normal alpha blending, not additive blending.
Keep intermediate frames and previews outside the repository.
