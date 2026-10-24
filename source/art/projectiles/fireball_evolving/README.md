# Evolving hostile fireball release source

Original generated gas-flame RGB artwork supplies the color detail. Ten independently animated procedural flame tongues supply the geometric lifecycle: six unequal outer tongues and four ignition patches. The four head patches also transport their source UVs backwards through the gas detail, with a pinned leading tip and a reset hidden by zero lifecycle opacity. Blender renders both effects into 32 offline poses. This is an original artwork, geometry and UV-assisted hybrid, not a claim that all color detail was authored in Blender.

The game continues to use its published Sprite2D atlas renderer and shader. No new runtime UV-advection code, particles or trail nodes were introduced. Geometry birth, growth, curl, rupture and replacement are present in the baked poses rather than being inferred from projectile translation.

Only the release source files are retained here. Historical variants, rendered frame caches, demos and review logs are excluded. The older published volume source remains separately in `../fireball`; it is not the runtime default.

## Runtime mapping and final quality

- `assets/projectiles/fireball/evolving_fire_atlas.png`: 1536 x 512 RGBA, 8 x 4 cells, 192 x 128 pixels per pose.
- 32 distinct poses at 32 fps, one-second loop. The unchanged renderer interpolates neighboring straight-alpha frames with alpha-weighted color.
- Orthographic capture bounds: `Rect2(-3.1, -1.6, 4.8, 3.2)` in collision-radius units. Camera center is x=-0.7; x=0 remains the original projectile collision center. No post-render stretching or collider change.
- Final quality: Blender 4.5.15 LTS, Cycles CPU, 64 samples, 2 render threads, seed 24026, 36 length subdivisions, 6 across, zero optional burn strength.
- The head has local soft-shoulder corrections only: lower at most 0.032R and upper at most 0.025R. Root, rear tip, six outer tongues, lifecycle and UV transport are unchanged by those corrections.
- `.gdignore` excludes source files from Godot import. Runtime loads only the final atlas.

The original collision-readability tests remain unchanged: both lateral sides must reach at least 0.9R at alpha 0.1, and at least 0.75R at alpha 0.5, with the existing upper bounds and forward-envelope limits. Static pixel checks do not replace real-Arena, gameplay, lifecycle or performance QA.

## Source lineage

`source_gas/black_prompt.txt` is the original artwork generation prompt. `gas_black_master.png` remains unchanged. `export_straight_alpha.py` derives `gas_straight_rgba.png` in linear light; `gas_alpha_provenance.json` records the original/output hashes and conversion error. Internal sampling avoids the cropped master-image edge.

`asset_manifest.json` records the delivered atlas hash, final render parameters, original render-input hashes and curated file hashes. Curated scripts preserve the final geometry/material math while normalizing paths, labels and descriptions. Original render-input hashes are retained separately because those descriptive edits necessarily change file hashes. No incomplete or proof-quality render is accepted by the release packer.

## Reproduction

The following are explicit offline commands, not an automatic render hook. Open an authorized render window first. The builder defaults remain safe proof mode with no requested frames; final quality requires explicit `--quality final --samples 64`. Do not use an 8-sample proof as the final asset. Render output goes outside the repository.

From the repository root:

    blender -b --disable-autoexec -t 2 -P source/art/projectiles/fireball_evolving/build_evolving_fire.py -- --quality final --samples 64 --out /tmp/ragecat-evolving-fire-frames --frames all --threads 2 --seed 24026 --loop-frames 32 --width 192 --height 128 --steps 36 --across 6 --view-width 4.8 --burn-strength 0
    python source/art/projectiles/fireball_evolving/pack_fireball.py /tmp/ragecat-evolving-fire-frames assets/projectiles/fireball/evolving_fire_atlas.png

`pack_fireball.py` requires a completed final/64-sample render manifest and 32 distinct 192x128 RGBA frames. It validates source lineage and copies pixels without resizing, backgrounds or alpha reapplication. Use `--check` to verify the existing atlas without writing images. Blender manifests and frame caches remain in the temporary render directory.

Only when updating the original artwork, regenerate the straight-alpha derivative using Python with Pillow and NumPy:

    python source/art/projectiles/fireball_evolving/source_gas/export_straight_alpha.py

Any actual artwork/geometry change requires refreshed asset provenance and the unchanged visual-safety gates, not merely repacking.
