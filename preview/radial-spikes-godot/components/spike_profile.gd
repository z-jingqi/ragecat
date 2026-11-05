class_name RadialSpikeProfile
extends Resource
## Visual-only radial eruption. Distances are logical pixels, time is seconds.
@export_enum("Earth", "Ice", "Lightning") var element:int=0
@export_range(1,6,1) var layers:int=3
@export_range(20,180,1) var radius:float=103.0
@export_range(12,60,1) var inner_radius:float=36.0
@export_range(0,.8,.01) var layer_delay:float=0.0
@export_range(0,1,.01) var layer_overlap:float=.24
@export_range(.3,2.0,.05) var density:float=1.0
@export_range(.4,2.0,.05) var spike_size:float=1.0
@export_range(.05,.5,.01) var rise_time:float=.14
@export_range(0,3,.05) var hold_time:float=.08
@export_range(.1,2,.05) var fade_time:float=.28
@export_range(0,1,.05) var irregularity:float=.7
@export_range(.35,1,.05) var ground_squash:float=.53
@export_range(0,2,.1) var debris_density:float=1.0
@export_range(0,1,.05) var ground_opacity:float=.7
@export var primary:Color=Color("a97b51")
@export var highlight:Color=Color("e1b477")
@export var shadow:Color=Color("4a3940")
func clean()->Resource:
	var p:Resource=duplicate(true)
	p.element=clampi(element,0,2); p.layers=clampi(layers,1,6)
	p.radius=_safe(radius,103,20,180); p.inner_radius=_safe(inner_radius,36,12,minf(60,p.radius))
	p.layer_delay=_safe(layer_delay,0,0,.8); p.density=_safe(density,1,.3,2)
	p.spike_size=_safe(spike_size,1,.4,2); p.rise_time=_safe(rise_time,.14,.05,.5)
	p.hold_time=_safe(hold_time,.08,0,3); p.fade_time=_safe(fade_time,.28,.1,2)
	p.irregularity=_safe(irregularity,.7,0,1)
	p.layer_overlap=_safe(layer_overlap,.24,0,minf(p.fade_time,p.layer_span()*.49))
	p.ground_squash=_safe(ground_squash,.53,.35,1)
	p.debris_density=_safe(debris_density,1,0,2); p.ground_opacity=_safe(ground_opacity,.7,0,1)
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
func lifetime()->float:
	return .1+(layers-1)*layer_stride()+layer_span()
