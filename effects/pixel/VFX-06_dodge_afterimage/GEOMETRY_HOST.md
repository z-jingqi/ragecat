# Geometry-host adapter

`preview/godot/effects/VFX-06_dodge_afterimage/geometry_afterimage.gd` adapts the existing short cooling silhouette history and directional one-pixel accents to hosts drawn with geometry. It does not replace, move, recolor or animate the host. No production sprite artwork, attack animation or gameplay code is introduced. Hosts may supply an immutable texture resource alongside geometry.

## Contract

- `configure(overrides)` applies clamped settings. The compact default is six silhouettes, 0.025 s sampling, 0.16 s life, 0.42 opacity, ten-pixel minimum spacing and short 0.08 s directional accents. Configuration names match the canonical effect where applicable.
- `start(world_transform, geometry, host_alpha=1)` starts a clean accepted dash. Supply the actual host global transform. The adapter does not decide whether a dash is allowed.
- After each real movement step, `advance(dt, world_transform, geometry, host_alpha=1)` records only the segment between the last supplied transform and the new supplied transform. It never writes a transform or simulates a player. The current caller-supplied appearance is authoritative, as in the original Sprite2D adapter. Subdivide updates at appearance changes if historical pose timing must be exact.
- `stop()` stops new captures but leaves a short finite tail. Keep calling `advance` to age that tail. For the final dash step, advance before stop.
- `set_paused(true)` freezes time, capture and position. `reset()` immediately clears history, accents and pause. Reset on cancellation, death, run end, restart or pool reuse. A large teleport clears history instead of bridging it.
- Geometry coordinates are host-local. Each command is `circle` (`center`, `radius`, `color`), `polygon` (`points: PackedVector2Array`, `color`) or `line` (`from`, `to`, `width`, `color`), selected by `kind`. Host alpha multiplies captured command alpha once. Snapshot command metadata and transforms are copied, not live aliases; texture resources are shared under the immutable-resource contract below. Supply only actual body/facing geometry, not invulnerability or quantitative cooldown rings. This is command-based silhouette capture, not an offscreen framebuffer snapshot: opacity applies once per primitive, so overlapping translucent commands still composite separately. Prefer the body silhouette and detached facing marker, omitting facial detail, for a restrained trail without stacked alpha.

There is no `_process`, physics callback, host reference, gameplay signal, material override or automatic deletion. The effect node belongs below the host and hostile warnings inside the game's existing clip. Captured transforms stay in world space even if the effect parent moves. Rendering uses non-antialiased captured geometry and pixel-stepped accents; it does not manufacture a production character sprite.

Capacity is bounded to 24 snapshots and 24 accents, 32 commands per snapshot and 256 polygon vertices per command. Defaults are lower. Long time steps skip already-expired history and cap sampling work. No scene objects are spawned per capture. Unsupported or nonfinite commands are ignored; bad transforms cancel.

## Reference and verification

The public eight-moment [Dash Afterimage strip](https://particlefx.studio/effects/dash-afterimage) and the actual canonical Ragecat Godot preview were inspected. Retained the clear moving front, ordered fading/cooling history and short uneven direction accents. No launch ring, sword cut, dust or reference artwork is imported. Sparse reference moments are not a full animation reproduction.

`test_geometry.gd` covers 30/60/144 Hz, bounded history, exact supplied path segments, immutable shape snapshots, parent movement, stationary suppression, pause, invalid input, teleport, long stalls, finite stop and 1,000 reset/reuse cycles. `test_geometry_render.gd` is a separate native-renderer check for source alpha, silhouette, historical world transforms under effect translation/scale, frozen pause pixels, accents and complete cleanup. A headless pass alone does not establish appearance.

## Immutable texture commands

A texture command has `kind: "texture"`, `texture: Texture2D`, `rect: Rect2` (host-local destination), `region: Rect2` (source pixels), and optional `color: Color` (white by default). Both rectangles must have finite positions and strictly positive finite dimensions. Destination dimensions are at most 256×256 host-local units; the source region must be fully inside the texture. Unsupported types, empty/negative rectangles, out-of-bounds regions and nonfinite colors are ignored. Use host transforms for flips, rotation and scaling rather than negative rectangles.

The host must treat the Texture2D and any underlying atlas/source as immutable until all captured ghosts expire or reset. Imported static PNG textures are appropriate. Live ViewportTexture, AnimatedTexture, video and resources updated in place are outside this contract: the adapter cannot freeze them without copying pixels. Replacing a command's texture with a different resource is safe; existing ghosts retain the old resource. Command dictionaries/rectangles/colors are copied, but the Texture2D resource is deliberately shared. There is no `get_image`, image copy, texture construction, resource duplication or upload in the capture path.

Rendering uses nearest filtering and `draw_texture_rect_region`. Source alpha × command alpha × captured host alpha × configured opacity × lifetime fade is applied once, preserving transparent holes and atlas cropping. Tint modulates RGB using the existing tint progression; it does not turn source-transparent pixels into a rectangle. The same external clock, pause/stop/reset behavior and command/snapshot caps apply. This is static-resource sampling, not framebuffer capture or per-frame sprite animation.

`texture_fixture.gd` creates a tiny procedural atlas once for tests. `test_texture.gd` verifies shared resource identity across repeated captures, command metadata isolation, caller resource replacement, invalid commands, mixed shapes, capacity, pause and expiry. `test_texture_render.gd` checks nearest cropped pixels, source/command/host alpha, holes, tint, world-space history, pause, fade, expiry and reset with a real renderer. `texture_preview.tscn` provides a looping native preview using only that synthetic atlas. No user portrait PNG is committed to Ragecat.

Run from the repository root (set writable HOME/XDG directories if required by the runner):

```sh
godot --headless --path preview/godot --script effects/VFX-06_dodge_afterimage/test_texture.gd
godot --headless --path preview/godot --script effects/VFX-06_dodge_afterimage/test_geometry.gd
godot --path preview/godot --rendering-method gl_compatibility --script effects/VFX-06_dodge_afterimage/test_texture_render.gd -- --proof=/tmp/ragecat-texture-proof.png
godot --path preview/godot res://effects/VFX-06_dodge_afterimage/texture_preview.tscn
```

Native render tests require a display and are not replaced by headless state tests. The optional proof PNG contains actual transparent rendered pixels at 96×64, deliberately faint because all four half-alpha factors are exercised.
