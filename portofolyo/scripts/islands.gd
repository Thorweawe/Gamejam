extends Node3D
## Ana adanin acigindaki mini adalar (CityMap'in cocugu, menude ve oyunda calisir).
## Harita tools/map_gen.py ile uretiliyor; adalar calisma aninda eklenir, sahne dosyasi degismez.
## Her ada: sig suda kumsal seridi, kayalik yamaclar ve yukseltili cimen tepe (oyunun alcak poligon
## tarzinda, duz golgeli). Tepede haritanin kendi agac / kaya / cali modelleri, bazilarinda fener ya da
## semsiye. Cevresinde dalgalanan kopuk + turkuaz sig su halkasi. Kiyi kara maskesinden bulunur
## (land_mask, bkz. map_gen.py), adalar ana adanin kiyisindan biraz acikta durur.
## Tekneler (wildlife.gd) adalarin icinden gecmesin diye adalar bitince avoid_islands cagrilir.

const COUNT := 7
const SEED := 4242  # adalar her acilista ayni yerde ve ayni bicimde
const SEGMENTS := 26  # alcak poligon kenar sayisi

const C_SAND := Color(0.93, 0.83, 0.62)
const C_WET := Color(0.78, 0.68, 0.5)
const C_ROCK := Color(0.55, 0.5, 0.45)
const C_ROCK_DARK := Color(0.42, 0.38, 0.35)
const C_GRASS := Color(0.38, 0.6, 0.27)
const C_GRASS_LIGHT := Color(0.45, 0.66, 0.3)

var spots: Array[Vector4] = []  # x, z, yaricap, tepe yuksekligi

var _rng := RandomNumberGenerator.new()
static var _mat: StandardMaterial3D
static var _shallow_mat: ShaderMaterial


func _ready() -> void:
	_rng.seed = SEED
	var city: Node = get_parent()
	var sea := city.get_node_or_null("Sea") as MeshInstance3D
	if sea == null or not (sea.mesh.material is ShaderMaterial):
		return
	var sm := sea.mesh.material as ShaderMaterial
	var tex := sm.get_shader_parameter("land_mask") as Texture2D
	if tex == null:
		return
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var mn: Vector2 = sm.get_shader_parameter("map_min")
	var sz: Vector2 = sm.get_shader_parameter("map_size")
	var land := func(p: Vector2) -> float:
		var uv := (p - mn) / sz
		if uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
			return 0.0
		var px := (uv * Vector2(img.get_size())).floor().clamp(Vector2.ZERO, Vector2(img.get_size()) - Vector2.ONE)
		return img.get_pixelv(Vector2i(px)).r
	var nature := _nature_sources(city.get_node_or_null("Nature"))
	var props := city.get_node_or_null("Props")
	for i in COUNT:
		var a := TAU * (i + _rng.randf_range(-0.25, 0.25)) / COUNT + 0.4
		var dir := Vector2(cos(a), sin(a))
		# merkezden disari yuru: kara bitince acikta, ana adaya degmeyecek uzaklikta dur
		var r := 20.0
		while r < 90.0 and land.call(dir * r) > 0.02:
			r += 1.0
		var radius := _rng.randf_range(2.3, 4.0)
		var at := dir * (r + radius * 1.9 + _rng.randf_range(2.0, 6.0))
		at.x = clampf(at.x, -58.0, 58.0)
		at.y = clampf(at.y, -54.0, 54.0)
		if land.call(at) > 0.01 or _too_close(at, radius):
			continue
		var h := _rng.randf_range(0.7, 1.7) * clampf(radius / 3.0, 0.75, 1.3)
		spots.append(Vector4(at.x, at.y, radius, h))
		_build_island(at, radius, h, nature, props, i)
	var wildlife := city.get_node_or_null("Wildlife")
	if wildlife and wildlife.has_method("avoid_islands"):
		wildlife.avoid_islands(spots)


func _too_close(p: Vector2, r: float) -> bool:
	for s in spots:
		if Vector2(s.x, s.y).distance_to(p) < s.z + r + 4.0:
			return true
	return false


## Haritadaki dogal modellerden ornekler (ayni olcekle kopyalanir: agac / kaya / cali boyu tutarli).
func _nature_sources(nature: Node) -> Dictionary:
	var out := {"tree": [], "rock": [], "bush": []}
	if nature == null:
		return out
	for n in nature.get_children():
		var nm := String(n.name)
		for k in out:
			if nm.begins_with(k + "_") and (out[k] as Array).size() < 24 and _rng.randf() < 0.35:
				out[k].append(n)
	return out


# ------------------------------------------------------------------ ada
func _build_island(at: Vector2, radius: float, h: float, nature: Dictionary, props: Node, index: int) -> void:
	var root := Node3D.new()
	root.name = "Islet%d" % index
	root.position = Vector3(at.x, 0.0, at.y)
	add_child(root)
	# kenar egrisi: birkac sinus dalgasi -> her ada farkli, yuvarlak degil
	var waves := []
	for k in 3:
		waves.append([_rng.randi_range(2, 5), _rng.randf() * TAU, _rng.randf_range(0.06, 0.16)])
	var shape := func(ang: float) -> float:
		var s := 1.0
		for w in waves:
			s += sin(ang * w[0] + w[1]) * w[2]
		return s
	# halkalar: [yaricap carpani, yukseklik, renk]; disaridan ice (sig su tabani -> tepe)
	var lean := Vector2(_rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.25, 0.25)) * radius  # tepe hafif yana kayik
	var rings := [
		[1.38, -0.35, C_WET, 0.0],
		[1.22, 0.07, C_SAND, 0.0],
		[1.08, 0.13, C_SAND, 0.15],
		[0.98, 0.22, C_ROCK_DARK, 0.3],
		[0.9, h * 0.55, C_ROCK, 0.6],
		[0.8, h, C_ROCK, 1.0],
		[0.74, h + 0.06, C_GRASS, 1.0],
		[0.4, h + 0.22, C_GRASS_LIGHT, 1.0],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0xFFFFFFFF)  # duz golge: oyunun alcak poligon tarzi
	var pts := []  # halka -> nokta listesi
	for ring in rings:
		var arr := []
		for s in SEGMENTS:
			var ang := TAU * s / SEGMENTS
			var jitter := _rng.randf_range(0.95, 1.05) if ring[1] > 0.2 else 1.0
			var rr: float = radius * ring[0] * shape.call(ang) * jitter
			var off: Vector2 = lean * ring[3]
			var y: float = ring[1] + (_rng.randf_range(-0.06, 0.06) if ring[1] > 0.3 else 0.0)
			arr.append(Vector3(cos(ang) * rr + off.x, y, sin(ang) * rr + off.y))
		pts.append(arr)
	for ri in rings.size() - 1:
		for s in SEGMENTS:
			var s2 := (s + 1) % SEGMENTS
			var a0: Vector3 = pts[ri][s]
			var a1: Vector3 = pts[ri][s2]
			var b0: Vector3 = pts[ri + 1][s]
			var b1: Vector3 = pts[ri + 1][s2]
			# ust halkanin rengi yuzeyi boyar (kumsal, kaya, cimen bantlari net ayrilir)
			var col: Color = rings[ri + 1][2]
			if ri + 1 == 4 or ri + 1 == 5:
				col = col.lerp(C_ROCK_DARK, _rng.randf() * 0.35)  # kaya yuzleri hafif farkli tonlarda
			_tri(st, a0, b0, a1, col)
			_tri(st, a1, b0, b1, col)
	# tepe kapagi
	var top: Array = pts[rings.size() - 1]
	var center := Vector3(lean.x, h + 0.28, lean.y)
	for s in SEGMENTS:
		_tri(st, top[s], center, top[(s + 1) % SEGMENTS], C_GRASS_LIGHT)
	st.generate_normals()
	st.set_material(_island_mat())
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	root.add_child(mi)
	_add_shallows(root, radius, shape)
	_decorate(root, radius, h, lean, nature, props, index)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for v in [c, b, a]:  # Godot on yuzu saat yonunde
		st.set_color(col)
		st.add_vertex(v)


## Tepeye agac / cali / kaya, bazi adalarda fener ya da kumsalda semsiye.
func _decorate(root: Node3D, radius: float, h: float, lean: Vector2, nature: Dictionary, props: Node, index: int) -> void:
	var top_r := radius * 0.62
	var trees := _rng.randi_range(2, 3 + int(radius))
	if index % 3 == 0 and props:
		# fenerli ada: ortada fener, cevresinde az agac
		var lh := _find_prop(props, "lighthouse_")
		if lh:
			var n := lh.duplicate() as Node3D
			n.position = Vector3(lean.x, h + 0.2, lean.y)
			n.rotation.y = _rng.randf() * TAU
			root.add_child(n)
			trees = 1
	for i in trees:
		_place(root, nature.tree, lean + _rand_in(top_r * 0.8), h + 0.18, _rng.randf_range(0.8, 1.15))
	for i in _rng.randi_range(1, 3):
		_place(root, nature.bush, lean + _rand_in(top_r), h + 0.15, 1.0)
	for i in _rng.randi_range(1, 3):  # yamaclarda ve kumsalda kayalar
		var ang := _rng.randf() * TAU
		var rr := radius * _rng.randf_range(1.0, 1.15)
		_place(root, nature.rock, Vector2(cos(ang), sin(ang)) * rr, 0.08, _rng.randf_range(0.8, 1.4))
	if index % 3 == 1 and props:
		var um := _find_prop(props, "umbrella")
		if um:
			var ang := _rng.randf() * TAU
			var n := um.duplicate() as Node3D
			n.position = Vector3(cos(ang) * radius * 1.13, 0.08, sin(ang) * radius * 1.13)
			root.add_child(n)


func _place(root: Node3D, pool: Array, p: Vector2, y: float, k: float) -> void:
	if pool.is_empty():
		return
	var src: Node3D = pool[_rng.randi() % pool.size()]
	var n := src.duplicate() as Node3D
	n.position = Vector3(p.x, y, p.y)
	n.rotation.y = _rng.randf() * TAU
	n.scale = src.scale * k
	root.add_child(n)


func _rand_in(r: float) -> Vector2:
	var a := _rng.randf() * TAU
	return Vector2(cos(a), sin(a)) * r * sqrt(_rng.randf())


func _find_prop(props: Node, prefix: String) -> Node3D:
	for n in props.get_children():
		if String(n.name).begins_with(prefix):
			return n
	return null


# ------------------------------------------------------------------ sig su + kopuk
## Adanin cevresinde: kumsala vuran beyaz kopuk (ice dogru akan dalgalar) ve disa dogru solan turkuaz sig su.
func _add_shallows(root: Node3D, radius: float, shape: Callable) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := SEGMENTS * 2
	var r0 := 1.12
	var r1 := 2.1
	for s in n:
		var a0 := TAU * s / n
		var a1 := TAU * (s + 1) / n
		var u0 := float(s) / n
		var u1 := float(s + 1) / n
		var p00: Vector3 = Vector3(cos(a0), 0, sin(a0)) * radius * r0 * shape.call(a0)
		var p01: Vector3 = Vector3(cos(a1), 0, sin(a1)) * radius * r0 * shape.call(a1)
		var p10: Vector3 = Vector3(cos(a0), 0, sin(a0)) * radius * r1 * lerpf(shape.call(a0), 1.0, 0.5)
		var p11: Vector3 = Vector3(cos(a1), 0, sin(a1)) * radius * r1 * lerpf(shape.call(a1), 1.0, 0.5)
		for v in [[p00, Vector2(u0, 0)], [p10, Vector2(u0, 1)], [p01, Vector2(u1, 0)],
				[p01, Vector2(u1, 0)], [p10, Vector2(u0, 1)], [p11, Vector2(u1, 1)]]:
			st.set_uv(v[1])
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0] + Vector3(0, 0.085, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _shallows_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


static func _island_mat() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true  # renkler sRGB yazildi (yoksa soluk / beyazimsi gorunur)
		_mat.roughness = 1.0
		_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON  # haritanin geri kalaniyla ayni isik (map_visuals TOON)
		_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return _mat


static func _shallows_mat() -> ShaderMaterial:
	if _shallow_mat == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
uniform vec3 shallow : source_color = vec3(0.24, 0.78, 0.8);
void fragment() {
	float v = UV.y;  // 0 kumsal kenari .. 1 acik deniz
	float u = UV.x * 6.2831;
	// kumsala dogru akan iki dalga seridi + kenarda sabit kopuk
	float wave1 = smoothstep(0.08, 0.0, abs(fract(v * 1.6 + TIME * 0.35 + sin(u * 3.0) * 0.04) - 0.5) - 0.38);
	float edge = smoothstep(0.22, 0.02, v + sin(u * 7.0 + TIME * 1.5) * 0.025);
	float foam = clamp(edge + wave1 * (1.0 - v) * 0.7, 0.0, 1.0);
	vec3 col = mix(shallow, vec3(0.96, 0.99, 1.0), foam);
	float a = mix(0.55 * (1.0 - smoothstep(0.25, 1.0, v)), 0.92, foam);
	ALBEDO = col;
	ALPHA = a;
}"""
		_shallow_mat = ShaderMaterial.new()
		_shallow_mat.shader = sh
	return _shallow_mat
