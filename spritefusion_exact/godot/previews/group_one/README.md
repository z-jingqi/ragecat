# Native effects 1–8 preview scenes

Open any `.tscn` here in Godot 4.6.3 and run the current scene. Each scene runs the
saved native source port, not an exported animation or the previous approximation.
Space pauses; R restarts; left/right selects source situations; S stops loops.
Controls sit in a reserved footer below the unchanged 640×400 effect area. The
logical window is 640×456 (960×684 at its default display scale); the Frame, world
origin and effect scale stay unchanged.

The host actor is an original synthetic pixel fixture. Movement cues update its
position and visibility. Shake, flash, ripple and kick callbacks are recorded,
not substituted with unverified screen effects. Back effects, actor pixels, and front effects
are drawn into one shared Frame. The combined light buffer is presented first
with additive blending, then the combined color buffer with normal alpha. Both
use nearest-neighbor scaling, as required by the official Frame contract.
A combined-frame regression covers impact ticks 0, 1, 2, 6, 12, 24, and 36, with
and without an opaque actor overlapping the effect.

Every simulation step is 1/60 second. Slow CPU rendering slows playback rather
than skipping steps. These reference scenes do not claim real-time 60 fps,
Sprite Fusion website-scene equality, or production GPU/device performance.
The saved per-effect fixtures verify raw buffers, hooks and lifecycle separately.

The sampled animations and contact sheets are generated from actual combined
native frames, not by combining the separate-layer parity snapshots. Their
combined color/light hashes are compared with the original TypeScript source;
`reports/presentation/` retains those oracle hashes. The files are CPU-composited
illustrations of those buffers, rather than evidence about a GPU or display.
