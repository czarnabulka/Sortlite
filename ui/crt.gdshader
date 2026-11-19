shader_type canvas_item;
// Old-monitor look for the 640×360 game picture: slight barrel curve,
// one scanline per source pixel row, a little glow, colour fringe and vignette.
// Runs on the scaled-up TextureRect, so scanlines have screen pixels to live in.

uniform bool enabled = true;
uniform vec2 source_size = vec2(640.0, 360.0);
uniform float curvature : hint_range(0.0, 0.3) = 0.05;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.18;
uniform float glow : hint_range(0.0, 1.0) = 0.3;
uniform float aberration : hint_range(0.0, 0.005) = 0.0003;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.25;

vec2 warp(vec2 uv) {
	vec2 c = uv * 2.0 - 1.0;
	c *= 1.0 + curvature * dot(c, c);
	return c * 0.5 + 0.5;
}

void fragment() {
	if (!enabled) {
		COLOR = texture(TEXTURE, UV);
	} else {
		vec2 uv = warp(UV);
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		} else {
			vec2 px = 1.0 / source_size;
			vec3 col;
			col.r = texture(TEXTURE, uv + vec2(aberration, 0.0)).r;
			col.g = texture(TEXTURE, uv).g;
			col.b = texture(TEXTURE, uv - vec2(aberration, 0.0)).b;

			vec3 blur = texture(TEXTURE, uv + vec2(px.x, 0.0)).rgb
					+ texture(TEXTURE, uv - vec2(px.x, 0.0)).rgb
					+ texture(TEXTURE, uv + vec2(0.0, px.y)).rgb
					+ texture(TEXTURE, uv - vec2(0.0, px.y)).rgb;
			col += blur * 0.25 * glow * 0.6;

			// Brightest in the middle of each source row, darker between rows.
			float line = 0.5 - 0.5 * cos(uv.y * source_size.y * 6.2831853);
			col *= 1.0 - scanline_strength * (1.0 - line);

			vec2 v = uv * (1.0 - uv);
			col *= pow(clamp(v.x * v.y * 16.0, 0.0, 1.0), vignette_strength);

			COLOR = vec4(col, 1.0);
		}
	}
}
