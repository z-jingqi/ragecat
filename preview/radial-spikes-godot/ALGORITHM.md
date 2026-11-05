# Radial eruption algorithm

1. Sanitize and deep-copy the profile. Seed a local Godot RandomNumberGenerator once per cast.
2. Interpolate each layer radius from inner to outer radius. Choose count from circumference / 32 × density.
3. Rotate each layer independently; jitter angular sectors by at most 24% and radial distance by 3.5px,
   both scaled by irregularity. Random height, width and lean avoid repeated silhouettes.
4. A site's spawn is 0.10 + layer × interval + bounded local delay. The delay is always below
   the layer interval, so outer layers cannot start before the inner layer completes its onset.
5. Project only ground anchors to an ellipse using ground_squash. Keep upward visual height uncompressed.
6. Give each site a local Node2D draw canvas. Nested y-sort compares ground depth with a sibling host actor.
7. Evaluate drawing from site age. Earth uses cubic rise, stable fractured planes and sinking/fading dry grit.
   The stateless evaluation permits exact replay, reverse seeking and delta-independent endpoints.
8. clear() frees generated canvases immediately. Completion hides the expired geometry and emits once;
   subsequent play or seek before the end begins a fresh completion interval. The host frees the root node.

No per-frame random calls, particle history, camera shake, bloom, physics, damage or animation atlases.
