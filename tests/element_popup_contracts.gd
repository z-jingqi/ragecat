extends SceneTree
## Real hits must produce component feedback without splitting health/crit events.
var arena: RageArena
var checks := 0
var failures := 0
const ELEMENTS := ["fire", "lightning", "ice", "dark"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func near(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.001, "%s: actual=%s expected=%s" % [label, actual, expected])
func reset(ranks: Dictionary) -> void:
	arena.clear_enemies()
	for node in arena.effects.get_children(): node.free()
	arena.apply_ranks(ranks)
	arena.stats.crit_chance = 0.0
	arena.player.position = Vector2(350, 350)
func target(at: Vector2) -> EnemyActor:
	var enemy := arena.spawn_enemy("dummy", at)
	enemy.radius = 3.0
	enemy.max_health = 10000.0
	enemy.health = 10000.0
	return enemy
func fire() -> CatArrow:
	var bait := target(arena.player.position + Vector2(150, 0))
	arena.bow.shoot()
	bait.free()
	for node in arena.arrows.get_children():
		if node is CatArrow and not node.secondary and not node.is_queued_for_deletion(): return node
	return null
func popups() -> Array[FloatingText]:
	var result: Array[FloatingText] = []
	for node in arena.effects.get_children():
		if node is FloatingText and not node.is_queued_for_deletion(): result.append(node)
	return result
func rect(text: FloatingText) -> Rect2:
	return Rect2(text.position + text.label.position, text.label.get_combined_minimum_size())
func hit(arrow: CatArrow, victim: EnemyActor, expected: float, label: String) -> void:
	var before := victim.health
	var events := [0]
	victim.damaged.connect(func(_amount: float, _crit: bool, _at: Vector2) -> void: events[0] += 1)
	var total_before := arena.total_damage
	var hits_before := arena.hits
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.state = arena.rng.state
	expected_rng.randf()
	arrow._physics_process(50.0 / arrow.speed)
	near(before - victim.health, expected, label + " actual hp")
	near(arena.total_damage - total_before, expected, label + " accounting not doubled by labels")
	check(events[0] == 1, label + " one atomic damaged signal")
	check(arena.hits == hits_before + 1, label + " one hit")
	check(arena.rng.state == expected_rng.state, label + " one crit roll")

func of_kind(texts: Array[FloatingText], kind: String) -> FloatingText:
	for text in texts:
		if text.damage_kind == kind: return text
	return null
func amount_sum(texts: Array[FloatingText]) -> float:
	var amount := 0.0
	for text in texts: amount += text.displayed_amount
	return amount
func component_cases() -> void:
	var element_colors: Array[Color] = []
	for element: String in ELEMENTS:
		var base_normal_color := Color.WHITE
		for critical: bool in [false, true]:
			reset({element + "_enchant": 1, "damage_flat": 1, "damage": 1, "burst": 1})
			arena.stats.crit_chance = 1.0 if critical else 0.0
			var source := fire()
			var victim := target(source.position + Vector2(40, 0))
			var expected := 36.0 if critical else 18.0
			hit(source, victim, expected, element + " critical%s" % critical)
			var texts := popups()
			check(texts.size() == 2, element + " exactly B/E captions, no third total")
			var base := of_kind(texts, "base")
			var elemental := of_kind(texts, "element")
			check(base != null and elemental != null, element + " both component kinds")
			if base == null or elemental == null: continue
			near(base.displayed_amount, 28.8 if critical else 14.4, "base decimal value")
			near(elemental.displayed_amount, 7.2 if critical else 3.6, "element decimal value")
			near(amount_sum(texts), expected, "component labels sum actual hp loss")
			check(base.label.text == ("CRIT 28.8" if critical else "14.4"), "normal/critical base label format")
			check(elemental.label.text == (("CRIT " if critical else "") + element.substr(0, 1).to_upper() + (" 7.2" if critical else " 3.6")), "typed elemental decimal label")
			check(base.critical == critical and elemental.critical == critical, "one critical marks both components")
			check(elemental.element_type == element, "element caption type identity")
			check(base.font_size == (23 if critical else 18), "critical base larger")
			check(elemental.font_size == (21 if critical else 18), "critical element larger")
			check(base.label.get_theme_color("font_color") != elemental.label.get_theme_color("font_color"), "base/element visually distinct")
			if not critical:
				base_normal_color = base.label.get_theme_color("font_color")
				element_colors.append(elemental.label.get_theme_color("font_color"))
			else:
				check(base.label.get_theme_color("font_color") != base_normal_color, "critical base uses distinct color")
				check(elemental.label.get_theme_color("font_color") == element_colors[-1], "critical retains elemental type color")
			check(not rect(base).intersects(rect(elemental)), "simultaneous B/E do not overlap")
		for index in range(element_colors.size() - 1):
			check(element_colors[index] != element_colors[-1], element + " has distinct elemental color")

func zero_and_overkill() -> void:
	reset({})
	var source := fire()
	var victim := target(source.position + Vector2(40, 0))
	hit(source, victim, 15.0, "no enchant")
	check(popups().size() == 1 and popups()[0].damage_kind == "base", "zero E emits no elemental caption")
	reset({"fire_enchant": 1})
	arena.stats.arrow_damage = 0.0
	source = fire()
	victim = target(source.position + Vector2(40, 0))
	hit(source, victim, 5.0, "zero base")
	check(popups().size() == 1 and popups()[0].damage_kind == "element", "zero B emits no base caption")
	reset({"fire_enchant": 1})
	source = fire()
	victim = target(source.position + Vector2(40, 0))
	victim.health = 5.0
	hit(source, victim, 5.0, "overkill")
	var texts := popups()
	check(texts.size() == 2, "overkill retains paired component captions")
	var base := of_kind(texts, "base")
	var elemental := of_kind(texts, "element")
	if base != null and elemental != null:
		near(base.displayed_amount, 3.75, "overkill base proportional actual damage")
		near(elemental.displayed_amount, 1.25, "overkill element proportional actual damage")
	near(amount_sum(texts), 5.0, "overkill captions sum hp removed, not attempted packet")

func derived_and_cap() -> void:
	reset({"fire_enchant": 1, "fire_bow": 3})
	var source := fire()
	var primary := target(source.position + Vector2(40, 0))
	var witness := target(primary.position + Vector2(0, 35))
	var total_before := arena.total_damage
	source._physics_process(50.0 / source.speed)
	var texts := popups()
	check(texts.size() == 3, "main B/E pair plus derived E-only")
	var base_count := 0
	var elemental_count := 0
	var derived_count := 0
	for text in texts:
		if text.damage_kind == "base": base_count += 1
		if text.damage_kind == "element": elemental_count += 1
		if is_equal_approx(text.displayed_amount, 10.0):
			derived_count += 1
			check(text.damage_kind == "element" and text.element_type == "fire" and not text.critical, "derived correctly typed noncrit")
	check(base_count == 1 and elemental_count == 2 and derived_count == 1, "no base caption on derived effect")
	near(witness.max_health - witness.health, 10.0, "derived actual hp")
	near(arena.total_damage - total_before, 30.0, "direct+derived accounting unchanged")
	near(amount_sum(texts), 30.0, "direct+derived displayed values match total")
	reset({"fire_enchant": 1})
	var old_limit: int = arena.definition.effect_limit
	arena.definition.effect_limit = 3
	for repeat in range(10):
		for node in arena.arrows.get_children(): node.free()
		for node in arena.enemies.get_children(): node.free()
		source = fire()
		primary = target(source.position + Vector2(40, 0))
		source._physics_process(50.0 / source.speed)
		check(arena.effects.get_child_count() <= 3, "paired captions respect shared effect cap")
	arena.definition.effect_limit = old_limit

func boundary_pairs() -> void:
	var points: Array[Vector2] = [arena.bounds.position + Vector2(10, 10), Vector2(arena.bounds.end.x - 10, arena.bounds.position.y + 10), arena.bounds.end - Vector2(10, 10), Vector2(arena.bounds.position.x + 10, arena.bounds.end.y - 10)]
	for reverse_order: bool in [false, true]:
		for at in points:
			reset({"lightning_enchant": 3, "damage": 3})
			arena.stats.crit_chance = 1.0
			var source := fire()
			source.position = at - Vector2(40, 0)
			var victim := target(at)
			victim.position = at
			hit(source, victim, 96.0, "boundary pair")
			var texts := popups()
			check(texts.size() == 2, "boundary pair retains both labels")
			if texts.size() != 2: continue
			if reverse_order: texts.reverse()
			for text in texts: check(arena.bounds.encloses(rect(text)), "damage caption initially inside arena")
			check(not rect(texts[0]).intersects(rect(texts[1])), "boundary pair initially separated")
			for elapsed: float in [0.01, 0.19, 0.2, 0.2]:
				for text in texts: text._process(elapsed)
				for text in texts: check(arena.bounds.encloses(rect(text)), "damage caption remains inside while floating")
				check(not rect(texts[0]).intersects(rect(texts[1])), "boundary pair stays separated, either process order")

func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	component_cases()
	zero_and_overkill()
	derived_and_cap()
	boundary_pairs()
	arena.free()
	print("ELEMENT POPUP CONTRACTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
