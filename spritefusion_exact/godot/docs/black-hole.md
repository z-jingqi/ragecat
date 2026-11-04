# Black Hole: native Godot reconstruction

Open the Godot project and run `scenes/effects/black-hole.tscn`. This separate
scene leaves the other effect previews and game scenes unchanged. It preserves
the original effect options, fixed 60 Hz simulation ticks, single-frame
back → actor → front ordering, and light-before-color presentation. Screen
flash, shake and darken callbacks are recorded but are not applied by this host;
the preview footer discloses that limit.

The lens is implemented procedurally in GDScript. It materializes the original
snapshot, reproduces ordered ring geometry, image filtering, antialiased clip
coverage and byte compositing, then applies the two original radial fills.
It does not use a browser, JavaScript runtime, prerecorded animation or stored
reference pixels. High-precision fused float operations are reconstructed in
native GDScript; lower-precision image stages retain their separate arithmetic.

The scene uses an opaque 640×400 sRGB background. The lens host's
`set_source_rgba(bytes, width, height)` must receive the current scene before
`present(lens)`, followed by effect light/color layers. The supplied scene uses
a fixed synthetic background and actor. The restricted raster helpers reject
unsupported transforms or bounds rather than silently approximating them.

The original effect buffers, state callbacks and lifecycle were compared against
the archived TypeScript. The complete lens was independently checked at six fixed
payload/background combinations, plus two disabled-background controls, in Godot
4.6.3 Compatibility rendering: every compared byte matched. These are bounded
cases, not a proof for every possible parameter, graphics driver or platform.
The local reference datasets and diagnostic captures are not runtime dependencies
and are intentionally not distributed with this code-first release.

This implementation prioritizes exact rendering and is computationally expensive.
The fixed simulation step does not imply real-time 60 FPS. Real-time performance
work is separate from this reconstruction.

The original TypeScript remains archived separately with its MIT attribution.
Skia-derived raster helpers retain their BSD-3-Clause terms and notices in
`licenses/SKIA_LICENSE.txt` and `licenses/SKIA_NOTICE.txt`. The Chromium
geometry-dispatch notice is accompanied by `licenses/CHROMIUM_LICENSE.txt`.
