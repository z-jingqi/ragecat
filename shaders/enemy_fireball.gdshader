shader_type canvas_item;
render_mode unshaded;
uniform sampler2D flame_atlas : source_color, filter_linear, repeat_disable;
uniform vec2 atlas_grid = vec2(6.0, 4.0);
uniform float frame_count = 24.0;
uniform float surface_opacity = 1.0;
uniform float phase = 0.0;
uniform vec4 arena_rect = vec4(0.0);
varying vec2 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
vec4 sample_frame(float frame, vec2 uv) {
 vec2 cell = vec2(mod(frame, atlas_grid.x), floor(frame / atlas_grid.x));
 vec2 inset = 0.5 * atlas_grid / vec2(textureSize(flame_atlas, 0));
 return texture(flame_atlas, (cell + clamp(uv, inset, vec2(1.0)-inset)) / atlas_grid);
}
void fragment() {
 float current = mod(floor(phase), frame_count);
 vec4 a = sample_frame(current, UV);
 vec4 b = sample_frame(mod(current + 1.0, frame_count), UV);
 // Interpolate premultiplied samples to avoid dark edges on transparent folds.
 float alpha = mix(a.a, b.a, fract(phase));
 vec3 rgb = mix(a.rgb*a.a, b.rgb*b.a, fract(phase)) / max(alpha, 0.00001);
 alpha *= surface_opacity;
 if(arena_rect.z>0.0 && arena_rect.w>0.0 && (world_position.x<arena_rect.x || world_position.y<arena_rect.y || world_position.x>arena_rect.x+arena_rect.z || world_position.y>arena_rect.y+arena_rect.w)) alpha=0.0;
 COLOR = vec4(rgb, alpha);
}
