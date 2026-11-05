extends SceneTree
const FX=preload("../components/radial_spikes.gd")
const Profile=preload("../components/spike_profile.gd")
var failures:int=0
var checks:int=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void: call_deferred("run")
func run()->void:
	var p:Resource=Profile.new(); var fx:Node2D=FX.new(); root.add_child(fx); fx.configure(p); fx.play(Vector2(20,30),17)
	check(fx.position==Vector2(20,30),"center anchored at provided host position")
	check(fx.spikes.size()>=40 and fx.spikes.size()<=60,"bounded default density")
	check(fx.canvases.size()==fx.spikes.size(),"one sorted canvas per spike")
	var first:Array[Dictionary]=fx.spikes.duplicate(true)
	fx.play(Vector2(20,30),17); check(fx.spikes==first,"seed replay exact")
	fx.play(Vector2.ZERO,18); check(fx.spikes!=first,"seed changes ring layout")
	fx.play(Vector2.ZERO,17)
	for layer in p.layers:
		var begin:float=100; var end:float=-1; var radii:Array[float]=[]
		for spike in fx.spikes:
			if spike.layer!=layer: continue
			begin=minf(begin,spike.spawn); end=maxf(end,spike.spawn)
			var at:Vector2=spike.pos; radii.append(Vector2(at.x,at.y/p.ground_squash).length())
		check(end-begin>.002,"within-layer timing stagger %d"%layer)
		check(end<p.onset_delay+(layer+1)*p.layer_stride(),"strict radial wave sequence %d"%layer)
		check(radii.max()-radii.min()>1,"radius variation %d"%layer)
	fx.seek(p.onset_delay-.01); check(fx.active_layers().is_empty(),"before onset empty")
	fx.seek(p.onset_delay+.04); check(fx.active_layers()==[0],"inner layer first")
	fx.seek(p.onset_delay+p.layer_stride()+.03); check(fx.active_layers()==[0,1],"second layer later")
	fx.seek(p.onset_delay+2*p.layer_stride()+.03); check(fx.active_layers()==[1,2],"outer layer grows while middle layer fades")
	fx.seek(p.lifetime()+.01); check(fx.active_layers().is_empty(),"all effects expire")
	fx.seek(p.onset_delay+p.layer_stride()+.03); check(fx.active_layers()==[0,1],"reverse seek reconstructs")
	var before:float=fx.age; fx.advance(-1); fx.seek(NAN); check(fx.age==before,"invalid clock ignored")
	var count:Array[int]=[0]; fx.finished.connect(func(): count[0]+=1)
	fx.advance(10); fx.advance(10); check(count[0]==1 and not fx.running,"finish signal exactly once")
	fx.clear(); check(fx.canvases.is_empty() and fx.get_child_count()==0 and fx.spikes.is_empty(),"clear releases runtime canvases")
	for i in 50: fx.play(Vector2.ZERO,17+i); fx.clear()
	check(fx.get_child_count()==0,"repeated play clear no child growth")
	p.layers=99; p.radius=NAN; p.rise_time=INF; p.ground_squash=0; fx.configure(p)
	check(fx.profile.layers==6 and fx.profile.radius==103 and fx.profile.rise_time==.075 and fx.profile.ground_squash==.35,"invalid profile sanitized")
	p=Profile.new(); p.layers=1; p.density=.3; fx.configure(p); fx.play(Vector2.ZERO,17)
	check(fx.spikes.size()==4,"single sparse layer safe")
	p.primary=Color.RED; check(fx.profile.primary!=Color.RED,"profile copied per instance")
	for name in ["earth","ice","lightning","fire"]:
		var path:String="res://presets/"+name+".tres"
		if not ResourceLoader.exists(path): continue
		fx.configure(load(path)); fx.play(Vector2.ZERO,123); fx.seek(fx.profile.onset_delay+2*fx.profile.layer_stride()+fx.profile.stagger_window()+.03)
		check(fx.active_layers()==[1,2],name+" pulse moves outward without holding all three layers")
		check(fx.canvases[0].renderer.resource_path.ends_with(name+".gd"),name+" uses own renderer")
	# Regression: configure and seek must not revive stale completed geometry.
	fx.configure(Profile.new()); fx.play(Vector2.ZERO,17); fx.advance(10)
	var changed:Resource=Profile.new(); changed.layers=1; changed.primary=Color.RED
	fx.configure(changed); fx.seek(.12)
	check(fx.active_layers()==[0] and fx.canvases[0].profile.primary==Color.RED,"completed configure rebuilds retained geometry")
	fx.advance(10); fx.seek(10); fx.advance(1)
	check(not fx.running,"seeking beyond completion never leaves running forever")
	var limits:Resource=Profile.new(); limits.residue_lifetime=NAN; limits.residue_density=INF; limits.residue_size=-9; limits.shape=99; limits.lane_count=99; limits.lane_directions=PackedFloat32Array([NAN,540,-540]); limits.lightning_direction_mode=99
	var safe:Resource=limits.clean()
	check(safe.residue_lifetime==3.2 and safe.residue_density==1 and safe.residue_size==.4,"residue nonfinite and size values sanitized")
	check(safe.shape==2 and safe.lane_count==2 and safe.lane_directions==PackedFloat32Array([-180,-180]) and safe.lightning_direction_mode==2,"shape and explicit directions sanitized")
	fx.free()
	print("PASS" if failures==0 else "FAIL"," radial core: ",checks," assertions, ",failures," failures")
	quit(0 if failures==0 else 1)
