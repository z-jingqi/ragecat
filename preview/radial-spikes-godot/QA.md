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
