# Verification

2026-11-05, Godot 4.6.3 stable, Compatibility renderer, native Linux X11 Mesa llvmpipe.
Base main: `7f98a66b9b733bdc1b99a39828f08f947bde7fa0`. Source and evidence are separate:
logs, PNGs and videos are outside the repository; no binary output is committed.

## Earth milestone

- Import and startup: passed.
- test_radial: 31 assertions passed. Seed replay, actual radial ordering, local stagger,
  profile isolation/sanitization, arbitrary-time seek, single sparse ring, lifecycle and 50 clear/replay cycles.
- test_workshop: 20 assertions passed. All 10 sliders, pause, clear, replay, seed, reset,
  background toggle and seek-after-completion/clear.
- render_radial --element=earth: 13 native assertions passed. Transparent before/after,
  outward growth at 0.18/0.43/0.70s, native pixel-coverage budget, default bounds,
  replay/seek equality, clear, and 120Hz-update versus direct-seek rendering.
- Native interactive inspection: 1× and 2×, sequential layers and character depth,
  time scrub, pause/resume, clear and replay inspected in the actual Godot window.
- First rendered pass exceeded the chosen 12,000-pixel default coverage budget. Spacing
  was opened from 28 to 32px and stone width reduced from 10–15 to 9–13px. The same
  unchanged coverage assertion passed on the final pass.
- Separate read-only engineering review found two completion/seek defects. Added regressions
  first (31 checks, 2 failures), fixed stale configuration and repeated terminal transitions,
  then reran to 31/31 passing. This review is not independent rendered-visual approval.
- Recorded actual Godot MovieWriter: 12 seconds, 1280×850, 60fps, dark and light fields.

No full-game, Unity, target-device performance or user visual acceptance is claimed.
The 60fps recording is fixed-step offline capture, not a real-time performance guarantee.
The existing Sprite Fusion 25/41 parity inventory is unchanged and not re-certified by this work.

## Ice milestone

- Added independent ice renderer and immutable source preset; earth implementation remains unchanged.
- Core: 33/33; workshop: 20/20; native ice rendering: 13/13 assertions passed.
- Native frames and 12-second MovieWriter capture inspected at 1×/2×, dark/light fields.
- Clear crystalline silhouette differs from opaque fractured earth. No triangulation errors in native log.
- Stateless renderer was separately smoke-tested over negative, rising, holding, fading and expired ages.
- This remains an original proposal awaiting user visual feedback, not reference-image parity.

## Lightning milestone and final regression

- Added third independent preset and stateless electrical renderer. Element values 0/1/2 select
  earth/ice/lightning. Renderer loading is now resource-relative for reusable component copies.
- Core: 35/35; workshop: 20/20 passed on final code.
- Final native regression: earth 13/13, ice 13/13, lightning 13/13 passed.
- Lightning native lifecycle: 6/6 passed. Across 48 samples, one site had 18 dark frames,
  30 lit frames and 28 frame changes. Tests also prove exact reverse seek, ground-off,
  sparse-spark-off and full palette-alpha behavior.
- The initial single-time spark assertion sampled a frame with no emitted spark. Replaced it
  with an actual 24-frame emission window, retaining the requirement that zero density removes
  observed spark events. No renderer change was needed for that test-fixture issue.
- Rechecked the two earlier lifecycle findings through a separate read-only review; both fixed.
  That review independently ran core/workshop tests and found no additional actionable issues.
- Native interaction: switched Earth → Ice → Lightning, scrubbed timeline, inspected bright
  and dark fields. Three presets retain their own timing and palette; lightning uses Bolt size label.
- Lightning recorded as actual Godot MovieWriter 12s/60fps/1280×850 and inspected at 1×/2×.
- Total final focused checks: 100 assertions (35 core + 20 workshop + 39 native + 6 electrical).

## Overlapping outward wave revision

Base main: `e350eaf10420b9f289b54dbbba2c7130106991eb`. The earlier milestone results above
describe the original longer-lived effects, not the revised default timing below.

- User feedback required each layer to appear and disappear independently, with the next
  growing while the previous is still fading. Replaced fixed onset spacing with an explicit
  fade-overlap window and optional extra layer delay; shortened all three preset lifecycles.
- The focused regression failed before the change: 15 checks, 9 failures. Afterwards it
  passes 24/24, proving fade/growth overlap, a maximum of two live adjacent layers, independently
  configurable overlap/delay, and safe non-finite fallback clamping for all three presets.
- Final headless import passed. Core 35/35 and workshop 22/22 passed, including the new
  slow-playback control and actual-site phase labels at a fading/growing handoff.
- Native overlap check: 12/12 passed. At eight consecutive samples per handoff, both layers
  have actual rendered pixels in 8/8 samples for earth and ice; lightning has 4/8 and 8/8
  because electrical pulses intentionally include dark gaps. The inner layer is fully gone
  while the third grows, and all effects are transparent at the end.
- Native baseline regression: earth 13/13, ice 13/13, lightning 13/13 passed.
- Electrical lifecycle 6/6 passed: 17 dark samples, 31 lit samples, 32 frame changes. The
  48-sample fixture now uses 120Hz to observe the shorter live pulse, rather than mostly
  sampling its expired tail; the original assertions and thresholds are retained.
- Independent read-only review found no remaining blocking issue. It reran 81 headless
  checks and additionally checked 300 element/seed cases with 900 timing assertions. A
  non-finite fallback clamping issue found during review was fixed and given a regression.
- Total focused final checks: 138 (35 core + 22 workshop + 24 overlap + 39 native + 12 handoff
  pixel checks + 6 electrical). Separate seed-review assertions are not included in this total.
- The shared scheduling change and all presets are released atomically to avoid mixed old/new
  timing. No gameplay, character art, imported assets or third-party license changes.

Native recordings show 16 seconds per element: 6 seconds at 1×, followed by 10 seconds at
0.35×, with a bright field during the last 4 seconds. The phase row reports each ring's
actual site state. Videos are fixed-step native MovieWriter captures, not fabricated frame
assemblies or real-time hardware-performance measurements. User visual acceptance and full
game integration remain unverified.

## Fast impact, residue, four elements and range shapes

Base main: d59add0480bf6abee9d6e172771510d3cb93d63a. The previous sections describe earlier
iterations. This revision uses the user's approved method references rather than claiming exact
Sprite Fusion parity or pre-approved new visuals.

- Focused before check recorded six expected failures: missing residue/shape controls, slow rise,
  and a lifetime too short for persistent debris. The new profile supplies these capabilities.
- Four headless suites passed: core 39, workshop 65, overlap 32 and geometry 5348 assertions.
- Geometry tests include footprint containment, deterministic replay, radius bounds, sector wrap
  and 360-degree equivalence, default three lanes, explicit absolute headings, mirror direction,
  six-band small footprints and budgets. All samples use the same geometry as the displayed guide.
- Independent read-only review found two defects before release: short lanes put all bands at the
  same endpoint, and the 980px physical window still used an 850px logical viewport. Both were fixed;
  new regression assertions cover small footprints and every control rectangle inside the viewport.
- Native Compatibility rendering passed: all four elemental baselines 13/13 each; overlapping
  handoffs 16/16; residue and all 12 element/shape combinations 46/46; electrical lifecycle 8/8.
- Residue pixel checks prove a low grounded silhouette, steady presence after 2.3 seconds,
  fading near expiry, no pixels after expiry, repeatable reverse seek, configurable size,
  density 0/lifetime 0 behavior and full palette-alpha handling for both earth and ice.
- Lightning's old single ground-opacity sample fell in its deliberate dark gap. Replaced the
  fixture with a 24-sample arrival window rather than weakening the renderer. Final native event
  has 7 dark samples, 41 lit samples and 41 frame changes; ground/spark disabling, three visibly different directions, main/secondary hierarchy and reverse seek pass.
- Native interaction verified the bottom controls are accessible; changing rectangle width and
  heading changes both sampled sites and the same projected range guide.
- Total focused checks: 5606 (5484 headless plus 122 native). Independent additional 180 lifecycle
  checks are separate. No target-device, Unity, full-game or real-time performance claim.

Native MovieWriter previews are 24 seconds each, 1280×980, 60fps: circle, sector and three lanes
at normal speed for 6 seconds each, then a bright-field circle at 0.35× for 6 seconds. Long solid
residue is shown at normal speed; the final slow segment makes growth-to-collapse handoff visible.
Logs and binary captures remain outside the repository. Existing licenses remain unchanged.
