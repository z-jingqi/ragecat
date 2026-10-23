extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)
func near(value: float, expected: float, label: String) -> void:
	check(is_equal_approx(value, expected), label + " (%s != %s)" % [value, expected])
func modifier(channel: String, scale: float = 1.0, values: PackedFloat32Array = []) -> UpgradeStatModifier:
	var effect := UpgradeStatModifier.new()
	effect.channel = channel
	effect.scale = scale
	effect.values = values
	return effect
func upgrade(id: String, values: PackedFloat32Array, effects: Array[UpgradeStatModifier]) -> UpgradeDefinition:
	var item := UpgradeDefinition.new()
	item.upgrade_id = id
	item.values = values
	item.stat_modifiers = effects
	return item
func packed(node: Node) -> PackedScene:
	var scene := PackedScene.new()
	check(scene.pack(node) == OK, "custom scene packs")
	node.free()
	return scene
func run() -> void:
	var defaults := CharacterDefinition.new().create_stats()
	var default_channels := {"vitality":"max_hp", "damage_flat":"damage_flat", "damage":"damage_percent", "attack_speed":"attack_speed", "crit_chance":"crit_chance", "crit_damage":"crit_multiplier", "move_speed":"move_speed", "pickup_radius":"pickup_radius", "regen":"regen", "knockback":"knockback", "long_draw":"arrow_range"}
	var baselines := {"vitality":100.0,"damage_flat":0.0,"damage":0.0,"attack_speed":1.0,"crit_chance":0.05,"crit_damage":2.0,"move_speed":230.0,"pickup_radius":75.0,"regen":0.0,"knockback":45.0,"long_draw":520.0}
	for key: String in default_channels:
		for rank in range(4):
			defaults.apply_ranks({key:rank})
			var amount := defaults.catalog.value(key,rank)
			var baseline: float = baselines[key]
			var expected: float = baseline * (1.0 + amount) if key in ["move_speed","knockback","long_draw"] else baseline + amount
			near(float(defaults.get(default_channels[key])),expected,"default rank values preserved: " + key)
	check(defaults.character.upgrades.size() == UpgradeCatalog.UPGRADES.size(), "default catalog is captured by run snapshot")
	var authored_vitality: UpgradeDefinition = null
	for item: UpgradeDefinition in UpgradeCatalog.UPGRADES:
		if item.upgrade_id == "vitality": authored_vitality = item
	var original_value := authored_vitality.values[1]
	authored_vitality.values[1] = 999.0
	defaults.apply_ranks({"vitality":1})
	near(defaults.max_hp,120,"default authored catalog changes cannot mutate running build")
	authored_vitality.values[1] = original_value
	var independent := upgrade("self_contained",PackedFloat32Array(),[modifier("health",1.0,PackedFloat32Array([0,12,24,36]))])
	var standalone := CharacterDefinition.new()
	standalone.upgrades = [independent]
	var standalone_stats := standalone.create_stats()
	standalone_stats.catalog.all_unlocked = true
	check(standalone_stats.catalog.max_rank("self_contained")==3,"modifier-owned rank table needs no dummy parent values")
	check(standalone_stats.catalog.eligible({}).has("self_contained"),"self-contained modifier card can be offered")
	standalone_stats.apply_ranks({"self_contained":2})
	near(standalone_stats.max_hp,124,"modifier-owned rank table reaches runtime")
	var source := CharacterDefinition.new()
	var agile := upgrade("agile_vigor", PackedFloat32Array([0, 10, 20, 30]), [modifier("health"), modifier("move_ratio", 0.01)])
	var bargain := upgrade("risky_power", PackedFloat32Array([0, 5, 10, 15]), [modifier("damage_flat"), modifier("health", -1.0)])
	var extra := upgrade("second_vigor", PackedFloat32Array([0, 7, 14, 21]), [modifier("health")])
	source.upgrades = [agile, bargain, extra]
	var stats := source.create_stats()
	stats.catalog.all_unlocked = true
	var ranks := {"agile_vigor":2,"risky_power":1,"second_vigor":3}
	stats.apply_ranks(ranks)
	near(stats.max_hp, 136, "different IDs combine health and signed cost")
	near(stats.move_speed, 276, "compound card contributes move ratio")
	near(stats.damage_flat, 5, "compound card contributes flat damage")
	near(stats.base_damage, 20, "derived damage calculated after additive channels")
	for iteration in range(5):
		stats.apply_ranks(ranks)
		near(stats.max_hp,136,"rebuild is idempotent")
		near(stats.move_speed,276,"ratio is applied once")
	var description := stats.catalog.describe_rank("agile_vigor",2)
	check(description.contains("20") and description.contains("\n"), "custom compound description contains both effects")
	check(not stats.catalog.describe_rank("risky_power",1).contains("+-"), "negative cost description is readable")
	var other := source.create_stats()
	near(other.max_hp,100,"other run has no acquired upgrade")
	agile.stat_modifiers[0].scale = 100.0
	stats.apply_ranks(ranks)
	near(stats.max_hp,136,"authored modifier mutation cannot alter existing run snapshot")
	stats.catalog.definition("agile_vigor").stat_modifiers[0].scale=200
	stats.apply_ranks(ranks)
	near(stats.max_hp,136,"temporary catalog edits do not mutate character snapshot")
	var dark_character := CharacterDefinition.new()
	dark_character.combat.base_attack_speed = 2.0
	for item: UpgradeDefinition in UpgradeCatalog.UPGRADES: dark_character.upgrades.append(item)
	dark_character.upgrades.append(upgrade("heavy_pull_cost",PackedFloat32Array([0,0.5,0.75,1.0]),[modifier("knockback_ratio",-1.0)]))
	var dark_stats := dark_character.create_stats()
	dark_stats.apply_ranks({"element_type":"dark","enchant_rank":1,"element_skill_rank":1,"heavy_pull_cost":1})
	var gravity := dark_stats.element_skill.gravity
	near(dark_stats.gravity_gap,maxf(gravity.minimum_gap,gravity.base_gap/2.0),"custom base attack speed affects post-gravity gap")
	near(dark_stats.gravity_acceleration,gravity.parameter(gravity.acceleration_by_rank,1)*maxf(0,1-0.5*gravity.pull_upgrade_scale),"negative knockback cost reduces gravity pull")
	check(dark_stats.catalog.describe_build_rank("heavy_pull_cost",1,dark_stats.ranks).contains("-"),"gravity cost description matches signed effect")
	var bad := modifier("health", NAN, PackedFloat32Array([0, INF, -5, -10])).validated_copy()
	near(bad.value_at(1,[]),0,"invalid modifier is finite")
	bad.channel="missing_channel"
	near(bad.value_at(1,[]),0,"unsupported channel ignored")
	var actor := PlayerActor.new()
	actor.name="AlternateActor"
	var controller := BowController.new()
	controller.name="AlternateBow"
	var arrow := BowArrow.new()
	arrow.name="AlternateArrow"
	var character := CharacterDefinition.new()
	character.actor_scene=packed(actor)
	character.bow.controller_scene=packed(controller)
	character.bow.projectile_scene=packed(arrow)
	var arena := RageArena.new()
	arena.practice=true
	arena.sound_enabled=false
	arena.character_definition=character
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.bow.set_physics_process(false)
	check(arena.player.name=="AlternateActor" and not arena.player is Archer,"arena uses data-selected shared actor")
	check(arena.bow.name=="AlternateBow","arena uses data-selected weapon controller")
	var target:=arena.spawn_enemy("dummy",arena.player.position+Vector2(100,0))
	check(target!=null,"compatible actor works with arena target")
	arena.bow.shoot()
	check(arena.arrows.get_child_count()==1,"alternate weapon creates projectile")
	check(arena.arrows.get_child(0).name=="AlternateArrow","normal shot uses configured projectile scene")
	var source_arrow:=arena.arrows.get_child(0) as BowArrow
	source_arrow.impact_position=arena.player.position+Vector2(30,0)
	source_arrow.impact_traveled=30
	arena.stats.split_angles=PackedFloat32Array([-0.2,0.2])
	arena.stats.split_damage=0.3
	arena.bow._spawn_fragments(source_arrow,target.get_instance_id())
	check(arena.arrows.get_child_count()==3,"split uses compatible projectile factory")
	for projectile in arena.arrows.get_children():
		check(projectile is BowArrow,"all custom roots retain projectile contract")
	for projectile in arena.arrows.get_children(): projectile.free()
	arena.stats.apply_ranks({"element_type":"dark","enchant_rank":1,"element_skill_rank":1})
	arena.bow.shoot()
	check(arena.bow.active_gravity_arrow != null,"alternate scene works with gravity lifecycle")
	check(arena.bow.active_gravity_arrow.name=="AlternateArrow","gravity also uses configured scene")
	check(arena.bow.active_gravity_arrow.gravity_field != null,"gravity component is attached separately")
	arena.queue_free()
	await process_frame
	var invalid:=packed(Node.new())
	var fallback_player:=CombatSceneFactory.player(invalid)
	var fallback_bow:=CombatSceneFactory.bow(invalid)
	var fallback_arrow:=CombatSceneFactory.arrow(invalid)
	check(fallback_player is Archer,"invalid actor falls back safely")
	check(fallback_bow is BowController,"invalid weapon falls back safely")
	check(fallback_arrow is BowArrow,"invalid projectile falls back safely")
	fallback_player.free();fallback_bow.free();fallback_arrow.free()
	await create_timer(0.2).timeout
	print("Composition architecture: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
