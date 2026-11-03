extends Node
const GALLERY = "res://gallery/main.tscn"

func _unhandled_key_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		var current = get_tree().current_scene
		if current != null and current.scene_file_path != GALLERY:
			get_viewport().set_input_as_handled()
			get_tree().change_scene_to_file(GALLERY)
