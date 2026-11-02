# Verification

- 1222 controller assertions: valid/invalid host size, deterministic replay, seed variation, 30/60/144 Hz completion, once-only signal, bounds, 1000 reset cycles, zero-host independent mode, invalid delta handling, ground hold, expiry, world anchoring, teleport/reset cleanup, residue disable/bounds and callback reset, source-pixel birth, exact ballistic landing and retained particle identity.
- 8 demo assertions: waiting, activation, cancellation staying restored, replay after cancellation, reset controls, presets, two-view configuration parity.
- Preset JSON parity and headless scene startup passed.
- Actual native Godot preview: game-size creature, original-speed dissolve, parameter change, pause, reset and cancel/restored snapshot inspected.
- Actual GPU viewport proof with debris disabled: opaque/partial-alpha body pixels decrease a strictly decreasing count ending in zero at ready/0.06s/0.12s/0.20s/completion. No output appears outside the original alpha, including interior holes. Fractional alpha is retained exactly, not squared or faded. Reset matches original rendering exactly; horizontal flip matches mirrored alpha.
- Directional thresholds use source-pixel centers; the standalone burst is rasterized to source-pixel cells, not a high-resolution smooth polygon.
- Preview recording: actual Godot MovieWriter frames, 640×360, 60 fps, 17.2 s; original speed with 1× game size and 3× nearest detail, upward/sideways/bright-background/standalone/residue-disabled cases. This is engine-rendered fixed-time video, not a fabricated sprite animation.

The creature is demonstration geometry, not final production monster art. Input host uses a captured death pose; live animation extraction and gameplay death/reward logic belong to the caller. No target Unity runtime is included in this stage.

Ground revision: the default body/airborne phase remains 0.38 seconds, followed by a configurable 3-second ground hold. The normal-speed preview includes the full hold and cleanup, not a shortened substitute.

The ground-specific GPU probe verifies occupied pixels are confined to the feet strip. After the short color cooling step, the ground patch is byte-identical two seconds later, then empty after its deadline.

Continuity revision replaces the separate spawned patch with retained IDs from the actual falling fragments. Source release times match the shader dissolve threshold; each chip reaches exactly the same point used for its grounded state.

Final continuity checks: 32 GPU source-release assertions confirm sampled host pixels are present just before their release threshold and absent just after it. The normal-speed transition has no empty frame: body-plus-fragment occupancy decreases from 805 pixels to 20 grounded pixels over the measured sequence. All 1032 preview frames preserve exact 1×→3× nearest-neighbor body-region correspondence.
