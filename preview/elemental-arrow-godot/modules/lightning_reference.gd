extends RefCounted
# Original procedural interpretation of the approved lightning-arrow design.
# Sprite Fusion midpoint/fork and PixelFX 30Hz re-strike/core-priority methods
# inform the electrical inking; existing MIT notices are retained in licenses/.
const D=preload("drawing.gd")
const Wandering=preload("lightning_wandering.gd")
const EDGE=Color("075ac7")
const BLUE=Color("0c8df5")
const CYAN=Color("34caff")
const WHITE=Color("ffffff")
# Deliberately unequal lens lengths and off-axis crossings, keyed from the design.
const KNOTS_A=[Vector2(0,0),Vector2(.10,-.64),Vector2(.18,-.55),Vector2(.29,.72),Vector2(.40,.42),Vector2(.53,.54),Vector2(.67,.22),Vector2(.77,-.76),Vector2(.86,-.94),Vector2(.95,-.42),Vector2(1,0)]
const KNOTS_B=[Vector2(0,0),Vector2(.10,.78),Vector2(.19,1.05),Vector2(.29,.72),Vector2(.39,-.72),Vector2(.47,-1.05),Vector2(.56,-.66),Vector2(.67,.22),Vector2(.77,.80),Vector2(.86,1.02),Vector2(.94,.54),Vector2(1,0)]
static func contour(u:float,strand:int,_time:float=0.0)->float:
	var knots=KNOTS_A if strand==0 else KNOTS_B
	for i in range(knots.size()-1):
		if u<=knots[i+1].x:
			var f=(u-knots[i].x)/(knots[i+1].x-knots[i].x)
			return lerpf(knots[i].y,knots[i+1].y,smoothstep(0,1,f))
	return 0.0
static func signed_random(index:int,seed_value:int)->float:
	return D.random01(index,seed_value)*2.0-1.0
static func carrier_at(strike:int,length:float,width:float,a:Resource)->Dictionary:
	# A fresh paired path per strike, not a light travelling on a fixed spline.
	# Shared moving crossings keep three openings; each lobe redraws its bends.
	var v=a.arc_variation; var seed_i=a.seed_value; var id=strike*149
	var anchors=PackedVector2Array([Vector2.ZERO,
		Vector2(.29+.060*v*signed_random(id+1,seed_i),clampf(.72+.32*v*signed_random(id+2,seed_i),-1.08,1.08)),
		Vector2(.67+.060*v*signed_random(id+3,seed_i),clampf(.22+.32*v*signed_random(id+4,seed_i),-1.08,1.08)),Vector2(1,0)])
	var bases=[0.0,.29,.67,1.0]
	var paths=[PackedVector2Array(),PackedVector2Array()]; var depths=[PackedFloat32Array(),PackedFloat32Array()]
	var radius=5.95*length/96.0*a.size+width*.15
	for lobe in 3:
		for k in range(0 if lobe==0 else 1,5):
			var f=float(k)/4.0; var at=lerpf(bases[lobe],bases[lobe+1],f)
			var x=lerpf(anchors[lobe].x,anchors[lobe+1].x,f)
			var c=(contour(at,0)+contour(at,1))*.5
			var separation=absf(contour(at,0)-contour(at,1))*.5
			var crossing_shift=lerpf(anchors[lobe].y-contour(bases[lobe],0),anchors[lobe+1].y-contour(bases[lobe+1],0),f)
			c+=crossing_shift
			if k>0 and k<4:
				var key=id+lobe*17+k*3
				x+=(anchors[lobe+1].x-anchors[lobe].x)*.060*v*signed_random(key,seed_i+73)
				c+=.30*v*signed_random(key+1,seed_i+79)
				separation*=1.0+.40*v*signed_random(key+2,seed_i+83)
			if k>0 and k<4:
				separation=clampf(separation,.05,1.06)
				c=clampf(c,-1.12+separation,1.12-separation)
			for strand in 2:
				var side=-1.0 if (lobe+strand)%2==0 else 1.0
				var y=clampf(c+side*separation,-1.12,1.12)
				if k==0 or k==4: y=anchors[lobe if k==0 else lobe+1].y
				paths[strand].append(Vector2(lerpf(-length*.82,-length*.13,x),y*radius))
				depths[strand].append(0.0 if k==0 or k==4 else side*sin(f*PI))
	return {"paths":paths,"depths":depths,"anchors":anchors}
static func arcs_at(time:float,length:float,width:float,a:Resource)->Array:
	if not a.arc_wandering: return paired_arcs_at(time,length,width,a)
	if a.arc_density<=0 or a.intensity<=0: return []
	var result=[]
	for event in Wandering.schedule_at(time,a):
		if event.kind=="local": result.append(Wandering.local_arc(time,event,length,width,a))
		else:
			for arc in paired_arcs_at(time,length,width,a):
				arc.opacity*=Wandering.life_opacity(time,event)
				arc.id=event.id+arc.id; arc.kind="peak"; arc.birth=event.birth; arc.life=event.life
				result.append(arc)
	return result
static func paired_arcs_at(time:float,length:float,width:float,a:Resource)->Array:
	var result=[]
	if a.arc_density<=0 or a.intensity<=0: return result
	var tick=int(floor(time*a.arc_rate)); var shape_tick=int(floor(time*a.arc_path_rate))
	var carrier=carrier_at(shape_tick,length,width,a)
	var scale_factor=length/96.0
	var jitter_scale=minf(1.25,scale_factor)
	var head=-length*.13; var tail=-length*.82
	var subdivisions=clampi(ceili(length/64.0),1,4); var steps=12*subdivisions; var seed_value=a.seed_value
	for strand in 2:
		var seed_i=seed_value+strand*2017
		var points=PackedVector2Array(); var depths=PackedFloat32Array()
		for i in steps+1:
			var u=float(i)/steps
			var envelope=clampf(minf(u,1-u)*9,0,1)
			var leg=mini(i/subdivisions,11); var f=float(i-leg*subdivisions)/subdivisions
			var p:Vector2=carrier.paths[strand][leg].lerp(carrier.paths[strand][leg+1],f)
			var depth=lerpf(carrier.depths[strand][leg],carrier.depths[strand][leg+1],f)
			p.y+=(D.random01(i+tick*137,seed_i+19)*2-1)*.75*jitter_scale*a.size*a.arc_jitter*envelope
			if i>0:
				var middle=(points[-1]+p)*.5
				middle.y+=(D.random01(i+tick*151,seed_i+23)*2-1)*.85*jitter_scale*a.size*a.arc_jitter*envelope
				points.append(middle); depths.append((depths[-1]+depth)*.5)
			points.append(p); depths.append(depth)
		var segments=[]
		for i in range(points.size()-1):
			# Mostly connected silhouettes, with tiny dark/broken intervals and hot runs.
			var r=D.random01(i/2+tick*29,seed_i+41)
			var energy=0.0 if r<.025 and i>1 and i<points.size()-3 else .38 if r<.17 else 1.0
			var along=(float(i)+.5)/float(points.size()-1)
			var drift=.025*signed_random(shape_tick*37,seed_i+101)
			var hot=(strand==0 and along>.08+drift and along<.32+drift) or (strand==1 and along>.38+drift and along<.65+drift) or (strand==1 and along>.75-drift and along<.97-drift)
			var knot=hot and D.random01(i/3+int(tick/3)*7,seed_i+83)>.7
			var z0=depths[i]; var z1=depths[i+1]
			if z0*z1<0:
				var crossing=points[i].lerp(points[i+1],absf(z0)/(absf(z0)+absf(z1)))
				segments.append({"from":points[i],"to":crossing,"front":z0>=0,"energy":energy,"hot":hot,"knot":knot,"glow_point":i%3==0})
				segments.append({"from":crossing,"to":points[i+1],"front":z1>=0,"energy":energy,"hot":hot,"knot":knot,"glow_point":i%3==0})
			else: segments.append({"from":points[i],"to":points[i+1],"front":z0+z1>=0,"energy":energy,"hot":hot,"knot":knot,"glow_point":i%3==0})
		var forks=[]
		var branch_count=clampi(ceili(2*a.arc_forks),0,3)
		for slot in branch_count:
			var location=[.15,.52,.83][slot]+(.035 if strand==0 else -.035)
			location+=.10*(D.random01(slot+shape_tick*19,seed_i+59)*2-1)
			var index=clampi(int(location*(points.size()-1)),3,points.size()-4)
			var root=points[index]; var live_root=false
			for offset in [0,-1,1,-2,2]:
				var candidate=points[index+offset]
				for segment in segments:
					if segment.energy>0 and (segment.from.is_equal_approx(candidate) or segment.to.is_equal_approx(candidate)):
						root=candidate; index+=offset; live_root=true; break
				if live_root: break
			if not live_root: continue
			var side=1.0 if root.y>=0 else -1.0
			var direction=-1.0 if D.random01(slot+shape_tick*31,seed_i+61)<.5 else 1.0
			var end=root+Vector2(direction*(1.5+2*D.random01(slot+shape_tick*13,seed_i+63)),side*(2.0+3.5*D.random01(slot+shape_tick,seed_i+67)))*scale_factor*a.size
			end.x=clampf(end.x,tail,head)
			var middle=root.lerp(end,.43)+Vector2(-direction*1.3*scale_factor*a.size,0)
			middle.x=clampf(middle.x,tail,head)
			var elbow=root.lerp(end,.68)+Vector2(direction*.6*scale_factor*a.size,0)
			elbow.x=clampf(elbow.x,tail,head)
			var twig=PackedVector2Array()
			if slot==1:
				var twig_end=middle+Vector2(-direction*2.2,side*1.3)*scale_factor*a.size
				twig_end.x=clampf(twig_end.x,tail,head)
				twig=PackedVector2Array([middle,twig_end])
			forks.append({"points":PackedVector2Array([root,middle,elbow,end]),"twig":twig,"front":depths[index]>=0,"root_index":index})
		result.append({"id":strand,"carrier":carrier.paths[strand],"anchors":carrier.anchors,"points":points,"depths":depths,"segments":segments,"forks":forks,"opacity":minf(1,a.arc_density)*(.96+.04*D.random01(tick,seed_i+79))})
	return result
static func soft_glow(c:CanvasItem,at:Vector2,radius:float,color:Color,power:float)->void:
	# Only light is smooth. The hard arrow and electrical silhouette stay pixel-grid.
	for band in range(10,0,-1):
		c.draw_circle(at,radius*float(band)/10.0,Color(color,clampf(power*.012*(11-band)*color.a,0,.18)),true,-1,true)
static func draw_side(fx:Node2D,a:Resource,front_side:bool)->void:
	var key=[fx.age,fx.profile.length,fx.profile.width,a.size,a.intensity,a.arc_density,a.arc_forks,a.arc_jitter,a.arc_rate,a.arc_variation,a.arc_path_rate,a.arc_wandering,a.arc_activity,a.arc_lifetime,a.arc_flow_rate,a.seed_value]
	var cache=fx.get_meta("reference_lightning_cache",{})
	if cache.get("key",[])!=key:
		cache={"key":key,"events":arcs_at(fx.age,fx.profile.length,fx.profile.width,a)}
		fx.set_meta("reference_lightning_cache",cache)
	var events=cache.events
	# Each depth layer inks all fringes first, so later fringes never erase cores.
	for event in events:
		for segment in event.segments:
			if segment.front!=front_side or segment.energy<=0: continue
			if a.glow>0:
				for band in [7,5,3]:
					var alpha=.08 if band==7 else .14 if band==5 else .22
					D.local_line(fx,fx.pose,segment.from,segment.to,D.tinted(BLUE,a,alpha*a.glow*event.opacity*segment.energy),band)
				if segment.hot and segment.energy>.5 and segment.glow_point:
					var at=(segment.from+segment.to)*.5
					soft_glow(fx,D.point(fx.pose,at.x,at.y),maxf(2,fx.profile.length*.021)*a.size,D.tinted(Color("086eff"),a),1.2*a.glow*event.opacity)
			D.local_line(fx,fx.pose,segment.from,segment.to,D.tinted(EDGE,a,.65*event.opacity*segment.energy),5 if segment.knot and fx.profile.length>=192 else 3)
			D.local_line(fx,fx.pose,segment.from,segment.to,D.tinted(CYAN if segment.energy>.5 else BLUE,a,.9*event.opacity*segment.energy),4 if segment.knot and fx.profile.length>=192 else 3 if segment.hot and fx.profile.length>=96 else 2)
	for event in events:
		for segment in event.segments:
			if segment.front!=front_side or segment.energy<=0: continue
			var color=WHITE if segment.hot and segment.energy>.5 else CYAN if segment.energy>.5 else BLUE
			D.local_line(fx,fx.pose,segment.from,segment.to,D.tinted(color,a,event.opacity*(1.0 if front_side else .94)),3 if segment.knot and fx.profile.length>=192 else 2 if segment.hot and fx.profile.length>=96 else 1)
		for fork in event.forks:
			if fork.front!=front_side: continue
			for i in range(fork.points.size()-1):
				D.local_line(fx,fx.pose,fork.points[i],fork.points[i+1],D.tinted(BLUE,a,event.opacity*.30),2)
				D.local_line(fx,fx.pose,fork.points[i],fork.points[i+1],D.tinted(WHITE if i==0 else CYAN,a,event.opacity*(.95 if i==0 else .75)),1)
			if not fork.twig.is_empty(): D.local_line(fx,fx.pose,fork.twig[0],fork.twig[1],D.tinted(CYAN,a,event.opacity*.75),1)
