# Verification

- 1046 controller assertions: valid/invalid host size, deterministic replay, seed variation, 30/60/144 Hz completion, once-only signal, bounds, 1000 reset cycles, zero-host independent mode, invalid delta handling.
- 8 demo assertions: waiting, activation, cancellation staying restored, replay after cancellation, reset controls, presets, two-view configuration parity.
- Preset JSON parity and headless scene startup passed.
- Actual native Godot preview: game-size creature, original-speed dissolve, parameter change, pause, reset and cancel/restored snapshot inspected.
- Actual GPU viewport proof with debris disabled: opaque/partial-alpha body pixels decrease **805 → 695 → 185 → 0 → 0** at ready/0.06s/0.12s/0.20s/completion. No output appears outside the original alpha, including interior holes. Fractional alpha is retained exactly, not squared or faded. Reset matches original rendering exactly; horizontal flip matches mirrored alpha.
- Directional thresholds use source-pixel centers; the standalone burst is rasterized to source-pixel cells, not a high-resolution smooth polygon.
- Preview recording: actual Godot MovieWriter frames, 640×360, 60 fps, 12 s; original speed with 1× game size and 3× nearest detail, upward/sideways/bright-background/standalone cases. This is engine-rendered fixed-time video, not a fabricated sprite animation.

The creature is demonstration geometry, not final production monster art. Input host uses a captured death pose; live animation extraction and gameplay death/reward logic belong to the caller. No target Unity runtime is included in this stage.
