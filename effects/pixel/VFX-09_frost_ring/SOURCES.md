# Reference review and provenance

Reviewed 2026-11-03. The Frost Ring implementation is new procedural code, with no
third-party code or image asset copied into this folder.

- [mrsir8433: Distortion/Shockwave Shader, 2022](https://godotshaders.com/shader/distortion/).
  Reviewed its published annular mask and externally animated radius interface.
  Its screen-reading, chromatic-aberration presentation is deliberately not used:
  Frost Ring needs local world registration, hard pixel colors and a literal
  damage circle. The page marks code CC0 but excludes its images/videos from that
  code license. No visual asset was downloaded or redistributed.
- [Godot CanvasItem shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html).
  Verified local UV/vertex behavior, normal alpha blending, parent modulation and
  that built-in TIME does not stop with scene pause. This renderer uses only its
  caller's age uniform and retains normal CanvasItem transform/modulation.
- [Godot CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html).
  Reviewed inherited transforms and visibility for a reusable world-space child.
- Existing Ragecat `VFX-09_ice/ice.gdshader` and its algorithm notes were inspected
  for the accepted restrained cyan facets, deterministic breakup and pixel-grid
  convention. Its line of standing crystals is not an annulus and is not reused.
- Existing Ragecat reusable slash runtime was inspected for the two-file adapter
  boundary and external simulation clock expected by Mountains and Seas.

The older signed-distance reference URL at Inigo Quilez returned HTTP403 during
this review and is not claimed as inspected. No asset pack was installed, no new
license agreement accepted, and no image-generation assets or spritesheets are used.
