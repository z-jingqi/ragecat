# Externally owned war and revival visuals

`hero_state.gd` composes the existing Ragecat elite aura and healing component. It is a visual adapter, not a passive/health implementation. It adds no host animation or character art and never reads or writes health, damage, movement, cooldowns, resources, kills, equipment or death state.

Copy these portable dependencies together, preserving the relative folders:

- `VFX-16_elite_aura/hero_state.gd`
- `VFX-16_elite_aura/aura.gd`
- `VFX-20_shield_heal/support.gd`

## API

- `set_war(active, world_anchor, urgent=false)` follows an authoritative active state at the supplied world foot point. True starts/follows the subdued warm aura. False clears the aura immediately. Repeated true calls do not restart its entrance. Urgency changes the accent palette, not timing or stats.
- `revive(world_anchor, event_id)` starts one 0.58-second healing cue only after the game's actual successful revival. Use that run's increasing revive counter as the integer event ID. Duplicate or older IDs are ignored even after the cue ends. A new revival clears war; entering war clears any old revival cue.
- `tick(dt)` is the only clock. Neither child is automatically processed. `set_paused(true)` freezes time and follow updates. `clear()` cancels both components immediately and resets the event ID and pause for reuse.

Call `set_war` before `tick`. For Xing Tian, a foot offset near `(0, 15)` matches the existing 17-pixel body. Place the component below the actual player and hostile warnings, under the same arena clipping layer. The quantitative war meter and existing invulnerability arc remain caller-drawn and unchanged. Revival is a finite cue anchored at the actual revival point; it does not chase the player or imply ongoing regeneration.

The wrapper allocates exactly two children once. War uses six analytic mote slots, no per-frame nodes. Revival has ten mote slots and two tiny crosses with one-pixel arms. Warm side filaments and a foot halo leave the body center clear; the short return cue uses the established subdued green heal family.

The only change to the canonical aura is `externally_sustained=false` by default. Opting in keeps the aura alive until the caller ends it, so it cannot incorrectly expire at a visual preset's sustain duration. Ordinary aura play/stop behavior remains unchanged.

## Reference and checks

Inspected the actual public eight-moment [Pixel Art Aura](https://particlefx.studio/effects/pixel-art-aura) and [Heal](https://particlefx.studio/effects/heal) strips and native canonical Ragecat previews. This adapter reuses Ragecat's already-written procedural modules rather than copying those assets or adding dense pillars/large icons.

Run `test_hero_state.gd` for persistent state beyond its old visual timer, world-to-local anchors, urgent palette, pause, duplicate events, 30/60/144 Hz return completion, cancellation and 1,000 reuse cycles. `test_aura.gd` verifies canonical default lifecycle regression. `test_hero_state_render.gd` separately checks visible native pixels, clear body center, pixel-identical pause, immediate cancellation and complete finite return cleanup.

Run `hero_state_preview.tscn` for the geometry-host preview. The circular fixture repeats the existing Mountains body/face/facing geometry, not a new character. Its ghosts copy only the body silhouette and detached facing marker; the live host keeps its eyes and gameplay indicator arcs. Preview updates split a frame at the real dash endpoint, capture its last moving segment before `stop()`, then age the tail for any remaining time. Demo motion and synthetic events exist only in the preview, never in the reusable modules. Pause, Replay and Clear are available. A headless test is not a claim of visual acceptance.
