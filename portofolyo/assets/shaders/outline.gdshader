shader_type spatial;
// Ekran uzayinda kontur (map_visuals.gd kameranin onune tam ekran bir dortgen olarak koyar).
// Derinlik sicramalari (siluetler) ve keskin yuzey yonu degisimleri (bina koseleri, cati sirti)
// ince koyu cizgi olur. Duz zemin ve yumusak egriler cizgi uretmez.
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;
uniform vec3 line_color : source_color = vec3(0.09, 0.08, 0.14);
uniform float strength = 0.85;
uniform float thickness = 1.4;  // 1080p'de piksel
uniform float depth_threshold = 0.012;
uniform float normal_threshold = 0.4;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float depth_at(vec2 uv) {
	return texture(depth_tex, uv).r;
}

vec3 normal_at(vec2 uv) {
	return texture(normal_tex, uv).xyz * 2.0 - 1.0;
}

void fragment() {
	vec2 px = thickness * max(VIEWPORT_SIZE.y / 1080.0, 1.0) / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float d0 = depth_at(uv);
	float dl = depth_at(uv - vec2(px.x, 0.0));
	float dr = depth_at(uv + vec2(px.x, 0.0));
	float du = depth_at(uv - vec2(0.0, px.y));
	float dd = depth_at(uv + vec2(0.0, px.y));
	// ham derinlik duz yuzeylerde ekranda dogrusal degisir: laplasyen sadece sicramalarda buyur
	float lap = abs(dl + dr + du + dd - 4.0 * d0) / max(d0, 1e-5);
	float edge_d = smoothstep(depth_threshold, depth_threshold * 2.5, lap);

	vec3 n0 = normal_at(uv);
	float nd = 0.0;
	nd = max(nd, 1.0 - dot(n0, normal_at(uv + vec2(px.x, 0.0))));
	nd = max(nd, 1.0 - dot(n0, normal_at(uv + vec2(0.0, px.y))));
	float edge_n = smoothstep(normal_threshold, normal_threshold + 0.25, nd);

	float edge = max(edge_d, edge_n * 0.8);
	if (d0 <= 0.0) {
		edge = 0.0;  // gokyuzu
	}
	// uzaklastikca cizgi hafifler: tam haritada kucuk detaylar siyah noktaya donmesin
	vec4 view = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, d0, 1.0);
	float dist = -view.z / view.w;
	edge *= mix(1.0, 0.55, smoothstep(35.0, 110.0, dist));
	ALBEDO = line_color;
	ALPHA = edge * strength;
}
