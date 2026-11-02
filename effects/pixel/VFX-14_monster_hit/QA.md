# Verification

- 1026 state / control assertions: independent host materials and colors, static world contact despite host movement, unchanged pose and modulation, pause, completion, body-only/contact-only modes, 1000 repeated hits, four-slot bound, clear/rebind/destroyed-host cleanup, external material ownership, invalid input, and 30/60/144Hz completion.
- 4803 actual-render assertions: exact alpha retention for a half-opacity host including partially transparent texture pixels, unaffected neighboring monster, and exact original RGBA after both natural completion and cancellation. 308 visible host pixels change color.
- Native normal-speed review: Hit A, Hit B / Both, pause, single frame, Alpha, background, reset and movement.
- Fresh 12.0167-second 60fps Godot viewport capture: 721 frames. The 2× panel matches nearest-neighbor enlargement of the actual-size panel pixel-for-pixel across every frame.
- The video demonstrates independent target colors, body-only response, moving hosts with separate contact impacts, semitransparency and light background. No production sprite sheet or Unity runtime was generated.
