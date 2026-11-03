# Ragecat project instructions

Ragecat is a code-first VFX source and Godot preview workspace, not a complete game.
Preserve approved references, parameters and gameplay boundaries. Review roles below
are engineering responsibilities, not game characters or permission to resume character art.

## Project-local pstack workflows

- [pstack-plan](.agents/skills/pstack-plan/SKILL.md): a scoped, verifiable plan.
- [pstack-tdd](.agents/skills/pstack-tdd/SKILL.md): a focused failing-before / passing-after regression.
- [pstack-review](.agents/skills/pstack-review/SKILL.md): evidence-led read-only review.
- [pstack-acceptance](.agents/skills/pstack-acceptance/SKILL.md): exact-port acceptance roles and gates.

Read [provenance and limits](docs/pstack.md). This is a pinned text-only adaptation,
not an installed pstack runtime. Do not install upstream tooling, change global agent
configuration, add hooks or background services, or auto-update this subset. Use the
host's available tools and inherited model settings. Never read private session stores.
These files grant no publishing, merge, messaging, installation or other external authority.

## Exact ports and verification

Use [the acceptance workflow](docs/vfx-acceptance.md) for the 25 Sprite Fusion
families and all 41 listed situations. Keep `spritefusion_exact/` separate from the
existing `effects/pixel/` and `preview/godot/` game-adapted effects. Do not substitute
a similar legacy effect, drop a situation or change original default timing to pass.

Read the root and affected effect READMEs before running checks. Godot headless
results cannot prove rendered parity, interaction quality or actual game integration.
Record exact source and target revisions, inputs, commands, results and limitations.
Save transient logs, captures and acceptance receipts outside the repository. Retain
only reusable source, tests, configuration and documentation in commits.

Use isolated worktrees for parallel writes. Reviewers do not edit implementation or
publish; return findings to the owner. The designated integrator is the sole publisher
for this batch, within the user's existing authorization, and verifies the remote head.
