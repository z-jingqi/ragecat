shader_type canvas_item;
render_mode unshaded;
uniform sampler2D seam_map : filter_nearest, repeat_disable;
uniform float amount : hint_range(0.0,1.0) = 0.0;
uniform float breathing_phase = 0.0;
uniform float flow_phase = 0.0;
uniform float intensity = 1.0;
uniform float local_glow = 0.24;
uniform float flow_strength = 0.42;
uniform float breathing = 0.07;
uniform vec4 dark_color : source_color = vec4(0.447,0.086,0.133,1.0);
uniform vec4 seam_color : source_color = vec4(0.765,0.165,0.216,1.0);
uniform vec4 hot_color : source_color = vec4(0.969,0.451,0.376,1.0);
uniform bool markings_enabled = true;
uniform bool flow_enabled = true;
void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec3 out_rgb = original.rgb;
	if (amount > 0.0 && intensity > 0.0 && original.a > 0.0) {
		vec2 art = floor(UV * vec2(238.0,318.0)) + vec2(0.5);
		vec4 map = texture(seam_map, art / vec2(238.0,318.0));
		float reveal = smoothstep(map.g-0.075, map.g+0.075, amount) * step(0.005,map.r);
		float grain = fract(sin(dot(art,vec2(12.9898,78.233)))*43758.5453);
		float core = smoothstep(0.70+grain*0.05,0.86,map.r);
		float halo = pow(map.r,2.0) * local_glow;
		float heat = (0.38+amount*0.62) * reveal;
		float pulse = 1.0-breathing+breathing*sin(breathing_phase+map.b*1.4);
		float phase = fract(map.b - flow_phase + map.g*2.0);
		float flow = pow(max(0.0, 1.0-abs(phase-0.5)*7.0),2.0);
		flow *= smoothstep(0.62,1.0,amount) * step(0.65,map.a) * flow_strength;
		if (!flow_enabled) flow = 0.0;
		vec3 seam = mix(dark_color.rgb,seam_color.rgb,amount*0.8);
		seam = mix(seam,hot_color.rgb,flow);
		float ink = clamp(core*heat*pulse*intensity*(0.84+grain*0.16),0.0,0.82);
		out_rgb = mix(original.rgb,seam,ink);
		out_rgb += seam_color.rgb*(halo*heat*intensity*0.65 + flow*core*reveal*0.18);
		// Only the existing red glyph strip on the left drape. It never paints white cloth.
		float glyph_region = step(91.0,art.x)*step(art.x,108.0)*step(99.0,art.y)*step(art.y,147.0);
		float red_ink = smoothstep(0.13,0.27,original.r-max(original.g,original.b));
		float glyph = glyph_region * red_ink * smoothstep(0.38,0.95,amount);
		if (markings_enabled) out_rgb += seam_color.rgb * glyph * intensity * 0.25;
	}
	// The alpha channel and silhouette are immutable at every state.
	COLOR = vec4(clamp(out_rgb,vec3(0.0),vec3(1.0)),original.a);
}
