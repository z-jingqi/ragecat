extends RefCounted
## Original seam drawing in normalized portrait coordinates (238x318 art grid).
## Data, not painted animation frames. Static artist-authored geometry follows this portrait.
const SIZE = Vector2i(238, 318)
static var _cache: Texture2D

static func texture() -> Texture2D:
	if _cache != null: return _cache
	var image = Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	# [reveal order, flow weight, points]. First awaken the chest, then branch outward.
	var paths = [
		[0.08, 0.12, [[104,112],[107,117],[113,120],[120,121],[127,119],[133,115]]],
		[0.15, 0.12, [[106,123],[111,127],[117,129],[126,127],[132,123]]],
		[0.23, 0.14, [[108,131],[115,135],[121,134],[128,131]]],
		[0.28, 0.24, [[128,101],[131,105],[133,110],[136,113],[144,116],[151,118],[156,116]]],
		[0.34, 0.18, [[131,114],[133,119],[133,125],[130,130],[128,136]]],
		[0.40, 0.12, [[118,121],[119,126],[117,129]]],
		[0.46, 0.80, [[137,98],[145,99],[152,103],[154,108],[153,112]]],
		[0.53, 0.85, [[139,119],[141,125],[145,129],[150,131],[156,131]]],
		[0.60, 1.00, [[143,133],[147,137],[151,139],[156,138],[159,135]]],
		[0.66, 1.00, [[151,147],[154,149],[155,154],[153,157]]],
		[0.71, 1.00, [[160,146],[163,150],[164,155],[161,158],[157,158]]],
		[0.77, 1.00, [[150,161],[154,164],[159,165],[163,162]]],
		[0.82, 1.00, [[153,168],[158,171],[163,170],[165,166]]],
		[0.70, 0.25, [[118,119],[119,116],[117,114],[118,111]]],
		[0.81, 0.85, [[147,113],[146,110],[148,108],[147,105]]],
		[0.88, 0.80, [[149,130],[150,127],[148,125]]],
		[0.88, 0.70, [[153,176],[156,179],[161,180],[164,177]]],
		[0.63, 0.70, [[64,172],[68,173],[73,174],[77,172]]],
		[0.76, 0.80, [[64,178],[67,179],[68,183]]],
	]
	for path in paths:
		var pts: Array = path[2]
		var total: float = 0.0
		for i in range(1, pts.size()): total += Vector2(pts[i][0]-pts[i-1][0],pts[i][1]-pts[i-1][1]).length()
		var traveled: float = 0.0
		for i in range(1, pts.size()):
			var a = Vector2(pts[i-1][0], pts[i-1][1]); var b = Vector2(pts[i][0], pts[i][1])
			_segment(image, a, b, path[0], path[1], traveled, total)
			traveled += a.distance_to(b)
	_cache = ImageTexture.create_from_image(image)
	return _cache

static func _segment(image: Image, a: Vector2, b: Vector2, order: float, flow: float, traveled: float, total: float) -> void:
	var delta = b-a; var length_squared = delta.length_squared()
	for y in range(maxi(0, int(minf(a.y,b.y))-3), mini(SIZE.y, int(maxf(a.y,b.y))+4)):
		for x in range(maxi(0, int(minf(a.x,b.x))-3), mini(SIZE.x, int(maxf(a.x,b.x))+4)):
			var pt = Vector2(x+0.5,y+0.5)
			var u = clampf((pt-a).dot(delta)/maxf(length_squared,0.001),0,1)
			var d = pt.distance_to(a+delta*u)
			var strength = maxf(0.0, 1.0-d/3.0)
			if strength <= image.get_pixel(x,y).r: continue
			image.set_pixel(x,y,Color(strength, order, (traveled+delta.length()*u)/maxf(total,1.0), flow))
