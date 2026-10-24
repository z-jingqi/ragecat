extends SceneTree
## Compare real full-health and lethal hits: only accounting may be HP-capped.
var arena: RageArena
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func near(a: float, b: float, message: String) -> void:
	check(absf(a - b) < 0.001, "%s (%s != %s)" % [message, a, b])
func clear_popups() -> void:
	for child in arena.effects.get_children(): child.free()
func popups() -> Array[FloatingText]:
	var result: Array[FloatingText] = []
	for child in arena.effects.get_children():
		if child is FloatingText: result.append(child)
	return result
func target(kind: String, hp: float) -> EnemyActor:
	var enemy := arena.spawn_enemy(kind, Vector2(600, 300))
	enemy.max_health = 10000.0
	enemy.health = hp
	return enemy
func reset(element: String = "ice", rank: int = 0) -> void:
	arena.clear_enemies()
	clear_popups()
	arena.apply_ranks({"element_type": element, "enchant_rank": 3, "element_skill_rank": rank})
	arena.stats.crit_chance = 0.0
func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for popup in popups():
		result.append({"kind": popup.damage_kind, "element": popup.element_type, "amount": popup.displayed_amount, "text": popup.label.text, "critical": popup.critical})
	return result
func hit_case(kind: String, critical: bool, retention: float, scale: float, frost: bool, shock: bool, hp: float) -> Array[Dictionary]:
	reset("ice", 3 if frost else 0)
	arena.stats.combat_definition.total_crit_chance_cap = 1.0
	arena.stats.crit_chance = 1.0 if critical else 0.0
	var enemy := target(kind, hp)
	if frost:
		if enemy is BossActor: enemy.status.ice_mark_remaining = 2.0
		else: enemy.status.frozen_remaining = 2.0
	if shock:
		enemy.status.shock_remaining = 2.0
		enemy.status.shock_bonus = 0.2
	var arrow := BowArrow.new()
	arrow.retention = retention
	arrow.damage_scale = scale
	arrow.secondary = scale < 1.0
	arrow.impact_position = enemy.position
	var expected_base := 15.0 * retention * scale * (2.0 if critical else 1.0) * (2.0 if frost else 1.0)
	var expected_element := expected_base * (1.2 if shock else 1.0)
	var before_total := arena.total_damage
	var deaths := [0]
	enemy.killed.connect(func(_enemy: EnemyActor) -> void: deaths[0] += 1)
	arena._on_arrow_hit(arrow, enemy)
	arrow.free()
	near(arena.total_damage - before_total, minf(hp, expected_base + expected_element), "health accounting excludes overkill")
	near(enemy.health, maxf(0, hp - expected_base - expected_element), "internal health not rounded")
	var texts := popups()
	check(texts.size() == 2, "accepted enchanted direct hit has two captions")
	if texts.size() == 2:
		near(texts[0].displayed_amount, expected_base, "base has final crit/pierce/secondary/frost modifiers")
		near(texts[1].displayed_amount, expected_element, "element additionally includes shock exactly once")
		for text in texts:
			check(text.label.text.is_valid_int() and int(text.label.text) > 0, "positive integer only")
	var result := snapshot()
	if hp == 1.0:
		check(deaths[0] == 1 and enemy.is_dead, "lethal hit kills once")
		enemy.receive_damage(100.0)
		arena.deal_element_damage(enemy, 100.0, "fire")
		check(deaths[0] == 1 and snapshot() == result, "dead target cannot generate more feedback or deaths")
	return result
func direct_matrix() -> void:
	for kind: String in ["mob", "ranged", "swiftfang", "elite_hornling", "mountainbreaker", "beastcaller", "wildfire"]:
		for critical: bool in [false, true]:
			for scenario: Array in [[1.0, 1.0, false, false], [0.65, 1.0, false, false], [0.65, 0.6, true, true]]:
				var full := hit_case(kind, critical, scenario[0], scenario[1], scenario[2], scenario[3], 10000.0)
				var lethal := hit_case(kind, critical, scenario[0], scenario[1], scenario[2], scenario[3], 1.0)
				check(full == lethal, kind + " lethal/full health feedback identical")
func derived_cases() -> void:
	for source: FeedbackEvent.Source in [FeedbackEvent.Source.BLAST, FeedbackEvent.Source.CHAIN, FeedbackEvent.Source.BURN, FeedbackEvent.Source.GRAVITY]:
		for element: String in ["fire", "lightning", "ice", "dark"]:
			reset(element)
			var enemy := target("dummy", 0.1)
			enemy.status.shock_remaining = 2.0
			enemy.status.shock_bonus = 0.2
			var before := arena.total_damage
			var event := FeedbackEvent.impact(source, enemy.position)
			arena.deal_damage_packet(enemy, {"damage": 2.25, "base_damage": 0.0, "elemental_damage": 2.25, "element": element}, event)
			near(arena.total_damage - before, 0.1, "derived actual accounting")
			near(event.actual_damage, 0.1, "hit feedback actual_damage remains real HP loss")
			var texts := popups()
			check(texts.size() == 1, "derived feedback E only")
			if texts.size() == 1:
				near(texts[0].displayed_amount, 2.7, "derived resolved E not truncated")
				check(texts[0].label.text == "3" and texts[0].element_type == element, "derived integer and element retained")
func invalid_and_rounding() -> void:
	reset()
	var enemy := target("dummy", 3.0)
	var before := arena.total_damage
	for amount: float in [0.0, -1.0, NAN, INF]:
		enemy.receive_damage(amount)
		arena.deal_element_damage(enemy, amount, "fire")
	arena.deal_element_damage(null, 20.0, "fire")
	check(popups().is_empty() and enemy.health == 3.0 and arena.total_damage == before, "invalid hits produce neither damage nor numbers")
	enemy.receive_damage(20.25)
	check(popups().size() == 1 and popups()[0].label.text == "20", "packetless lethal hit also displays uncapped integer")
	near(arena.total_damage - before, 3.0, "packetless health accounting capped")
	reset()
	enemy = target("dummy", 1.0)
	arena.deal_damage_packet(enemy, {"damage": 0.02, "base_damage": 0.01, "elemental_damage": 0.01, "element": "fire"})
	near(enemy.health, 0.98, "tiny damage keeps precision")
	check(popups().size() == 2, "tiny B/E both visible")
	for text in popups(): check(text.label.text == "1", "tiny positive minimum 1 is visual only")
	for locale: String in ["en", "zh_CN"]:
		TranslationServer.set_locale(locale)
		for pair: Array in [[0.49, "1"], [1.49, "1"], [1.5, "2"], [12345.67, "12346"]]:
			var text := arena._damage_popup(pair[0], "element", "fire", true, Vector2(500, 300))
			check(text.label.text == pair[1], "round nearest initial " + locale)
			text.refresh_language()
			check(text.label.text == pair[1], "round nearest locale refresh " + locale)
	for amount: float in [0, -1, NAN, INF]: check(arena._damage_popup(amount, "base", "", false, Vector2.ZERO) == null, "invalid popup suppressed")
func nested_and_fallback() -> void:
	reset()
	var outer := target("dummy", 3.0)
	var inner := target("dummy", 2.0)
	outer.damaged.connect(func(_lost: float, _critical: bool, _at: Vector2) -> void:
		arena.deal_damage_packet(inner, {"damage": 12.0, "base_damage": 0.0, "elemental_damage": 12.0, "element": "dark"})
	)
	var before := arena.total_damage
	arena.deal_damage_packet(outer, {"damage": 20.0, "base_damage": 15.0, "elemental_damage": 5.0, "element": "fire"})
	var texts := popups()
	check(texts.size() == 3, "nested damage emits three components")
	if texts.size() == 3:
		check(texts[0].element_type == "dark" and texts[0].displayed_amount == 12.0, "inner packet isolated")
		check(texts[1].damage_kind == "base" and texts[1].displayed_amount == 15.0, "outer base restored")
		check(texts[2].element_type == "fire" and texts[2].displayed_amount == 5.0, "outer element restored")
	near(arena.total_damage - before, 5.0, "nested accounting uses only real combined loss")
	reset()
	outer = target("dummy", 3.0)
	arena.deal_damage_packet(outer, {"damage": 20.0, "elemental_damage": 5.0, "element": "fire"})
	texts = popups()
	check(texts.size() == 2 and texts[0].displayed_amount == 15.0 and texts[1].displayed_amount == 5.0, "missing base inferred without counting E twice")
	reset()
	outer = target("dummy", 0.0)
	outer.receive_damage(15.0)
	check(popups().is_empty(), "zero-health target cannot generate positive hit feedback")
func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	direct_matrix()
	derived_cases()
	invalid_and_rounding()
	nested_and_fallback()
	arena.free()
	await process_frame
	print("RESOLVED DAMAGE POPUPS: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(1 if failures else 0)
