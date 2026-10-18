shader_type spatial;
// Agac ve calilar (map_visuals.gd uygular): orman paketinin atlas rengi + hafif ruzgar salinimi.
// Govde yere sabit kalir, tepe daha cok sallanir (yukseklige gore karesel). Her agac kendi konumuna gore
// farkli fazda sallanir (hepsi ayni anda sallanip "dalga" gibi gorunmez). Isik: digerleri gibi toon.
render_mode diffuse_toon, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float sway = 0.012;  // model biriminde, yukseklik^2 ile carpilir
uniform float speed = 1.0;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float ph = origin.x * 0.37 + origin.z * 0.29;
	float h = max(VERTEX.y, 0.0);
	float t = TIME * speed;
	// ana salinim + kucuk titreme (yapraklar) + yavas ruzgar dalgasi (sahne boyunca ilerleyen esinti)
	float gust = 0.6 + 0.4 * sin(t * 0.35 + origin.x * 0.08);
	float s = sin(t * 1.25 + ph) * 0.7 + sin(t * 2.7 + ph * 1.9) * 0.18;
	VERTEX.x += s * sway * h * h * gust;
	VERTEX.z += cos(t * 1.05 + ph * 1.3) * sway * 0.45 * h * h * gust;
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
	ROUGHNESS = 0.6;
}
