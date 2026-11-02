# VFX-19 checks

- Component and preview script: 7311 assertions pass for deterministic seeded raster/geometry, analytical 30/60/144 Hz image parity, canvas margins, parameter limits, intensity and layer disable controls, cancellation/reuse, one completion event and independent overlap.
- Four presets exercise size, angle, palette, duration and reduced intensity.
- Native Godot preview reviewed at logical 1× and nearest 2×: star silhouette, sparse retracting fragments, light background, clear then frame-step, reset and low-brightness three-hit overlap.
- Recorded 900 actual Godot-rendered frames at 60 Hz: 15 seconds, four presets/backgrounds followed by staggered overlapping impacts. Rendering logs contain no script/runtime errors.
- Pixel source files and captured preview use the same component and lab scripts.
