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
