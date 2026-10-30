extends "res://scripts/vfx/cel/charge_component.gd"
## Authored, stationary cel planes. Only a compact scale pulse moves the surface;
## no angular scrolling, concentric rotating rings, noise shader or pixel grid.
const Config = preload("res://scripts/vfx/cel/pulsing_orb_config.gd")
@export var settings: Config = Config.new()
var config: Config = Config.new()
var _planes: Array = []

func _ready() -> void:
	if not _configured: configure(settings)

func configure(value: Config) -> void:
	config = value.duplicate(true) if value != null else Config.new()
	config.sanitize()
	_configured = true
	if _planes.is_empty(): _build_planes()
	queue_redraw()

## Each section is a cubic curve (two handles, endpoint), in unit-orb space.
func _contour(start: Vector2, sections: Array) -> PackedVector2Array:
	var points := PackedVector2Array([start])
	var previous := start
	for section in sections:
		for j in range(1,9):
			var t := j/8.0
			points.append(previous.bezier_interpolate(section[0],section[1],section[2],t))
		previous = section[2]
	if points[-1].is_equal_approx(start): points.resize(points.size()-1)
	return points

func _plane(start: Vector2, sections: Array, palette: String, accent: bool = false) -> void:
	_planes.append({"points":_contour(start,sections),"palette":palette,"accent":accent})

func _build_planes() -> void:
	# Unequal lobes, flattened shoulders and a pointed foot keep the silhouette
	# drawn rather than a mathematically concentric set of circles.
	_plane(Vector2(-0.08,-1.0),[
		[Vector2(0.28,-1.03),Vector2(0.65,-0.84),Vector2(0.79,-0.62)],
		[Vector2(0.97,-0.41),Vector2(1.03,-0.1),Vector2(0.98,0.17)],
		[Vector2(0.96,0.53),Vector2(0.76,0.79),Vector2(0.46,0.91)],
		[Vector2(0.19,1.05),Vector2(-0.06,1.01),Vector2(-0.31,0.98)],
		[Vector2(-0.65,0.9),Vector2(-0.89,0.64),Vector2(-0.97,0.33)],
		[Vector2(-1.07,0.02),Vector2(-0.96,-0.35),Vector2(-0.79,-0.59)],
		[Vector2(-0.61,-0.83),Vector2(-0.37,-0.99),Vector2(-0.08,-1.0)]
	],"shade_color")
	_plane(Vector2(-0.25,-0.91),[
		[Vector2(0.08,-1.00),Vector2(0.19,-0.88),Vector2(0.39,-0.82)],
		[Vector2(0.68,-0.76),Vector2(0.83,-0.55),Vector2(0.82,-0.31)],
		[Vector2(0.95,-0.13),Vector2(0.91,0.16),Vector2(0.80,0.34)],
		[Vector2(0.84,0.57),Vector2(0.59,0.78),Vector2(0.30,0.84)],
		[Vector2(0.09,0.98),Vector2(-0.21,0.89),Vector2(-0.42,0.83)],
		[Vector2(-0.66,0.72),Vector2(-0.78,0.49),Vector2(-0.81,0.28)],
		[Vector2(-0.96,0.06),Vector2(-0.9,-0.26),Vector2(-0.74,-0.47)],
		[Vector2(-0.64,-0.71),Vector2(-0.44,-0.84),Vector2(-0.25,-0.91)]
	],"body_color")
	# A single off-center ivory heart; the accents are broken shapes, not rings.
	_plane(Vector2(-0.16,-0.48),[
		[Vector2(0.08,-0.52),Vector2(0.31,-0.35),Vector2(0.36,-0.17)],
		[Vector2(0.48,0.02),Vector2(0.41,0.26),Vector2(0.27,0.37)],
		[Vector2(0.13,0.51),Vector2(-0.14,0.47),Vector2(-0.28,0.37)],
		[Vector2(-0.49,0.21),Vector2(-0.49,-0.02),Vector2(-0.43,-0.19)],
		[Vector2(-0.40,-0.34),Vector2(-0.29,-0.43),Vector2(-0.16,-0.48)]
	],"core_color")
	# Short hand-cut surface tongues, attached to their light/shade mass.
	_plane(Vector2(-0.79,-0.35),[
		[Vector2(-0.64,-0.62),Vector2(-0.42,-0.74),Vector2(-0.36,-0.78)],
		[Vector2(-0.51,-0.72),Vector2(-0.69,-0.67),Vector2(-0.77,-0.53)],
		[Vector2(-0.70,-0.64),Vector2(-0.62,-0.75),Vector2(-0.55,-0.84)],
		[Vector2(-0.77,-0.69),Vector2(-0.86,-0.48),Vector2(-0.79,-0.35)]
	],"shade_color",true)
	_plane(Vector2(0.63,-0.62),[
		[Vector2(0.79,-0.47),Vector2(0.78,-0.28),Vector2(0.72,-0.21)],
		[Vector2(0.70,-0.35),Vector2(0.60,-0.49),Vector2(0.57,-0.53)],
		[Vector2(0.60,-0.50),Vector2(0.65,-0.49),Vector2(0.68,-0.44)],
		[Vector2(0.66,-0.51),Vector2(0.65,-0.58),Vector2(0.63,-0.62)]
	],"shade_color",true)
	_plane(Vector2(0.87,0.06),[
		[Vector2(0.84,0.30),Vector2(0.75,0.43),Vector2(0.68,0.48)],
		[Vector2(0.73,0.36),Vector2(0.74,0.23),Vector2(0.72,0.19)],
		[Vector2(0.77,0.23),Vector2(0.82,0.13),Vector2(0.87,0.06)]
	],"shade_color",true)
	_plane(Vector2(0.59,0.70),[
		[Vector2(0.42,0.82),Vector2(0.19,0.84),Vector2(0.00,0.79)],
		[Vector2(0.11,0.89),Vector2(0.35,0.93),Vector2(0.49,0.84)],
		[Vector2(0.47,0.79),Vector2(0.55,0.74),Vector2(0.59,0.70)]
	],"shade_color",true)
	_plane(Vector2(-0.75,0.38),[
		[Vector2(-0.62,0.57),Vector2(-0.49,0.65),Vector2(-0.35,0.68)],
		[Vector2(-0.49,0.69),Vector2(-0.65,0.63),Vector2(-0.69,0.59)],
		[Vector2(-0.68,0.68),Vector2(-0.57,0.75),Vector2(-0.52,0.79)],
		[Vector2(-0.72,0.73),Vector2(-0.79,0.53),Vector2(-0.75,0.38)]
	],"shade_color",true)
	_plane(Vector2(-0.24,-0.50),[
		[Vector2(-0.47,-0.50),Vector2(-0.65,-0.25),Vector2(-0.60,0.08)],
		[Vector2(-0.57,0.00),Vector2(-0.53,-0.10),Vector2(-0.50,-0.14)],
		[Vector2(-0.54,-0.20),Vector2(-0.42,-0.42),Vector2(-0.24,-0.50)]
	],"core_color",true)
	_plane(Vector2(-0.12,-0.59),[
		[Vector2(0.10,-0.66),Vector2(0.33,-0.52),Vector2(0.39,-0.36)],
		[Vector2(0.27,-0.47),Vector2(0.13,-0.51),Vector2(0.02,-0.49)],
		[Vector2(0.06,-0.53),Vector2(0.10,-0.54),Vector2(0.14,-0.55)],
		[Vector2(0.04,-0.59),Vector2(-0.04,-0.6),Vector2(-0.12,-0.59)]
	],"core_color",true)
	_plane(Vector2(0.43,-0.23),[
		[Vector2(0.58,-0.05),Vector2(0.57,0.20),Vector2(0.42,0.35)],
		[Vector2(0.48,0.21),Vector2(0.46,0.10),Vector2(0.45,0.07)],
		[Vector2(0.51,0.10),Vector2(0.51,0.12),Vector2(0.50,0.13)],
		[Vector2(0.53,-0.03),Vector2(0.46,-0.17),Vector2(0.43,-0.23)]
	],"core_color",true)
	_plane(Vector2(-0.29,0.45),[
		[Vector2(-0.11,0.62),Vector2(0.18,0.59),Vector2(0.34,0.44)],
		[Vector2(0.23,0.63),Vector2(0.05,0.66),Vector2(-0.10,0.61)],
		[Vector2(-0.16,0.57),Vector2(-0.25,0.49),Vector2(-0.29,0.45)]
	],"core_color",true)

func pulse_scale(time: float) -> float:
	return 1.0+config.pulse_amplitude*sin(TAU*config.pulse_rate*time)

func build_commands(at_age: float = -INF, stopped_at: float = -1.0) -> Array:
	if at_age == -INF:
		at_age = age
		stopped_at = stop_at
	var amount := envelope(at_age,stopped_at,config.dissipate_seconds)
	var commands: Array = []
	var radius := config.radius*config.size*amount
	if radius < 0.3: return commands
	if _planes.is_empty(): _build_planes()
	var scale_value := radius*pulse_scale(at_age)
	for plane in _planes:
		if plane.accent and config.accent_strength < 0.02: continue
		var points := PackedVector2Array()
		var center := Vector2.ZERO
		if plane.accent:
			for point in plane.points: center += point
			center /= plane.points.size()
		for point in plane.points:
			var shaped: Vector2 = center+(point-center)*config.accent_strength if plane.accent else point
			points.append(shaped*scale_value)
		commands.append({"points":points,"color":config.get(plane.palette)})
	return commands
