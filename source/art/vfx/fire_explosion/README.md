# Original pressure-burst fire

The sprite is authored in Blender 4.3.2 and rendered with Cycles. No external
artwork, downloaded textures, stock explosion, or compositor bloom is used.
The single volume domain contains a compact irregular pressure body and short,
unequal curved/tapered pressure jets,
coarse flow distortion, fine turbulent erosion, separate thermal and density
fields, and a brief small core. Five subordinate ember shards finish the decay. The body and jets are gone
before 40% of the clip; the final period contains only sparse cooling embers.
The animation is purely presentation; it must not delay combat damage.

## Rebuild

    blender -b --factory-startup -t 2 --python render_player_fire_explosion.py -- --out /tmp/ragecat-fire-explosion/frames --samples 32 --ortho 2.5 --save
    python pack_player_fire_explosion.py /tmp/ragecat-fire-explosion/frames ../../../../assets/vfx/blender/fire/player_fire_explosion.png

Use `--frames 0,3,7,13,19,23` to render selected frames, or `--size 160 --samples 16`
for a material preview. The final orthographic span is 2.5 units. `--stop-file PATH` allows a render to stop between frames
when that file appears. `--save` saves the editable animated .blend in the output parent’s `source` folder.

## Runtime contract

Use clip `fire_explosion` for player blast-arrow ElementFlash only. This source
does not replace the existing boss `fire_burst` clip or atlas.

The atlas is 1536 by 1024 RGBA, arranged 6 columns by 4 rows of 256-pixel cells.
All 24 frames remain in order, non-looping, nominal 72 fps. Normalized sampling
can retain the existing gameplay-independent effect duration. Frame zero is
visible immediately; the final frame is transparent. Use normal straight-alpha
mixing, not premultiplied-alpha import. The image does not require a glow pass.

Only the atlas is a runtime texture. Keep previews, logs, contact sheets, and
playback recordings outside the game repository. The script and .blend are
editable original asset sources.

## Artist controls

`jets` controls the short outward exits (angle, reach, girth, curl, and lifetime).
`folds` controls the unequal pressure-body pockets and their independent breakup.
The named shader values and all object keys are also editable in the .blend.
Temperature is separate from opacity/density, so the small fragments remain hot
rather than fading into a uniformly brown cloud. Final rendering uses 32 samples,
transparent film, Standard color management, and no denoiser or bloom compositor.

The final source uses a 2.5-unit camera and a 1.0 runtime size multiplier. Use clip opacity
1.0 and the independently configured player effect opacity; do not double-fade
the texture. Keep gameplay damage timing and blast radius in gameplay code.
