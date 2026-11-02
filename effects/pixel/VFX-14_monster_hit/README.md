# VFX-14 · Monster hit feedback

A per-monster composition of small non-emissive procedural blood flecks and the existing **VFX-05 host flash**. VFX-04 and VFX-05 are unchanged. Contact position and host appearance are independent inputs. No recoil, health, targeting, movement, or damage is implemented.

## Godot preview

Open `preview/godot/effects/VFX-14_monster_hit/monster_hit.tscn`. The first row is actual 1× size, the second is exact nearest 2×. A and B respond independently with different flash colors; the other four remain untouched except in Crowd mode. Controls demonstrate body/contact separation, moving targets, semitransparent hosts, pause/step/reset and background contrast. The fixture textures are original procedural test monsters, not game art.

## Integration

Create one `monster_hit.gd` controller per Sprite2D and call `bind(sprite)`. Keep the controller in an unscaled world-effects layer, not as a child of the moving monster. Call `hit(world_contact, incoming)` where incoming uses VFX-04's mathematical XY convention (+Y up). The controller converts the world point into its local effects coordinates; it does not move particles after impact when the monster moves.

`tick(seconds)` is automatic unless `auto_tick=false`. Pause using `paused`. `clear()` cancels both layers and restores the original host material. Rebinding restores the previous host. Host deletion clears its active effects. Only the controller's own temporary material is restored; an externally replaced material is not overwritten. The original material is temporarily replaced while flashing, so arbitrary custom shader animation cannot be composed automatically. Bind one controller per host and coordinate material ownership with other host effects.

Every host gets its own ShaderMaterial. Texture alpha, self-modulate, transform, flip and original material are not modified by the controller. Up to four contact players are recycled per host; a fifth overlapping hit replaces the oldest slot. Repeated hits do not restart an active body flash; a default 0.18s minimum flash interval prevents rapid retrigger flicker. Particle hits remain independent. No additive blending or cumulative brightness is used.

## Configuration

`configure(dictionary)` applies settings to subsequent hits (flash color/peak also affects an active flash on the next tick).

| Key | Default | Range / meaning |
|---|---|---|
| `peak` | 0.20 | 0–0.8 RGB color mix; not opacity |
| `duration` | 0.11 s | 0.02–0.5 s |
| `hold` | 0.008 s | 0–0.08 s, capped at half duration |
| `color` | pale ivory | HTML RGB flash color |
| `flash_enabled` | true | Body feedback switch |
| `impact_enabled` | true | Independent contact feedback switch |
| `flash_interval` | 0.18 s | 0–1 s minimum interval, active flashes never restart |
| `impact` | blood dictionary | Independent particle parameters below |

The impact preset is replaced, not merged, when supplied; omitted fields use blood defaults: `color="b83e50"`, `count=5` (0–16), `distance=14` pixels (0–40), `life=0.24` seconds (0.06–0.8), `spread_degrees=75` (0–180), `direction_degrees=180` offset relative to incoming direction, `seed=23`. Flecks are 1–2px, fall slightly and shrink away. Emission seeds advance per hit and reset on clear. No gore or persistent decal. Changing configuration does not retrospectively change already emitted particles. A seed belongs to the contact preset; host flashing is deterministic and needs no fake random seed.

## Reference study

[ParticleFX Hit Flash](https://particlefx.studio/effects/hit-flash), including its downloaded eight-time image strip, was viewed before implementation. The relevant idea is independent local blood/drop movement and short host-wide color response, not a screen flash. Its pictured red glow and long 1.4s demo loop were not copied. The present effect substitutes tiny non-glowing blood flecks and a lower alpha-preserving color mix; the reference's additive sparks and white peaks are deliberately omitted for crowded combat. No third-party sprites, runtime source or frames are shipped.

## Validation

- `godot --headless --path preview/godot --script res://effects/VFX-14_monster_hit/test_monster_hit.gd`
- GPU/normal renderer: `godot --path preview/godot --script res://effects/VFX-14_monster_hit/test_render.gd`
- Tests cover independent materials/colors, fixed contact coordinates, pause, reset, rebind, external material replacement, destroyed hosts, capacity, 1000 repeats and 30/60/144Hz completion.
- Render probe compares exact alpha, the unaffected neighbor, and full RGBA restoration after completion/cancellation.

Unity runtime code is not part of this prototype. Its composition contract is engine-neutral; an eventual engine adapter can reuse the blood motion parameters and flash definitions.
