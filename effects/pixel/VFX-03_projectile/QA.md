# VFX-03 verification record

## Scope and tested runtime

- **Godot 4.6.3.stable.official.7d41c59c4**, standard Linux build, Compatibility / OpenGL 4.5 / Mesa llvmpipe.
- Godot source, configuration and visual prototype only. **Unity intentionally not implemented / not tested.**
- No old effect, asset, sprite sheet, image-generated mockup or third-party effect code was restored.

## Automated checks — PASS

`python3 effects/pixel/VFX-03_projectile/tests/run_checks.py`

- 23 behavioral assertions + 2400 per-step history-cap assertions against the actual Godot state class.
- 12 assertions against the actual scene/control callbacks: pause, frame step, reset, preset changes, input speed, cross-bound slider display, teleport, bounded turning, stop and replay.
- 30/60/144 FPS constant-input state equivalence; simulation retains fractional positions.
- Canonical preset copy equality and preset override contract.
- Headless import and independent scene startup, with no script error.

## Native UI and rendered motion — PASS

Launched the real Godot desktop runtime, inspected live free flight and 4× tracking view, clicked pause, frame step, camera tracking, inner-flow slider, background cycling, reset and stop. Verified the stop settled to an empty view rather than looping again. Tested effect visibility on dark and light backgrounds. The light background exposed low-contrast UI labels; fixed label contrast and Reset background restoration. The first native turning capture exposed a diagnostic caption overlap; removed the overlapping caption and bounded both visual panels, then captured the corrected final source again.

The baseline is a compact three-color bolt: rounded leading head, continuous short taper, interior moving highlights. No circular corona, uniform spokes, stray particles or noisy waves. The 1× view stays small enough to read as a game projectile rather than a screen-scale effect. The 4× view is diagnostic only; extreme radii/lengths remain confined to its panel instead of drawing over controls.

## Video and immutable evidence

- Library item: **`libfile_b541dbd12bc4819187fa094e72a78354`**, version **0**.
- Filename: `vfx03-projectile-native-preview.mp4`.
- **10.600 s, 636 frames, 60 FPS, 640×360**, original simulation speed.
- MP4 SHA-256: `9a22032389fa667ee7c827f6719d1bcc9c79697cdd0316c31c4c5151f44da829`.
- Exact render-source manifest digest: `3dea56e0f5e6a80aa84d078c57fb3b565893f9520c7d02f02ae16714901f1833`.
- Source snapshot, unaltered native PNG frames, log, frame-proof JSON and MP4 live outside the repo in the task's `vfx03-qa/` artifact directory. PNGs are lossless **test captures**, not production animation assets.

The native Godot MovieWriter produced the frames from the frozen source at fixed 60 FPS; FFmpeg only encoded those frames. This is actual engine output, but fixed-frame movie writing is **not a hardware real-time performance benchmark**. The separate normal interactive run verifies live controls and playback.

Timeline: 0–2 s free flight at 180 px/s; 2–4 s tracked 180; 4–6 s tracked 60; 6–8 s tracked 320; 8–10 s turn-limited flight; 10–10.6 s stop/clear.

`tests/check_capture.py` verifies the original lossless frames and every frozen source hash:

- Frames **144 and 150**: tracked silhouette is exactly identical (**142 pixels**); **28 interior pixels change**. Internal motion is not merely a flying static image.
- Frame **150**: 4× panel equals exact nearest-neighbor replication of the 1× effect, **zero differing samples**.
- Exactly **three effect RGB values**: `(35,139,144)`, `(122,231,197)`, `(236,255,244)`; no blended edge colors in native frames.
- Frames **270 / 390**: visible length is **17 / 29 pixels** at 60 / 320 px/s; radius remains 8 rendered pixels high.
- Frame **504**: bounded turn is visible and the tail stays connected; no caption collision.
- Frame **635**: effect ROI is completely clear.

Capture inputs can be frozen again with `tests/make_snapshot.py <outside-repo-artifact-directory>`. See the [official MovieWriter documentation](https://docs.godotengine.org/en/4.6/tutorials/animation/creating_movies.html) for fixed-FPS lossless PNG recording. The current image sequence is evidence only and is not imported by the effect.

## Remaining status

Visual prototype/self-check complete; user artistic acceptance still pending. Final game collision, damage, real gameplay scale integration and any future engine port are outside this delivery.
