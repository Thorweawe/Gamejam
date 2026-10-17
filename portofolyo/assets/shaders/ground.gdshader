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
// duz nehir karolari (map_visuals.gd karo basina 1 yapar; kose karolarinda 0): karo duzlestirilir, su
// kanali karonun ortasindaki duz serit yerine kivrimli bir cizgiyi izler. Kivrim her karo sinirinda
// sifira iner -> kopru, kose karolari ve komsu karolarla kesintisiz birlesir.
instance uniform float meander = 0.0;
const float RIVER_HALF = 0.51;  // tile_river_straight kanal yari genisligi (modelden olculdu)
varying vec3 tile_c;
varying vec3 tile_x;
varying vec3 tile_z;
// arazi maskesi (map_gen.py): R orman, G dag. terrain > 0 iken cimen rengi karoya gore degil
// dunyaya gore hesaplanir -> komsu karolar arasinda dikis / kare kare ton farki olmaz.
uniform sampler2D terrain_mask : filter_linear, repeat_disable;
uniform float terrain = 0.0;
uniform float dirt_grass = 0.0;
uniform sampler2D sand_mask : filter_linear, repeat_disable;
// yangin izi (disasters.gd calisma aninda cizer): 1 yanmis (kul), ~0.45 sondurulmus (kavrulmus cimen)
uniform sampler2D burn_mask : filter_linear, repeat_disable;
uniform float use_burn = 0.0;
uniform float sand_blend = 0.0;  // 1: cim karosu, kum maskesi yuksekse kuma doner; 2: kum karosu, dusukse cime doner
uniform vec3 sand_col : source_color = vec3(0.79, 0.655, 0.505);  // kum karosunun isiklandirilmis rengiyle ayni  // 1: kahverengi toprak da cimen olur (dag karosu); patikalarda 0
// 1: duz (yukari bakan) yuzeyler de cimen sayilir. Dag karosunun haki dokusu ne cimen ne toprak diye
// taniniyordu ve oldugu gibi kaliyordu -> sehirle dag arasinda ayri renkte bir bant olusuyordu.
uniform float flat_grass = 0.0;
uniform vec3 meadow : source_color = vec3(0.55, 0.62, 0.36);

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
	if (meander > 0.0) {
		VERTEX.y = 0.1;  // kiyiyla ayni yukseklik (komsu karolarla basamak / nokta nokta dikis kalmasin); kanal basamagi kalkar: su ve kiyi ayni duzlemde, kivrimi shader cizer
		NORMAL = vec3(0.0, 1.0, 0.0);
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	tile_c = MODEL_MATRIX[3].xyz;
	tile_x = normalize(MODEL_MATRIX[0].xyz);
	tile_z = normalize(MODEL_MATRIX[2].xyz);
}

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	float big = fbm(wpos.xz * 0.16);
	float mid = fbm(wpos.xz * 0.85 + 5.0);
	float fine = noise(wpos.xz * 11.0);

	// yesil ve turkuaz (saha, dag etegi) yuzeyler cimen; belirgin mavi yuzeyler su
	float grass = smoothstep(0.06, 0.16, base.g - base.r) * smoothstep(-0.1, -0.02, base.g - base.b) * grass_amount;
	float water = smoothstep(0.1, 0.2, base.b - base.g) * smoothstep(0.15, 0.3, base.b - base.r);
	if (meander > 0.0) {
		// karo ekseni boyunca konum (karo merkezleri tek, sinirlari cift dunya koordinatinda)
		float along = dot(wpos, tile_z);
		float across = dot(wpos - tile_c, tile_x);
		float amp = 0.3 * (0.55 + 0.45 * noise(vec2(along * 0.3, 7.0)));
		float center = amp * sin(along * 1.5707963);  // her karo sinirinda 0
		float edge = (noise(wpos.xz * 2.2) - 0.5) * 0.12;  // patika gibi duzensiz kiyi
		float d = abs(across - center) - (RIVER_HALF + edge);
		water = 1.0 - smoothstep(-0.03, 0.03, d);
		grass = max(grass, 1.0 - water);  // kanaldan cikan kisim kiyi cimeni olur
	}

	// cimen: genis acik / koyu lekeler + kucuk kurumus ot alanlari + ince taneler
	vec3 g = mix(grass_dark, grass_light, smoothstep(0.3, 0.7, big)) * grass_shade;
	g = mix(g, g * vec3(1.15, 1.04, 0.62), smoothstep(0.62, 0.8, mid) * 0.4);
	float blades = noise(wpos.xz * vec2(36.0, 12.0)) * 0.6 + noise(wpos.xz * vec2(12.0, 36.0) + 9.0) * 0.4;
	g *= 1.0 + ((mid - 0.5) * 0.3 + (fine - 0.5) * 0.12 + (blades - 0.5) * 0.14) * variation;

	if (terrain > 0.0) {
		vec2 tuv = (wpos.xz - map_min) / map_size;
		vec3 tm = texture(terrain_mask, tuv).rgb;
		g *= mix(1.0, 0.8, tm.r);  // orman tabani hafif koyu
		vec3 md = meadow * (0.88 + 0.24 * big) * (1.0 + (fine - 0.5) * 0.1);
		// dag etegi cayir tonu: maske ~1.5 birim cevresinden ortalanir ve sadece daga yaklastikca
		// guclenir -> dag eteginden sehrin yesiline gecis 2 karoya yayilir (onceden sehir kenarinda keskin cizgi)
		vec2 o = vec2(1.5) / map_size;
		float mg = (tm.g * 2.0 + texture(terrain_mask, tuv + vec2(o.x, 0.0)).g + texture(terrain_mask, tuv - vec2(o.x, 0.0)).g
			+ texture(terrain_mask, tuv + vec2(0.0, o.y)).g + texture(terrain_mask, tuv - vec2(0.0, o.y)).g) / 6.0;
		mg += (big - 0.5) * 0.12;  // sinir duz bir cizgi degil, lekeli
		g = mix(g, md, smoothstep(0.3, 0.95, mg) * 0.9);
		// dag karosunun kahverengi topragi da ayni zemin rengini alir (kaya lekeleri kalir)
		float dirt = smoothstep(0.08, 0.16, base.r - base.b) * step(base.b, base.g) * (1.0 - grass) * dirt_grass;
		grass = max(grass, dirt);
		grass = max(grass, flat_grass * smoothstep(0.8, 0.95, normalize(wnormal).y));
	}
	vec3 dirt_col = vec3(0.0);
	float path = 0.0;
	if (terrain > 0.0) {
		// patika: maske gurultuyle kaydirilir -> kivrimli kenar, genislik yer yer degisir
		vec2 warp = vec2(noise(wpos.xz * 0.55 + 3.0), noise(wpos.xz * 0.55 + 41.0)) - 0.5;
		vec2 puv = (wpos.xz + warp * 0.55 - map_min) / map_size;
		float pm = texture(terrain_mask, puv).b;
		path = smoothstep(0.32, 0.5, pm + (fine - 0.5) * 0.12);
		dirt_col = mix(vec3(0.3, 0.18, 0.08), vec3(0.43, 0.28, 0.13), smoothstep(0.3, 0.75, mid));  // sicak toprak (dogrusal renk)
		dirt_col *= 1.0 + (fine - 0.5) * 0.18;
		dirt_col = mix(dirt_col * 0.72, dirt_col, smoothstep(0.5, 0.75, pm));  // kenarlar koyu (cimen bitimi)
	}
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

	col = mix(col, dirt_col, path);
	if (use_burn > 0.0) {
		vec2 bw = vec2(noise(wpos.xz * 0.7 + 11.0), noise(wpos.xz * 0.7 + 23.0)) - 0.5;
		float bm = texture(burn_mask, (wpos.xz + bw * 0.8 - map_min) / map_size).r;
		bm += (mid - 0.5) * 0.25 + (fine - 0.5) * 0.1;
		float scorch = smoothstep(0.12, 0.3, bm);  // kavrulmus: sari-kahve cimen
		float ash = smoothstep(0.55, 0.72, bm);  // tamamen yanmis: koyu kul
		vec3 dry = col * vec3(0.78, 0.62, 0.36);
		vec3 ash_c = mix(vec3(0.035, 0.03, 0.028), vec3(0.09, 0.075, 0.06), fine);
		ash_c += vec3(0.5, 0.12, 0.0) * smoothstep(0.93, 0.99, noise(wpos.xz * 6.0)) * ash;  // sonmekte olan korlar
		col = mix(col, dry, scorch);
		col = mix(col, ash_c, ash);
	}
	if (sand_blend > 0.0) {
		float sm = texture(sand_mask, (wpos.xz - map_min) / map_size).r;
		float edge = 0.5 + (big - 0.5) * 0.25 + (mid - 0.5) * 0.12;
		float to_sand = smoothstep(edge - 0.03, edge + 0.03, sm);
		vec3 sandc = sand_col * (1.0 + (fine - 0.5) * 0.06 + (mid - 0.5) * 0.05);
		vec3 grassc = mix(grass_dark, grass_light, smoothstep(0.3, 0.7, big)) * (1.0 + (mid - 0.5) * 0.25);
		if (sand_blend < 1.5) {
			col = mix(col, sandc, to_sand);
		} else {
			col = mix(grassc, col, to_sand);
		}
	}
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.88, 0.96, max(grass, path)), 0.12, water);
	SPECULAR = mix(0.25, 0.5, water);
}
