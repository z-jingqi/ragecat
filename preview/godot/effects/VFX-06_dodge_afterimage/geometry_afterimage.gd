extends Node2D
## External-clock afterimages for host-supplied geometry. Never moves a host.
## Coordinates in shape commands are host-local; transforms are global/world.
## Texture commands borrow immutable Texture2D resources; only command data is copied.
const MAX_IMAGES := 24
const MAX_SHAPES := 32
const MAX_VERTICES := 256
const DEFAULTS := {"interval":.025,"lifetime":.16,"hold":.018,"max_images":6,
	"opacity":.42,"color_mix":.85,"minimum_distance":10.0,"teleport_distance":80.0,
	"speed_lines":true,"line_length":16.0,"line_spread":14.0,"line_opacity":.55,
	"line_lifetime":.08,"minimum_speed":100.0,"tint":"7bdfeb","end_tint":"493f80"}
var config := DEFAULTS.duplicate()
var enabled := false
var paused := false
var clock := 0.0
var next_sample := 0.0
var snapshots: Array[Dictionary] = []
var accents: Array[Dictionary] = []
var previous_transform := Transform2D.IDENTITY
var last_emission := Vector2.INF
var sample_serial := 0

func _init() -> void:
	set_notify_transform(true)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED: queue_redraw()

func configure(overrides: Dictionary = {}) -> void:
	config = DEFAULTS.duplicate()
	for key in overrides:
		if config.has(key): config[key] = overrides[key]
	var limits := {"interval":Vector2(.01,.2),"lifetime":Vector2(.03,1),"hold":Vector2(0,.5),
		"max_images":Vector2(1,MAX_IMAGES),"opacity":Vector2(0,1),"color_mix":Vector2(0,1),
		"minimum_distance":Vector2(0,128),"teleport_distance":Vector2(4,512),
		"line_length":Vector2(2,36),"line_spread":Vector2(0,32),"line_opacity":Vector2(0,1),
		"line_lifetime":Vector2(.02,.25),"minimum_speed":Vector2(0,10000)}
	for key in limits:
		var value := float(config[key]) if config[key] is float or config[key] is int else float(DEFAULTS[key])
		config[key] = clampf(value if is_finite(value) else float(DEFAULTS[key]),limits[key].x,limits[key].y)
	config.max_images = int(config.max_images)
	config.hold = minf(config.hold,config.lifetime*.5)
	config.speed_lines = config.speed_lines == true
	for key in ["tint","end_tint"]:
		if not Color.html_is_valid(str(config[key])): config[key] = DEFAULTS[key]
	while snapshots.size() > config.max_images: snapshots.pop_front()
	queue_redraw()

func set_paused(value: bool) -> void:
	paused = value

func valid_transform(value: Transform2D) -> bool:
	return value.x.is_finite() and value.y.is_finite() and value.origin.is_finite()

func start(world_transform: Transform2D, geometry: Array, host_alpha: float = 1.0) -> void:
	reset()
	if not valid_transform(world_transform) or clean_geometry(geometry).is_empty(): return
	if not is_finite(host_alpha) or host_alpha <= 0: return
	previous_transform = world_transform
	enabled = true

func stop() -> void:
	enabled = false

func reset() -> void:
	enabled = false
	paused = false
	clock = 0
	next_sample = 0
	last_emission = Vector2.INF
	sample_serial = 0
	snapshots.clear()
	accents.clear()
	queue_redraw()

func advance(delta: float, world_transform: Transform2D, geometry: Array, host_alpha: float = 1.0) -> void:
	if paused or delta <= 0 or not is_finite(delta): return
	if not valid_transform(world_transform): reset(); return
	var old := clock
	clock += delta
	if world_transform.origin.distance_to(previous_transform.origin) > float(config.teleport_distance):
		snapshots.clear(); accents.clear(); last_emission = Vector2.INF
		next_sample = clock + float(config.interval)
	var shapes := clean_geometry(geometry)
	var alpha := clampf(host_alpha,0,1) if is_finite(host_alpha) else 0.0
	if enabled and not shapes.is_empty() and alpha > 0:
		# Interpolation records only the supplied segment; it is not host movement.
		# A long stalled frame never causes unbounded sampling or stale history.
		next_sample = maxf(next_sample,clock-float(config.lifetime))
		var iterations := 0
		var velocity := (world_transform.origin-previous_transform.origin)/delta
		while next_sample <= clock+.000001 and iterations < 128:
			var amount := clampf((next_sample-old)/delta,0,1)
			var pose := previous_transform.interpolate_with(world_transform,amount)
			if last_emission == Vector2.INF or pose.origin.distance_to(last_emission) >= float(config.minimum_distance):
				snapshots.append({"transform":pose,"geometry":shapes.duplicate(true),"born":next_sample,"alpha":alpha})
				while snapshots.size() > config.max_images: snapshots.pop_front()
				if config.speed_lines and velocity.length() >= float(config.minimum_speed):
					var direction := velocity.normalized()
					var flank: float = [-1.0,.7,-.4,1.0][sample_serial%4]
					accents.append({"origin":pose.origin-direction*7+direction.orthogonal()*float(config.line_spread)*flank,
						"direction":direction,"born":next_sample,"length":float(config.line_length)*[.7,1.0,.5,.85][sample_serial%4],"alpha":alpha})
					while accents.size() > MAX_IMAGES: accents.pop_front()
				sample_serial += 1
				last_emission = pose.origin
			next_sample += float(config.interval)
			iterations += 1
	previous_transform = world_transform
	for i in range(snapshots.size()-1,-1,-1):
		if clock-float(snapshots[i].born) >= float(config.lifetime)-.000001: snapshots.remove_at(i)
	for i in range(accents.size()-1,-1,-1):
		if clock-float(accents[i].born) >= float(config.line_lifetime)-.000001: accents.remove_at(i)
	queue_redraw()

func clean_geometry(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in source.slice(0,MAX_SHAPES):
		if not item is Dictionary: continue
		var color = item.get("color",Color.WHITE)
		if not color is Color or not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a): continue
		match item.get("kind",""):
			"texture":
				var texture = item.get("texture")
				var rect = item.get("rect")
				var region = item.get("region")
				if not texture is Texture2D or not rect is Rect2 or not region is Rect2: continue
				if not rect.position.is_finite() or not rect.size.is_finite() or not region.position.is_finite() or not region.size.is_finite(): continue
				if rect.size.x <= 0 or rect.size.y <= 0 or region.size.x <= 0 or region.size.y <= 0: continue
				if rect.size.x > 256 or rect.size.y > 256: continue
				# A resource reference is retained, never read back or duplicated per capture.
				# Callers must not update the resource while any ghost can reference it.
				if not Rect2(Vector2.ZERO,texture.get_size()).encloses(region): continue
				result.append({"kind":"texture","texture":texture,"rect":rect,"region":region,"color":color})
			"circle":
				var center = item.get("center",Vector2.ZERO)
				var radius = item.get("radius",0.0)
				if center is Vector2 and center.is_finite() and (radius is int or radius is float) and is_finite(float(radius)) and float(radius)>0:
					result.append({"kind":"circle","center":center,"radius":minf(float(radius),128),"color":color})
			"polygon":
				var points = item.get("points",PackedVector2Array())
				if not points is PackedVector2Array or points.size()<3 or points.size()>MAX_VERTICES: continue
				var valid := true
				for point in points:
					if not point.is_finite(): valid = false; break
				if valid: result.append({"kind":"polygon","points":points.duplicate(),"color":color})
			"line":
				var from = item.get("from",Vector2.ZERO)
				var to = item.get("to",Vector2.ZERO)
				var width = item.get("width",1.0)
				if from is Vector2 and to is Vector2 and from.is_finite() and to.is_finite() and (width is int or width is float) and is_finite(float(width)):
					result.append({"kind":"line","from":from,"to":to,"width":clampf(float(width),1,8),"color":color})
	return result

func _draw() -> void:
	var inverse := global_transform.affine_inverse()
	for snapshot in snapshots:
		var age: float = clock-float(snapshot.born)
		var progress := clampf((age-float(config.hold))/maxf(.001,float(config.lifetime)-float(config.hold)),0,1)
		var tone := Color(config.tint).lerp(Color(config.end_tint),progress)
		var fade := float(config.opacity)*pow(1-progress,1.4)*float(snapshot.alpha)
		var pose: Transform2D = snapshot.transform
		pose.origin = pose.origin.round()
		draw_set_transform_matrix(inverse*pose)
		for shape in snapshot.geometry:
			var original: Color = shape.color
			var color := original.lerp(tone,float(config.color_mix))
			color.a = original.a*fade
			match shape.kind:
				"texture": draw_texture_rect_region(shape.texture,shape.rect,shape.region,color)
				"circle": draw_circle(shape.center,shape.radius,color,true,-1,false)
				"polygon": draw_colored_polygon(shape.points,color)
				"line": draw_line(shape.from,shape.to,color,shape.width,false)
	draw_set_transform_matrix(inverse)
	for accent in accents:
		var progress := clampf((clock-float(accent.born))/float(config.line_lifetime),0,1)
		var direction: Vector2 = accent.direction
		var tip: Vector2 = accent.origin-direction*progress*4
		var length: float = float(accent.length)*(1-progress*.75)
		var color := Color(config.tint).lerp(Color(config.end_tint),progress)
		color.a *= float(config.line_opacity)*float(accent.alpha)*(1-progress)
		for j in int(ceil(length)):
			var point: Vector2 = (tip-direction*j).round()
			draw_rect(Rect2(point,Vector2.ONE),color)
