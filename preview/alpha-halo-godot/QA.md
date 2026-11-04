# Verification · 2026-11-04

Based on Ragecat main `ac7c55e6a60d3be07d61ef89faabf0bcfeacc47d`.
The prior body study is untouched. Only a standalone new alpha-halo preview and
its approved character fixtures are added; no Mountains & Seas gameplay changes.

## Executed

- Godot 4.6.3 Standard, Compatibility; fresh headless editor import: exit 0.
- Headless API/state test: **124 checks, 0 failures**. Covers sanitized resources,
  invalid input, large clocks, source regions/AtlasTexture resolution, per-instance
  state, clear/restart, and accumulation/decay envelope.
- Actual native render probe on Mesa llvmpipe: **47 checks, 0 failures**. These
  are real rendered pixels, not headless rendering assertions.
- Both unchanged approved portraits rendered at 76 logical pixels. Exterior
  pixel counts at full state: Xing Tian 786, Hou Yi 978 (alpha > .01). Fully
  opaque source pixels have zero differences. Halo alpha energy increases at
  25/50/100% state. At zero/full decay/Clear, the source is restored exactly.
- Native checks also exercise tight texture boundaries, transparent neighboring
  atlas cell exclusion, live AtlasTexture frame changes, same-instance image
  replacement versus a fresh node, partial alpha, flips, translation, scaling,
  zero intensity, width expansion, alternate color, and parent alpha modulation.
- Native comparison UI reviewed on arena-dark and light fields. A first-pass
  inset compositing defect (double alpha multiply) was corrected with premultiplied
  blending, then all native checks repeated against final code.
- Actual controls clicked: Full and Pause, zero/restored intensity, maximum and
  reduced width, hex color change to cyan, BG, Decay, Clear then amount/width/
  timeline edits without resurrection, explicit restart, manual amount, movement
  toggle, Reset. Reset restored red/default width/dark field and replay. Normal
  window close completed without project errors or leaked-resource warnings.
- Native Godot MovieWriter: 780 frames, 1280×800, 60 fps, 13 seconds, exit 0.
  MP4 conversion preserves those dimensions/frame count/rate. Full-state and
  fully decayed MP4 frames were inspected after encoding. Capture uses the
  default restrained red profile, not the maximum-width interactive test.
- Independent read-only code/document review found no correctness blockers.
  This was a second agent on the inherited model, not a multi-model panel.

Evidence logs, native screenshots, test receipts, AVI and MP4 are outside the
repository. No transient capture, comparison dataset or generated frame sequence
is committed.

## Boundaries

This proves standalone native behavior and appearance at the stated logical
size. It is not a gameplay integration, an attack-speed implementation, a
hardware/mobile performance benchmark, a Unity port, or user visual approval.
The native environment uses a software renderer and another permitted recording
was running concurrently, so its timings are not performance claims. Hou Yi is
shown at 76 px for shape comparison although the current game uses 64 px.

The tested animation path swaps textures and atlas frames on the same component;
no skeletal animation rig or third-party packed/rotated atlas integration has
been validated. See README for supported frame types and clipping margins.
