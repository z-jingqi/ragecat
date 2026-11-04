# Verification receipts

## Plain arrow, 2026-11-04

- Godot 4.6.3 Standard import and headless scene launch passed.
- `tests/test_arrow.gd`: 18 state, direction, curve tangent/history, configuration
  ownership, clear/replay, finite input and bounded history assertions passed.
- `tests/render_validation.gd`: real Compatibility viewport, 8 directions and
  clear-to-transparent, 9 assertions passed. This is not a headless rendering claim.
- Native 1280×800 MovieWriter capture: 600 frames / 60fps / 10 seconds. Reviewed
  actual frames for right, left, diagonal, tangent-changing curve and stationary.
  Arrow remains 34px at 1× beside 30px static guides; 2× panel shares the same viewport.
- Source-specific references were read, PixelFX tooling was run and four contact
  sheets inspected. Original native Fire/Electrified/Crystals captures were also
  viewed. Local reference material is not part of the deliverable.
- At this milestone no element module is claimed complete. Color, modules and
  parameter resources reserve the later composition interface.

Video frame pacing is a deterministic capture, not proof of real-time 60 fps or
complete-game behavior. Device performance, gameplay and Unity are not tested.

## Fire attachment, 2026-11-04

- Three native render/inspection passes, with first-pass degenerate rounded
  tongue polygons fixed and the final capture free of script/render errors.
- Existing 18 host/state checks passed; native render suite now passes 20
  assertions, including 8 fire directions, body-independent attachment, zero
  intensity yielding zero alpha, and clear-to-transparent.
- Fresh 10-second / 600-frame native recording covers all five trajectory modes.
  Inspected the real 1× and 2× frames; shaft and tip remain identifiable.
- UI presets, enable controls, color picker and full-speed capture share the
  actual components. Fire uses `presets/fire.tres`, not a special recording path.

## Lightning attachment, 2026-11-04

- Three inspectable native passes: first motion capture, 8-direction alpha
  render sweep, refined final motion capture. Final logs contain no errors.
- State suite: 21 assertions, adding arc endpoint preservation, same-seed
  determinism and changed-seed variation.
- Expanded native suite: 59 assertions: default bounds, independent body/element
  controls, zero intensity and transparent tint, custom tint and UI-size stress,
  plus the original directions and clear lifecycle for plain/fire/lightning.
- New 10-second / 600-frame native video; all five trajectories sampled at 1× / 2×.

## Ice and final composition, 2026-11-04

- Native ice render/inspect/refine passes improved shaft frost and crystal
  readability at 1× while retaining the physical arrow. A fresh 10-second /
  600-frame native recording covers right, left, diagonal, curve and stationary.
- Current host suite: 33 assertions, zero failures. Includes deterministic
  stationary seek with explicit axis, 60–1000 Hz sampling and a 1000-second
  clock regression. Timestamp comparisons no longer collapse long-running wakes.
- Current workshop suite: 10 assertions, zero failures. Layer edits preserve
  the other resources, Clear persists through parameter changes and scrub,
  Replay recovers, and curve/diagonal velocities match position derivatives.
- Current real Compatibility render suite: 80 assertions, zero failures. All
  four presets run in 8 directions; custom sizes/colors, alpha-zero, body-off,
  intensity-zero, default bounds and clear-to-transparent are covered.
- Native combination suite: 17 assertions, zero failures. All 8 fire/lightning/ice
  masks render on light and dark backgrounds, repeated same-time renders match,
  and Clear remains clear after control changes.
- Actual native UI interaction verified Fire + Ice, EDIT Ice intensity zero
  leaving Fire visible, pause/scrub, Clear with subsequent edits, light/dark
  background, and Replay. No special capture-only effect renderer is used.
- Independent read-only code review reran the 33 host and 10 workshop assertions.
  Reported issues with per-layer edits, dense history, stationary seeking and
  large-clock comparisons were fixed and rechecked; no blockers remained in
  that scope. The failure harness was also verified to return nonzero when an
  assertion fails (`tests/test_arrow.gd -- --self-test-failure`).

These checks establish an isolated visual component, not whole-game integration.
Native capture used the Compatibility software renderer (llvmpipe). GPU/device
performance and gameplay are not inferred from fixed-step movie output.

## Arrowhead fire revision, 2026-11-04

- Flame roots moved from the shaft to one compact layered mass at the broadhead.
  Rear shaft and fletching remain bare. Default short-fleck lifetime is 0.35×.
- New native 10-second / 600-frame video was inspected at right and curved poses.
- State 33, workshop 10, general native render 80 and composition 17 assertions
  passed. New `render_refinements.gd` adds 88 passing real-render assertions:
  actual preset, 8 directions × 3 times, hard geometry bounded near the tip,
  plus size 3 / length 18 stress without clipping. Lightning-specific checks
  remain opt-in until the next revision.

## Shaft-only lightning revision, 2026-11-04

- One thin shaft arc replaces dense surrounding arcs. Outward branches, wake
  lines and detached particles were removed; an occasional short cross-shaft
  pulse remains. Default trail length is zero and its UI slider is disabled.
- New native 10-second / 600-frame recording covers all five trajectories.
  Inspected right and diagonal frames at actual 1× and nearest 2× scale.
- State 33, workshop 11, native render 80 and native composition 17 assertions
  passed. `render_refinements.gd -- --lightning` passed 200 assertions, including
  head/shaft-local bounds for 8 directions × 3 times, exact image equality with
  lightning trail length 0 versus 2, and resource size 3 / short-arrow stress.
- These revisions change only fire/lightning modules, their presets, relevant
  UI control state and validation/docs. Ice geometry is unchanged.
