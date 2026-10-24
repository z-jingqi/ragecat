class_name EnemyOccupancySolver
extends Node
## Static-mode query proxies are deliberate: Godot kinematic body transforms
## remain in new_transform until the next server integration step. Static-mode
## native body_test_motion + explicit transform notification is immediately
## visible to subsequent queries in this same arena callback.
const OCCUPANCY_LAYER := 1 << 7
var arena: RageArena
var definition := EnemyOccupancyDefinition.new()
var _entries: Dictionary = {}
var _reservations: Dictionary = {}
var _walls: Array[StaticBody2D] = []
var _wall_bounds := Rect2()
var _order_tick := 0
var collision_count := 0
var max_penetration := 0.0
var occupancy_certified := true
var spawn_admission_failed := false
var charge_failure := false
var _solve_actors: Array[EnemyActor] = []
var _solve_proxies: Array[StaticBody2D] = []
var _charge_starts := PackedVector2Array()
var _priority_indices: Dictionary = {}
var _charge_work := 0
var _charge_limit := 0.0
var last_solve_usec := 0
var _priority_frame := -1
var _priority_targets: Dictionary = {}
var _priority_budget_starts: Dictionary = {}
var _priority_prepare_usec := 0
var priority_blocked_this_tick := false
var priority_blocked_total := 0
var priority_block_reason := ""
var priority_candidate_trace := PackedStringArray()
var _priority_wall_blocker := -1
var collect_diagnostics := false
var priority_query_counts: Dictionary = {}
var priority_entry_counts: Dictionary = {}
var priority_commit_counts: Dictionary = {}

func _enter_tree() -> void: process_physics_priority = -5

func _physics_process(delta: float) -> void:
	if not is_instance_valid(arena) or arena.finished or arena.run_phase == "victory": return
	var start := Time.get_ticks_usec()
	solve(arena.enemies, delta)
	last_solve_usec = Time.get_ticks_usec() - start + _priority_prepare_usec
	arena.finalize_enemy_launch_origins(definition.enabled)

func reset_cache() -> void:
	_priority_frame = -1
	_priority_targets.clear()
	_priority_budget_starts.clear()
	spawn_admission_failed = false
	charge_failure = false
	max_penetration = 0.0
	clear_reservations()
	for identity in _entries.keys(): _retire(identity)
	for wall in _walls:
		wall.collision_layer = 0
		wall.collision_mask = 0
		wall.queue_free()
	_walls.clear()
	_wall_bounds = Rect2()
	_order_tick = 0

func _retire(identity: int) -> void:
	var entry: Dictionary = _entries.get(identity, {})
	if entry.is_empty(): return
	var proxy: StaticBody2D = entry.proxy
	proxy.collision_layer = 0
	proxy.collision_mask = 0
	proxy.queue_free()
	_entries.erase(identity)
	_priority_targets.erase(identity)
	_priority_budget_starts.erase(identity)

func admit_spawn(actor: EnemyActor, reserved_proxy: StaticBody2D = null) -> bool:
	actor.occupancy_controller = self
	if is_instance_valid(reserved_proxy):
		actor.lock_occupancy_radius()
		actor.position = reserved_proxy.position
		actor.occupancy_motion_start = actor.position
		_entries[actor.get_instance_id()] = {"actor": weakref(actor), "proxy": reserved_proxy, "shape": (reserved_proxy.get_child(0) as CollisionShape2D).shape, "committed": actor.position}
		return true
	if not definition.enabled: return true
	var requested := actor.position
	var accepted := _find_spawn_point(actor, requested)
	if not accepted.is_finite():
		spawn_admission_failed = true
		return false
	actor.position = accepted
	actor.occupancy_motion_start = accepted
	_register(actor)
	return true

func _find_spawn_point(actor: EnemyActor, requested: Vector2) -> Vector2:
	var origin := _spawn_bounded(actor, requested)
	for attempt in range(definition.spawn_search_attempts):
		var distance := 8.0 * sqrt(float(attempt))
		if distance > definition.spawn_search_distance: break
		var candidate := _spawn_bounded(actor, origin + Vector2.from_angle(float(attempt) * 2.39996323) * distance)
		var available := true
		for entry: Dictionary in _entries.values():
			var other: EnemyActor = entry.actor.get_ref()
			if not is_instance_valid(other) or other.is_dead or other.is_queued_for_deletion(): continue
			if candidate.distance_to(entry.proxy.position) < actor.occupancy_radius + other.occupancy_radius + definition.safe_margin * 2.0:
				available = false
				break
		if available:
			for reservation: Dictionary in _reservations.values():
				for proxy: StaticBody2D in reservation.proxies:
					if candidate.distance_to(proxy.position) < actor.occupancy_radius + float(reservation.radius) + definition.safe_margin * 2.0: available = false
		if available: return candidate
	return Vector2(INF, INF)

func _register(actor: EnemyActor) -> void:
	var identity := actor.get_instance_id()
	if _entries.has(identity): return
	actor.occupancy_controller = self
	actor.lock_occupancy_radius()
	var proxy := StaticBody2D.new()
	proxy.name = "GroundOccupancy%d" % identity
	proxy.collision_layer = OCCUPANCY_LAYER
	proxy.collision_mask = OCCUPANCY_LAYER
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = actor.occupancy_radius
	shape.shape = circle
	proxy.add_child(shape)
	proxy.position = actor.position
	add_child(proxy)
	proxy.force_update_transform()
	_entries[identity] = {"actor": weakref(actor), "proxy": proxy, "shape": circle, "committed": actor.position}

func _ensure_walls(bounds: Rect2) -> void:
	if not _walls.is_empty() and bounds == _wall_bounds: return
	for wall in _walls:
		wall.collision_layer = 0
		wall.queue_free()
	_walls.clear()
	_wall_bounds = bounds
	var center := bounds.get_center()
	_wall(Vector2(bounds.position.x - 50, center.y), Vector2(100, bounds.size.y + 200))
	_wall(Vector2(bounds.end.x + 50, center.y), Vector2(100, bounds.size.y + 200))
	_wall(Vector2(center.x, bounds.position.y - 50), Vector2(bounds.size.x + 200, 100))
	_wall(Vector2(center.x, bounds.end.y + 50), Vector2(bounds.size.x + 200, 100))

func _wall(at: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = OCCUPANCY_LAYER
	wall.collision_mask = OCCUPANCY_LAYER
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = at
	add_child(wall)
	wall.force_update_transform()
	_walls.append(wall)

func _bounded(actor: EnemyActor, at: Vector2) -> Vector2:
	return at.clamp(actor.arena_bounds.position + Vector2.ONE * actor.radius, actor.arena_bounds.end - Vector2.ONE * actor.radius)

func solve(container: Node, delta: float) -> void:
	_begin_physics_tick()
	collision_count = 0
	_priority_indices.clear()
	_solve_actors.clear()
	_solve_proxies.clear()
	_charge_starts.clear()
	_charge_limit = minf(definition.charge_clearance_speed * delta, definition.charge_clearance_cap)
	occupancy_certified = true
	if not definition.enabled:
		reset_cache()
		return
	for identity in _reservations.keys():
		var owner: BossActor = _reservations[identity].owner.get_ref()
		if not is_instance_valid(owner) or owner.is_dead or owner.is_queued_for_deletion():
			if is_instance_valid(arena): arena._cancel_summons_by_id(identity)
			else: cancel_reservation(identity)
	var actors: Array[EnemyActor] = []
	var alive: Dictionary = {}
	for node in container.get_children():
		if node is not EnemyActor or node.is_dead or node.is_queued_for_deletion(): continue
		actors.append(node)
		alive[node.get_instance_id()] = true
	for identity in _entries.keys():
		if not alive.has(identity): _retire(identity)
	if actors.is_empty(): return
	_ensure_walls(actors[0].arena_bounds)
	for actor in actors:
		if not _entries.has(actor.get_instance_id()):
			var raw_endpoint := actor.position
			actor.position = actor.occupancy_motion_start if actor.occupancy_motion_frame >= 0 else actor.position
			_register(actor)
			actor.position = raw_endpoint
	# Sample every original intent before any occupancy correction is committed.
	var raw_endpoints := PackedVector2Array()
	var requests := PackedVector2Array()
	for actor in actors:
		var proxy: StaticBody2D = _entries[actor.get_instance_id()].proxy
		raw_endpoints.append(actor.position)
		var committed: Vector2 = _entries[actor.get_instance_id()].committed
		requests.append(_bounded(actor, actor.position) - committed)
		_solve_actors.append(actor)
		_solve_proxies.append(proxy)
		_charge_starts.append(proxy.position)
		proxy.collision_mask = OCCUPANCY_LAYER
		if _priority_targets.has(actor.get_instance_id()):
			_priority_indices[_solve_actors.size() - 1] = true
	for order in range(actors.size()):
		var i := (order + _order_tick) % actors.size()
		if _priority_indices.has(i): continue
		var actor := actors[i]
		var proxy: StaticBody2D = _entries[actor.get_instance_id()].proxy
		var remainder := requests[i]
		for slide in range(definition.maximum_slides):
			if remainder.length_squared() < 0.0000001: break
			remainder = _bounded(actor, proxy.position + remainder) - proxy.position
			var collision := proxy.move_and_collide(remainder, false, definition.safe_margin, false)
			proxy.force_update_transform()
			if collision == null: break
			collision_count += 1
			remainder = collision.get_remainder().slide(collision.get_normal())
	for i in range(actors.size()):
		actors[i].position = _solve_proxies[i].position
		actors[i].occupancy_correction = actors[i].position - raw_endpoints[i]
		actors[i].occupancy_motion_start = actors[i].position
		_entries[actors[i].get_instance_id()].committed = actors[i].position
	_order_tick += 1
	if collect_diagnostics:
		max_penetration = 0.0
		for i in range(actors.size()):
			for j in range(i + 1, actors.size()):
				max_penetration = maxf(max_penetration, actors[i].occupancy_radius + actors[j].occupancy_radius - actors[i].position.distance_to(actors[j].position))
		occupancy_certified = occupancy_certified and max_penetration <= definition.certification_tolerance

func reserve_batch(owner: BossActor, positions: Array[Vector2], radius: float) -> bool:
	if not definition.enabled: return true
	var identity := owner.get_instance_id()
	if _reservations.has(identity): return false
	for i in range(positions.size()):
		for j in range(i):
			if positions[i].distance_to(positions[j]) < radius * 2.0 + definition.safe_margin * 2.0: return false
		for entry: Dictionary in _entries.values():
			var actor: EnemyActor = entry.actor.get_ref()
			if not is_instance_valid(actor) or actor.is_dead or actor.is_queued_for_deletion(): continue
			if positions[i].distance_to(entry.proxy.position) < radius + actor.occupancy_radius + definition.safe_margin * 2.0: return false
		for reservation: Dictionary in _reservations.values():
			for proxy: StaticBody2D in reservation.proxies:
				if positions[i].distance_to(proxy.position) < radius + float(reservation.radius) + definition.safe_margin * 2.0: return false
	var proxies: Array[StaticBody2D] = []
	for at in positions:
		var proxy := StaticBody2D.new()
		proxy.collision_layer = OCCUPANCY_LAYER
		proxy.collision_mask = OCCUPANCY_LAYER
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = radius
		shape.shape = circle
		proxy.add_child(shape)
		proxy.position = at
		add_child(proxy)
		proxy.force_update_transform()
		proxies.append(proxy)
	_reservations[identity] = {"owner": weakref(owner), "proxies": proxies, "radius": radius}
	return true

func take_reserved_proxies(identity: int) -> Array[StaticBody2D]:
	var proxies: Array[StaticBody2D] = []
	if _reservations.has(identity):
		proxies.assign(_reservations[identity].proxies)
		_reservations.erase(identity)
	return proxies

func cancel_reservation(identity: int) -> void:
	for proxy in take_reserved_proxies(identity):
		proxy.collision_layer = 0
		proxy.collision_mask = 0
		proxy.queue_free()

func clear_reservations() -> void:
	for identity in _reservations.keys(): cancel_reservation(identity)

func _snapshot_positions() -> PackedVector2Array:
	var result := PackedVector2Array()
	for proxy in _solve_proxies: result.append(proxy.position)
	return result

func _restore_positions(snapshot: PackedVector2Array) -> void:
	for i in range(_solve_proxies.size()):
		_solve_proxies[i].position = snapshot[i]
		_solve_proxies[i].force_update_transform()

func _clear_priority_corridor(boss: int, from: Vector2, target: Vector2) -> bool:
	var forward := from.direction_to(target)
	if forward.is_zero_approx(): return true
	var side := forward.orthogonal()
	# Arena currently admits one boss; a Beastcaller reservation cannot coexist
	# with Mountainbreaker charge. External fixtures still must not bypass it.
	for reservation: Dictionary in _reservations.values():
		for proxy: StaticBody2D in reservation.proxies:
			var nearest := Geometry2D.get_closest_point_to_segment(proxy.position, from, target)
			if proxy.position.distance_to(nearest) < _solve_actors[boss].occupancy_radius + float(reservation.radius): return false
	for i in range(_solve_proxies.size()):
		if i == boss: continue
		var at := _solve_proxies[i].position
		var nearest := Geometry2D.get_closest_point_to_segment(at, from, target)
		var required := _solve_actors[boss].occupancy_radius + _solve_actors[i].occupancy_radius + definition.safe_margin * 3.0
		if at.distance_to(nearest) >= required: continue
		var relative := at - nearest
		var clearance := sqrt(maxf(0.0, required * required - pow(relative.dot(forward), 2)))
		var lateral := relative.dot(side)
		var preferred := 1.0 if lateral >= 0.0 else -1.0
		var solved := false
		var failed_sides: Array[String] = []
		for sign_side in [preferred, -preferred]:
			var snapshot := _snapshot_positions()
			if _push_priority_chain(i, side * (sign_side * clearance - lateral)):
				solved = true
				break
			failed_sides.append(priority_block_reason)
			priority_candidate_trace.append("lateral actor=%d side=%.0f: %s" % [i, sign_side, priority_block_reason])
			_restore_positions(snapshot)
			# A pure lateral push can meet a wall although a short wall-tangent
			# displacement clears the same swept capsule. Try its exact boundary
			# intersections; these are still native swept moves, never teleports.
			if "wall" in priority_block_reason and _priority_wall_blocker >= 0:
				var wall_members: Array[int] = [_priority_wall_blocker]
				var candidates := _wall_clearance_candidates(i, from, target, required, sign_side, wall_members)
				var tried: Dictionary = {}
				var candidate_index := 0
				while candidate_index < candidates.size():
					var candidate := candidates[candidate_index]
					candidate_index += 1
					if tried.has(candidate): continue
					tried[candidate] = true
					if _push_priority_chain(i, candidate - at):
						priority_candidate_trace.append("wall tangent actor=%d to=%s: accepted" % [i, candidate])
						solved = true
						break
					priority_candidate_trace.append("wall tangent actor=%d to=%s: %s" % [i, candidate, priority_block_reason])
					failed_sides.append(priority_block_reason)
					_restore_positions(snapshot)
					# New members can impose a tighter translation interval. Add
					# each once and intersect all known wall constraints, rather
					# than alternately fixing one wall and violating another.
					if "wall" in priority_block_reason and _priority_wall_blocker >= 0 and not wall_members.has(_priority_wall_blocker):
						wall_members.append(_priority_wall_blocker)
						candidates = _wall_clearance_candidates(i, from, target, required, sign_side, wall_members)
						candidate_index = 0
					if _charge_work >= definition.charge_work_limit: break
			if solved: break
		if not solved:
			priority_block_reason = "both_sides " + str(failed_sides)
			return false
	for i in range(_solve_proxies.size()):
		if i == boss: continue
		var nearest := Geometry2D.get_closest_point_to_segment(_solve_proxies[i].position, from, target)
		if _solve_proxies[i].position.distance_to(nearest) < _solve_actors[boss].occupancy_radius + _solve_actors[i].occupancy_radius - 0.1: return false
	return true

func _wall_clearance_candidates(index: int, from: Vector2, target: Vector2, required: float, side_sign: float, wall_members: Array[int]) -> Array[Vector2]:
	var actor := _solve_actors[index]
	var at := _solve_proxies[index].position
	var legal := actor.arena_bounds.grow(-actor.radius)
	# Intersect member wall constraints in root-endpoint coordinates.
	for member in wall_members:
		var member_actor := _solve_actors[member]
		var member_legal := member_actor.arena_bounds.grow(-member_actor.radius)
		var mapped := Rect2(at + member_legal.position - _solve_proxies[member].position, member_legal.size)
		legal = legal.intersection(mapped)
		if not legal.has_area(): return []
	var forward := from.direction_to(target)
	var side := forward.orthogonal()
	var length := from.distance_to(target)
	var raw: Array[Vector2] = []
	# Capsule consists of two endpoint circles and two parallel line segments.
	for axis in range(2):
		var lines: Array[float] = [legal.position[axis], legal.end[axis]]
		for wall in lines:
			var other := 1 - axis
			for center in [from, target]:
				var offset: float = wall - center[axis]
				if absf(offset) > required: continue
				var tangent := sqrt(maxf(0.0, required * required - offset * offset))
				for sign_value in [-1.0, 1.0]:
					var point: Vector2 = center
					point[axis] = wall
					point[other] += sign_value * tangent
					raw.append(point)
			if absf(forward[axis]) > 0.000001:
				for sign_value in [-1.0, 1.0]:
					var start: Vector2 = from + side * required * sign_value
					var distance: float = (wall - start[axis]) / forward[axis]
					if distance >= 0.0 and distance <= length: raw.append(start + forward * distance)
	var result: Array[Vector2] = []
	for point in raw:
		if point.distance_to(point.clamp(legal.position, legal.end)) > 0.001: continue
		var nearest := Geometry2D.get_closest_point_to_segment(point, from, target)
		if point.distance_to(nearest) < required - 0.001: continue
		if (point - nearest).dot(side) * side_sign < -0.001: continue
		# A candidate outside the per-tick disk is not a legal wall workaround.
		if point.distance_to(_charge_starts[index]) > _charge_limit + 0.0001:
			priority_candidate_trace.append("wall tangent actor=%d to=%s: outside net push budget" % [index, point])
			continue
		if not result.has(point): result.append(point)
	result.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var da := a.distance_squared_to(at)
		var db := b.distance_squared_to(at)
		if da != db: return da < db
		return a.x < b.x if a.x != b.x else a.y < b.y)
	return result

func _charge_work_unit(kind: String, index: int) -> bool:
	# Count admission, every exploratory native query, and every native commit.
	# A refused operation is not executed or charged as hidden extra work.
	if _charge_work >= definition.charge_work_limit:
		priority_block_reason = "work_limit before %s actor=%d" % [kind, index]
		return false
	_charge_work += 1
	if collect_diagnostics:
		var counts: Dictionary = priority_entry_counts if kind == "entry" else (priority_query_counts if kind == "query" else priority_commit_counts)
		counts[index] = int(counts.get(index, 0)) + 1
	return true

func _push_priority_chain(root_index: int, motion: Vector2) -> bool:
	_priority_wall_blocker = -1
	if motion.length_squared() < 0.000001: return true
	# Candidate-local closure: every member gets the SAME displacement, so
	# internal separations do not change. A member is queried repeatedly until
	# its entire sweep is clear of all bodies outside the growing group.
	if not _charge_work_unit("entry", root_index): return false
	var members: Array[int] = [root_index]
	var depths: Dictionary = {root_index: 0}
	var excluded: Array[RID] = [_solve_proxies[root_index].get_rid()]
	var cursor := 0
	while cursor < members.size():
		var index := members[cursor]
		var proxy := _solve_proxies[index]
		if _priority_indices.has(index) or int(depths[index]) >= definition.charge_chain_depth:
			priority_block_reason = "group_depth_or_priority actor=%d depth=%d" % [index, int(depths[index])]
			return false
		var destination := proxy.position + motion
		if destination.distance_to(_charge_starts[index]) > _charge_limit + 0.0001:
			priority_block_reason = "net_push_limit actor=%d requested=%.3f limit=%.3f" % [index, destination.distance_to(_charge_starts[index]), _charge_limit]
			return false
		if destination.distance_to(_bounded(_solve_actors[index], destination)) > 0.0001:
			_priority_wall_blocker = index
			priority_block_reason = "wall_bound actor=%d at=%s destination=%s" % [index, proxy.position, destination]
			return false
		while true:
			if not _charge_work_unit("query", index): return false
			var parameters := PhysicsTestMotionParameters2D.new()
			parameters.from = proxy.global_transform
			parameters.motion = motion
			parameters.margin = definition.safe_margin
			parameters.exclude_bodies = excluded
			var result := PhysicsTestMotionResult2D.new()
			if not PhysicsServer2D.body_test_motion(proxy.get_rid(), parameters, result): break
			var blocker := _solve_proxies.find(result.get_collider())
			if blocker < 0:
				_priority_wall_blocker = index
				priority_block_reason = "native_wall_or_reservation actor=%d normal=%s" % [index, result.get_collision_normal()]
				return false
			if _priority_indices.has(blocker):
				priority_block_reason = "old_priority_body actor=%d" % blocker
				return false
			if depths.has(blocker):
				priority_block_reason = "native_exclusion_failed actor=%d" % blocker
				return false
			if not _charge_work_unit("entry", blocker): return false
			depths[blocker] = int(depths[index]) + 1
			members.append(blocker)
			excluded.append(_solve_proxies[blocker].get_rid())
		cursor += 1
	# Front-to-back native commits preserve collision visibility throughout.
	# No persistent collision exceptions, layer changes, or direct teleports.
	members.sort_custom(func(a: int, b: int) -> bool:
		var pa := _solve_proxies[a].position.dot(motion)
		var pb := _solve_proxies[b].position.dot(motion)
		return pa > pb if pa != pb else a < b)
	for index in members:
		if not _charge_work_unit("commit", index): return false
		var proxy := _solve_proxies[index]
		var destination := proxy.position + motion
		proxy.move_and_collide(motion, false, definition.safe_margin, false)
		proxy.force_update_transform()
		if proxy.position.distance_to(destination) >= 0.1:
			priority_block_reason = "native_commit_shortfall actor=%d requested=%s reached=%s" % [index, destination, proxy.position]
			return false
	# Native recovery from a pre-existing tiny contact can perturb a commit.
	# Certify actual endpoints, not just the ideal common-translation argument.
	for index in members:
		var at := _solve_proxies[index].position
		if at.distance_to(_charge_starts[index]) > _charge_limit + 0.0001 or at.distance_to(_bounded(_solve_actors[index], at)) > 0.001:
			priority_block_reason = "committed_budget_or_wall actor=%d" % index
			return false
		for other in range(_solve_proxies.size()):
			if other == index: continue
			var penetration := _solve_actors[index].occupancy_radius + _solve_actors[other].occupancy_radius - at.distance_to(_solve_proxies[other].position)
			if penetration > definition.certification_tolerance:
				priority_block_reason = "committed_overlap actors=%d,%d penetration=%.5f" % [index, other, penetration]
				return false
	return true

func _spawn_bounded(actor: EnemyActor, at: Vector2) -> Vector2:
	var inset := actor.radius
	if is_instance_valid(arena): inset = maxf(inset, arena.definition.spawn_inset)
	return at.clamp(actor.arena_bounds.position + Vector2.ONE * inset, actor.arena_bounds.end - Vector2.ONE * inset)

func reservation_matches_radius(identity: int, radius: float) -> bool:
	return not definition.enabled or (_reservations.has(identity) and is_equal_approx(float(_reservations[identity].radius), radius))

func _begin_physics_tick() -> void:
	var frame := Engine.get_physics_frames()
	if frame == _priority_frame: return
	_priority_frame = frame
	_priority_targets.clear()
	_priority_budget_starts.clear()
	_priority_prepare_usec = 0
	_priority_indices.clear()
	_charge_work = 0
	charge_failure = false
	priority_blocked_this_tick = false
	priority_block_reason = ""
	priority_candidate_trace.clear()
	priority_entry_counts.clear()
	priority_query_counts.clear()
	priority_commit_counts.clear()

func prepare_priority_move(actor: EnemyActor, from: Vector2, target: Vector2, delta: float) -> bool:
	if not definition.enabled or not is_instance_valid(arena): return true
	_begin_physics_tick()
	var started := Time.get_ticks_usec()
	_solve_actors.clear()
	_solve_proxies.clear()
	_charge_starts.clear()
	_priority_indices.clear()
	_charge_limit = minf(definition.charge_clearance_speed * delta, definition.charge_clearance_cap)
	var alive: Dictionary = {}
	for node in arena.enemies.get_children():
		if node is not EnemyActor or node.is_dead or node.is_queued_for_deletion(): continue
		alive[node.get_instance_id()] = true
		_register(node)
		var proxy: StaticBody2D = _entries[node.get_instance_id()].proxy
		_solve_actors.append(node)
		_solve_proxies.append(proxy)
		if not _priority_budget_starts.has(node.get_instance_id()): _priority_budget_starts[node.get_instance_id()] = proxy.position
		_charge_starts.append(_priority_budget_starts[node.get_instance_id()])
		if node == actor or _priority_targets.has(node.get_instance_id()): _priority_indices[_solve_actors.size() - 1] = true
	for identity in _entries.keys():
		if not alive.has(identity): _retire(identity)
	_ensure_walls(actor.arena_bounds)
	var index := _solve_actors.find(actor)
	if index < 0:
		_priority_prepare_usec += Time.get_ticks_usec() - started
		return true # Unmanaged standalone combat fixture has no occupancy service.
	var snapshot := _snapshot_positions()
	var proxy := _solve_proxies[index]
	var valid := target.distance_to(_bounded(actor, target)) < 0.001 and proxy.position.distance_to(from) < 0.001
	proxy.collision_mask = 0
	if not valid: priority_block_reason = "invalid_target_or_unsynced_start"
	if not valid or not _clear_priority_corridor(index, from, target):
		_restore_positions(snapshot)
		proxy.collision_mask = OCCUPANCY_LAYER
		priority_blocked_this_tick = true
		priority_blocked_total += 1
		_priority_prepare_usec += Time.get_ticks_usec() - started
		return false
	proxy.position = target
	proxy.force_update_transform()
	_priority_targets[actor.get_instance_id()] = target
	_priority_prepare_usec += Time.get_ticks_usec() - started
	return true
