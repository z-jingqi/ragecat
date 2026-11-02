shader_type canvas_item;
render_mode unshaded;
uniform vec4 flash_color : source_color = vec4(0.88,0.92,0.94,1.0);
uniform float amount : hint_range(0.0,1.0) = 0.0;
void fragment() {
 vec4 host = COLOR; // Godot 4 fragment COLOR already includes texture and modulation.
 COLOR = vec4(mix(host.rgb, flash_color.rgb, clamp(amount,0.0,1.0)), host.a);
}
