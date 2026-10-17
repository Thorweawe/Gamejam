class_name FloodFX
extends Node3D
## Sel efekti (disasters.gd kurar, Effects'in cocugu):
##  - akan camurlu su: nehre yakin yerde daha hizli akinti, akinti yonunde kopuk seritleri,
##    yagmur damlasi halkalari, hafif dalga (water shader, tum karolar tek malzeme)
##  - su nehirden disari dogru yayilarak yukselir, cekilirken ayni sirayla iner
##  - akintida suruklenen enkaz: sandik, kutuk, cop kovasi (sallanir, doner, sona gelince basa sarar)
##  - firtina: rastgele simsek (zikzak yildirim + gokyuzu flasi), gecikmeli gok gurultusu, koyulasan sis
## Kullanim: var fx := FloodFX.new(); effects.add_child(fx); fx.rise(tiles, level, river_z)
##           ... fx.drain()  (su cekilir, firtina biter, dugum kendini siler)

const M := "res://assets/models/"
const DEBRIS := 8

var river_z := 0.0
var level := 0.1

var _waters: Array[Node3D] = []
var _debris: Array[Dictionary] = []
var _x_range := Vector2(-40, 40)
var _storm := false
var _next_bolt := 2.0
var _sun_flash: DirectionalLight3D
var _thunder: AudioStreamPlayer
var _env: Environment
var _fog0 := 0.0
var _t := 0.0

static var _water_mat: ShaderMaterial
static var _bolt_mat: StandardMaterial3D
static var _thunder_stream: AudioStreamWAV


func _ready() -> void:
	_sun_flash = DirectionalLight3D.new()
	_sun_flash.light_color = Color(0.78, 0.85, 1.0)
	_sun_flash.light_energy = 0.0
	_sun_flash.rotation = Vector3(deg_to_rad(-70), deg_to_rad(30), 0)
	_sun_flash.shadow_enabled = false
	add_child(_sun_flash)
	_thunder = AudioStreamPlayer.new()
	_thunder.bus = "SFX"
	add_child(_thunder)
	if _thunder_stream == null:
		_thunder_stream = _make_thunder()
	var we := get_tree().get_first_node_in_group("world_env") as WorldEnvironment
	if we == null:
		var city := get_parent().get_parent()
		we = city.get_node_or_null("WorldEnvironment") as WorldEnvironment if city else null
	if we:
		_env = we.environment
		_fog0 = _env.fog_density


## Su basan karolar yukselir (nehirden uzaklastikca gecikmeli), enkaz suruklenir, firtina baslar.
func rise(tiles: PackedVector2Array, lvl: float, rz: float, debris := true) -> void:
	level = lvl
	river_z = rz
	var mat := _get_water_mat()
	mat.set_shader_parameter("river_z", rz)
	if not tiles.is_empty():
		_x_range = Vector2(INF, -INF)
	for p in tiles:
		_x_range = Vector2(minf(_x_range.x, p.x), maxf(_x_range.y, p.x))
		var w: Node3D = (load(M + "yol_zemin/flood_water_overlay.gltf") as PackedScene).instantiate()
		w.position = Vector3(p.x, -0.06, p.y)
		add_child(w)
		for mi in w.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = mat
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_waters.append(w)
		var delay := absf(p.y - rz) * 0.18 + randf() * 0.25  # nehirden disari yayilir
		w.create_tween().tween_property(w, "position:y", lvl + randf_range(-0.01, 0.01), 2.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(delay)
	if debris:
		for i in DEBRIS:
			_add_debris(i)
	set_storm(true)


## Su ceker (nehirden uzak yerler once kurur), enkaz batar, firtina diner, dugum silinir.
func drain(sec := 3.0) -> void:
	set_storm(false)
	for w in _waters:
		var far := clampf(absf(w.position.z - river_z) / 8.0, 0.0, 1.0)
		var tw := w.create_tween()
		tw.tween_interval((1.0 - far) * 1.2)
		tw.tween_property(w, "position:y", -0.06, sec).set_trans(Tween.TRANS_SINE)
	for d in _debris:
		var n: Node3D = d.node
		n.create_tween().tween_property(n, "scale", Vector3.ONE * 0.01, 1.5).set_delay(randf() * 1.0)
	var tw := create_tween()
	tw.tween_interval(sec + 1.4)
	tw.tween_callback(queue_free)


func set_storm(on: bool) -> void:
	_storm = on
	_next_bolt = randf_range(0.8, 2.0)
	if _env:
		create_tween().tween_property(_env, "fog_density", _fog0 * (1.8 if on else 1.0), 2.5)


func _exit_tree() -> void:
	if _env:
		_env.fog_density = _fog0


func _process(delta: float) -> void:
	_t += delta
	# akintida suruklenen enkaz
	for d in _debris:
		var n: Node3D = d.node
		var p: Vector3 = n.position
		p.x += d.speed * delta
		if p.x > _x_range.y + 1.0:
			p.x = _x_range.x - 1.0
			n.scale = d.scale
		p.z = river_z + d.lane + sin(_t * 0.7 + d.phase) * 0.3
		p.y = level + 0.03 + sin(_t * 2.3 + d.phase) * 0.025
		n.position = p
		n.rotation = Vector3(sin(_t * 1.7 + d.phase) * 0.15, n.rotation.y + d.spin * delta, cos(_t * 1.4 + d.phase) * 0.12)
	if _storm:
		_next_bolt -= delta
		if _next_bolt <= 0.0:
			_next_bolt = randf_range(2.5, 6.5)
			_lightning()


# ------------------------------------------------------------------ enkaz
func _add_debris(i: int) -> void:
	var n: Node3D
	match i % 4:
		0, 1:
			n = (load(M + "sokak/box_%s.gltf" % ("A" if i % 2 == 0 else "B")) as PackedScene).instantiate()
			n.scale = Vector3.ONE * 0.55
		2:
			n = (load(M + "sokak/trash_A.gltf") as PackedScene).instantiate()
			n.scale = Vector3.ONE * 0.6
		_:
			n = _log()
	add_child(n)
	n.position = Vector3(randf_range(_x_range.x, _x_range.y), level, river_z)
	n.rotation.y = randf() * TAU
	_debris.append({"node": n, "speed": randf_range(0.5, 1.1), "lane": randf_range(-0.6, 0.6), "phase": randf() * TAU,
		"spin": randf_range(-0.6, 0.6), "scale": n.scale})


func _log() -> Node3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.07
	c.bottom_radius = 0.08
	c.height = randf_range(0.7, 1.1)
	c.radial_segments = 7
	c.rings = 1
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.28, 0.16)
	c.material = m
	mi.mesh = c
	var root := Node3D.new()
	root.add_child(mi)
	mi.rotation.z = PI / 2.0  # yatik kutuk
	return root


# ------------------------------------------------------------------ simsek
func _lightning() -> void:
	# gokyuzu flasi: cift parlama (gercek simsek gibi titrek)
	var tw := create_tween()
	tw.tween_property(_sun_flash, "light_energy", 2.6, 0.05)
	tw.tween_property(_sun_flash, "light_energy", 0.4, 0.08)
	tw.tween_property(_sun_flash, "light_energy", 1.8, 0.05)
	tw.tween_property(_sun_flash, "light_energy", 0.0, 0.35)
	# yildirim: kameranin gordugu alanin uzak bir yerine zikzak cizgi
	var cam := get_viewport().get_camera_3d()
	var at := Vector3(randf_range(-30, 30), 0.0, river_z + randf_range(-20, -8))
	if cam:
		var fwd := -cam.global_transform.basis.z
		fwd.y = 0.0
		var side := cam.global_transform.basis.x
		at = cam.global_position * Vector3(1, 0, 1) + fwd.normalized() * randf_range(6.0, 16.0) + side * randf_range(-12.0, 12.0)
	var bolt := _bolt(at)
	add_child(bolt)
	var bt := bolt.create_tween()
	bt.tween_interval(0.12)
	bt.tween_property(bolt, "transparency", 1.0, 0.25)
	bt.tween_callback(bolt.queue_free)
	# gok gurultusu: uzakliga gore gecikmeli, perdesi rastgele
	get_tree().create_timer(randf_range(0.25, 1.1)).timeout.connect(func():
		if is_instance_valid(_thunder):
			_thunder.pitch_scale = randf_range(0.8, 1.1)
			_thunder.volume_db = randf_range(-6.0, -1.0)
			_thunder.play())


## Gokten yere zikzak serit (kameraya donuk, parlak -> parlama efektine girer), birkac dal.
func _bolt(at: Vector3) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cam := get_viewport().get_camera_3d()
	var right := cam.global_transform.basis.x if cam else Vector3.RIGHT
	_bolt_branch(st, at + Vector3(randf_range(-4, 4), 30.0, randf_range(-4, 4)), at, 0.12, right, 14, true)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _get_bolt_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _bolt_branch(st: SurfaceTool, from: Vector3, to: Vector3, width: float, right: Vector3, steps: int, main: bool) -> void:
	var prev := from
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var p := from.lerp(to, t)
		if i < steps:
			p += Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * 1.4 * (1.0 - t * 0.5)
		var w := width * (1.0 - t * 0.6)
		var a0 := prev - right * w
		var a1 := prev + right * w
		var b0 := p - right * w
		var b1 := p + right * w
		for v in [a0, b0, a1, a1, b0, b1]:
			st.add_vertex(v)
		if main and i > 2 and i < steps - 2 and randf() < 0.3:
			_bolt_branch(st, p, p + Vector3(randf_range(-5, 5), -randf_range(4, 8), randf_range(-5, 5)), w * 0.5, right, 5, false)
		prev = p


static func _get_bolt_mat() -> StandardMaterial3D:
	if _bolt_mat == null:
		_bolt_mat = StandardMaterial3D.new()
		_bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_bolt_mat.albedo_color = Color(0.85, 0.9, 1.0)
		_bolt_mat.emission_enabled = true
		_bolt_mat.emission = Color(0.7, 0.8, 1.0)
		_bolt_mat.emission_energy_multiplier = 6.0
		_bolt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_bolt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _bolt_mat


# ------------------------------------------------------------------ su malzemesi
static func _get_water_mat() -> ShaderMaterial:
	if _water_mat:
		return _water_mat
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;
uniform float river_z = 0.0;
varying vec3 wp;
float hash(vec2 p) {
	uvec2 q = uvec2(ivec2(floor(p)) + 32768);
	uint h = q.x * 1597334677u ^ q.y * 3812015801u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	return float(h & 0xffffu) / 65535.0;
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (sin(wp.x * 1.7 + TIME * 2.2) + cos(wp.z * 1.3 + TIME * 1.7)) * 0.006;
}
void fragment() {
	// akinti: nehre yakin hizli, kenarlarda yavas (+x yonunde denize)
	float near = 1.0 - smoothstep(1.0, 7.0, abs(wp.z - river_z));
	vec2 fp = wp.xz * vec2(0.55, 1.3) - vec2(TIME * (0.35 + 1.1 * near), 0.0);
	float n = noise(fp) * 0.6 + noise(fp * 2.1 + 9.0) * 0.4;
	// renkler dogrusal uzayda (sRGB degil): koyu camur kahvesi -> ekranda kahverengi gorunur
	vec3 mud = mix(vec3(0.1, 0.055, 0.02), vec3(0.22, 0.13, 0.05), n);
	vec3 col = mix(vec3(0.05, 0.085, 0.075), mud, 0.6 + 0.25 * near);
	// akinti yonunde uzayan kopuk seritleri
	float streak = smoothstep(0.66, 0.82, noise(fp * vec2(0.45, 3.2) + 3.0)) * (0.35 + 0.65 * near);
	// yagmur damlasi halkalari: her hucrede rastgele zamanda buyuyen halka
	vec2 g = wp.xz * 2.2;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float h = hash(cell + 17.0);
	float t = fract(TIME * 0.8 + h);
	vec2 c = vec2(hash(cell + 3.0), hash(cell + 7.0)) * 0.6 + 0.2;
	float ring = smoothstep(0.035, 0.0, abs(length(f - c) - t * 0.32)) * (1.0 - t);
	float foam = clamp(streak * 0.55 + ring * 0.7, 0.0, 1.0);
	ALBEDO = mix(col, vec3(0.62, 0.6, 0.52), foam);
	ROUGHNESS = 0.32 + foam * 0.5;
	SPECULAR = 0.15;
	ALPHA = mix(0.88, 0.96, foam);
}"""
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = sh
	return _water_mat


# ------------------------------------------------------------------ gok gurultusu (kodla uretilir)
## Basta keskin catirti, ardindan alcak frekansli, dalgalanarak sonen gumburtu.
static func _make_thunder() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 3.2)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var lp1 := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / rate
		var white := rng.randf() * 2.0 - 1.0
		lp1 = lerpf(lp1, white, 0.06)  # alcak geciren: gumburtu
		lp2 = lerpf(lp2, lp1, 0.12)
		var crack := white * exp(-t * 28.0) * 0.6
		var roll := 0.65 + 0.35 * sin(t * 7.0 + sin(t * 2.3) * 2.0)  # dalgali yuvarlanma
		var body := lp2 * 7.0 * exp(-t * 1.1) * roll * minf(1.0, t * 30.0)
		var v := clampf(crack + body, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s
