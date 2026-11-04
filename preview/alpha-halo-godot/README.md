# Adaptive alpha halo · standalone Godot preview

Only a restrained exterior glow. No foot circle, floor light, attack animation,
body-specific cracks, or gameplay changes. The previously published body study
remains separately available in `../xingtian-body-godot/`.

## Run

Godot 4.6.3 Standard / Compatibility:

```sh
godot --editor --path preview/alpha-halo-godot --import
godot --path preview/alpha-halo-godot
godot --headless --path preview/alpha-halo-godot --script tests/test_halo.gd
ALPHA_HALO_CAPTURE_DIR=/absolute/existing/output godot --path preview/alpha-halo-godot --script tests/render_probe.gd
```

The native render probe writes evidence outside the project. Headless checks are
state/API checks, not visual acceptance. This is a new original Godot study, not
an exact Sprite Fusion port.

## What to compare

- Left: the same 76-pixel-tall Xing Tian render enlarged exactly 4×, nearest.
- Middle: Hou Yi with a different silhouette, using the identical shader/profile.
- Right: normal and active examples at **76 logical pixels**, plus one live
  component changing source images every two seconds. Moving examples also flip.
- Dark field/grid uses the actual Mountains & Seas arena palette (`102936`, grid
  RGBA `0.2,0.4,0.45,0.14`). A light background is available via BG.
- Xing Tian's current game portrait is 76 px tall; Hou Yi's actual game height is
  64 px. Both are deliberately 76 here for a controlled shape comparison, not a
  claim of exact game integration. The fixture finds each PNG's used alpha rect
  once for framing. The component itself never reads image pixels on the CPU.
- The twelve-second visual-only demo is normal → accumulation → hold → decay.
  It does not implement or change actual attack speed or passive timing.

Controls: Normal, Build, Full, Decay, Clear, amount, color, intensity, width,
Follow/flip, timeline, Replay, Pause/Resume, BG, Reset. **Clear is latched**:
changing parameters, frame or timeline cannot revive it; start via a state
button or Replay. Width is 0.5–8 local pixels, default 2.8; intensity is 0–1,
default 0.58. Optional gentle breathing is configured on the Resource.

## Reuse and animation

`components/alpha_halo.gd` is a display-only `Node2D`. Instantiate as a child of
an actor or visual anchor; no physics/input/gameplay ownership is added.

```gdscript
var halo = preload("components/alpha_halo.gd").new()
add_child(halo)
halo.set_frame(texture, frame_rect, display_size) # rect empty = whole texture
halo.configure(profile)                         # sanitized private copy
halo.start(0.0)                                  # explicit (re)start
halo.set_amount(normalized_status)               # host's 0..1 state
halo.seek(visual_seconds)                        # or advance(delta)
halo.set_flip(facing_left)
# On animation frame changes, call set_frame with that frame's texture/region.
# Keep the animation host's display rectangle/anchor consistent to avoid jumps.
halo.clear()                                    # art remains; light is disabled
```

`set_frame` returns false and leaves the previous frame intact for invalid
inputs. Supported: ordinary Texture2D, explicit nonrotated sprite-sheet regions,
and standard AtlasTexture frames with zero virtual margin. The atlas is sampled
directly: no frame image extraction, alpha baking, per-character coordinates or
mask authoring. Nested AtlasTextures, nonzero virtual margins, and rotated atlas
packing require a host adapter to resolve the underlying region/anchor first;
these inputs are not silently guessed. AnimatedSprite2D can pass its current
SpriteFrames texture at each frame change. The preview does not auto-bind to a
particular animation player or skeleton.

The host controls `display_size` and Node2D transforms. Glow and portrait share
translation/rotation/scale/flip. Width scales with the component, rather than
being screen-constant at arbitrary camera zoom. Reserve width + 1 local pixels
beyond the frame when putting it into a clipped Control/SubViewport. The glow
quad already adds that space, including when opaque pixels touch the texture
edge. Missing/cropped original art is not reconstructed.

## Algorithm and alpha

The shader samples the live frame alpha at 16 directions × three radii. Weighted
soft dilation minus central alpha yields an exterior light band. Half-texel
clamping excludes neighboring atlas frames; samples outside the selected frame
are zero. It follows holes, protrusions, weapons and any visible source alpha,
including detached opaque marks: it does not semantically distinguish body from
weapon/smoke. There are no fixed Xing Tian points or separate effect textures.

The original portrait is drawn independently with nearest sampling. Fully opaque
source pixels are unchanged. Semi-transparent edge pixels naturally composite
with the light behind them. The glow intentionally expands the final alpha
footprint; source PNGs and their alpha are unchanged. With amount/intensity zero,
or after Clear/full decay, the output is exactly the original portrait.

The 4× inset uses premultiplied-alpha compositing for its transparent SubViewport,
avoiding a second alpha multiply that would darken the halo. Runtime output is
not baked into image sequences. Shader cost is 49 alpha samples per glow pixel;
no hardware/mobile performance claim is made. For many simultaneous actors,
profile on the actual target before integration.

See [QA](QA.md), [asset provenance](assets/README.md), and
[reference methods](THIRD_PARTY_NOTICES.md).
