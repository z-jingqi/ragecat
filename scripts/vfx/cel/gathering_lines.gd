extends "res://scripts/vfx/cel/charge_component.gd"
## Full-circle, independently staggered inward needles; never a rotating emitter.
const Config = preload("res://scripts/vfx/cel/gathering_lines_config.gd")
@export var settings: Config = Config.new()
var config: Config = Config.new()

func _ready() -> void:
	if not _configured: configure(settings)

func configure(value: Config) -> void:
	config = value.duplicate(true) if value != null else Config.new()
	config.sanitize()
	_configured = true
	queue_redraw()

## Event-local hash, independent of engine/global RNG and evaluation order.
func noise(value: int) -> float:
	var n := (value*1103515245+12345)&0x7fffffff
	n = ((n^(n>>11))*48271)&0x7fffffff
	return float(n)/2147483647.0

func sample_line(index: int, time: float) -> Dictionary:
	if not is_finite(time) or time < 0: return {"active":false}
	# Each lane has its own clock. Density fills idle gaps, not a circular comb.
	var lane := config.seed*977+index*1999
	var period := lerpf(config.lifetime_max*1.18,config.lifetime_max*2.15,noise(lane+17))/config.density
	period = maxf(period,config.lifetime_max)
	var phase := noise(lane+31)*period
	var clock := time*config.speed+phase
	var cycle := floori(clock/period)
	var event := lane+cycle*7919
	var duration := lerpf(config.lifetime_min,config.lifetime_max,noise(event+53))
	var elapsed := fposmod(clock,period)
	if elapsed >= duration: return {"active":false}
	var life := elapsed/duration
	# A new random group center each cycle, plus broad irregular intra-group gaps.
	# No sector quantization: every angle in the full circle remains possible.
	var group := floori(index/3.0)
	var angle := noise(config.seed*37+group*2017+cycle*7919)*TAU+(noise(event+89)-0.5)*0.7
	var direction := Vector2.from_angle(angle)
	var spawn := lerpf(config.spawn_radius_min,config.spawn_radius_max,noise(event+107))
	var radius := lerpf(spawn,config.end_radius,pow(life,1.16))
	var strength := smoothstep(0,0.09,life)*(1.0-smoothstep(0.78,1.0,life))
	var length := lerpf(config.length_min,config.length_max,pow(noise(event+131),1.4))*strength
	var width := lerpf(config.width_min,config.width_max,noise(event+173))*strength
	return {"active":true,"life":life,"direction":direction,"radius":radius,
		"length":length,"width":width,"tone":noise(event+211),
		"start":(cycle*period-phase)/config.speed,"event":event}

func build_commands(at_age: float = -INF, stopped_at: float = -1.0) -> Array:
	if at_age == -INF:
		at_age = age
		stopped_at = stop_at
	var amount := envelope(at_age,stopped_at,config.dissipate_seconds)
	var commands: Array = []
	if amount <= 0: return commands
	for i in range(config.line_count):
		var line := sample_line(i,at_age)
		if not line.active: continue
		if stopped_at >= 0 and at_age >= stopped_at and line.start > stopped_at: continue
		var length: float = line.length*amount*config.size
		var width: float = line.width*amount*config.size
		if length < 0.8 or width < 0.2: continue
		var direction: Vector2 = line.direction
		var normal := direction.orthogonal()
		var tip: Vector2 = direction*line.radius*config.size
		# Forward point faces the center. Short tapered shard, not a ribbon/trail.
		var points := PackedVector2Array([tip,tip+direction*length*0.58+normal*width*0.5,
			tip+direction*length,tip+direction*length*0.67-normal*width*0.5])
		var color: Color = config.core_color if line.tone < 0.57 else (config.body_color if line.tone < 0.86 else config.shade_color)
		commands.append({"points":points,"color":color})
	return commands
