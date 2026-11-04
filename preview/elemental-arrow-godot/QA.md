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

## Lightning amplitude refinement, 2026-11-04

- Base revision: `9a784dffc50747c65eb402eba408be0e87e7e4ce`. At the
  previous default, many core vertices rounded onto the shaft. Added a native
  cyan/white-core lower-bound regression before changing production code:
  224 assertions, 24 failed for insufficient 1× excursion, process exit 1.
- One nine-point shaft arc now has three alternating, seeded bends at a default
  4.2–5.0 px peak offset; attachment size scales that amplitude. Endpoints remain
  on the shaft. No additional branches, emitters or historical tail were added.
- After: 36 headless state assertions, 11 workshop assertions, 224 native
  refinement assertions, 80 native general-render assertions and 17 native
  composition assertions passed. The new gate requires at least 6 px normal
  span in the bright core across 8 directions × 3 times, excludes sheath/glow,
  and retains shaft-local limits plus trail-length 0/2 image equality.
- New actual Godot MovieWriter capture: 600 frames / 10 seconds / 1280×800.
  Reviewed right and diagonal 1×/2× frames; the zigzag is distinguishable from
  the physical shaft. Recording also includes left, curve and stationary paths.
- Independent read-only review found no blocker and cross-checked 1,800
  length/size/frame-seed combinations. Fire/ice modules and presets are unchanged.
- Fixed-step software-rendered capture is not a target-device performance claim.

## Current revision: transient branching crackle, 2026-11-04

- Base `4fcebcbe` was a regular full-shaft path. The new effect instead uses
  several independently phased 65–110 ms events, 30 Hz random midpoint shape
  changes and occasional explicit attached micro-forks. Cores stay 1 px.
- A new native temporal regression was run before implementation: 5 assertions,
  1 failure because the old effect changed only 12 of 59 frame transitions.
  Current 60-frame isolated render changes 59 transitions, has 6 count variants,
  averages 2.217 distinct bright components and has multiple components in
  46/60 frames. Pixel components alone are not treated as independent emitters.
- State tests separately verify actual independent IDs, short local paths,
  expiry within 120 ms, random-seed behavior, same-time determinism, density,
  amplitude, no-tail parameters and geometry re-strikes within a surviving
  event. Mean default population is 2.494 arcs across 180 samples, with multiple
  arcs in 131 samples and 234 attached forks over that sequence.
- Final passes: 33 host state, 12 workshop wiring, 15 crackle state, 7 native
  temporal/no-history/zero-density, 200 native bounds/refinements, 80 native
  general render and 17 native composition assertions. No failures.
- The old requirement for one continuous arc spanning at least 6 px every frame
  was replaced by the new temporal/multiplicity tests; short events may blink
  out independently. Shaft-local bounds and trail-length 0/2 equality remain.
- Native pixel equality proves identical current lightning at the same pose/time
  after different straight/curved histories. Density zero yields a transparent
  attachment, including its glow. No trailing geometry or detached particles.
- Actual UI verified density zero, density restoration, amplitude changes and
  light/dark backgrounds. Arc density replaces the unused lightning Wake control;
  fire/ice retain their Wake controls and do not read the added density field.
- Fresh Godot MovieWriter recording: 600 frames / 10 seconds / 1280×800, covering
  right, left, diagonal, curve and stationary. Inspected real 1×/2× views.
  Fire/ice render modules and presets are unchanged. Reference methods were
  re-read and a read-only review found no runtime/API blocker.

This remains an isolated visual preview, not whole-game or device-performance QA.

## Current experiment: head-to-tail helical lightning, 2026-11-04

Base `f1c7393` is retained as the selectable CRACKLE mode; its module is copied
byte-for-byte. The new SPIRAL default has two independently seeded complete
strands, each reaching within 1 px of both arrow ends. Its original helix carrier
uses sine projection and cosine depth, with shared zero-depth crossing points.
Rear halves render behind the body, front halves in front, with 1 px cores.

- Before implementation, the focused three-assertion helix test failed two
  shape requirements on the previous micro-arcs. A review then caught an early
  shortened endpoint band. Tightening the tests produced 37 failures across 53
  assertions before correcting the carrier endpoints; those checks now pass.
- Final headless passes: 33 host state, 16 workshop controls, 15 preserved crackle
  state and 54 helix state assertions. Helix tests check every strand separately,
  including 18/34/64 px lengths, resource width/size extremes, full span, continuous
  depth joins, independent phases, seed determinism, amplitude/density, mode
  restoration and zero intensity. A 30 Hz boundary test uses two-microsecond
  sample separation and requires >0.25 px geometry jumps, excluding smooth
  rotation alone as proof of electrical re-strikes.
- Final native passes: 79 helix, 200 bounds/refinements, 80 general render,
  17 composition and 7 preserved crackle assertions. Total: 501, no failures.
  The new native sequence changes on 59/59 frame transitions, checks full-length
  restrained 1x extent over 60 samples, and verifies 324 rear-arc/body pixel
  intersections are correctly occluded across eight directions. The actual
  component matches the diagnostic front/body/back render byte-for-byte.
- Current-pose images match after different straight/curved flight histories.
  Density zero is fully transparent. Updated axial render bounds reflect the
  explicitly requested head-to-tail coverage, allowing only raster-width
  overshoot around the arrow ends, never a historical tail.
- Native interactive checks: SPIRAL → CRACKLE → SPIRAL restoration at the same
  time, increased amplitude on light background, density zero and restoration,
  resumed motion. Recorded and inspected 1x/2x right, left, diagonal, curved and
  stationary views, with dark/light element combinations.
- Fresh MovieWriter capture: 600 frames, 10 seconds, 1280x800. Final code matches
  the capture. Fire, ice, body modules and preset resources are unchanged.
  Read-only review found no remaining blocker after the endpoint correction.

Commands are listed in README. Logs, PNGs and video remain outside the repository.
This is native preview QA on Godot 4.6.3 Compatibility / software rendering, not
whole-game integration, real target-device performance, or user visual acceptance.

## Current experiment: phase-locked double helix, 2026-11-04

The new default DOUBLE mode has exactly two head-to-tail strands with shared
pitch, radius, rotation speed and a half-turn phase difference. Mirrored jagged
midpoints preserve the paired silhouette while re-striking at 30 Hz. Opposite
cosine depth makes their front/back halves alternate around the arrow body.
The independent SPIRAL module is a byte-identical copy from base `7c7f0d1`;
CRACKLE and mode indices 0/1 remain available without changes.

- Before implementation, the focused three-assertion double-helix test failed
  two shape requirements on the independent spirals. Final headless passes:
  33 host state, 20 workshop controls, 15 crackle, 54 original spiral and 19
  double-helix assertions. The paired checks cover all 120 time samples,
  equal axial coordinates, opposite offsets/depth, full length, parameter
  extremes, continuous depth joins, deterministic seeds, amplitude, visibility,
  zero intensity and actual 30 Hz discontinuities rather than rotation alone.
- Final native passes: 79 double helix, 79 preserved original spiral, 200
  refinements/bounds, 80 general render, 17 compositions and 7 crackle. Total:
  603 assertions with no failures. Double and original spiral each change on
  59/59 frame transitions. Eight-direction occlusion checks cover 334 rear/body
  pixel intersections for Double and 324 for the preserved Spiral; actual host
  rendering matches the diagnostic front/body/back composite byte-for-byte.
- Native current-pose equality after distinct flight histories, transparent
  zero visibility, restrained 1x axial bounds and all eight dark/light element
  combinations pass. No historical tail or free-flying particles are added.
- Interactive native checks verify Double/Spiral switching at a fixed time,
  restored original density 1.5 after switching back, amplitude changes on a
  light background, and zero visibility leaving only the plain arrow. Double's
  control is labelled Arc visibility and cannot alter the two-strand count;
  Spiral/Crackle retain Arc density. Automated workshop tests also verify Clear
  and switching preserve time, other layers and stored original density.
- Fresh Godot MovieWriter capture: 600 frames, 10 seconds, 1280x800, covering
  right, left, diagonal, curved and stationary motion. Actual 1x/2x frames were
  inspected. Video code matches the final source. Fire, ice, body, crackle and
  preset resources are unchanged. Read-only review found no remaining blocker.

Logs, PNGs and video remain outside the repository. This is native preview QA
on Godot 4.6.3 Compatibility / software rendering, not whole-game integration,
real target-device performance, or user visual acceptance.
