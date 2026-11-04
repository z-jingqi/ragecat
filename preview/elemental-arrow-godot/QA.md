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

Video frame pacing is a deterministic capture, not proof of real-time60fps or
complete-game behavior. Device performance, gameplay and Unity are not tested.

## Fire attachment, 2026-11-04

- Three native render/inspection passes, with first-pass degenerate rounded
  tongue polygons fixed and the final capture free of script/render errors.
- Existing 18 host/state checks passed; native render suite now passes20
  assertions, including 8 fire directions, body-independent attachment, zero
  intensity yielding zero alpha, and clear-to-transparent.
- Fresh 10second/600frame native recording covers all five trajectory modes.
  Inspected the real 1× and2× frames; shaft and tip remain identifiable.
- UI presets, enable controls, color picker and full-speed capture share the
  actual components. Fire uses `presets/fire.tres`, not a special recording path.
