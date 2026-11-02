# Algorithm

Gameplay and decoration have independent clocks. Due gameplay index `n` is delivered when `n * tick_interval <= age`; start index is 1. Capture the generation number at tick entry; after each signal return, abort if stop/play changed it. Resolve weak candidates at event time, sample positions, and compare squared distance with squared world radius. No game damage logic or target discovery is owned here.

Visual geometry is a pure function of seed, arc slot and age. For each recent slot and each staggered emitter, choose two disk positions and build a correlated-displacement polyline with fixed endpoints. Subordinate short forks and terminal sparks are clipped to the visual disk. Each curve remains stable for its short lifetime; its three layers dim/shorten in discrete stages instead of rerolling every rendered frame. Only recent slots are evaluated; <=35 arcs, 8 main points +3 fork points each, regardless of duration. Drawing uses integer pixel rectangles along sampled line segments, ensuring repeatable raster density. The displayed 2× preview samples the same low-resolution render texture, not enlarged geometry.

At duration or stop all geometry/references are released; the area has no lingering damaging tail. Callers may layer a separate expiry puff if desired.
