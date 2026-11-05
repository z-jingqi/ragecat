extends Resource
@export_range(4,16,1) var count:int=9
@export_range(36,100,1) var radius:float=66.0
@export_range(.6,1.5,.05) var size:float=1.0
@export_range(.025,.15,.005) var rise_time:float=.045
@export_range(.06,.8,.01) var hold_time:float=.32
@export_range(.18,.6,.01) var break_time:float=.32
@export_range(0,2,.1) var grit_density:float=.6
@export_range(0,5,.1) var residue_lifetime:float=2.4
@export_range(0,2,.1) var scatter:float=1.0
@export var primary:Color=Color("9a704c")
@export var highlight:Color=Color("d0a36c")
@export var shadow:Color=Color("473936")
func clean()->Resource:
 var p:Resource=duplicate(true)
 p.count=clampi(count,4,16)
 for item in [["radius",66,36,100],["size",1,.6,1.5],["rise_time",.045,.025,.15],["hold_time",.32,.06,.8],["break_time",.32,.18,.6],["grit_density",.6,0,2],["residue_lifetime",2.4,0,5],["scatter",1,0,2]]:
  var value:float=p.get(item[0]); p.set(item[0],clampf(value if is_finite(value) else float(item[1]),item[2],item[3]))
 for key in ["primary","highlight","shadow"]:
  var col:Color=p.get(key)
  p.set(key,col.clamp() if is_finite(col.r) and is_finite(col.g) and is_finite(col.b) and is_finite(col.a) else Color.WHITE)
 return p
func site_lifetime()->float: return rise_time+hold_time+break_time+residue_lifetime
func lifetime()->float: return .088+site_lifetime()
