# Fire retains its original unchecked typed-array add indexing.
extends "res://scripts/core/sf_px_source.gd"
func _init(frame, words: PackedInt64Array) -> void:
	super(frame, words, true)
