# Physical projectile verification

## Delivered scope

Independent `VFX-03_physical_projectile` directories in `effects/pixel/` and `preview/godot/effects/`. Godot only; no Unity implementation or claimed Unity validation. No production texture, sprite sheet, image-generated preview or external asset.

## Checks passed

- **2237 executable Godot assertions**: 37 behavioral/control assertions plus 2200 per-step bounded-buffer assertions.
- Continuous floating simulation; 30/60/144 FPS agreement for position, tail-length response and age, plus exact lifetime endpoint sampling across those frame rates.
- Stop/time expiry, pause/frame step/reset/replay, immediate clear, motionless retraction, non-finite input, parameter extremes, independent width, body preset/attachment changes, bounded turning.
- Teleport clears history, including a teleport crossing the final lifetime interval.
- Canonical JSON synchronization and no runtime references to the energy bolt or weapon trail.
- Existing energy-bolt checks re-run: 2423 state checks + 12 demo checks passed.
- Existing weapon-trail checks re-run: 7 contract tests, 17 history tests, 21 demo tests passed.
- The existing energy and weapon effect files were not changed.

## Native self-review

Actual Godot **4.6.3.stable.official.7d41c59c4**, Compatibility, OpenGL 4.5 / Mesa llvmpipe. Opened a normal interactive runtime, checked recognizable arrow and throwing knife at 1×, switched presets, paused, single-stepped, resumed, tracked the camera, turned, changed independent trail width, inspected light/dark backgrounds, reset and stopped. Arrow shaft/feathers and knife handle remain distinct; the tail uses a single rear-point path, not a broad weapon swept surface or energy core.

The final native capture uses an immutable source snapshot. Shader rasterization keeps thin diagonal paths covered until the last tapered tip. Normal preview controls and the actual rendered movie were inspected, not just headless import.

## New video

- Library **`libfile_e1b2083128308191b63fb8c6dc3187f7`**, version **0**.
- `vfx03-physical-projectile-preview.mp4`
- **763 frames / 60 FPS / 640×360 / 12.716667 seconds**, normal simulation speed.
- MP4 SHA-256: `9fbb496b51017d904dc6b8d53512fc194bd3110532c4916c872ab0dca9e816e5`.
- Final render-source digest: `811f9a0e67927ae65ad45352bbe9b1da872a141c992cce437b3f63ddf5546c1b`.

The video is native Godot MovieWriter output, encoded by FFmpeg; fixed-frame movie writing is not a real-time hardware benchmark. The physical preview is a **new Library item**, separate from the earlier energy-bolt and weapon-trail videos. A final lifetime/teleport edge-case fix was followed by a fresh native capture; all 763 PNG frame files were byte-identical to the uploaded video's source frames, so the already-new video remains exact and was not duplicated.

Timeline: 0–2s arrow axial flight; 2–4s throwing knife axial flight; 4–6s arrow turning; 6–8s knife turning; 8–10s 60 px/s; 10–12s 320 px/s; then stop and clear.

## Raw-frame proof

`tests/check_capture.py` validates every frozen source hash and the native PNG sequence:

- Frame 48: arrow head/shaft/feathers; frame 168: distinct knife blade/handle.
- Frames 264/384: both turning paths render behind their physical bodies, with no caption overlap.
- Frame 630: 3× image is exactly the nearest-neighbor replication of the 1× effect, with **zero different pixels**.
- Frames 510/630: full body-plus-trail visible bounds grow from **32 to 52 pixels** at 60/320 px/s while both bodies remain 7 pixels high.
- Stop frames 720/723/726/732/762 contain **60 / 56 / 46 / 0 / 0** effect pixels: visible decay, then complete cleanup within the 0.2s history window.

Raw captures, source manifests and checks stay outside the repository under the task's `vfx03-physical-qa/` artifacts. They are QA evidence, not animation assets. The capture helper freezes only this effect and project settings, so neither earlier effect is needed to reproduce it.

Artistic acceptance by the user remains separate from these checks. Collision, damage, target selection and game-host integration are intentionally outside the preview.
