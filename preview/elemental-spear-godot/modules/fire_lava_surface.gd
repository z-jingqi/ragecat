extends RefCounted
## CPU adaptation of Hou Yi components/lava_surface.gdshader: same seeded value
## noise, warped Voronoi crust, broken edge, channel palette and carved front lip.
## Canvas-only renderer keeps the stage API stateless: no child nodes/materials
## survive Clear. Cache contains geometry only; host age drives flowing heat.
const G=preload("geometry.gd")
var cache_key=Vector3(-1,-1,-1)
var samples:Array=[]
var pixel_size=2.0
var seed_value=41.0
func hash2(p:Vector2)->float:
	return fposmod(sin(p.dot(Vector2(127.1,311.7))+seed_value*.91)*43758.5453,1.0)
func noise(p:Vector2)->float:
	var i=p.floor(); var f=p-i
	f=f*f*(Vector2.ONE*3.0-f*2.0)
	return lerpf(lerpf(hash2(i),hash2(i+Vector2.RIGHT),f.x),lerpf(hash2(i+Vector2.DOWN),hash2(i+Vector2.ONE),f.x),f.y)
func cells(p:Vector2)->Vector2:
	var i=p.floor(); var f=p-i; var d1=8.0; var d2=8.0
	for y in range(-1,2):
		for x in range(-1,2):
			var o=Vector2(x,y)
			var v=o+Vector2.ONE*.2+Vector2(hash2(i+o),hash2(i+o+Vector2.ONE*17.7))*.6-f
			var d=v.length_squared()
			if d<d1: d2=d1; d1=d
			else: d2=minf(d2,d)
	return Vector2(sqrt(d1),sqrt(d2)-sqrt(d1))
func prepare(radius:float,squash:float,seed_input:int)->void:
	var key=Vector3(radius,squash,seed_input)
	if key==cache_key: return
	cache_key=key; seed_value=seed_input; samples.clear()
	# Bound the grid to at most 164 by 164 for any sanitized stage size.
	pixel_size=maxf(2,ceilf(radius/80.0))
	var extent=ceilf(radius*1.2/pixel_size)
	for iy in range(-int(extent),int(extent)+1):
		for ix in range(-int(extent),int(extent)+1):
			var pos=Vector2(ix,iy)*pixel_size
			var q=pos/Vector2(1,squash)
			var n=noise(q*.055); var angle=q.angle()
			var edge=radius*(.88+.16*(noise(Vector2(cos(angle),sin(angle))*2.2+Vector2.ONE*5.7)-.5)+.10*sin(angle*3+seed_value)+.055*sin(angle*7-2)+.09*(n-.5))
			var depth=edge-q.length()
			if depth < -2: continue
			var warp=Vector2(noise(q*.06),noise(q*.06+Vector2.ONE*16))-Vector2.ONE*.5
			var cell=cells(q/15.0+warp*1.15)
			var vein=.26*(.72+.55*noise(q*.11))
			var fissure=1-smoothstep(vein*.66,vein,cell.y)
			fissure=maxf(fissure,smoothstep(.55,.72,noise(q*.045))*.9)
			samples.append([pos,q,n,depth,fissure,warp,q.length()/maxf(1,edge),cell.y,vein])
func render(n:Node2D,s:Dictionary,p:Resource,c:Resource,growth:float,cooling:float)->void:
	prepare(s.radius,p.ground_squash,p.seed_value)
	var flow=Vector2(s.age*.22,-s.age*.22*.35)
	for item in samples:
		if item[6]>growth: continue
		var q:Vector2=item[1]; var depth:float=item[3]
		var hot=clampf(item[4]-cooling*1.15,0,1)
		var palette=Color("29262b")*(.82+.32*floorf(item[2]*4)/3)
		palette.a=1
		if item[7]<item[8]*1.5: palette+=Color(.045,.022,.012,0)*(1-cooling)
		if hot>.01:
			var stream=noise(q*Vector2(.15,.20)+flow*1.2+item[5]*2)
			var molten=Color("632326") if stream<.28 else Color("ad3d2a")
			if stream>.68 and hot>.7: molten=molten.lerp(Color("e47737"),.8)
			palette=palette.lerp(molten,hot)
		if depth<3.5:
			palette=Color("140f14") if item[0].y<0 else Color("3b2626")
			if depth>1.4: palette=palette.lerp(Color("ad3d2a")*.8,(1-cooling)*.7)
		if depth<0: palette=Color("100d12")
		G.pixel(n,item[0],G.color(palette,c,s.fade*.94),pixel_size)
