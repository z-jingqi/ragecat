extends SceneTree
# UI-only bounded list fixture; it never opens a dummy effect or changes source pixels.
var checks := 0
var failures := 0
func require(value, label):
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _initialize(): call_deferred("run")
func press(key):
	var event = InputEventKey.new()
	event.keycode = key
	event.pressed = true
	root.push_input(event)
	event = InputEventKey.new()
	event.keycode = key
	event.pressed = false
	root.push_input(event)
	for i in range(2): await process_frame
func run():
	for count in [7, 25]:
		change_scene_to_file("res://gallery/main.tscn")
		for i in range(5): await process_frame
		var scroll = current_scene.get_child(0).get_child(0).get_child(2)
		var list = scroll.get_child(0)
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
		for i in range(count):
			var button = Button.new()
			button.text = "UI fixture %02d" % i
			button.custom_minimum_size.y = 36
			list.add_child(button)
		list.get_child(0).grab_focus()
		for i in range(5): await process_frame
		for i in range(count - 1): await press(KEY_DOWN)
		var focused = root.gui_get_focus_owner()
		require(focused == list.get_child(count - 1), "Down reaches final entry in %d-item list" % count)
		require(scroll.get_global_rect().encloses(focused.get_global_rect()), "Final focused entry fully visible")
		require(scroll.scroll_vertical > 0, "Long list actually scrolls")
		for i in range(count - 1): await press(KEY_UP)
		focused = root.gui_get_focus_owner()
		require(focused == list.get_child(0), "Up returns to first entry")
		require(scroll.get_global_rect().encloses(focused.get_global_rect()), "First entry fully visible")
		require(scroll.scroll_vertical == 0, "Scroll returns to top")
	print("PASS" if failures == 0 else "FAIL", " gallery keyboard scroll ", checks, " checks / ", failures, " failures")
	quit(0 if failures == 0 else 1)
