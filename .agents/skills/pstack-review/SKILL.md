---
name: pstack-review
description: Review a Ragecat VFX diff or specified game systems for evidenced correctness, design and verification issues. Return findings without automatically applying them.
---

# Evidence-led review

Adapted from pstack Interrogate and its review references. Read the project
[scope and provenance](../../../docs/pstack.md).

## Scope and intent

Identify the requested files or diff and the intended player-visible behavior.
Do not assume `main` exists or review unrelated work. Read callers, scene wiring,
resource definitions and tests needed to judge the change.

## Review

Use only applicable lenses:
- Correctness: trace concrete execution paths, state transitions, boundaries,
  pause/resume, restart, scene lifetime, signal connections and resource ownership.
- Root cause: distinguish a repaired contract from a guard that masks a defect.
- Structure: keep data and game rules in their canonical systems. Prefer clear
  state models over scattered conditionals, without inventing unnecessary layers.
- Verification: do checks exercise behavior, and is the actual interaction tested?
  Mark gaps in visual, device and performance evidence rather than fabricating it.
- Complexity: identify unnecessary abstractions, duplication and obsolete paths,
  but do not turn taste or hypothetical future requirements into blockers.
- Security where relevant: show a reachable input-to-effect path for a concern.

When independent review is useful and available, delegate bounded read-only reviews
with identical intent and scope. Explicitly forbid file edits and mutating commands.
Inherit model settings unless the user separately requests supported alternatives.
Disclose whether review used independent agents, multiple models, or a single pass;
multiple agents on one model are not a multi-model panel.

## Synthesis

Each finding needs severity, file/line or symbol, a concrete failure path, supporting
evidence and optional minimal correction. Deduplicate findings and investigate
disagreement. Independent agreement is a signal, not proof; a lone correctness
or security finding still deserves scrutiny.

Classify findings as act on, consider, noted, or dismissed, with rationale. Reject
unreachable hypotheticals and preference-only objections. No findings is valid.
Return intent, scope, review method, prioritized findings and remaining verification
gaps. Do not automatically apply changes or approve/merge a pull request.

For exact Sprite Fusion ports, also follow [pstack-acceptance](../pstack-acceptance/SKILL.md).
Do not treat a visually similar legacy effect or a game-adapted preset as an exact port.
