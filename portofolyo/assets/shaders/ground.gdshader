shader_type spatial;
// Zemin karolari ve daglar icin (map_visuals.gd uygular).
// Sehir paketinin atlas rengini okur; yesil yuzeyleri orman paketinin paletine ceker ve
// dunya koordinatli gurultuyle ton lekeleri ekler (karolar arasi dikis / "duz ucgen" gorunumu kaybolur).
// Mavi yuzeyler (nehir) denizle ayni renklerde, hafif akan su olur. Diger yuzeyler mat ve hafif desenli.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 grass_light : source_color = vec3(0.47, 0.69, 0.28);
uniform vec3 grass_dark : source_color = vec3(0.26, 0.47, 0.18);
uniform float grass_amount = 1.0;
uniform float grass_shade = 1.0;  // daglarda cimen biraz daha koyu
uniform float variation = 1.0;
// yesil olmayan yuzeyleri bu renge yaklastir (dag eteklerindeki soluk haki zemin)
uniform vec3 tint : source_color = vec3(0.5);
uniform float tint_amount = 0.0;
// deniz shader'iyla ayni (dogrusal) renkler
uniform vec3 water_deep = vec3(0.05, 0.36, 0.62);
uniform vec3 water_light = vec3(0.16, 0.66, 0.72);
// kiyi: denizin de kullandigi bulanik kara maskesi (0 deniz, 1 kara; karo kenari ~0.55).
// coast_cut > 0 ise maske bu degerin (+ dalgali gurultu) altinda kalan kisim oyulur: kare karolarin
// merdiven gibi kenari yerine yumusak, kivrimli bir kiyi cizgisi ve islak kum seridi olusur.
uniform sampler2D land_mask : filter_linear, repeat_disable;
uniform vec2 map_min;
uniform vec2 map_size = vec2(1.0);
uniform float coast_cut = 0.0;
// nehir karolari: maske nehri kara sayar; kiyi cizgisi nehrin iki yanindaki kumsaldan (z +-2) okunur
// ki nehir kumsalla ayni yerde bitip denize acilsin (suyun altindaki kum yatak da birlikte kesilir)
uniform float river_mode = 0.0;

varying vec3 wpos;
varying vec3 wnormal;

// tam sayi hash (sea.gdshader ile ayni): sin() tabanli hash bazi GPU'larda karo / hucre dikisi yapiyor
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

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.03 + 17.0) * 0.3 + noise(p * 4.1 + 31.0) * 0.15;
}

// sea.gdshader'daki ile ayni olmali (kopuk tam kumun bittigi yerde dursun)
float shore_wave(vec2 p) {
	return (noise(p * 0.33) - 0.5) * 0.08 + (noise(p * 1.4 + 3.0) - 0.5) * 0.03;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	float big = fbm(wpos.xz * 0.16);
	float mid = fbm(wpos.xz * 0.85 + 5.0);
	float fine = noise(wpos.xz * 11.0);

	// yesil ve turkuaz (saha, dag etegi) yuzeyler cimen; belirgin mavi yuzeyler su
	float grass = smoothstep(0.06, 0.16, base.g - base.r) * smoothstep(-0.1, -0.02, base.g - base.b) * grass_amount;
	float water = smoothstep(0.1, 0.2, base.b - base.g) * smoothstep(0.15, 0.3, base.b - base.r);

	// cimen: genis acik / koyu lekeler + kucuk kurumus ot alanlari + ince taneler
	vec3 g = mix(grass_dark, grass_light, smoothstep(0.3, 0.7, big)) * grass_shade;
	g = mix(g, g * vec3(1.15, 1.04, 0.62), smoothstep(0.62, 0.8, mid) * 0.4);
	float blades = noise(wpos.xz * vec2(36.0, 12.0)) * 0.6 + noise(wpos.xz * vec2(12.0, 36.0) + 9.0) * 0.4;
	g *= 1.0 + ((mid - 0.5) * 0.3 + (fine - 0.5) * 0.12 + (blades - 0.5) * 0.14) * variation;

	vec3 col = mix(base, tint * dot(base, vec3(0.3, 0.59, 0.11)) / 0.25, tint_amount);
	col *= 1.0 + (big - 0.5) * 0.18 * variation + (mid - 0.5) * 0.08 * variation + (fine - 0.5) * 0.05 * variation;
	col = mix(col, g, grass);

	// nehir: denizle ayni tonlar, akintiyla kayan parlak cizgiler
	float flow = sin(wpos.x * 0.9 + wpos.z * 1.6 + TIME * 1.4 + mid * 5.0) * 0.5 + 0.5;
	vec3 w = mix(water_deep, water_light, 0.2 + 0.4 * big);
	w += vec3(0.5, 0.55, 0.6) * smoothstep(0.93, 0.99, flow) * 0.25;
	col = mix(col, w, water);

	if (coast_cut > 0.0) {
		vec2 muv = (wpos.xz - map_min) / map_size;
		float m = texture(land_mask, muv).r;
		if (river_mode > 0.0) {
			vec2 dz = vec2(0.0, 2.0) / map_size;
			m = 0.5 * (texture(land_mask, muv + dz).r + texture(land_mask, muv - dz).r);
		}
		float e = m - (coast_cut + shore_wave(wpos.xz));
		// kiyidaki karolarin dik yan yuzleri de gizlenir: "yukselti / basamak" hissi kalmasin
		bool side = abs(normalize(wnormal).y) < 0.5 && m < 0.9;
		if (e < 0.0 || side) {
			discard;
		}
		// nehir agza yaklastikca deniz sigligiyla ayni renge karisir (akarak denize birlesir)
		col = mix(col, water_light * 1.1, water * (1.0 - smoothstep(0.0, 0.25, e)) * 0.7);
		// suya yakin kum islak ve koyu, en kenarda ince kopuk
		float wet = 1.0 - smoothstep(0.0, 0.09, e);
		col = mix(col, col * vec3(0.74, 0.72, 0.7), wet * 0.85);
		col = mix(col, vec3(0.92, 0.95, 0.97), (1.0 - smoothstep(0.0, 0.012, e)) * 0.75);
	}

	ALBEDO = col;
	ROUGHNESS = mix(mix(0.88, 0.96, grass), 0.12, water);
	SPECULAR = mix(0.25, 0.5, water);
}
