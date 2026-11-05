extends Resource
## Independent single-spike study. Seconds and logical pixels.
@export_range(.6,1.5,.05) var size:float=1.0
@export_range(.025,.15,.005) var rise_time:float=.055
@export_range(.18,.9,.01) var hold_time:float=.46
@export_range(.04,.24,.01) var crack_time:float=.13
@export_range(.25,.7,.01) var break_time:float=.55
@export_range(0,2,.1) var shake_amount:float=1.05
@export_range(.03,.18,.01) var shake_time:float=.09
@export_range(0,.12,.005) var stagger:float=.055
@export_range(0,2,.1) var grit_density:float=.65
@export_range(0,5,.1) var residue_lifetime:float=2.2
@export_range(0,2,.1) var scatter:float=1.0
@export_range(.8,4,.1) var depth:float=2.5
@export_range(0,2,.1) var impact_strength:float=1.0
@export var primary:Color=Color("967454")
@export var highlight:Color=Color("c4a274")
@export var shadow:Color=Color("473b34")
func clean()->Resource:
 var p:Resource=duplicate(true)
 for item in [["size",1,.6,1.5],["rise_time",.055,.025,.15],["hold_time",.46,.18,.9],["crack_time",.13,.04,.24],["break_time",.55,.25,.7],["shake_amount",1.05,0,2],["shake_time",.09,.03,.18],["stagger",.055,0,.12],["grit_density",.65,0,2],["residue_lifetime",2.2,0,5],["scatter",1,0,2],["depth",2.5,.8,4],["impact_strength",1,0,2]]:
  var value:float=p.get(item[0]); p.set(item[0],clampf(value if is_finite(value) else float(item[1]),item[2],item[3]))
 p.crack_time=minf(p.crack_time,p.hold_time); p.shake_time=minf(p.shake_time,p.hold_time); p.stagger=minf(p.stagger,p.break_time*.3)
 for key in ["primary","highlight","shadow"]:
  var col:Color=p.get(key)
  p.set(key,col.clamp() if is_finite(col.r) and is_finite(col.g) and is_finite(col.b) and is_finite(col.a) else Color.WHITE)
 return p
func site_lifetime()->float: return rise_time+hold_time+break_time+residue_lifetime
func lifetime()->float: return .2+site_lifetime()
