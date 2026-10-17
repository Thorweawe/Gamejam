shader_type spatial;
// Deniz (city_map.tscn'deki gomulu shader'in yerine map_visuals.gd calisma aninda takar; malzeme
// parametreleri ayni kalir). Farki: kiyi cizgisi ground.gdshader'daki dalgali oymayla birebir ayni
// formulden hesaplanir; kopuk tam o cizgide ince ve "nefes alan" bir serit olur. Acik denizdeki
// kopuk seritleri de gurultuyle bukulur (karo merdiveni izi kalmaz).
uniform vec3 deep = vec3(0.02, 0.17, 0.42);
uniform vec3 mid = vec3(0.05, 0.36, 0.62);
uniform vec3 shallow = vec3(0.16, 0.66, 0.72);
uniform float light = 1.0;
uniform sampler2D land_mask : filter_linear, repeat_disable;
uniform vec2 map_min;
uniform vec2 map_size;
uniform float coast_cut = 0.63;  // map_visuals.gd COAST_CUT ile ayni olmali
// nehir agzi (map_visuals.gd doldurur): kara maskesi nehri kara saydigi icin kiyi kopugu agzi boydan
// boya kesiyordu (nehir kopuk duvarina carpiyormus gibi). Agizda kopuk bastirilir, nehrin acik turkuazi
// denize dogru yelpaze gibi acilarak karisir.
uniform float river_z = 0.0;
uniform float river_x0 = 100000.0;  // kiyinin nehri kestigi x (dogu kiyisi); varsayilan: agiz yok
varying vec3 wpos;
varying float wave;

float land(vec2 p) {
	vec2 uv = (p - map_min) / map_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { return 0.0; }
	return texture(land_mask, uv).r;
}

// ground.gdshader ile ayni gurultu (kiyi cizgisi iki shader'da ust uste otursun)
// tam sayi hash: sin() tabanli hash bazi GPU'larda komsu hucrelerde farkli sonuc verip keskin dikis yapiyor
float hash(vec2 p) {
	uvec2 q = uvec2(ivec2(p)) * uvec2(1597334673u, 3812015801u);
	uint n = (q.x ^ q.y) * 1597334673u;
	return float(n >> 8u) * (1.0 / 16777216.0);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// maskedeki keskin kenarli sig bolgeler kutu gibi gorunmesin: acik deniz rengi icin yumusatilmis maske
float land_soft(vec2 p) {
	float s = land(p) * 0.12;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 d = vec2(cos(a), sin(a));
		s += land(p + d * 1.5) * 0.055 + land(p + d.yx * vec2(-1.0, 1.0) * 3.2) * 0.055;
	}
	return s;
}

float shore_wave(vec2 p) {
	return (noise(p * 0.33) - 0.5) * 0.08 + (noise(p * 1.4 + 3.0) - 0.5) * 0.03;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float calm = 1.0 - land(wpos.xz) * 0.8;
	wave = sin(wpos.x * 0.45 + TIME * 1.1) * 0.5 + cos(wpos.z * 0.38 + TIME * 0.8) * 0.5;
	wave += sin((wpos.x + wpos.z) * 1.3 + TIME * 2.1) * 0.25;
	VERTEX.y += wave * 0.045 * calm;
}

void fragment() {
	// renk / acik deniz kopugu icin bukulmus maske
	vec2 warp = (vec2(noise(wpos.xz * 0.28), noise(wpos.xz * 0.28 + 7.3)) - 0.5) * 2.2;
	float m = land_soft(wpos.xz + warp);
	vec3 col = mix(deep, mid, smoothstep(0.0, 0.18, m));
	col = mix(col, shallow, smoothstep(0.12, 0.42, m));
	float ripple = sin(m * 60.0 - TIME * 2.2 + sin(wpos.x * 0.7) * 1.5) * 0.5 + 0.5;
	float foam = smoothstep(0.22, 0.34, m) * (1.0 - smoothstep(0.4, 0.5, m)) * smoothstep(0.6, 0.95, ripple);

	// kiyi kopugu: kumun bittigi cizgiye (bukulmemis maske) dayanan, gidip gelen ince serit
	float e = (coast_cut + shore_wave(wpos.xz)) - land(wpos.xz);  // > 0: su tarafi
	float reach = 0.035 + 0.02 * sin(TIME * 1.3 + wpos.x * 0.35 + wpos.z * 0.2);
	// kopuk sadece su tarafinda; kara tarafi (normalde kumun altinda, nehir agzinda gorunur) sig su
	foam += (1.0 - smoothstep(reach * 0.5, reach, e)) * smoothstep(-0.03, 0.0, e) * 0.95;
	col = mix(col, shallow * 1.15, (1.0 - smoothstep(0.0, 0.12, e)) * 0.45);  // kiyiya yakin acik turkuaz

	// nehir agzi: agzin genisligi denize dogru acilir; burada kiyi kopugu yok, nehir suyu yayilir
	float dx = wpos.x - river_x0;
	float spread = 1.1 + max(dx, 0.0) * 0.22;
	float plume = (1.0 - smoothstep(spread * 0.6, spread, abs(wpos.z - river_z + sin(wpos.x * 0.8 + TIME * 0.6) * 0.15)))
		* smoothstep(-4.0, -1.5, dx) * (1.0 - smoothstep(4.0, 9.0, dx));
	foam *= 1.0 - plume;
	col = mix(col, shallow * 1.2, plume * 0.6 * (1.0 - smoothstep(0.0, 14.0, dx)));
	// akinti cizgileri: nehirden denize uzanan hafif parlak seritler
	float flowline = smoothstep(0.85, 0.98, sin((wpos.z - river_z) * 7.0 + noise(wpos.xz * 0.6) * 2.0) * 0.5 + 0.5);
	col += vec3(0.05) * flowline * plume * smoothstep(-1.0, 3.0, dx);

	col = mix(col, vec3(0.95, 0.98, 1.0), clamp(foam, 0.0, 1.0) * 0.8);
	col += wave * 0.035;
	ALBEDO = col * light;
	ROUGHNESS = 0.2;
	SPECULAR = 0.45;
}
