# VFX-14 · Monster hit feedback

A per-monster composition of **VFX-04 contact impact** and **VFX-05 host flash**. It deliberately does not introduce another particle renderer or flash shader. Contact position and host appearance are independent inputs. No recoil, health, targeting, movement, or damage is implemented.

## Godot preview

Open `preview/godot/effects/VFX-14_monster_hit/monster_hit.tscn`. The first row is actual 1× size, the second is exact nearest 2×. A and B respond independently with different flash colors; C remains untouched. Controls demonstrate body/contact separation, moving targets, semitransparent hosts, pause/step/reset and background contrast. The fixture textures are original procedural test monsters, not game art.

## Integration

Create one `monster_hit.gd` controller per Sprite2D and call `bind(sprite)`. Keep the controller in an unscaled world-effects layer, not as a child of the moving monster. Call `hit(world_contact, incoming)` where incoming uses VFX-04's mathematical XY convention (+Y up). The controller converts the world point into its local effects coordinates; it does not move particles after impact when the monster moves.

`tick(seconds)` is automatic unless `auto_tick=false`. Pause using `paused`. `clear()` cancels both layers and restores the original host material. Rebinding restores the previous host. Host deletion clears its active effects. Only the controller's own temporary material is restored; an externally replaced material is not overwritten. The original material is temporarily replaced while flashing, so arbitrary custom shader animation cannot be composed automatically. Bind one controller per host and coordinate material ownership with other host effects.

Every host gets its own ShaderMaterial. Texture alpha, self-modulate, transform, flip and original material are not modified by the controller. Up to four contact players are recycled per host; a fifth overlapping hit replaces the oldest slot. A repeated body hit restarts its short flash instead of increasing brightness.

## Configuration

`configure(dictionary)` applies settings to subsequent hits (flash color/peak also affects an active flash on the next tick).

| Key | Default | Range / meaning |
|---|---|---|
| `peak` | 0.46 | 0–0.8 RGB color mix; not opacity |
| `duration` | 0.11 s | 0.02–0.5 s |
| `hold` | 0.018 s | 0–0.08 s, capped at half duration |
| `color` | pale ivory | HTML RGB flash color |
| `flash_enabled` | true | Body feedback switch |
| `impact_enabled` | true | Independent contact feedback switch |
| `impact` | compact VFX-04 preset | Same sanitized VFX-04 settings; size 0.62, core 4px, 4 shards, duration 0.16s |

The impact preset is replaced, not merged, when supplied; omitted fields use VFX-04 defaults. Changing configuration does not retrospectively change already emitted particles. A seed belongs to the contact preset; host flashing is deterministic and needs no fake random seed.

## Reference study

[ParticleFX Hit Flash](https://particlefx.studio/effects/hit-flash), including its downloaded eight-time image strip, was viewed before implementation. The relevant idea is independent local contact spark and short host-wide color response, not a screen flash. Its pictured red glow and long 1.4s demo loop were not copied. The present effect reuses this repository's approved compact impact and moderate alpha-preserving flash. No third-party sprites, runtime source or frames are shipped.

## Validation

- `godot --headless --path preview/godot --script res://effects/VFX-14_monster_hit/test_monster_hit.gd`
- GPU/normal renderer: `godot --path preview/godot --script res://effects/VFX-14_monster_hit/test_render.gd`
- Tests cover independent materials/colors, fixed contact coordinates, pause, reset, rebind, external material replacement, destroyed hosts, capacity, 1000 repeats and 30/60/144Hz completion.
- Render probe compares exact alpha, the unaffected neighbor, and full RGBA restoration after completion/cancellation.

Unity runtime code is not part of this prototype. Its composition contract is engine-neutral; an eventual engine adapter can reuse the existing impact/flash definitions.
