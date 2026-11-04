# Body-state preview verification

Baseline: Ragecat `9eeba59c423455ee80f83ace434fc5eca783c37b`.
Scope: new `preview/xingtian-body-godot/` only. No gameplay, other VFX, exact-port
reference data or comparison captures are included in this change.

## Source and visual process

- Inspected actual approved 1904×2544 portrait and aligned original seam geometry
  on a 238×318 coordinate grid. Copied PNG byte-identically; SHA-256 is recorded
  in `assets/README.md`.
- Called SpriteFusion Power Up MCP and read real source. Read pinned Patch
  PixelFX status helpers/rage/haste and authoring methods. Deliberately excluded
  their stock actor, ground effects, poses, free aura and gameplay behavior.
- Rendered original PixelFX seam timing study: 361 frames, official check passed
  (one effect, zero failures or warnings). It is a timing/shape draft, not an
  exact comparison to this Godot shader or the source portrait.
- First actual Godot render inspected at 20/45/70/100%. Then refined the too-even
  seam cores with restrained static variation and three short fracture branches.
  A separate read-only reviewer inspected source and native stills; no blocking
  design finding. Fixed reported invalid-start/clock-overflow and misleading
  manual-clock label edge cases.

## Automated and native evidence

- Final headless lifecycle/configuration/preview suite: **118 checks, 0 failures**.
  Includes stable clear, explicit restart, independent material/configuration,
  backward seek, nonfinite values, very large clocks, and monotonic demo envelope.
- Final native Compatibility pixel probe: **20 checks, 0 failures**. Zero amount,
  zero intensity, cleared and completed-decay output equal the original renderer
  exactly. Alpha is unchanged at 20/45/70/100%, with no outside-silhouette pixels
  or changed pixels outside the upper-body region. Changed coverage increases
  from 1,520 → 4,564 → 7,378 → 9,291 pixels in the 476×636 probe.
- Same external time repeats exactly; full-state flow changes pixels over time;
  disabling flow and breathing produces identical images across time.
- Native final 1280×800 still inspected after the refined seam branches and core
  variation. White cloth and lower body remain clean; full-state detail stays
  within the chest/shoulder/forearm panel.

- Actual pointer interaction checked Full, Pause, manual 64%, Clear followed by
  amount/intensity/timeline edits, explicit Full restart, flow off, both backgrounds
  and normal window close. Clear kept the unmodified portrait throughout edits.
  Bright-background label contrast was improved, tested headlessly and rechecked
  in a second actual native window.
- Final MovieWriter capture: **780 frames / 13 seconds / 1280×800 / 60fps**, exit 0.
  MP4 transcode verified to retain dimensions, frame count and duration. Inspected
  full-state and decayed movie frames; no script/shader errors. The later UI-only
  bright-background label fix does not alter this default dark-background capture.

Headless state checks do not certify visual quality. Native checks render actual
Compatibility viewport pixels against an original-texture-only baseline.

## Limits

Static portrait only, no pose/attack animation or actual game integration.
The original head flame and forearm fire are still pixels of the supplied PNG.
Its top crop is pre-existing; no art reconstruction was attempted.

Native renderer is Mesa llvmpipe Compatibility, not a hardware-GPU/device test.
MovieWriter fixed 60fps is a presentation timeline, not a real-time performance
measurement. The approved image has binary alpha; arbitrary translucent images
were not tested. The component's coordinate paths are Xing-Tian-specific.

User visual approval remains separate. Transient native captures, comparison
images, logs, movie files and receipts are kept outside the repository.
