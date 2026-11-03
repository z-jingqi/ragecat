---
name: pstack-tdd
description: Fix Ragecat VFX bugs with a failing-before and passing-after regression check when the user requests TDD or a cheap local test path exists.
---

# Focused regression workflow

Adapted from pstack TDD. Read the project [scope and provenance](../../../docs/pstack.md).

1. Identify intended and actual behavior and the smallest reproducible scenario.
2. Find the nearest existing executable check, using the affected effect’s README.
   Existing effects use `preview/godot/`; exact ports use `spritefusion_exact/godot/`.
   Verify that the named test exists before running it. Prefer actual effect
   state and host APIs over mocks of their implementation.
3. Add the smallest relevant regression case and run it before production changes.
   Confirm the failure is the bug, not a missing engine, parse error or fixture issue.
4. Make the smallest production fix that preserves nearby contracts.
5. Rerun the regression and appropriate nearby checks from the root README.
   Restore temporary test fixtures and avoid unrelated coverage or balancing changes.
6. Report the exact commands, failing-before evidence, passing-after evidence,
   and any unverified interactive/device behavior.

If no practical automated check exists, use the closest repeatable native-preview or game reproduction
and explain the gap. Do not add expensive infrastructure solely to claim TDD.
For visual feel or device input, distinguish a headless state assertion from a
native-preview, game-integration or device check. Never weaken assertions to fit incorrect behavior.

For exact Sprite Fusion ports, also follow [pstack-acceptance](../pstack-acceptance/SKILL.md).
Do not treat a visually similar legacy effect or a game-adapted preset as an exact port.
