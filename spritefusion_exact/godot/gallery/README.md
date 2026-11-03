# Standalone Godot gallery

F5 runs this menu. Only existing effect scenes are shown; the count is installed
families out of the 25-source catalog, not a claim that missing families passed.
Enter or click opens a scene. Esc returns here through a small navigation node.
Scene replacement invokes each preview's normal cleanup. No effect parameters,
random generators, update methods or pixel buffers are changed by the menu.

The initial editor import is required for Godot's global script-class index.
The navigation regression also checks that effects created live native instances,
not only that a scene file was opened. Run it after import:

    godot --headless --path spritefusion_exact/godot --script res://gallery/test_navigation.gd

Acceptance: independent read-only source review and fresh imported-checkout
navigation passed; the strengthened test passes 11 checks. A real Compatibility
window showed the four currently released scenes, readable buttons and footer.
Enter opened Explosion and Esc returned; clicking Pickup and returning also
worked. The manual check was stopped with Ctrl+C, not counted as an automated
exit-code 0 test. Effect-specific numerical/native proofs remain separate.

Keyboard scrolling is explicitly enabled on the ScrollContainer. A regression
with real Down/Up key events and bounded 7- and 25-entry UI fixtures checks that
the focused final button becomes fully visible and Up returns to the first
button at scroll zero. Before the fix, focus stopped at a clipped sixth button.
Run `godot --headless --path spritefusion_exact/godot --script res://gallery/test_keyboard_scroll.gd`
for all 12 checks. This UI-only fixture does not instantiate unshipped effects.

All eight first-group effect families also have a standalone reuse regression:
`godot --headless --path spritefusion_exact/godot --script res://tests/common/test_group_one_lifecycle.gd`.
It reconfigures each instance at the same seed, compares the resulting color and
light buffers, and disposes twice. It is a bounded lifecycle check, not a full
parameter-space or live-performance test.
