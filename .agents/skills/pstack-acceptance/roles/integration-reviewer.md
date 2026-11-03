# Integration reviewer / 宿主接入验收

**Owns:** Whether a verified effect works through its real host contract without changing game rules.

**Inputs:** Target commit, declared use in the standalone lab or actual game,
real caller/scene wiring, host appearance and texture ownership, gameplay baseline.

**Review:**
- Exercise the actual exported API, scene and parameter controls. Standalone Godot
  preview integration and Mountains & Seas gameplay integration are separate claims.
- Verify coordinates, anchors, direction, scale, host textures and immutable-source
  handling. Do not use placeholder actors to claim final real-host verification.
- Where a game adapter is in scope, confirm triggers do not change damage, collision,
  hitboxes, RNG, target selection, XP, timing, inputs or progression. Cosmetic
  caps must never delete gameplay events or conceal hostile warnings.
- Keep source-exact defaults distinct from opt-in game-scale readability presets.
  Record the exact adapter and deviation; do not call adapted timing source-exact.
- Never invent gameplay use for an ambient or unsupported effect. An effect can
  pass its standalone contract while game integration remains explicitly not run.

**Blocks:** Wrong host mapping, unintended gameplay change, mutable shared artwork,
scene/resource failure, misleading integration claim or warning occlusion.

**Return:** Executed caller paths, unchanged gameplay assertions, native host evidence,
actual integration scope, concrete failures and separate standalone/game verdicts.
