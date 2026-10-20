# Passive-upgrade expansion QA — 2026-10-20

## Delivered behavior

20 passive upgrades, all maximum level 3. New upgrades are impact splitting, stronger knockback and Long Draw. Exactly three bow-exclusive traits are Rapid Volley (existing burst), Fan of Fangs (existing scatter) and Long Draw (range + projectile speed). No other weapon, active skill, stamina or progression system was added. Toxic Precision now has three useful ranks: +35/+70/+100 percentage points against an already-poisoned enemy.

Impact fragments use 30/45/60% of the originating arrow's pre-critical direct damage, including a side arrow's 55% modifier. They spawn at the true swept collision point, inherit traveled distance, exclude the triggering enemy without consuming their one hit, and cannot crit, pierce, split recursively, spread poison or trigger bleeding sustain. They can apply poison/bleed. Original arrow and fragment budgets are independently 128 each, so fragments cannot crowd out a normal bow volley. At the cap a whole fan/pair is skipped rather than partially spawned; queued deletion immediately releases capacity. No total-range reset or repeated pierce decay was introduced.

## Differentiated test → fix → regression groups

1. **Restored baseline and mechanism implementation.** Restored the previously delivered Verified source instead of modifying the older environment snapshot; all 622 previous checks passed before edits. Added the new resource/stat/proc paths and physical-collision tests. Review identified maximum-speed burst scheduling could overwrite a pending final shot due to discarded frame residuals; preserve residual timing and finish queued volleys before starting another. Tests verify four shots at 60 Hz, 30 Hz and 0.01-second steps.
2. **Upgrade menu and rank progression.** Tested all 20 upgrades at each of their three levels through actual card signals, 24 seeded distinct eligible three-card offers, prerequisites, max-rank exclusion, mastered-build continuation and idempotent stat resets. Initial UI tests exposed missing visible category tags. Fixed category display and enabled wrapping for long card descriptions; the catalog/UI suite then passed. Old single-rank Toxic Precision assertions were updated to the explicitly requested three-rank design, not silently removed.
3. **Collision, proc and resource-limit interactions.** 91 focused assertions pass: physical impact point, oblique/large-step remaining range, endpoint expiration, exclusion vs successful-hit identity, one-hit nonrecursive fragments, no critical/spread/sustain leakage, additive poison-critical thresholds, real knockback at every rank and Boss immunity, independent projectile capacity and immediate capacity reuse. One test fixture initially used an intentionally knockback-immune dummy; corrected the fixture to a normal enemy rather than changing correct gameplay.
4. **Full mixed-build stress.** Controlled fixture, not normal difficulty: all upgrades at rank 3, 48 stationary high-health targets, actual bow/projectile/status callbacks with automatic gameplay ticking disabled. Each of 60 Hz, 30 Hz and 0.07-second steps advances exactly 30 game seconds. Results: 7,153 / 7,153 / 6,531 hits; primary projectile peaks 40 / 41 / 34 and fragment peaks 31 / 31 / 31. Every-frame range and budget assertions pass; different coarse-step timing is not claimed to be numerically identical.
5. **Normal progression and desktop GUI.** See results below. No repeated test group is presented as another playthrough merely to inflate the round count.

## Normal engine-driven progression

Actual engine callbacks and movement/dash actions, actual offered Button selections, global and arena RNG seeded, no granted ranks, invulnerability, HP manipulation or manual director advancement. Stop at death or 240 game seconds. Fixed-fps headless execution is accelerated, so game time is not wall-clock human playtime. Steering has perfect state access: these are integration tests, not a difficulty/balance certificate.

| Strategy / seed | Game time | Level / kills | Final HP | Boss kills |
|---|---:|---:|---:|---:|
| Bow / 7319 | 240 s | 10 / 224 | 82.4 | 1 |
| Split-status priority / 38117 | 240 s | 10 / 231 | 100 | 1 |
| Mobility-defense / 91073 | 240 s | 9 / 165 | 10 | 1 |
| Supplemental split-priority / 10891 | 240 s | 9 / 186 | 60 | 1 |

All four runs passed invariants. Long Draw and knockback were genuinely offered and selected in the first three. Split was not selected in those runs, so exactly one supplementary predetermined-seed run was added: at 69.65 game seconds it naturally selected Split, then generated 738 fragments with 209 actual secondary hit events; live primary/secondary peaks were 8/9. No rank was granted or seed repeatedly searched. Complete offered-card text and picks are recorded in UPGRADE_NORMAL_RUNS.json.

## Desktop checks

Frozen production-source copy, manifest hash 10cb5453bcbcaeda26815c77d50a88848941b1149ca2dbc6f70a67ebb682b9ce. Actual GUI confirmed impact splitting, separate volley vs fan visuals, maximum rank staying at 3, and Long Draw shooting a distant target. Exact 30% values and collision/proc arithmetic are established by deterministic tests, not by visual timing. Normal upgrade-card GUI passed: at 00:23 active game time the genuine level-2 offer showed Long Draw [1/3] [BOW EXCLUSIVE], its full +10/20/30% description and 0→10% preview without clipping; Zoomies and Bubble Guard were also readable. Selecting Long Draw resumed normal movement/shooting through 00:31, level 2, 16 kills, followed by menu/quit. Manually trying to increase Split, Heavy Tips and Long Draw beyond 3 kept them at 3. The log contains only known unavailable-ALSA/VSync environment warnings, with no script or gameplay errors. Screenshots were visible in the GUI session, but no persisted screenshot files are claimed.

## Commands and verification limits

From project root, with writable HOME/XDG directories in restricted environments:

```sh
bash tests/run_all.sh
godot --headless --fixed-fps 60 --script tests/upgrade_mix_stress.gd
godot --headless --fixed-fps 60 --script tests/upgrade_normal_runs.gd
godot --headless --fixed-fps 60 --script tests/upgrade_normal_runs.gd -- --strategy=split_status --seed=10891
```

The full runner passes with no Godot ERROR or SCRIPT ERROR, including original lifecycle, dash, shield, invulnerability, Boss, death/reset and first-pierce-only/range regressions plus new catalog and split suites. Independent read-only code review and reruns of both new focused suites found no reproducible blocking issue.

Normal runs did not reach natural death or saturate projectile capacity; deterministic tests cover lifecycle/death and capacity edges. No claim of exhaustive testing, long-term balance, performance profiling or platform export verification. Source delivery is through GitHub after approval of these results; no ZIP is produced. Previous exported binaries do not contain this upgrade expansion. Previous-cycle QA remains in QA_REPORT.md and is historical evidence, not a claim that those old screenshots depict the new upgrades.
