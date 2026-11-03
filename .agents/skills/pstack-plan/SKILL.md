---
name: pstack-plan
description: Plan substantial Ragecat VFX effect, preview or architecture changes as small verifiable steps before implementation. Use for an implementation plan, not a request to build immediately.
---

# Project planning

Adapted from pstack's multi-phase planning playbook. Read the project
[scope and provenance](../../../docs/pstack.md).

1. Read the relevant source algorithms, scenes, scripts, resources, tests and effect notes.
   Separate implemented behavior from proposed mechanics and unknowns.
2. State the player's observable outcome, the data/state model, constraints and
   explicit non-goals. Preserve the approved reference and default parameters. Ask about unresolved product choices; do not
   silently decide them by coding a preferred design.
3. Compare approaches only where the choice matters. Investigate factual unknowns
   read-only first. Prototypes or implementation require scope that allows changes.
4. Break the work into independently verifiable steps. For each, name the files
   or systems, dependencies, behavior change, acceptance check, and evidence to save.
   Use the smallest useful plan rather than a mandatory fleet of agents or PRs.
5. Include headless checks and a native Godot preview scenario where behavior is interactive.
   Add a performance measurement only for a relevant risk, with a comparable
   baseline. Never invent test results or claim headless checks prove game feel.
6. Return the plan, alternatives and unresolved decisions. A planning request ends
   with the plan; it does not authorize implementation, scheduling, or publishing.

If the user asks to save the plan, use the requested path or a descriptive file
under `docs/`. Do not create global configuration or hidden orchestration stores.
For a small obvious edit, explain that a separate plan is unnecessary.

For exact Sprite Fusion ports, also follow [pstack-acceptance](../pstack-acceptance/SKILL.md).
Do not treat a visually similar legacy effect or a game-adapted preset as an exact port.
