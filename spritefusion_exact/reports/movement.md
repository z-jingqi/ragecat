# Movement: Dash and Blink acceptance

Run `godot --path spritefusion_exact/godot res://previews/group_one/movement.tscn`
after editor import. Left/right selects Dash or Blink, Space pauses and R replays.
The synthetic host responds to the original movement/visibility cues. The source
API remains configurable; no game movement system is silently substituted.

- Both modes at baseline and stress inputs: 398 frames and 1,592 separate
  back/front color/light hashes match TypeScript, with exact actor coordinates,
  visibility-related hooks and done timing.
- Independent actual Compatibility comparison: 26/26 rendered states match
  the independent shared-Frame compositor and replayed source cues. Checks cover
  Dash displacement, Blink disappearance and reappearance at source x420,
  historical silhouettes and completed states.
- The fresh two-mode native video is 10.0167 seconds at 960×684. Actual mode
  frames and the complete two-line footer were visually inspected.

Reproduce saved fixtures with
`python spritefusion_exact/tools/test_effect.py movement`.
[movement.json](movement.json) records the finite test coverage. Sampled WebP/PNG
files come from verified combined CPU frames, separate from the native movie.

The source silhouette is caller-provided; this demo uses original synthetic
fixture art, not website artwork. Full website-scene identity is not claimed.
Finite verified inputs do not prove every parameter combination. Native capture
used Mesa llvmpipe Compatibility and fixed-frame MovieWriter, not a real-time
FPS or physical-GPU benchmark.
