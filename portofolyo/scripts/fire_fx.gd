class_name FireFX
extends Node3D
## Parcacikli yangin efekti: dalgalanan alev dilleri, havaya savrulan kivilcimlar, hacimli duman
## sutunu ve titreyen isik. Bina yangini, orman yangini ve menudeki yanan binalar kullanir.
##   var fx := FireFX.make(Vector3(0.6, 0.1, 0.6), 1.0); parent.add_child(fx); fx.position = ...
##   fx.stop()  -> alev soner, duman beyaz buhara doner, birkac saniye sonra kendini siler
## extents: alevlerin ciktigi kutunun yari boyutu; power: buyukluk (duman yuksekligi, isik, parcacik sayisi).
## Kaynaklar (shader, mesh, surec malzemeleri) tum yanginlarda paylasilir. Yavas makinede
## (graphics_quality seviye >= 3) parcacik sayisi azalir.

const GraphicsQuality := preload("res://scripts/graphics_quality.gd")

var extents := Vector3(0.6, 0.1, 0.6)
var power := 1.0
var light_energy := 2.6
var light_range := 3.0

var _flames: GPUParticles3D
var _embers: GPUParticles3D
var _smoke: GPUParticles3D
var _light: OmniLight3D
var _t := 0.0
var _stopping := false

static var _res := {}  # paylasilan kaynaklar


static func make(ext: Vector3, pwr := 1.0) -> FireFX:
	var fx := FireFX.new()
	fx.extents = ext
	fx.power = pwr
	return fx


## Alevi olan bir dugumu sondur: FireFX ise yavasca, degilse hemen silinir.
static func extinguish(n: Node) -> void:
	if not is_instance_valid(n):
		return
	if n is FireFX:
		(n as FireFX).stop()
	else:
		n.queue_free()


func _ready() -> void:
	_t = randf() * 10.0
	var q := 0.6 if GraphicsQuality.level >= 3 else 1.0
	var area := clampf((extents.x + extents.z) / 1.2, 0.6, 2.0)
	var top := extents.y + 0.2
	# alev dilleri
	_flames = _particles(_r("flame_proc"), _r("flame_mesh"), int(18 * area * q), 0.75)
	_flames.process_material = _flame_proc_for(extents)
	_flames.scale = Vector3.ONE * clampf(power, 0.6, 2.0)
	# kivilcimlar
	_embers = _particles(_r("ember_proc"), _r("ember_mesh"), int(22 * area * q), 1.8)
	_embers.position.y = top * 0.5
	# duman: alevlerin ustunden yukselir, ruzgarla hafif kayar
	_smoke = _particles(_r("smoke_proc"), _r("smoke_mesh"), int(16 * clampf(power, 0.7, 1.6) * q), 4.6)
	_smoke.position.y = top + 0.25
	_smoke.scale = Vector3.ONE * clampf(power, 0.7, 1.8)
	_smoke.preprocess = 1.5  # yangin basladiginda duman sutunu hemen gorunsun
	if light_energy <= 0.0:
		return  # isiksiz (yakindaki baska yangin zaten aydinlatiyor)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.52, 0.18)
	_light.omni_range = light_range * clampf(power, 0.8, 1.6)
	_light.light_energy = light_energy
	_light.position = Vector3(0, top * 0.6 + 0.3, 0)
	add_child(_light)


func _particles(proc: Material, mesh: Mesh, amount: int, life: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(4, amount)
	p.lifetime = life
	p.randomness = 0.4
	p.process_material = proc
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 12, 8))
	add_child(p)
	return p


func _process(delta: float) -> void:
	if _stopping or _light == null:
		return
	_t += delta
	# isik titremesi: iki farkli hizda dalga + kucuk gurultu (dumdum degil, canli)
	var f := 0.82 + sin(_t * 13.0) * 0.08 + sin(_t * 7.3 + 1.7) * 0.07 + randf() * 0.08
	_light.light_energy = light_energy * f * clampf(power, 0.8, 1.6)


## Sondurme: alev ve kivilcim kesilir, isik soner, duman beyaz buhara doner.
func stop() -> void:
	if _stopping:
		return
	_stopping = true
	_flames.emitting = false
	_embers.emitting = false
	_smoke.process_material = _r("steam_proc")
	_smoke.amount_ratio = 0.7
	var tw := create_tween()
	if _light:
		tw.tween_property(_light, "light_energy", 0.0, 0.6)
	tw.tween_interval(1.4)
	tw.tween_callback(func(): _smoke.emitting = false)
	tw.tween_interval(_smoke.lifetime)
	tw.tween_callback(queue_free)


# ------------------------------------------------------------------ paylasilan kaynaklar
## Billboard + parcacik donusu (ParticleProcessMaterial angle / scale) ortak tepe kodu.
const BILLBOARD := """
varying float vseed;
varying float vlife;
void vertex() {
	vseed = fract(float(INSTANCE_ID) * 0.6180339);
	vlife = INSTANCE_CUSTOM.y;
	mat4 m = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	m = m * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * m * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
"""
## Tam sayi hash'li deger gurultusu (sin-hash bazi GPU'larda dikis yapiyordu, bkz. ground.gdshader).
const NOISE := """
float hash(vec2 p) {
	uvec2 q = uvec2(ivec2(floor(p)) + 32768);
	uint h = q.x * 1597334677u ^ q.y * 3812015801u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	return float(h & 0xffffu) / 65535.0;
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
"""


static func _r(key: String) -> Resource:
	if _res.is_empty():
		_build_resources()
	return _res[key]


static func _flame_proc_for(ext: Vector3) -> ParticleProcessMaterial:
	var key := "flame_proc_%.2f_%.2f_%.2f" % [ext.x, ext.y, ext.z]
	if not _res.has(key):
		var p := (_r("flame_proc") as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		p.emission_box_extents = ext
		_res[key] = p
	return _res[key]


static func _build_resources() -> void:
	# --- alev: genisten sivriye damla bicimi, asagidan yukari akan gurultuyle dalgalanir.
	# Rengi parcacik omrune gore: beyaz-sari cekirdek -> turuncu -> koyu kirmizi -> sonuk.
	var flame_sh := Shader.new()
	flame_sh.code = "shader_type spatial;\nrender_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;\n" + NOISE + BILLBOARD + """
void fragment() {
	float seed = vseed * 17.0;
	vec2 uv = UV;
	float n = vnoise(vec2(uv.x * 3.0 + seed, uv.y * 2.5 + TIME * 3.2));
	float n2 = vnoise(vec2(uv.x * 6.0 - seed, uv.y * 5.0 + TIME * 5.0));
	uv.x += (n - 0.5) * 0.32 * (1.0 - uv.y);
	vec2 p = vec2((uv.x - 0.5) * 2.0, uv.y);
	float w = mix(0.08, 0.9, pow(p.y, 0.55));
	float body = 1.0 - smoothstep(w * 0.45, w, abs(p.x));
	body *= smoothstep(0.02, 0.35, p.y + (n2 - 0.5) * 0.25) * smoothstep(1.0, 0.72, p.y);
	float core = body * smoothstep(0.35, 0.95, p.y) * (1.0 - smoothstep(0.0, w * 0.6, abs(p.x)));
	vec3 col = mix(COLOR.rgb, vec3(1.0, 0.86, 0.45), core * 0.6);
	ALBEDO = col * (1.15 + core * 0.55);  // parlak ama beyaza patlamasin (parlama efekti)
	ALPHA = clamp(body * (0.75 + n2 * 0.5), 0.0, 1.0) * COLOR.a;
}"""
	var flame_mat := ShaderMaterial.new()
	flame_mat.shader = flame_sh
	flame_mat.render_priority = 1
	var flame_mesh := QuadMesh.new()
	flame_mesh.size = Vector2(0.62, 0.95)
	flame_mesh.center_offset = Vector3(0, 0.3, 0)
	flame_mesh.material = flame_mat
	_res["flame_mesh"] = flame_mesh
	var fp := ParticleProcessMaterial.new()
	fp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	fp.emission_box_extents = Vector3(0.6, 0.1, 0.6)
	fp.direction = Vector3.UP
	fp.spread = 12.0
	fp.initial_velocity_min = 0.5
	fp.initial_velocity_max = 1.1
	fp.gravity = Vector3(0, 1.2, 0)
	fp.damping_min = 0.5
	fp.damping_max = 1.0
	fp.angle_min = -12.0
	fp.angle_max = 12.0
	fp.scale_min = 0.7
	fp.scale_max = 1.35
	fp.scale_curve = _curve([Vector2(0, 0.35), Vector2(0.25, 1.0), Vector2(0.7, 0.8), Vector2(1, 0.1)])
	fp.color_ramp = _gradient([[0.0, Color(1.0, 0.85, 0.4, 0.0)], [0.12, Color(1.0, 0.72, 0.25, 1.0)],
		[0.5, Color(1.0, 0.42, 0.1, 0.95)], [0.85, Color(0.75, 0.16, 0.06, 0.6)], [1.0, Color(0.3, 0.08, 0.05, 0.0)]])
	_res["flame_proc"] = fp

	# --- kivilcim: kucuk parlak noktalar, girdapli (turbulans) yukselir, sonerek kizarir
	var ember_sh := Shader.new()
	ember_sh.code = "shader_type spatial;\nrender_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;\n" + BILLBOARD + """
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float a = exp(-d * d * 7.0) * smoothstep(1.0, 0.7, d);
	ALBEDO = COLOR.rgb * 3.0;
	ALPHA = a * COLOR.a;
}"""
	var ember_mat := ShaderMaterial.new()
	ember_mat.shader = ember_sh
	ember_mat.render_priority = 2
	var ember_mesh := QuadMesh.new()
	ember_mesh.size = Vector2(0.09, 0.09)
	ember_mesh.material = ember_mat
	_res["ember_mesh"] = ember_mesh
	var ep := ParticleProcessMaterial.new()
	ep.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ep.emission_box_extents = Vector3(0.5, 0.2, 0.5)
	ep.direction = Vector3.UP
	ep.spread = 30.0
	ep.initial_velocity_min = 1.2
	ep.initial_velocity_max = 2.6
	ep.gravity = Vector3(0.25, 0.5, 0.1)
	ep.damping_min = 0.4
	ep.damping_max = 1.0
	ep.turbulence_enabled = true
	ep.turbulence_noise_strength = 2.2
	ep.turbulence_noise_scale = 2.5
	ep.turbulence_noise_speed_random = 0.6
	ep.scale_min = 0.5
	ep.scale_max = 1.2
	ep.scale_curve = _curve([Vector2(0, 1.0), Vector2(1, 0.2)])
	ep.color_ramp = _gradient([[0.0, Color(1.0, 0.9, 0.55, 1.0)], [0.4, Color(1.0, 0.55, 0.15, 1.0)], [1.0, Color(0.8, 0.15, 0.05, 0.0)]])
	_res["ember_proc"] = ep

	# --- duman: hacimli gorunen yumusak bulutcuk (sahte kure normali -> gunes ve alev isigiyla golgelenir)
	var smoke_sh := Shader.new()
	smoke_sh.code = "shader_type spatial;\nrender_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;\n" + NOISE + BILLBOARD + """
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float seed = vseed * 31.0;
	float n = vnoise(p * 2.2 + seed + vec2(0.0, TIME * 0.25)) * 0.6 + vnoise(p * 4.5 - seed) * 0.4;
	float d = length(p) + (n - 0.5) * 0.45;
	float a = smoothstep(1.0, 0.15, d);
	// sahte hacim: kure normaliyle sol-ustten aydinlik, alt kenar golgeli (gunun isigindan bagimsiz,
	// mavi gokyuzu ortam isigi dumani soluklastirmasin)
	float r2 = clamp(dot(p, p), 0.0, 1.0);
	vec3 nrm = normalize(vec3(p.x, -p.y, sqrt(1.0 - r2) + 0.3));
	float shade = 0.62 + 0.5 * clamp(dot(nrm, normalize(vec3(-0.45, 0.7, 0.55))), 0.0, 1.0);
	vec3 col = COLOR.rgb * shade * (0.85 + n * 0.3);
	// alttan alev yansimasi: yeni cikan bulutcuklarin alt yuzu turuncu
	col += vec3(0.42, 0.15, 0.03) * pow(1.0 - clamp(vlife * 2.5, 0.0, 1.0), 2.0) * clamp(p.y + 0.3, 0.0, 1.0);
	ALBEDO = col;
	ALPHA = a * COLOR.a;
}"""
	var smoke_mat := ShaderMaterial.new()
	smoke_mat.shader = smoke_sh
	smoke_mat.render_priority = 0
	var smoke_mesh := QuadMesh.new()
	smoke_mesh.size = Vector2(1.05, 1.05)
	smoke_mesh.material = smoke_mat
	_res["smoke_mesh"] = smoke_mesh
	var sp := ParticleProcessMaterial.new()
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 0.3
	sp.direction = Vector3.UP
	sp.spread = 14.0
	sp.initial_velocity_min = 0.9
	sp.initial_velocity_max = 1.4
	sp.gravity = Vector3(0.16, 0.2, 0.08)  # hafif ruzgar
	sp.damping_min = 0.15
	sp.damping_max = 0.35
	sp.angle_min = 0.0
	sp.angle_max = 360.0
	sp.angular_velocity_min = -25.0
	sp.angular_velocity_max = 25.0
	sp.scale_min = 0.8
	sp.scale_max = 1.3
	sp.scale_curve = _curve([Vector2(0, 0.45), Vector2(0.4, 1.4), Vector2(1, 2.6)])
	sp.color_ramp = _gradient([[0.0, Color(0.16, 0.14, 0.13, 0.0)], [0.08, Color(0.17, 0.15, 0.14, 0.92)],
		[0.5, Color(0.3, 0.29, 0.29, 0.72)], [1.0, Color(0.5, 0.5, 0.52, 0.0)]])
	_res["smoke_proc"] = sp
	# sondurulunce: beyaz buhar, daha hizli yukselir ve dagilir
	var steam := sp.duplicate() as ParticleProcessMaterial
	steam.initial_velocity_min = 1.0
	steam.initial_velocity_max = 1.6
	steam.color_ramp = _gradient([[0.0, Color(0.92, 0.94, 0.96, 0.0)], [0.12, Color(0.92, 0.94, 0.96, 0.6)], [1.0, Color(0.95, 0.96, 0.98, 0.0)]])
	_res["steam_proc"] = steam


static func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	c.max_value = 3.0
	for p in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


static func _gradient(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	g.colors = PackedColorArray(stops.map(func(s): return s[1]))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
