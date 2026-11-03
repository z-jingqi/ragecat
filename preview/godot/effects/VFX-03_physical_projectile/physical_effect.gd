extends Node2D
## Pure physical-projectile visual. Game supplies real tip positions/velocity.
## No motion, lifetime timer, collision, target selection or damage callbacks.
const History := preload("path_history.gd")
const View := preload("physical_view.gd")
var state: RefCounted
var view: Node2D
var done: bool:
	get: return state == null or not state.active

func play(tip: Vector2, velocity: Vector2, options: Dictionary = {}) -> void:
	if state == null:
		state = History.new()
		view = View.new()
		view.state = state
		add_child(view)
	var config := options.duplicate()
	config.external_lifetime = true
	state.configure(config)
	state.reset(tip,velocity)
	view.sync()

func sample(delta: float, tip: Vector2, velocity: Vector2) -> void:
	if state == null or not state.emitting: return
	state.tick(delta,tip,velocity)
	view.sync()

func stop(immediate: bool = false) -> void:
	if state == null: return
	state.stop(immediate)
	view.sync()

func advance(delta: float) -> void:
	# Live flight has already been sampled by the projectile. Only detached tails
	# use the cosmetics manager's clock, so neither can advance twice per frame.
	if state == null or state.emitting: return
	state.tick(delta,state.world_position,Vector2.ZERO)
	view.sync()
