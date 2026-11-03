---
name: pstack-acceptance
description: Coordinate evidence-based acceptance of Ragecat's 25 exact Sprite Fusion Godot ports and all 41 listed situations. Use for acceptance roles, parity review, or release readiness, not to create game characters.
---

# Exact-port acceptance

Read the [workflow and coverage inventory](../../../docs/vfx-acceptance.md) and
[provenance and boundaries](../../../docs/pstack.md). This is a project-specific
addition to the pinned pstack text workflow, not an upstream runtime feature.

1. Freeze source hashes, target commit, all situation IDs and comparison inputs.
2. Assign bounded reviews to the roles below. Use independent reviewers when
   available; otherwise disclose a single-person multi-pass review. Do not claim
   multiple models or independent reviewers merely because role names differ.
3. Keep reviewers read-only except for disposable test/capture output outside the
   checkout. Never execute unfamiliar third-party tooling without required approval.
4. Collect per-situation evidence. Missing source, license, renderer, comparison,
   lifecycle or declared performance evidence is blocked or not run, not a pass.
5. Send concrete findings to the implementation owner. After a fix, rerun affected
   gates at the new revision and trace any reused evidence to unchanged inputs.
6. The acceptance lead reconciles evidence and returns a precise verdict. Passing
   review does not itself authorize pushing, merging, deploying or contacting others.

## Roles

- [Source custodian](roles/source-custodian.md): identity, source coverage and licensing.
- [Algorithm reviewer](roles/algorithm-reviewer.md): exact state, math, RNG and timing.
- [Visual reviewer](roles/visual-reviewer.md): native rendered output and interaction.
- [Integration reviewer](roles/integration-reviewer.md): host and gameplay contracts.
- [Lifecycle reviewer](roles/lifecycle-reviewer.md): pause, reset, termination and cleanup.
- [Performance reviewer](roles/performance-reviewer.md): measured cost and steady state.
- [Acceptance lead](roles/acceptance-lead.md): coverage, disagreements and release verdict.

A role is an assigned review responsibility, not an always-running agent or a grant
of tools, permissions or background scheduling. Capacity may be handled in waves.
