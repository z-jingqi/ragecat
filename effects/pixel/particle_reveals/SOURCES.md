# Visual references

The actual 8-moment reference strips were downloaded and inspected before implementation:

- [ParticleFX Studio — Character Disintegrate To Dust](https://particlefx.studio/effects/character-disintegrate-to-dust): source-colored body pixels peel into a wind field, then cool; sparse edge embers reinforce the transition. Its HD reference is 2.7 seconds and uses 1983 source particles plus embers.
- [ParticleFX Studio — Character Materialize](https://particlefx.studio/effects/character-materialize): individual source-image particles collect into a recognizable character silhouette. The reference includes additional glow/ring layers; those are not necessary for this reusable crisp pixel transition.

This implementation independently builds source-pixel records and reversible analytic trajectories in GDScript. No source code, character sprite, texture, generated export or animation frames from either site are included in the repository. The reference image downloads remain QA research outside the repository. Their hosted runtime/export availability is not treated as an open-source license for the site.

The Godot preview uses an original procedural character and gem to demonstrate general image inputs. All production motion is code-generated; no reference sprite sheet is used.
