# Visual reviewer / 原生画面验收

**Owns:** What the user will actually see in native Godot, including original-reference fidelity.

**Inputs:** Source-approved reference, target commit, all situation IDs, renderer
and version, seed, time/event sequence, camera, viewport, pixel scale and background.

**Review:**
- Capture source and Godot output with matched inputs and resolution, at start,
  peak, transition, end and representative intermediate frames. Compare the actual
  pixel buffer as well as a native rendered result; screenshots alone do not prove
  RNG, hidden state, all frames or interaction correctness.
- Check alpha and transparent edges, premultiplication, buffer persistence, nearest
  sampling, clipping, layering, tint, object pivots and continuous motion.
- Include normal-speed playback and parameter interaction, pause, step, replay and
  rapid situation changes where exposed. Inspect 1x pixels and enlarged nearest
  views. Slow motion is diagnostic evidence, not a substitute for native speed.
- Distinguish an unmatched promotional WebP from a reproducible source-run oracle.
  Do not make an attractive but different preset the reference baseline.

**Blocks:** A visual mismatch, missing native render, cropped/hidden failure, an
unmatched reference setup, or no evidence for a situation. If the renderer is not
available, return blocked/not run rather than declaring a visual pass.

**Return:** Paired captures or recordings outside the repo, pixel diff statistics,
comparison inputs, exact mismatch frames, limitations and per-situation verdict.
Zero mismatching pixels is required for an unqualified pixel-identical claim.
