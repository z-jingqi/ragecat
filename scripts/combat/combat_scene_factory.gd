class_name CombatSceneFactory
extends RefCounted
## Validate compatible scene roots before they join the tree. Malformed optional
## scenes never replace the working default or leave an orphan node behind.
static func player(scene: PackedScene) -> PlayerActor:
	var node := _instance(scene)
	if node is PlayerActor: return node
	_discard(node)
	return load("res://scenes/characters/archer/archer.tscn").instantiate() as PlayerActor

static func bow(scene: PackedScene) -> BowController:
	var node := _instance(scene)
	if node is BowController: return node
	_discard(node)
	return load("res://scenes/weapons/bow.tscn").instantiate() as BowController

static func arrow(scene: PackedScene) -> BowArrow:
	var node := _instance(scene)
	if node is BowArrow: return node
	_discard(node)
	return load("res://scenes/projectiles/bow_arrow.tscn").instantiate() as BowArrow

static func _instance(scene: PackedScene) -> Node:
	return scene.instantiate() if scene != null and scene.can_instantiate() else null

static func _discard(node: Node) -> void:
	if node != null: node.free()
