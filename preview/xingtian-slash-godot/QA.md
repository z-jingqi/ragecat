# Xing Tian slash verification

Implementation baseline: Ragecat `8aa4d417` (fetched main). Only this standalone
preview directory is changed; no game or SpriteFusion exact-port file is modified.

## Checks completed

- Godot 4.6.3 Standard headless editor import and preview startup: pass.
- `tests/test_slash.gd`: 50 assertions, 0 failures. Includes explicit-contact-only
  blood/sparks, immutable configuration snapshots, independent instances/materials,
  NaN/Infinity/range handling, zero counts/intensity, deterministic analytical
  particles, repeated plays, seek, stop/clear, toggles and UI configuration clamping.
- Native Compatibility OpenGL render probe (`tests/render_probe.gd`): 14 assertions,
  0 failures. Real SubViewport pixels verify zero/onset/peak/tail/end, repeat-frame
  identity, reversed direction, max rotated arc, palette change, zero intensity,
  sparse/default/max blood, and cleared state. No partial alpha on the hard-pixel arc.
- PixelFX pinned official tools: original draft `melee/xingtian-copper` rendered on
  dark and light backgrounds, and `tools/check.mjs` passed (1 effect, 0 warnings).
- Actual native UI clicks: timeline pause/scrub, blood on/off, Clear then scrub,
  Replay, and Mirror. No character animation is present. The mirror check exposed
  a small-panel positioning issue; the arc-only sample is now centered at 1x.
- Independent read-only peer reviewed source, tests, default/Heavy native frames,
  blood readability, host authority and provenance. No runtime/gameplay blocker.
  It found a 0.5x movie-caption mismatch, fixed with a regression test. Slider
  displays now track sanitized thickness at small radii.
- Failing-before / passing-after checks: Clear followed by parameter editing and
  actual-speed captions (50 checks, 2 failures before; 0 after).

## Visual iteration

1. Rendered PixelFX reference heavy-cleave and sword-slash, then the new copper draft;
   inspected all-frame contact sheets and actual Godot first-pass movie.
2. Increased sparse blood travel and palette contrast so it leaves the target silhouette
   after the arc recedes. Preserved 9 drops, 6 sparks and a compact 0.25s arc. Fixed the
   capture viewport at 1280x800 rather than the desktop's clamped window dimensions.
3. Inspected dark/light draft sheets and native frames; fixed inaccurate half-speed
   label, clear-state editing, and mirror-safe isolated panel placement. The new final
   capture uses the current source, not a stale previous preview.

## Boundaries

This is a visual prototype. No gameplay, collision, attack animation, hit-stop,
health state, camera effect, damage or balance changes were made. Neutral geometry
figures are static size references. PixelFX and SpriteFusion are method/code sources,
not an assertion that this new design is an exact-port match.

MovieWriter's 60fps is a fixed presentation timebase, not measured real-time
performance. The native renderer here is Mesa llvmpipe; hardware/game integration
and exported-device performance were not tested. User visual approval is separate
from these engineering checks. Transient logs, frames and videos stay outside source.
