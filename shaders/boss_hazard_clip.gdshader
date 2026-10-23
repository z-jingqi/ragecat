shader_type canvas_item;
// World-space clipping changes presentation only. Hazard collision retains its
// original circle/annulus, rather than projecting out-of-bounds arcs onto walls.
uniform vec4 arena_rect = vec4(0.0);
varying vec2 hazard_world_position;
void vertex() {
	hazard_world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	if (arena_rect.z > 0.0 && arena_rect.w > 0.0) {
		vec2 end = arena_rect.xy + arena_rect.zw;
		if (hazard_world_position.x < arena_rect.x || hazard_world_position.y < arena_rect.y || hazard_world_position.x > end.x || hazard_world_position.y > end.y) {
			discard;
		}
	}
}
