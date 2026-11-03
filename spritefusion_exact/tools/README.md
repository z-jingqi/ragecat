# Native Sprite Fusion port tools

The TypeScript parser is an authoring dependency only. The Godot application runs
native GDScript and does not embed, evaluate, or launch JavaScript.

From this directory:

    npm ci --ignore-scripts
    node transpile.cjs ../source/impact.ts ../godot/scripts/effects/impact.gd --native-px

The `--native-px` flag selects the separately byte-tested native rasterizer. Fire
uses its source-specific typed-array indexing behavior. Without this flag, the
source's own Px class is mechanically translated for independent comparison.

The translator retains source-specific palettes, particle state, RNG call order,
fixed-step updates, Bayer dither, back/front draw order, and host callbacks.
Captured mutable variables are stored in shared GDScript dictionaries. Call
`effect.dispose()` after removing an effect: Godot's reference counting does not
collect the closure cycles that JavaScript's tracing garbage collector collects.

`sf_js.gd` implements JavaScript integer coercion, typed arrays, array methods,
truthiness, optional calls, and supported numeric operations. It is ordinary
GDScript, not an interpreter. Native libm functions can differ from V8 by one ULP;
per-effect byte comparisons determine the verified configurations. A generated
file alone is not evidence of equivalence for untested inputs.

`godot/tests/common/run_oracle.gd` replays fixed-60-Hz test fixtures, actor snapshots,
all source host hooks, back/front buffers, explicit stop/collect actions, and
complete done timing. Floating input values are encoded as IEEE-754 binary64 so
JSON parsing cannot alter a test input. Output JSON uses full float precision.
Original source hashes and per-effect reports record the exact coverage.

Additional explicit flags:
- `--direct-members` removes compatibility dispatch only for statically resolved
  native class methods and required dictionary fields. It preserves source
  algorithms and still requires the same per-effect differential test.
- `--v8-trig` calls the separately tested native fdlibm/V8 sin/cos port rather
  than platform libm. This is required for the black-hole alpha-boundary case.
  It does not change atan2, exp, or other math functions.
- `--skip=drawLens` omits the browser Canvas-only black-hole host adapter when a
  separate native Godot lens implementation is used.

`test_effect.py EFFECT --timeout SECONDS` runs both saved fixture suites by
 default, using a writable temporary Godot home. The default per-case timeout is
1,800 seconds so slow exact CPU atmospheric rasters can finish rather than being
mistaken for failures. Timing is not evidence of real-time rendering performance.

## Oracle runner integrity

`test_effect.py` now resolves its output path before assigning HOME/XDG folders.
An explicit `--output` must be absent or empty. A nonempty directory is rejected
without changing prior evidence, so stale frames or summaries cannot pass a new
run. The default still creates a fresh temporary directory automatically.

Editor import keeps both streams in `editor-import.log`; nonzero exit or an
`ERROR:` in either import/runtime stream fails the run. Harmless warnings remain
in the logs. Run `python spritefusion_exact/tools/test_effect_harness.py` for the
12 failure-path and fresh-output regressions using an explicitly fake engine.
These test infrastructure checks are separate from real Godot pixel oracles.
