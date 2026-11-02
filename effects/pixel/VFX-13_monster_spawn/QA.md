# Validation

- 2072 Godot state/configuration/UI assertions: 30/60/144 Hz playback, minimum/default/maximum lifetime, exactly-once appearance/completion, cancellation restoring prior host state, deterministic seed, invalid delta/configuration, zero particles, 1000 reuse cycles, freed or absent host, callback cancellation and preview controls.
- 248 native GPU shader assertions on a transparent 8×8 test texture with half-alpha source pixels: hidden rows and transparent holes remain transparent; visible half-alpha remains half-alpha; completed output matches an unmodified native Sprite2D baseline. The framebuffer uses premultiplied readback, so RGB is compared against the actual baseline, not raw texture bytes.
- Native preview inspected at normal speed and actual game size. Pause, Replay, frame step and Cancel were exercised through the window. The final preview places 1× and 2× views clear of labels at the maximum radius.
- Ten sampled rendered frames confirm the 2× view is an exact nearest-neighbor expansion of the 1× art. No smooth filtering or bloom.
- New 11-second/660-frame 60 fps preview shows default arrival, arcane palette, wider gathering, faster arrival and cancellation. Frames are actual Godot viewport renders at a fixed simulation cadence; the video is not a desktop screen recording.

## Re-run

`godot --headless --path preview/godot --script res://effects/VFX-13_monster_spawn/test_spawn.gd`

`godot --path preview/godot --audio-driver Dummy --script res://effects/VFX-13_monster_spawn/test_render.gd`

Run the scene with `-- --spawn-auto --spawn-quit --capture-dir=/absolute/output/path` to produce the deterministic preview frames; these are QA output, not production sprite assets. Tests return a nonzero status on failure. Optional frame files and videos stay outside the repository.
