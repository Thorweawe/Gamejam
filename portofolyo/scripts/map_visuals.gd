extends Node
## Harita gorsel uyumu (CityMap'in cocugu olarak eklenir, menude ve oyunda calisir).
## Harita iki farkli paketten geliyor: zemin / daglar sehir paketinin atlasini (neon yesil, parlak),
## agaclar / kayalar orman paketinin paletini kullaniyor. Burada:
##  - zemin karolari ve daglara ground.gdshader uygulanir (ortak yesil palet, ton lekeleri, mat yuzey,
##    denizle uyumlu nehir)
##  - ortam (tonlama, renk doygunlugu, golge yumusakligi) daha dengeli hale getirilir
## Modellerin kendisi degismez; tum degisiklik calisma aninda.

const GROUND_SHADER := preload("res://assets/shaders/ground.gdshader")
const OUTLINE_SHADER := preload("res://assets/shaders/outline.gdshader")
const GraphicsQuality := preload("res://scripts/graphics_quality.gd")
const MEADOW := Color(0.46, 0.6, 0.32)  # dag eteklerindeki soluk haki zemin bu cayir tonuna yaklasir (cimene yakin, keskin gecis olmasin)
## Karo / model adi on eki -> shader ayarlari
## terrain: renk karo basina degil arazi maskesine gore (orman / dag etegi yumusak gecis, kare kare gorunmez)
const GROUND := {
	# hepsi ayni cayir tonunu alir: onceden cimen / orman karolari shader'in varsayilan (daha haki)
	# tonunu, dag karolari MEADOW'u kullaniyordu -> dag eteginde iki farkli renk, keskin sinir
	"forest_": {"terrain": 1.0, "meadow": MEADOW, "sand_blend": 1.0},
	"grass_": {"terrain": 1.0, "meadow": MEADOW, "sand_blend": 1.0},
	"river_": {"variation": 0.6, "river_mode": 1.0, "terrain": 1.0, "meadow": MEADOW},
	"sand_": {"grass_amount": 0.0, "variation": 0.7, "sand_blend": 2.0},
	"mountain_": {"terrain": 1.0, "dirt_grass": 1.0, "flat_grass": 1.0, "meadow": MEADOW, "variation": 1.2},
}
const TERRAIN_MASK := preload("res://assets/textures/terrain_mask.png")
const SAND_MASK := preload("res://assets/textures/sand_mask.png")
## Tepe / zirve modelleri de arazi maskesini kullanir: dag eteginde zeminle ayni cayir tonu
## (onceden haki zeminde parlak yesil daireler gibi duruyordu).
const NATURE := {
	"peak_": {"grass_shade": 0.78, "variation": 0.5, "terrain": 1.0, "meadow": MEADOW},
	"hill_": {"grass_shade": 0.85, "variation": 0.7, "terrain": 1.0, "meadow": MEADOW},
}

var _materials := {}  # [doku, ayarlar] -> ShaderMaterial (ayni karolar tek malzemeyi paylasir)


func _ready() -> void:
	var city: Node = get_parent()
	var sea := city.get_node_or_null("Sea") as MeshInstance3D
	if sea:
		_sea_mat = sea.mesh.material as ShaderMaterial
		if _sea_mat:
			# kiyi kopugu oyulmus kumla ayni cizgide (parametreler ayni kalir, sadece shader degisir)
			var keep := {}
			for p in ["land_mask", "map_min", "map_size", "light"]:
				keep[p] = _sea_mat.get_shader_parameter(p)
			_sea_mat.shader = SEA_SHADER
			for p in keep:
				if keep[p] != null:
					_sea_mat.set_shader_parameter(p, keep[p])
			_sea_mat.set_shader_parameter("coast_cut", COAST_CUT)
			_set_river_mouth(city.get_node_or_null("MapInfo") as MapInfo)
	_apply_group(city.get_node_or_null("Ground"), GROUND, true)
	_apply_group(city.get_node_or_null("Nature"), NATURE)
	_add_wind(city.get_node_or_null("Nature"))
	_keep_on_sand(city.get_node_or_null("Props"))
	_tune_environment((city.get_node("WorldEnvironment") as WorldEnvironment).environment)
	(city.get_node("Sun") as DirectionalLight3D).shadow_blur = 1.5  # kesik golge kenarlari yerine yumusak gecis
	_add_outline(city.get_node("CameraRig/Camera3D"))
	_add_tilt_shift(city.get_node("CameraRig/Camera3D"))
	if TOON:
		_city = city
		for m in city.find_children("*", "MeshInstance3D", true, false):
			_toon(m)
		# sonradan yuklenen modeller (hasarli binalar, araclar, yangin...) de ayni isigi alsin
		get_tree().node_added.connect(_on_node_added)


## Hafif cizgi film isigi: mevcut malzemeler yumusak basamakli (toon) isik / parlama kullanir.
## Malzemeler model dosyalari arasinda paylasilir; her biri bir kez degistirilir.
const TOON := true
var _city: Node


func _on_node_added(n: Node) -> void:
	if n is MeshInstance3D and _city.is_ancestor_of(n):
		_toon(n)


func _toon(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(i) as BaseMaterial3D
		if mat == null or mat.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON:
			continue
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED  # parlak lekeler yollari / catilari beyaza bogmasin


## Ruzgar: agac ve calilar hafifce sallanir (foliage.gdshader). Ayni dokuyu kullananlar tek malzemeyi paylasir.
const FOLIAGE_SHADER := preload("res://assets/shaders/foliage.gdshader")
var _foliage := {}  # doku -> ShaderMaterial


func _add_wind(parent: Node) -> void:
	if parent == null:
		return
	for n in parent.get_children():
		var nm := String(n.name)
		if not (nm.begins_with("tree_") or nm.begins_with("bush_")):
			continue
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null or mi.mesh.get_surface_count() == 0:
				continue
			var src := mi.mesh.surface_get_material(0) as BaseMaterial3D
			if src == null or src.albedo_texture == null:
				continue
			if not _foliage.has(src.albedo_texture):
				var mat := ShaderMaterial.new()
				mat.shader = FOLIAGE_SHADER
				mat.set_shader_parameter("albedo_tex", src.albedo_texture)
				_foliage[src.albedo_texture] = mat
			mi.material_override = _foliage[src.albedo_texture]


## Minyatur (tilt-shift) etkisi: kameranin baktigi nokta net, cok yakin / cok uzak (ekranin ust ve alt
## kenari) hafif bulanik -> "maket sehir" hissi. Netlik mesafesi yakinlastirmayla birlikte guncellenir.
## Yavas makinede (grafik kalitesi >= 2) kapali.
var _dof_cam: Camera3D
var _dof: CameraAttributesPractical


func _add_tilt_shift(camera: Camera3D) -> void:
	_dof_cam = camera
	_dof = CameraAttributesPractical.new()
	_dof.dof_blur_amount = 0.045
	camera.attributes = _dof
	set_process(true)


func _process(_delta: float) -> void:
	if _dof == null or not is_instance_valid(_dof_cam):
		return
	var on := GraphicsQuality.level < 2
	_dof.dof_blur_far_enabled = on
	_dof.dof_blur_near_enabled = on
	if not on:
		return
	var d := _dof_cam.position.length()  # kamera -> bakilan nokta (rig merkezi)
	_dof.dof_blur_far_distance = d * 1.18
	_dof.dof_blur_far_transition = d * 0.7
	_dof.dof_blur_near_distance = d * 0.72
	_dof.dof_blur_near_transition = d * 0.35


## Cizgi film konturu: kameranin onunde tam ekran dortgen (outline.gdshader).
## Yavas makinede graphics_quality.gd "outline_fx" grubunu gizler.
func _add_outline(camera: Camera3D) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.render_priority = -100  # seffaf efektlerden (duman, alev) once: cizgiler dumanin ustune binmesin
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "Outline"
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0  # vertex shader ekrana yayiyor; kamera onunden kayinca kirpilmasin
	mi.position = Vector3(0, 0, -1)
	mi.add_to_group("outline_fx")
	mi.visible = GraphicsQuality.level < GraphicsQuality.OUTLINE_OFF_LEVEL
	camera.add_child(mi)


## Kiyi oyma esigi (ground.gdshader / sea.gdshader coast_cut). Karo kenari maskede ~0.55'e denk gelir;
## esik + dalga (+-0.055) bunun biraz ustunde: kare kenar kaybolur ama kiyidaki semsiyeler kumda kalir.
const COAST_CUT := 0.63
const SEA_SHADER := preload("res://assets/shaders/sea.gdshader")
var _sea_mat: ShaderMaterial


## Nehir agzi (sea.gdshader river_z / river_x0): nehrin denize ulastigi dogu ucu. Nehir dogu-bati yonunde
## (map_gen.py river_r satiri); kara maskesi orada biter, kiyi kopugu agizda bastirilir.
func _set_river_mouth(info: MapInfo) -> void:
	if info == null or info.river_tiles.is_empty():
		return
	var z: float = info.river_tiles[0].y
	var x_end := -INF
	for p in info.river_tiles:
		if absf(p.y - z) < 0.5:
			x_end = maxf(x_end, p.x)
	_sea_mat.set_shader_parameter("river_z", z)
	_sea_mat.set_shader_parameter("river_x0", x_end)


## Kiyi oyulunca en dis karodaki plaj semsiyeleri suya / kopuge denk gelebiliyor: kara maskesinin
## egimi boyunca biraz iceri (kuma) kaydir.
func _keep_on_sand(props: Node) -> void:
	if props == null or _sea_mat == null:
		return
	var tex := _sea_mat.get_shader_parameter("land_mask") as Texture2D
	if tex == null:
		return
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var mn: Vector2 = _sea_mat.get_shader_parameter("map_min")
	var sz: Vector2 = _sea_mat.get_shader_parameter("map_size")
	var sample := func(p: Vector3) -> float:
		var px := ((Vector2(p.x, p.z) - mn) / sz * Vector2(img.get_size())).floor()
		px = px.clamp(Vector2.ZERO, Vector2(img.get_size()) - Vector2.ONE)
		return img.get_pixelv(Vector2i(px)).r
	# ayni karodaki semsiyeler (umbrella0_27_13, umbrella1_27_13) birlikte kayar, ust uste binmez
	var shift := {}
	var groups := {}
	for p in props.get_children():
		var name := String(p.name)
		if not name.begins_with("umbrella"):
			continue
		var pos: Vector3 = p.position
		for i in 12:
			if sample.call(pos) >= COAST_CUT + 0.12:
				break
			var dx: float = sample.call(pos + Vector3(0.3, 0, 0)) - sample.call(pos - Vector3(0.3, 0, 0))
			var dz: float = sample.call(pos + Vector3(0, 0, 0.3)) - sample.call(pos - Vector3(0, 0, 0.3))
			var g := Vector2(dx, dz)
			if g.length() < 0.0001:
				break
			g = g.normalized() * 0.15
			pos += Vector3(g.x, 0.0, g.y)
		var key := name.substr(name.find("_"))
		groups.get_or_add(key, []).append(p)
		var d: Vector3 = pos - p.position
		if d.length() > (shift.get(key, Vector3.ZERO) as Vector3).length():
			shift[key] = d
	for key in shift:
		for p in groups[key]:
			p.position += shift[key]


func _apply_group(parent: Node, rules: Dictionary, coast := false) -> void:
	if parent == null:
		return
	for n in parent.get_children():
		var name := String(n.name)
		for prefix in rules:
			if name.begins_with(prefix):
				var settings: Dictionary = rules[prefix]
				if coast and _sea_mat:
					settings = settings.merged({"coast_cut": COAST_CUT})
				_apply(n, settings)
				# duz nehir karolari kivrimli akar (ground.gdshader meander); koseler oldugu gibi
				if prefix == "river_" and n.scene_file_path.contains("straight"):
					for m in n.find_children("*", "MeshInstance3D", true, false):
						(m as MeshInstance3D).set_instance_shader_parameter("meander", 1.0)
				break


func _apply(node: Node, settings: Dictionary) -> void:
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var src := mi.mesh.surface_get_material(0) as BaseMaterial3D
		if src == null or src.albedo_texture == null:
			continue
		var key := [src.albedo_texture, settings]
		if not _materials.has(key):
			var mat := ShaderMaterial.new()
			mat.shader = GROUND_SHADER
			mat.set_shader_parameter("albedo_tex", src.albedo_texture)
			for p in settings:
				mat.set_shader_parameter(p, settings[p])
			if settings.has("coast_cut"):
				for p in ["land_mask", "map_min", "map_size"]:
					mat.set_shader_parameter(p, _sea_mat.get_shader_parameter(p))
			if settings.has("sand_blend") and _sea_mat:
				mat.set_shader_parameter("sand_mask", SAND_MASK)
				for p in ["map_min", "map_size"]:
					mat.set_shader_parameter(p, _sea_mat.get_shader_parameter(p))
			if settings.has("terrain") and _sea_mat:
				mat.set_shader_parameter("terrain_mask", TERRAIN_MASK)
				for p in ["map_min", "map_size"]:
					mat.set_shader_parameter(p, _sea_mat.get_shader_parameter(p))
			_materials[key] = mat
		mi.material_override = _materials[key]


## Yangin izi maskesi (disasters.gd): orman / cim karolarinin malzemelerine verilir.
func set_burn_mask(tex: Texture2D) -> void:
	for key in _materials:
		var mat: ShaderMaterial = _materials[key]
		if mat.get_shader_parameter("terrain") != null and float(mat.get_shader_parameter("terrain")) > 0.0:
			mat.set_shader_parameter("burn_mask", tex)
			mat.set_shader_parameter("use_burn", 1.0)


## Isik / renk / atmosfer (menu ve oyun). Gun dongusu (day_cycle.gd) gunes ve ortam isigini saate gore
## degistirir; burada ton eslemesi, renk derecelendirmesi, ortam golgesi, sis ve parlama ayarlanir.
func _tune_environment(env: Environment) -> void:
	# ton esleme: ACES, parlak gok / beyaz yollar yanmaz, renkler daha "sinematik"
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.08
	env.tonemap_white = 6.0
	# renk derecelendirmesi: golgeler hafif serin mavi, isiklar sicak (oyuncak sehir / gun isigi hissi)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.08
	env.adjustment_brightness = 1.0
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	grad.colors = PackedColorArray([Color(0.0, 0.015, 0.05), Color(0.23, 0.245, 0.27), Color(0.61, 0.6, 0.575), Color(1.0, 0.985, 0.95)])
	var lut := GradientTexture1D.new()
	lut.gradient = grad
	lut.width = 256
	env.adjustment_color_correction = lut
	# ortam golgesi: binalarin dibi, agac alti, sokak kenarlari koyulasir -> binalar zemine "oturur"
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.4
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15  # dogrudan gunes alan yuzde de hafif kalsin (toon isikta derinlik)
	# atmosfer: uzak dag ve deniz gok renginde puslanir (hava perspektifi), yakin sehir net kalir
	env.fog_enabled = true
	env.fog_density = 0.0032
	env.fog_aerial_perspective = 0.75
	env.fog_sky_affect = 0.0
	env.fog_light_energy = 1.0
	env.set_meta("fog_base", env.fog_density)  # day_cycle.gd sabah pusunu bunun ustune ekler
	env.set_meta("fog_ap", env.fog_aerial_perspective)
	# parlama: ates, siren, lamba, pencere isiklari isildar; gunduz beyaz catilar parlamaz (esik)
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.05
	env.glow_hdr_scale = 2.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	for lv in 7:
		env.set_glow_level(lv, 1.0 if lv in [2, 3, 4] else (0.5 if lv == 5 else 0.0))
