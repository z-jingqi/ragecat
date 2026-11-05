extends SceneTree
const FX=preload("../components/radial_spikes.gd")
var failures:int=0
var checks:int=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void: call_deferred("run")
func run()->void:
	for name in ["earth","ice","lightning"]:
		var fx:Node2D=FX.new(); root.add_child(fx); fx.configure(load("res://presets/"+name+".tres")); fx.play(Vector2.ZERO,17)
		var p:Resource=fx.profile
		var starts:Array[float]=[]; var last_starts:Array[float]=[]
		for layer in p.layers:
			var first:float=INF; var last:float=-INF
			for s in fx.spikes:
				if s.layer==layer: first=minf(first,s.spawn); last=maxf(last,s.spawn)
			starts.append(first); last_starts.append(last)
		for layer in range(1,p.layers):
			var prior_fade:float=last_starts[layer-1]+p.rise_time+p.hold_time
			var prior_end:float=last_starts[layer-1]+p.rise_time+p.hold_time+p.fade_time
			check(starts[layer]>=prior_fade,name+" next layer waits until previous layer is fading")
			check(starts[layer]<prior_end-.04,name+" next layer visibly overlaps previous fade")
		var max_live:int=0
		for frame in ceili(p.lifetime()*120):
			fx.seek(float(frame)/120); max_live=maxi(max_live,fx.active_layers().size())
		check(max_live==2,name+" adjacent overlap without all three layers simultaneously filling")
		var q:Resource=p.duplicate(true); q.layer_overlap=0; fx.configure(q); fx.play(Vector2.ZERO,17)
		check(is_equal_approx(fx.profile.layer_stride(),fx.profile.layer_span()),name+" overlap zero is separately configurable")
		q.layer_overlap=.2; q.layer_delay=.4; fx.configure(q)
		check(fx.profile.layer_stride()>fx.profile.layer_span(),name+" additional delay is separately configurable")
		q.rise_time=.05; q.hold_time=0; q.fade_time=.1; q.irregularity=0; q.layer_overlap=NAN; fx.configure(q)
		check(fx.profile.layer_overlap<=fx.profile.layer_span()*.49,name+" nonfinite overlap is clamped to the timing budget")
		fx.free()
	print("PASS" if failures==0 else "FAIL"," layer overlap: ",checks," assertions, ",failures," failures")
	quit(0 if failures==0 else 1)
