# Archer projectile

Original projectile presentation, using the Archer's existing stored cedar arrow mesh, serving and three-dimensional feather vanes. A new faceted forged steel head and wrapped socket complete the projectile. No external assets or plugins are required.

Rebuild using Blender 4.3 or later from the project root:

    blender -b --disable-autoexec -t 4 -P source/art/projectiles/bow/build_arrow.py -- --archer source/art/characters/archer/archer.blend --output /tmp/arrow-render

Copy only arrow_base.png and arrow_accent.png into assets/projectiles/bow. The editable projectile_arrow.blend is the neutral model with lighting and transparent orthographic camera. The accent mask covers metal and feathers, never the wood shaft. The rendered canvas is 160 by 48 pixels, displayed at 40 by 12. Actual tip is approximately +14.5 game pixels, tail -20.5, within the prior projectile silhouette; collision remains the logical circular sweep, not the sprite or trail.

ArrowVisualDefinition references the existing damage feedback palette. Tint overlays preserve the underlying silver and feather value structure, and dark uses a configurable deeper base mixed with that palette. No new gameplay elemental effects are introduced.

ArrowPresentation samples existing global positions at physics cadence, converts them back to local draw space, and draws a capped tapered ribbon. All nodes, samples and reserved visual budget die with the parent arrow. It never changes velocity, damage, RNG, fire cadence, range or hit detection. Secondary and gravity arrows reduce only their cosmetic trail. Trail ownership is bounded independently of gameplay projectile limits.
