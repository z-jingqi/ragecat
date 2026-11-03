# Validation

Tested 2026-11-03 with Godot 4.6.3.

## Focused contracts

`test_frost_ring.gd`: **46 checks passed**. Coverage includes exact origin/radius,
default 180 ms timing, art-grid conversion, isolated materials/clocks, no automatic
clock, pause, seek, expiry, stop/replay/reset, invalid bounds/options, caller-data
immutability, equivalent 30/60/120 Hz clocks, bounded reuse and global/local RNG
isolation. Existing reusable slash tests (18 checks) and existing ice tests (1055
checks) also pass. Preview import and headless startup have no script errors.
These focused checks are not a full-workspace integration suite.

## Native render review

`render_probe.gd`: **65 checks passed** on native Godot Compatibility / Mesa
llvmpipe OpenGL. Covers actual 100/120/140-unit radii at 20/75/120/160/180 ms,
per-pixel radius clipping, full reach, pause/reseek image identity, canvas transform
registration, immediate stop and radius-1 visibility. Fifteen transparent lifecycle
captures were produced outside the repository. An initial radius-1 test exposed
undersampling; adapting the minimum art-grid resolution fixed it before publication.

Actual 20/75/120/160 ms images were inspected: one crisp cyan/white ring, short
inward facets, sparse flecks and an open center; the ring breaks into cooling
fragments and clears, without a persistent field or overshooting the damage circle.
The native preview shows all three game sizes with a four-frame lifecycle strip.

The display reports an unsupported V-Sync-mode warning; it does not affect these
pixel assertions. These software-renderer checks do not establish target-hardware
performance or user artistic acceptance. No game damage, slow/freeze behavior or
balance is changed. The actual game port and its integration tests are separate.
