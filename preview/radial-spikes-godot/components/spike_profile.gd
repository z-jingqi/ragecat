class_name RadialSpikeProfile
extends Resource
## Visual-only radial eruption. Distances are logical pixels, time is seconds.
@export_enum("Earth", "Ice", "Lightning", "Fire") var element:int=0
@export_range(1,6,1) var layers:int=3
@export_range(20,180,1) var radius:float=103.0
@export_range(12,60,1) var inner_radius:float=36.0
@export_range(0,.8,.01) var layer_delay:float=0.0
@export_range(0,1,.01) var layer_overlap:float=.145
@export_range(.3,2.0,.05) var density:float=1.0
@export_range(.4,2.0,.05) var spike_size:float=1.0
@export_range(.05,.5,.01) var rise_time:float=.075
@export_range(0,3,.05) var hold_time:float=.035
@export_range(.1,2,.05) var fade_time:float=.18
@export_range(0,1,.05) var irregularity:float=.7
@export_range(.35,1,.05) var ground_squash:float=.53
@export_range(0,2,.1) var debris_density:float=1.0
@export_range(0,1,.05) var ground_opacity:float=.7
@export_range(0,.5,.005) var onset_delay:float=.04
@export_range(0,2,.05) var impact_strength:float=1.25
@export_range(0,2,.1) var residue_density:float=1.0
@export_range(0,8,.1) var residue_lifetime:float=3.2
@export_range(.4,2,.1) var residue_size:float=1.0
@export_enum("Circle", "Sector", "Lanes") var shape:int=0
@export_range(-180,180,1) var direction_degrees:float=-90
@export_range(15,360,1) var sector_angle:float=100
@export_range(1,7,1) var lane_count:int=3
@export_range(0,300,1) var lane_spread:float=90
@export_range(20,160,1) var lane_length:float=110
@export_range(8,80,1) var lane_width:float=26
@export var lane_directions:PackedFloat32Array=[]
@export_enum("Outward", "Inward", "Vertical") var lightning_direction_mode:int=0
@export var primary:Color=Color("a97b51")
@export var highlight:Color=Color("e1b477")
@export var shadow:Color=Color("4a3940")
func clean()->Resource:
	var p:Resource=duplicate(true)
	p.element=clampi(element,0,3); p.layers=clampi(layers,1,6)
	p.radius=_safe(radius,103,20,180); p.inner_radius=_safe(inner_radius,36,12,minf(60,p.radius))
	p.layer_delay=_safe(layer_delay,0,0,.8); p.density=_safe(density,1,.3,2)
	p.spike_size=_safe(spike_size,1,.4,2); p.rise_time=_safe(rise_time,.075,.05,.5)
	p.hold_time=_safe(hold_time,.035,0,3); p.fade_time=_safe(fade_time,.18,.1,2)
	p.irregularity=_safe(irregularity,.7,0,1)
	p.layer_overlap=_safe(layer_overlap,.145,0,minf(p.fade_time,p.layer_span()*.49))
	p.ground_squash=_safe(ground_squash,.53,.35,1)
	p.debris_density=_safe(debris_density,1,0,2); p.ground_opacity=_safe(ground_opacity,.7,0,1)
	p.onset_delay=_safe(onset_delay,.04,0,.5); p.impact_strength=_safe(impact_strength,1.25,0,2)
	p.residue_density=_safe(residue_density,1,0,2); p.residue_lifetime=_safe(residue_lifetime,3.2,0,8)
	p.residue_size=_safe(residue_size,1,.4,2); p.shape=clampi(shape,0,2)
	p.direction_degrees=_safe(direction_degrees,-90,-180,180); p.sector_angle=_safe(sector_angle,100,15,360)
	p.lane_count=clampi(lane_count,1,7); p.lane_spread=_safe(lane_spread,90,0,300)
	p.lane_length=_safe(lane_length,110,20,160); p.lane_width=_safe(lane_width,26,8,80)
	var angles:PackedFloat32Array=[]
	for angle in lane_directions:
		if is_finite(angle) and angles.size()<7: angles.append(wrapf(angle,-180,180))
	p.lane_directions=angles
	if not angles.is_empty(): p.lane_count=angles.size()
	p.lightning_direction_mode=clampi(lightning_direction_mode,0,2)
	for key in ["primary","highlight","shadow"]:
		var c:Color=p.get(key)
		if not is_finite(c.r) or not is_finite(c.g) or not is_finite(c.b) or not is_finite(c.a): c=Color.WHITE
		p.set(key,c.clamp())
	return p
static func _safe(v:float,fallback:float,lo:float,hi:float)->float:
	return clampf(v if is_finite(v) else fallback,lo,hi)
func stagger_window()->float:
	return minf(.07,rise_time*.25)*irregularity
func layer_span()->float:
	return rise_time+hold_time+fade_time+stagger_window()
func layer_stride()->float:
	# A new ring begins while the old one is fading, never during its hold.
	# Half-span cap prevents a chain of three or more simultaneously alive rings.
	return layer_span()-minf(layer_overlap,minf(fade_time,layer_span()*.49))+layer_delay
func wave_lifetime()->float:
	return onset_delay+(layers-1)*layer_stride()+layer_span()
func residue_tail()->float:
	return residue_lifetime if element<2 and residue_density>0 else 0.0
func lifetime()->float:
	return wave_lifetime()+residue_tail()
