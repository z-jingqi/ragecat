# Muzzle Flash acceptance

Run `godot --path spritefusion_exact/godot res://previews/group_one/muzzle-flash.tscn`
after editor import. Space pauses, R replays and S calls the original stop hook.

- Baseline and stress: 347 frames and 1,388 separate back/front color/light
  hashes match original TypeScript, along with actor state, hooks and done timing.
- Independent real Compatibility comparison: 17/17 rendered states match the
  independent single-Frame compositor. The check replays every source tick and
  covers all nine scheduled shots, host overlap and the tick 292 end state.
- The final native movie is 10.0167 seconds at 960×684. Flash peaks and clean
  tail were visually inspected, as were the complete title and controls.
- Controls occupy a two-line footer outside the unchanged 640×400 effect area.
  The rejected three-line footer clipped its final line; that movie is not
  distributed. The final layout passes real font bounds and a short native clip.

Reproduce saved fixtures with
`python spritefusion_exact/tools/test_effect.py muzzle-flash`.
[The JSON report](muzzle-flash.json) records the finite input coverage. Retained
WebP/PNG illustrations are CPU diagnostic samples, not the viewport movie.

No website host artwork is redistributed. Source hooks remain available without
invented camera/postprocess behavior. Finite verified options are not a proof for
every possible input. Mesa llvmpipe fixed-frame capture is not a real-time FPS
measurement or physical-device performance test.
