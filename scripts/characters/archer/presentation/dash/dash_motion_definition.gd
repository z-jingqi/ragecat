class_name ArcherDashMotionDefinition
extends Resource
## Authored visual poses. Gameplay dash remains the actor's responsibility.
@export_range(0.0, 1.0) var guard_height_threshold := 0.15
@export var body: ArcherPoseLibrary
@export var guard: ArcherPoseLibrary
@export var normalized_times := PackedFloat32Array([0.0, 0.17, 0.36, 0.56, 0.78, 1.0, 1.1333333, 1.2666667, 1.4])
@export var bobs: Dictionary = {}
@export var gait_entry_phases: Dictionary = {}
@export var guard_move_distances: Dictionary = {}
@export var guard_move_exit_phases: Dictionary = {}

func sample_phase(normalized_time: float) -> float:
	if normalized_times.size() < 2: return 0.0
	var index := 0
	var distance := INF
	for i in normalized_times.size():
		var candidate := absf(normalized_times[i] - normalized_time)
		if candidate < distance:
			distance = candidate
			index = i
	return float(index) / (normalized_times.size() - 1)

func bob_for(clip: StringName, phase: float) -> Vector2:
	var values: PackedVector2Array = bobs.get(clip, PackedVector2Array())
	if values.is_empty(): return Vector2.ZERO
	return values[clampi(int(round(phase * (values.size() - 1))), 0, values.size() - 1)]
