extends RefCounted
# Original scalable brown/gold arrow, proportioned from the approved concept.
const D=preload("drawing.gd")
static func render(c:CanvasItem,p:Dictionary,_t:float,q:Resource)->void:
	var l=q.length; var w=q.width; var tint=q.body_tint
	var feather=l*.145; var head=l*.13; var collar=-l+feather
	var shaft=maxf(1,roundf(l*.012))*w; var band=maxf(1,roundf(l*.012))*w
	var dark=Color("36211a")*tint; var brown=Color("875137")*tint
	var gold=Color("c88b56")*tint; var light=Color("f1d4ac")*tint
	D.local_line(c,p,Vector2(-l,0),Vector2(-head*.55,0),dark,shaft+w)
	D.local_line(c,p,Vector2(-l,0),Vector2(-head*.55,0),brown,shaft)
	D.local_line(c,p,Vector2(-l+2,-shaft*.5),Vector2(-head*.65,-shaft*.5),Color("a67a57")*tint,w)
	for i in 12:
		var x=lerpf(collar+3,-head-3,float(i)/11)
		D.local_line(c,p,Vector2(x,-shaft*.5),Vector2(x+1.2,-shaft*.5),Color("dbc19d")*tint,w)
	# Stable original grain and broken warm reflections; no flat cream shaft bar.
	for x in range(int(collar+band*2),int(-head-2)):
		var n=D.random01(x,947)
		if n<.25: D.dot(c,D.point(p,x,0),brown.lerp(gold,.28),w)
		if n>.84: D.dot(c,D.point(p,x,-shaft*.5),light.darkened(.16),w)
	D.local_line(c,p,Vector2(collar+band*2,shaft*.5),Vector2(-head,shaft*.5),Color("4b2c22")*tint,w)
	for side in [-1,1]:
		var rise=feather*.32*w
		D.polygon(c,p,[Vector2(-l-1,side*rise),Vector2(-l+feather*.38,side*rise*.88),Vector2(collar+1,side*w),Vector2(-l+feather*.37,side*w)],dark)
		for barb in 4:
			var x=-l+float(barb)*feather*.19
			var height=rise*(1-float(barb)*.12)
			D.polygon(c,p,[Vector2(x,side*height),Vector2(x+feather*.18,side*height),Vector2(x+feather*.43,side*w),Vector2(x+feather*.25,side*w)],light if side<0 else gold)
			D.local_line(c,p,Vector2(x,side*height),Vector2(x+feather*.27,side*w),Color("fff0d2")*tint if side<0 else light,w)
		for barb in 4:
			var x=-l+float(barb)*feather*.19; var height=rise*(1-float(barb)*.12)
			D.local_line(c,p,Vector2(x+feather*.18,side*height),Vector2(x+feather*.43,side*w),brown,w)
			D.local_line(c,p,Vector2(x+feather*.09,side*height*.95),Vector2(x+feather*.34,side*w),gold,w)
	D.local_line(c,p,Vector2(collar+band*.5,-shaft),Vector2(collar+band*.5,shaft),dark,band+2*w)
	D.local_line(c,p,Vector2(collar+band*.5,-shaft*.7),Vector2(collar+band*.5,shaft*.7),gold,band)
	D.local_line(c,p,Vector2(collar+band*.5,-shaft*.7),Vector2(collar+band*.5,0),light,band)
	D.local_line(c,p,Vector2(collar+band*1.8,-shaft*.7),Vector2(collar+band*1.8,shaft*.7),light,w)
	var rise=head*.30*w
	D.polygon(c,p,[Vector2(1,0),Vector2(-head,-rise),Vector2(-head*.80,0),Vector2(-head,rise)],dark)
	D.polygon(c,p,[Vector2(0,0),Vector2(-head+1,-rise+w),Vector2(-head*.70,0)],light)
	D.polygon(c,p,[Vector2(0,0),Vector2(-head*.70,0),Vector2(-head+1,rise-w)],brown)
	D.polygon(c,p,[Vector2(-head*.85,-rise*.65),Vector2(-head*.55,-rise*.28),Vector2(-head*.40,0),Vector2(-head*.70,0)],gold)
	D.polygon(c,p,[Vector2(0,0),Vector2(-head*.72,-rise*.28),Vector2(-head*.70,0)],Color("fff2d3")*tint)
	D.local_line(c,p,Vector2(-head*.73,0),Vector2(0,0),Color("fff2d3")*tint,w)
	D.local_line(c,p,Vector2(-head*.55,0),Vector2(-head*.85,rise*.65),gold,w)
	D.local_line(c,p,Vector2(-head,-w),Vector2(-head,w),brown,2*w)
