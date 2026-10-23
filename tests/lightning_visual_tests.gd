extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var settings := ElementVisualDefinition.new().validated_copy()
	var points := PackedVector2Array([Vector2(0, 0), Vector2(100, 50), Vector2(180, -30), Vector2(270, 30), Vector2(350, 0)])
	seed(731)
	var expected := randf()
	seed(731)
	var ribbon := LightningRibbon.new()
	ribbon.build(points, settings)
	check(randf() == expected, "Building cosmetic ribbons never consumes global RNG")
	check(ribbon.endpoints == points, "Actual chain endpoint order is unchanged")
	check(ribbon.meshes.size() == points.size() - 1, "Exactly one cached mesh per actual hop")
	var vertices := 0
	for mesh in ribbon.meshes:
		var arrays := mesh.surface_get_arrays(0)
		vertices += arrays[Mesh.ARRAY_VERTEX].size()
		check(arrays[Mesh.ARRAY_VERTEX].size() == arrays[Mesh.ARRAY_TEX_UV].size(), "Ribbon vertices have valid texture coordinates")
		for uv in arrays[Mesh.ARRAY_TEX_UV]: check(uv.x >= 0 and uv.x <= 1 and uv.y >= 0 and uv.y <= 1, "Ribbon UV inside texture")
	check(vertices <= 4 * (16 + 4 * 3) * 6, "Geometry budget bounded per four-hop chain")
	var flash := ElementFlash.new()
	flash.kind = "chain"
	root.add_child(flash)
	# Real proc controller assigns endpoints after add_child and _ready.
	flash.points = points
	flash._prepare_lightning()
	check(flash.lightning != null, "Deferred endpoint assignment prepares visuals")
	check((flash.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "Compatibility additive rendering configured")
	var cached := flash.lightning.meshes[0]
	flash._prepare_lightning()
	check(cached == flash.lightning.meshes[0], "Mesh is not rebuilt on each frame")
	flash._process(0.05)
	check(flash.modulate.a == 1.0, "Discharge envelope is not faded twice")
	flash._process(NAN)
	check(is_finite(flash.remaining), "Invalid delta cannot poison lifetime")
	flash._process(10.0)
	check(flash.is_queued_for_deletion(), "Expired visuals are released")
	settings.bolt_branches = 99999
	settings.bolt_sparks = 99999
	settings.bolt_glow_width = INF
	settings = settings.validated_copy()
	check(settings.bolt_branches == 4 and settings.bolt_sparks == 12 and is_finite(settings.bolt_glow_width), "Pathological visual configuration is bounded")
	var host := Node2D.new()
	root.add_child(host)
	for i in range(70):
		var effect := ElementFlash.new()
		effect.kind = "chain"
		host.add_child(effect)
	var visible_count := 0
	var detail_count := 0
	for effect in host.get_children():
		if effect.presentation_priority() < effect.definition.lightning_visual_limit: visible_count += 1
		if effect.presentation_priority() < effect.definition.lightning_detail_limit: detail_count += 1
	check(visible_count == 16 and detail_count == 4, "70 live cosmetics stay inside independent 16 arc / 4 accent budgets")
	host.free()
	var outcomes := []
	for visual_budget in [1, 32]:
		var arena := RageArena.new()
		arena.practice = true
		root.add_child(arena)
		arena.apply_ranks({"element_type":"lightning", "enchant_rank":3, "element_skill_rank":3})
		arena.bow.enabled = false
		arena.rng.seed = 48152
		arena.feedback.definition.elements.lightning_visual_limit = visual_budget
		var targets: Array[EnemyActor] = []
		for i in range(5):
			var actor := arena.spawn_enemy("melee", Vector2(300 + i * 50, 300))
			actor.health = 99999
			actor.max_health = 99999
			actor.ai_enabled = false
			targets.append(actor)
		for i in range(100): arena.element_procs._chain(targets[0],targets[0].position,12,arena.stats.element_skill,3)
		var healths := []
		for actor in targets: healths.append(actor.health)
		outcomes.append([healths,arena.rng.randf(),arena.element_procs.proc_counts.lightning])
		check(arena.element_procs.get_child_count() <= arena.definition.effect_limit, "Original lifetime effect ceiling retained")
		arena.free()
	check(outcomes[0] == outcomes[1], "Visual budget leaves 100 chains damage, targets, shock RNG, and proc count identical")
	var begin := Time.get_ticks_usec()
	for i in range(48):
		var effect := LightningRibbon.new()
		effect.build(points, settings)
	print("48 worst-config four-hop mesh builds: %.2f ms" % ((Time.get_ticks_usec() - begin) / 1000.0))
	print("Lightning visual contracts: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(1 if failures else 0)
