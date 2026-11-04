extends Node2D
## Texture-independent alpha outline. Host owns frame, transform, state and time.
## Frame changes update shader uniforms immediately; no per-frame baking/readback.
const Profile = preload("halo_profile.gd")
const GlowShader = preload("alpha_halo.gdshader")
var profile: Resource
var amount: float = 0.0
var elapsed: float = 0.0
var active: bool = true
var source: Texture2D
var source_region: Rect2
var display_size: Vector2 = Vector2(76,76)
var portrait: Sprite2D
var glow: ColorRect
var shader_material: ShaderMaterial

func _init() -> void:
	glow=ColorRect.new(); glow.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shader_material=ShaderMaterial.new(); shader_material.shader=GlowShader
	glow.material=shader_material; add_child(glow)
	portrait=Sprite2D.new(); portrait.centered=true; portrait.region_enabled=true
	portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; portrait.region_filter_clip_enabled=true; add_child(portrait)
	configure(Profile.new())

func configure(settings: Resource) -> void:
	profile=settings.sanitized() if settings is Profile else Profile.new()
	shader_material.set_shader_parameter("width",profile.width)
	shader_material.set_shader_parameter("glow_color",profile.color)
	_layout(); _sync()

func set_frame(texture: Texture2D, region: Rect2 = Rect2(), size: Vector2 = Vector2(76,76)) -> bool:
	if texture == null: return false
	# Standard SpriteFrames AtlasTexture frames work without extracting new images.
	# Nonzero virtual margins or nested atlases require the host to resolve its anchor.
	if texture is AtlasTexture:
		if texture.atlas == null or texture.atlas is AtlasTexture or texture.margin != Rect2(): return false
		var frame: Rect2=texture.region
		if frame==Rect2(): frame=Rect2(Vector2.ZERO,texture.atlas.get_size())
		if region!=Rect2():
			if not Rect2(Vector2.ZERO,frame.size).encloses(region): return false
			frame=Rect2(frame.position+region.position,region.size)
		region=frame; texture=texture.atlas
	if not size.is_finite() or size.x<=0 or size.y<=0: return false
	var bounds=Rect2(Vector2.ZERO,texture.get_size())
	if region==Rect2(): region=bounds
	if not region.position.is_finite() or not region.size.is_finite() or region.size.x<1 or region.size.y<1: return false
	if not bounds.encloses(region): return false
	source=texture; source_region=region; display_size=size
	portrait.texture=source; portrait.region_rect=source_region
	portrait.scale=display_size/source_region.size
	shader_material.set_shader_parameter("source_texture",source)
	shader_material.set_shader_parameter("source_texel",Vector2.ONE/source.get_size())
	shader_material.set_shader_parameter("source_rect",Vector4(region.position.x/bounds.size.x,region.position.y/bounds.size.y,region.size.x/bounds.size.x,region.size.y/bounds.size.y))
	_layout(); _sync()
	return true

func set_flip(horizontal: bool, vertical: bool=false) -> void:
	portrait.flip_h=horizontal; portrait.flip_v=vertical
	shader_material.set_shader_parameter("flip_h",horizontal)
	shader_material.set_shader_parameter("flip_v",vertical)

func _layout() -> void:
	var padding: float=ceilf(profile.width)+1.0
	glow.position=-display_size*0.5-Vector2.ONE*padding
	glow.size=display_size+Vector2.ONE*padding*2
	shader_material.set_shader_parameter("padding",padding)
	shader_material.set_shader_parameter("display_size",display_size)

func start(value: float=0.0) -> void:
	active=true; elapsed=0.0; amount=clampf(value,0,1) if is_finite(value) else 0.0; _sync()
func set_amount(value: float) -> void:
	if not active or not is_finite(value): return
	amount=clampf(value,0,1); _sync()
func seek(seconds: float) -> void:
	if not active or not is_finite(seconds) or seconds<0: return
	elapsed=seconds; _sync()
func advance(delta: float) -> void:
	if not active or not is_finite(delta) or delta<0 or not is_finite(elapsed+delta): return
	elapsed+=delta; _sync()
func clear() -> void:
	active=false; amount=0; elapsed=0; _sync()
func _sync() -> void:
	var phase: float=fposmod(elapsed,1.0/profile.breathing_speed)*TAU*profile.breathing_speed if profile.breathing_speed>0 else 0.0
	var pulse: float=1.0-profile.breathing*(0.5+0.5*sin(phase))
	shader_material.set_shader_parameter("strength",amount*profile.intensity*pulse if active else 0.0)
	glow.visible=source!=null and active and amount>0 and profile.intensity>0
