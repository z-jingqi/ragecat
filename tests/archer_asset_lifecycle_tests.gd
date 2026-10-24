extends SceneTree
## Run in its own process: never preload or retain the heavy appearance here.
## Weak references prove resource release, not allocator RSS or GPU residency.
const APPEARANCE_PATH := "res://resources/characters/archer/appearance.tres"
const ACTOR_PATH := "res://scenes/characters/archer/archer.tscn"
const CYCLES := 3
const RELEASE_FRAMES := 6
var checks := 0
var failures := 0

class CharacterInstance extends Node2D:
	signal practice_restarted

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures += 1
		push_error("ARCHER ASSET LIFECYCLE: " + label)
	return value

func create_character(scene: PackedScene) -> CharacterInstance:
	var host := CharacterInstance.new()
	host.name = "CharacterInstance"
	host.process_mode = Node.PROCESS_MODE_DISABLED
	var actor := scene.instantiate() as Archer
	check(actor.appearance == null and actor.appearance_path == APPEARANCE_PATH,
		"Instantiating the default scene alone keeps heavy artwork unloaded")
	check(not ResourceLoader.has_cached(APPEARANCE_PATH), "Instantiation without tree entry does not populate appearance cache")
	actor.setup(CharacterDefinition.new().create_stats())
	host.add_child(actor)
	var enemies := Node2D.new()
	var arrows := Node2D.new()
	host.add_child(enemies)
	host.add_child(arrows)
	var bow := BowController.new()
	bow.setup(actor, actor.stats, enemies, arrows, Rect2(0, 0, 1280, 800))
	host.add_child(bow)
	root.add_child(host)
	check(actor.appearance != null and ResourceLoader.has_cached(APPEARANCE_PATH),
		"Real tree entry loads and caches appearance")
	actor.bind_presentation_weapon(bow, host)
	check(actor._presentation != null and actor._presentation.adapter.weapon == bow,
		"Real weapon binding reaches the loaded presentation")
	check(actor._presentation.has_visible_pose(), "Loaded and bound actor displays a valid carry pose")
	return host

func capture_resource(value: Resource, evidence: Dictionary) -> void:
	if value == null or evidence.ids.has(value.get_instance_id()): return
	evidence.ids[value.get_instance_id()] = true
	evidence.resources.append(weakref(value))
	if not value.resource_path.is_empty(): evidence.paths[value.resource_path] = true

func capture_nodes(node: Node, evidence: Dictionary) -> void:
	evidence.nodes.append(weakref(node))
	for child in node.get_children(): capture_nodes(child, evidence)

func release_evidence(host: CharacterInstance) -> Dictionary:
	# This helper's local strong references die before the caller awaits frames.
	var evidence := {"resources": [], "nodes": [], "paths": {}, "ids": {}}
	capture_nodes(host, evidence)
	var actor := host.get_child(0) as Archer
	capture_resource(actor.appearance, evidence)
	capture_resource(actor._presentation.view._pose_material, evidence)
	capture_resource(actor.appearance.dash_motion, evidence)
	capture_resource(actor.appearance.dash_feedback, evidence)
	for library in [actor.appearance.upper, actor.appearance.lower, actor.appearance.dash_motion.body, actor.appearance.dash_motion.guard]:
		capture_resource(library, evidence)
		for frames in [library.colors, library.depths]:
			capture_resource(frames, evidence)
			for clip in frames.get_animation_names():
				for index in range(frames.get_frame_count(clip)):
					var texture: Texture2D = frames.get_frame_texture(clip, index)
					capture_resource(texture, evidence)
					if texture is AtlasTexture: capture_resource(texture.atlas, evidence)
	return evidence

func check_released(evidence: Dictionary, cycle: int) -> void:
	check(not ResourceLoader.has_cached(APPEARANCE_PATH), "Cycle %d releases the appearance cache entry" % cycle)
	for path: String in evidence.paths:
		check(not ResourceLoader.has_cached(path), "Cycle %d releases cached resource %s" % [cycle, path])
	for index in range(evidence.resources.size()):
		check(evidence.resources[index].get_ref() == null, "Cycle %d releases resource weak reference %d" % [cycle, index])
	for index in range(evidence.nodes.size()):
		check(evidence.nodes[index].get_ref() == null, "Cycle %d releases node weak reference %d" % [cycle, index])

func run() -> void:
	check(not ResourceLoader.has_cached(APPEARANCE_PATH), "Fresh process has no appearance cached before loading the default scene")
	var scene := load(ACTOR_PATH) as PackedScene
	if not check(scene != null, "Default scene loads"):
		quit(1)
		return
	check(not ResourceLoader.has_cached(APPEARANCE_PATH), "Loading the default PackedScene does not preload its heavy appearance")
	var initial_children := root.get_child_count()
	var expected_resource_count := -1
	for cycle in range(CYCLES):
		var host := create_character(scene)
		var evidence := release_evidence(host)
		check(evidence.paths.has(APPEARANCE_PATH) and evidence.paths.size() > 2,
			"Release evidence includes appearance, pose libraries, and actual native atlas pages")
		if expected_resource_count < 0: expected_resource_count = evidence.resources.size()
		check(evidence.resources.size() == expected_resource_count, "Repeated actor construction owns the same resource graph")
		root.remove_child(host)
		host.queue_free()
		host = null
		for _frame in range(RELEASE_FRAMES): await process_frame
		check(root.get_child_count() == initial_children, "Cycle %d leaves no character instance in the tree" % cycle)
		check_released(evidence, cycle)
		# Keep the lightweight PackedScene alive through all cycles, modelling a
		# menu/factory preload while requiring each heavy actor graph to be freed.
	scene = null
	for _frame in range(RELEASE_FRAMES): await process_frame
	check(not ResourceLoader.has_cached(APPEARANCE_PATH), "Final release still leaves no appearance cached")
	print("ARCHER ASSET LIFECYCLE: %d checks, %d failures; %d load/bind/release cycles, %d resource weak references per cycle" % [checks, failures, CYCLES, expected_resource_count])
	quit(1 if failures else 0)
