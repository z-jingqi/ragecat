shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform float age = -1.0;
uniform float duration = 0.18;
uniform float extent = 51.0;
uniform float reach = 50.0;
uniform float thickness = 4.0;
uniform float expansion_ratio = 0.40;
uniform float hold_ratio = 0.10;
uniform int facets = 18;
uniform int shards = 12;
uniform float seed = 29.0;
uniform vec4 highlight_color : source_color = vec4(0.898, 0.984, 1.0, 1.0);
uniform vec4 body_color : source_color = vec4(0.514, 0.835, 0.906, 1.0);
uniform vec4 shade_color : source_color = vec4(0.224, 0.494, 0.667, 1.0);

float hash(float index) {
	return fract(sin(index * 127.1 + seed * 31.7) * 43758.5453);
}

void fragment() {
	// UV is local to the canvas item. Pixels travel with the effect/camera.
	vec2 p = floor((UV * 2.0 - 1.0) * extent) + vec2(0.5);
	float d = length(p);
	vec4 ink = vec4(0.0);
	// Conservative far-corner clipping: the WHOLE art pixel stays in actual radius.
	bool inside = length(abs(p) + vec2(0.5)) <= reach;
	if (age >= 0.0 && age < duration && inside) {
		float life = age / duration;
		float expand = clamp(life / expansion_ratio, 0.0, 1.0);
		float head = mix(min(reach * 0.20, 8.0), reach, 1.0 - pow(1.0 - expand, 2.0));
		float decay = clamp((life - expansion_ratio - hold_ratio) / (1.0 - expansion_ratio - hold_ratio), 0.0, 1.0);
		float angle = atan(p.y, p.x) + 3.14159265359;
		float sector = angle * float(facets) / 6.28318530718;
		float id = floor(sector);
		float part = fract(sector);
		float variation = hash(id + 3.0);
		// Short inward facets, asymmetric between sectors. One clear outer contour.
		float tooth = max(0.0, 1.0 - abs(part - (0.35 + variation * 0.25)) * 3.8);
		float width = thickness * (0.85 + tooth * (0.45 + variation * 0.50));
		float withdrawal = decay * (0.55 + variation * 0.70);
		float fragment_width = width * max(0.0, 1.0 - withdrawal);
		float gap = max(0.0, decay - 0.16) * (0.55 + variation * 0.26);
		bool segment = part > gap && part < 1.0 - gap * 0.80;
		float rim = head - 0.55;
		float depth = rim - d;
		if (segment && depth >= 0.0 && depth < fragment_width && decay < 0.88 + variation * 0.10) {
			ink = body_color;
			if (depth > fragment_width * 0.57 || decay > 0.65) ink = shade_color;
			if (depth < 1.1 && part < 0.70 && decay < 0.62) ink = highlight_color;
			// A narrow facet cleavage, not random per-frame noise.
			if (part > 0.76 && part < 0.86 && depth > 0.8) ink = shade_color;
		}
		// Sparse crystalline flecks peel inward from the passing rim, never beyond it.
		for (int i = 0; i < 24; i++) {
			if (i >= shards) break;
			float n = float(i);
			float a = (n + 0.20 + hash(n + 40.0) * 0.50) * 6.28318530718 / float(max(shards, 1));
			vec2 axis = vec2(cos(a), sin(a));
			float appear = expansion_ratio * (0.30 + hash(n + 60.0) * 0.28);
			float shard_age = clamp((life - appear) / (1.0 - appear), 0.0, 1.0);
			float shard_r = head * (0.78 + hash(n + 80.0) * 0.09) - shard_age * thickness * 0.8;
			vec2 q = p - axis * shard_r;
			float along = dot(q, axis);
			float across = dot(q, vec2(-axis.y, axis.x));
			float size = (1.1 + hash(n + 100.0) * 1.4) * (1.0 - shard_age);
			if (life > appear && shard_age < 0.82 && abs(along) / 1.8 + abs(across) < size) {
				ink = along > 0.0 && shard_age < 0.38 ? highlight_color : body_color;
				if (shard_age > 0.57) ink = shade_color;
			}
		}
	}
	COLOR = ink * COLOR;
}
