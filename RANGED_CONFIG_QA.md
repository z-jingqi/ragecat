# Ranged enemy and parameter audit

## Baseline and scope

All production scripts, resources, scenes and tests were byte-verified using Git blob hashes against GitHub main `c351faf4dea50095a5dec6a6d6cd277c445a8a6d` before editing. Six screenshot/image-import artifacts differed or were absent locally; no production source was stale. No binaries or ZIP delivery are part of this change.

## Parameter audit

| Area | Editable source | Runtime consumers |
|---|---|---|
| Character health, movement, dash, collision, immunity/feedback | CharacterDefinition and CombatDefinition via cat.tres | CombatStats snapshot, CatPlayer, HealthState |
| Bow damage, cadence, arrow dimensions/speed/range, spawn offset and budgets | BowDefinition via bow.tres | CombatStats, BowController, CatArrow |
| All 20 rank-0..3 upgrade values and secondary knobs | Individual UpgradeDefinition resources | CombatStats, UpgradeCatalog descriptions/previews, practice and normal upgrade UI |
| Poison/bleed duration and ticks, crit, regen, shield, pierce, split/fan/burst | CombatDefinition and corresponding upgrade arrays/properties | StatusEffects, CombatRules, health and projectile consumers |
| Enemy HP/radius/speed/feedback | EnemyActor exported properties; spawn HP in ArenaDefinition | EnemyActor and RageArena |
| Boss warning, charge, recovery, rocks, damage, seed, placement, aftermath | BossActor/RockWarning exports; three arena defaults in ArenaDefinition | Boss state machine and practice slider defaults |
| Spawn cadence, bounded difficulty, boss timing, XP and pickups, population/object caps, bounds and practice arrangements | ArenaDefinition | RunDirector, RageArena and main/practice UI |
| Ranged body/retreat and complete shot data | RangedDefinition | RangedEnemy and independent EnemyBullet snapshots |

Gameplay numbers in CombatStats and numeric card descriptions are no longer separate hidden tables. Configuration is validated before runtime consumption, definitions remain independent of mutable run state, and repeated rank changes rebuild rather than compound.

### Intentional remaining numeric literals

This is not a claim of zero numeric literals. Zero/one identities, percentage conversion, circle geometry, half-width calculations, enum/edge indexes, and rank-3 design bounds remain code structure. Named numerical tolerances and bounded boss search/work limits protect algorithms. The standalone boss initializer sets defaults of inherited exported fields without overriding scene/arena values later. Decorative polygon vertices, eye/wing geometry, UI spacing/font sizes and art colors are visual implementation details; gameplay collision radii, feedback timing and ranged colors are editable. The supported normal menu is limited to three upgrade choices rather than exposing an overflowing 20-card layout.

## New behavior and default balance

Ranged enemies never pursue: idle at distance, retreat with 220/280px hysteresis, clamp at walls. A 0.4s warning locks direction before each nonhoming single bullet. Defaults preserve the approved HP ratio60%, range520 and 2s shot cadence. Projectile damage8, speed240, radius6, max travel620 are editable. Shot contact is swept to prevent tunneling; contact consumes even when shared immunity/dash blocks damage. Shooter death cancels pending warnings but leaves fired bullets; clear/reset/run death removes them. Paused/slow/AI-disabled behavior is covered separately.

Population pressure was checked, not assumed. An initial 30s/20%/cap8 trial killed three automated builds at 76–123 game seconds. A paired no-ranged control reached 240s for all three. The final lighter 45s/12%/cap4 replacement population also reached 240s for all three, with 9–15 ranged spawned and 70–121 hostile shots per run. It does not add spawn events or increase existing difficulty curves. These are state-aware automated observations, not a human difficulty guarantee.

## Validation

Godot 4.6.3 official. Existing regression suites are retained without weakening assertions. Added suites cover ranged decisions, warning locking, death, shield/iframe/dash contact, custom projectile range/speed/damage, AI-off, cleanup, cap, custom spawn/XP/health settings, independent runs, actual SceneTree pause/time scale, boss config mutation, and combat/config/UI mutation.

`tests/ranged_normal_runs.gd` derives from the prior input-only normal harness and adds ranged/bullet population observations. It uses actual engine callbacks, movement/dash inputs, and clicks only offered upgrade buttons, with no HP/rank grants or manual gameplay ticks. Command: `godot --headless --fixed-fps 60 --script tests/ranged_normal_runs.gd -- --output=/absolute/results.json`. Fixed 60fps advances normal engine game time faster than wall time for bounded tests; three seeds use distinct build priorities and stop at death or 240 game seconds. Results: `RANGED_NORMAL_RUNS.json`.

### Final automated results

- `tests/run_all.sh`: 9,609 numbered assertions plus the stress scenario, all passing, zero Godot/script errors.
- New configuration suites: combat/UI 240, boss 147, ranged/world/UI 42.
- Original regression assertions remain intact, including upgrade catalog 8,464 and split bow 91.
- Final frozen-source mixed normal run: 1,226,179 repeated invariant checks, all passing. All three seeds reached 240 game seconds; each defeated one boss. Ranged live peak4, hostile-bullet peak4–6 (budget128).
- Paired control without ranged: all three seeds reached240s. Stored separately as `RANGED_CONTROL_RUNS.json`; it is a test-only configuration, not the delivered default.
- Final implementation source manifest SHA256: `db18ffa054d480031f8f3758255f151ea6fae802d5b3a05df8534a02df97f562` (132 source/resource/scene/test files).

### Desktop GUI observations

The unmodified release candidate was played in normal Endless through 01:06, level3, 43 kills. Three cyan ranged enemies stayed at the arena edge rather than pursuing; orange bullets continued in their fired direction while movement/dash avoided them. Two normal upgrade selections rendered without clipping. These visual observations are separate from the automated assertion counts.

The default practice bow kills the low-HP ranged enemy in roughly two arrows, making sustained retreat and defense observation difficult. A separate, non-release observation fixture changes only bow damage and knockback to zero. It is not the publication source and is not evidence for default damage or difficulty balance. In that observation fixture, the ranged enemy idled at distance, retreated as the player approached, stopped against the arena wall without teleporting, and stayed there instead of pursuing when the player moved away. Yellow straight-line warnings and orange bullets were visible; after the player moved sideways, a fired bullet continued along its old line. With invulnerability off, the shield preset showed BLOCK and shields3→2; after shields were exhausted, bullets produced -8HP feedback. Reset during a paused scene containing active enemy bullets cleared enemies/projectiles and restored HP100 and zero counters. No new gameplay bug was observed. Exact immunity duration remains supported by automated tests, not a millisecond claim from GUI observation.

