@tool
class_name Building
extends Node3D
## Haritadaki bir bina yuvasi. Normal / hasarli / yikik modellerini birlikte tutar
## ve aralarinda animasyonla gecer. Modeller adla bulunur:
##   <model_name>, <model_name>_damaged, <model_name>_collapsed
## Kullanim: damage(), collapse(), repair(), upgrade_to("house_lv2")

signal state_changed(new_state: State)

enum State { NORMAL, DAMAGED, COLLAPSED }

const MODEL_DIRS := ["binalar/konut", "binalar/kamu", "binalar/ticari", "binalar/hasar", "binalar/insaat"]
const SUFFIX := {State.NORMAL: "", State.DAMAGED: "_damaged", State.COLLAPSED: "_collapsed"}

@export var model_name: String = "house_lv1":
	set(value):
		model_name = value
		if is_node_ready():
			_build()

@export var state: State = State.NORMAL:
	set(value):
		state = value
		if is_node_ready():
			_apply_visibility()

const WINDOW_LIGHT := {State.NORMAL: 1.6, State.DAMAGED: 0.8, State.COLLAPSED: 0.0}

var _visual: Node3D
var _models := {}
var _busy := false
var _window_light: OmniLight3D


func _ready() -> void:
	add_to_group("buildings")
	if not has_meta("initial_model"):
		set_meta("initial_model", model_name)  # oyun sonu "hazirliksiz olsaydin" karsilastirmasi icin
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	if not Engine.is_editor_hint():
		# gece yanan pencere isigi (DayCycle "night_lights" grubunu yonetir)
		_window_light = OmniLight3D.new()
		_window_light.position = Vector3(0.0, 0.45, 0.85)
		_window_light.light_color = Color(1.0, 0.75, 0.45)
		_window_light.omni_range = 1.4
		_window_light.light_energy = 0.0
		_window_light.visible = false
		_window_light.add_to_group("night_lights")
		add_child(_window_light)
	_build()


static var _path_cache := {}  # model adi -> yol (ayni aramayi 120 bina tekrar tekrar yapmasin)


# ------------------------------------------------------------------ kamu binasi cati tabelasi
## Kamu binalarinin catisinda binanin turunu gosteren tabela: renkli cerceveli ikon levhasi, direk ve
## direk dibinde renkli taban. Levha kameraya doner (egik kamerada ve Q/E ile donunce de okunur) ama binanin parcasidir:
## derinlik testi acik, bina yukselince / gelisince catiyla birlikte yer degistirir.
## Muzelerin isareti baloncuktur (bubbles.gd): ilk acildiginda cikar, tiklaninca patlar.
## model oneki -> [ikon, renk]
const ROOF_SIGNS := {
	"building_townhall": ["res://assets/textures/belediye_1_saat_kulesi.png", Color(0.48, 0.38, 0.86)],
	"building_hospital": ["res://assets/textures/hastane_2_arti.png", Color(0.2, 0.62, 0.92)],
	"building_firestation": ["res://assets/textures/itfaiye_3_aracli.png", Color(0.93, 0.33, 0.25)],
	"building_afad": ["res://assets/textures/afad_1_merkez.png", Color(0.97, 0.6, 0.15)],
	"building_school": ["res://assets/textures/kitap_2_acik.png", Color(0.98, 0.76, 0.18)],
	"building_news": ["res://assets/textures/televizyon_1_retro.png", Color(0.16, 0.66, 0.62)],
}
const SIGN_SIZE := 0.95  # levha kenari (dunya birimi; bina 2x2)
static var _sign_tex := {}  # onek -> levha dokusu (bir kez cizilir)
static var _sign_mats := {}  # renk -> direk / taban malzemesi
var _sign: Node3D


func _sign_key() -> String:
	for k in ROOF_SIGNS:
		if model_name.begins_with(k):
			return k
	return ""


## Tabelayi kur / guncel catiya tasi (model degisince: gelistirme, hasar, onarim).
func _update_sign() -> void:
	if Engine.is_editor_hint():
		return
	var key := _sign_key()
	if key == "":
		if _sign:
			_sign.queue_free()
			_sign = null
		return
	if _sign == null:
		_sign = _make_sign(key)
		_visual.add_child(_sign)  # bina sallaninca / cokerken / gelisirken tabela da onunla hareket eder
	_sign.visible = state != State.COLLAPSED
	_sign.position = Vector3(0.0, top_height() - 0.04, 0.0)


func _make_sign(key: String) -> Node3D:
	var col: Color = ROOF_SIGNS[key][1]
	var root := Node3D.new()
	root.name = "RoofSign"
	if not _sign_mats.has(key):
		var metal := StandardMaterial3D.new()
		metal.albedo_color = Color(0.32, 0.34, 0.38)
		var base := StandardMaterial3D.new()
		base.albedo_color = col
		_sign_mats[key] = [metal, base]
	# taban: catiya oturan renkli yassi kaide (turun rengi yukaridan da secilsin)
	var base_mi := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.2
	base_mesh.bottom_radius = 0.24
	base_mesh.height = 0.08
	base_mesh.radial_segments = 12
	base_mesh.rings = 1
	base_mi.mesh = base_mesh
	base_mi.material_override = _sign_mats[key][1]
	base_mi.position.y = 0.04
	root.add_child(base_mi)
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.025
	post_mesh.bottom_radius = 0.03
	post_mesh.height = 0.32
	post_mesh.radial_segments = 6
	post_mesh.rings = 1
	post.mesh = post_mesh
	post.material_override = _sign_mats[key][0]
	post.position.y = 0.24
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(post)
	var board := Sprite3D.new()
	board.texture = _sign_texture(key)
	board.pixel_size = SIGN_SIZE / 128.0
	board.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # kus bakisi kamerada da tam okunur
	board.shaded = false  # isikli tabela: gece de okunur
	board.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	board.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	board.position.y = 0.36 + SIGN_SIZE * 0.5
	root.add_child(board)
	return root


## Levha: turun renginde kalin cerceve, krem ic, ortada ikon (yumusak kenarli, mipmapli).
static func _sign_texture(key: String) -> Texture2D:
	if _sign_tex.has(key):
		return _sign_tex[key]
	var col: Color = ROOF_SIGNS[key][1]
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var half := size * 0.5
	var radius := 26.0
	var inner := Color(1.0, 0.98, 0.94)
	for y in size:
		for x in size:
			# yuvarlatilmis kare uzaklik alani (kenarlarda 1 piksellik yumusatma)
			var q := Vector2(absf(x + 0.5 - half), absf(y + 0.5 - half)) - Vector2(half - 2.0 - radius, half - 2.0 - radius)
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
			var a := clampf(0.5 - d, 0.0, 1.0)
			if a <= 0.0:
				continue
			var c := col.lerp(inner, clampf(-d - 11.0, 0.0, 1.0))  # 12 px renkli cerceve
			if d > -3.0:
				c = col.darkened(0.25)  # dis kenar cizgisi
			c.a = a
			img.set_pixel(x, y, c)
	var icon_tex := load(ROOF_SIGNS[key][0]) as Texture2D
	if icon_tex:
		var icon := icon_tex.get_image()
		if icon.is_compressed():
			icon.decompress()
		icon.convert(Image.FORMAT_RGBA8)
		icon.resize(84, 84, Image.INTERPOLATE_LANCZOS)
		img.blend_rect(icon, Rect2i(0, 0, 84, 84), Vector2i(22, 22))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_sign_tex[key] = tex
	return tex


static func find_model(name: String) -> String:
	if _path_cache.has(name):
		return _path_cache[name]
	var found := ""
	for dir in MODEL_DIRS:
		var path := "res://assets/models/%s/%s.gltf" % [dir, name]
		if ResourceLoader.exists(path):
			found = path
			break
	_path_cache[name] = found
	return found


func is_busy() -> bool:
	return _busy


# ------------------------------------------------------------------ durumlar
func damage() -> void:
	if state != State.NORMAL or _busy:
		return
	_busy = true
	var tw := create_tween()
	_shake(tw, 0.45, 0.05)
	tw.tween_callback(func():
		_spawn_dust(14, 0.8)
		_spawn_debris(6)
		state = State.DAMAGED)
	_shake(tw, 0.25, 0.03)
	tw.tween_callback(_finish)


func collapse() -> void:
	if state == State.COLLAPSED or _busy:
		return
	_busy = true
	var tilt := Vector3(randf_range(-0.25, 0.25), 0.0, randf_range(-0.25, 0.25))
	var tw := create_tween()
	_shake(tw, 0.6, 0.07)
	tw.tween_callback(func():
		_spawn_dust(40, 1.6)
		_spawn_debris(18)
		get_tree().call_group("audio", "play", "collapse"))
	# bina egilerek yere gomulur
	tw.tween_property(_visual, "scale:y", 0.1, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_visual, "rotation", tilt, 0.7)
	tw.tween_callback(func():
		state = State.COLLAPSED
		_visual.rotation = Vector3.ZERO
		_visual.scale = Vector3(1.0, 0.5, 1.0)
		_spawn_dust(24, 1.2))
	# moloz yerine oturur
	tw.tween_property(_visual, "scale:y", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_finish)


## Yangin sonrasi duvarlarda is (kurum) izi; onarilinca / gelistirilince kalkar.
var _soot: Decal


func add_soot() -> void:
	if _soot and is_instance_valid(_soot):
		return
	_soot = GroundMarks.spawn_soot(self, top_height())


func _clear_soot() -> void:
	if _soot and is_instance_valid(_soot):
		_soot.queue_free()
	_soot = null


func repair() -> void:
	if state == State.NORMAL or _busy:
		return
	_clear_soot()
	_rebuild_anim(func(): state = State.NORMAL)


func upgrade_to(new_model: String) -> void:
	if _busy or find_model(new_model) == "":
		return
	_clear_soot()
	_rebuild_anim(func():
		state = State.NORMAL
		model_name = new_model)


func _rebuild_anim(swap: Callable) -> void:
	_busy = true
	var tw := create_tween()
	tw.tween_property(_visual, "scale:y", 0.05, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		swap.call()
		_spawn_dust(20, 1.0))
	tw.tween_property(_visual, "scale:y", 1.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_finish)


func _finish() -> void:
	_visual.position = Vector3.ZERO
	_visual.rotation = Vector3.ZERO
	_visual.scale = Vector3.ONE
	_busy = false
	_update_sign()
	if state != State.NORMAL:
		repair_days = maxi(repair_days, GameData.REPAIR_DAYS[state])
	else:
		repair_days = 0
	_update_scaffold()
	state_changed.emit(state)


# ------------------------------------------------------------------ modeller
func _model_path(s: State) -> String:
	var path := find_model(model_name + SUFFIX[s])
	if path == "" and s != State.NORMAL:
		# kacak / guclendirilmis versiyonun ozel hali yoksa temel seviyeninkini kullan
		var base := model_name.replace("_kacak", "").replace("_reinforced", "")
		path = find_model(base + SUFFIX[s])
	return path


## Sadece gereken model yuklenir; hasarli / yikik hali ilk ihtiyac aninda (acilis hizli olsun).
func _build() -> void:
	for child in _visual.get_children():
		_visual.remove_child(child)
		child.queue_free()
	_models.clear()
	_paths.clear()
	_sign = null  # tabela _visual'in cocuguydu, yukarida silindi
	_apply_visibility()
	_update_sign()


var _paths := {}  # durum -> model yolu ("" = bu durumun ozel modeli yok)


func _ensure_model(s: State) -> bool:
	if _models.has(s):
		return true
	if not _paths.has(s):
		_paths[s] = _model_path(s)
	if _paths[s] == "":
		return false
	var model := (load(_paths[s]) as PackedScene).instantiate() as Node3D
	_visual.add_child(model)
	WindowLights.apply(model)  # gece yanan pencereler
	_models[s] = model
	return true


func _apply_visibility() -> void:
	if _window_light:
		var on := _window_light.light_energy > 0.0
		_window_light.set_meta("energy", WINDOW_LIGHT[state])
		if on:  # gece ise yeni parlakligi hemen uygula
			_window_light.light_energy = WINDOW_LIGHT[state]
	var shown: int = state
	while shown > State.NORMAL and not _ensure_model(shown):
		shown -= 1
	_ensure_model(shown)
	for s in _models:
		_models[s].visible = s == shown


# ------------------------------------------------------------------ efektler
func _shake(tw: Tween, duration: float, amount: float) -> void:
	for i in int(duration / 0.04):
		var offset := Vector3(randf_range(-amount, amount), 0.0, randf_range(-amount, amount))
		tw.tween_property(_visual, "position", offset, 0.04)
	tw.tween_property(_visual, "position", Vector3.ZERO, 0.04)


func _spawn_dust(amount: int, size: float) -> void:
	if Engine.is_editor_hint():
		return
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.7, 0.25, 0.7)
	mat.direction = Vector3.UP
	mat.spread = 80.0
	mat.initial_velocity_min = 0.3 * size
	mat.initial_velocity_max = 1.2 * size
	mat.gravity = Vector3(0.0, -0.5, 0.0)
	mat.damping_min = 1.0
	mat.damping_max = 2.0
	mat.scale_min = 0.6 * size
	mat.scale_max = 1.3 * size
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 1.3))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	mat.scale_curve = curve_tex
	var grad := Gradient.new()
	grad.set_color(0, Color(0.78, 0.74, 0.68, 0.9))
	grad.set_color(1, Color(0.78, 0.74, 0.68, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	mesh.radial_segments = 6
	mesh.rings = 3
	var smat := StandardMaterial3D.new()
	smat.vertex_color_use_as_albedo = true
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = smat
	_emit(mat, mesh, amount, 1.8, 0.9, Vector3(0.0, 0.3, 0.0))


func _spawn_debris(amount: int) -> void:
	if Engine.is_editor_hint():
		return
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.6, 0.4, 0.6)
	mat.direction = Vector3.UP
	mat.spread = 50.0
	mat.initial_velocity_min = 1.2
	mat.initial_velocity_max = 2.8
	mat.gravity = Vector3(0.0, -7.0, 0.0)
	mat.angular_velocity_min = -360.0
	mat.angular_velocity_max = 360.0
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	mat.color = Color(0.55, 0.45, 0.4)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.06, 0.08)
	var smat := StandardMaterial3D.new()
	smat.vertex_color_use_as_albedo = true
	mesh.material = smat
	_emit(mat, mesh, amount, 1.0, 1.0, Vector3(0.0, 0.6, 0.0))


func _emit(mat: ParticleProcessMaterial, mesh: Mesh, amount: int, lifetime: float, explosiveness: float, offset: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = explosiveness
	p.process_material = mat
	p.draw_pass_1 = mesh
	p.position = offset
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


# ------------------------------------------------------------------ oyun yardimcilari
var on_fire := false
var repair_days := 0  # hasarli / yikik bina kac gun sonra kendiliginden onarilacak
var closed_days := 0  # gelistirme insaati: bu sure boyunca bina bos (vergi yok)
var _scaffold: Node3D
var _overlay_mat: StandardMaterial3D


## Gun gecisi: insaat ve onarim sayaclari. Doner: bugunun onarim gideri.
func tick_day() -> int:
	var cost := 0
	if closed_days > 0:
		closed_days -= 1
	if state != State.NORMAL and repair_days > 0:
		cost = GameData.REPAIR_UPKEEP[state]
		repair_days -= 1
		if repair_days == 0:
			# yikilan kacak yapi kurallara uygun (kacak katsiz) yeniden yapilir
			var base := model_name.replace("_kacak", "") if state == State.COLLAPSED else model_name
			if base != model_name:
				upgrade_to(base)
			else:
				repair()
	_update_scaffold()
	return cost


## Gelistirme: yeni model + insaat suresi (iskele gorunur, bina bos).
func start_upgrade(new_model: String, days: int) -> void:
	upgrade_to(new_model)
	closed_days = days
	_update_scaffold()


func is_closed() -> bool:
	return closed_days > 0 or (state != State.NORMAL and repair_days > 0)


func _update_scaffold() -> void:
	if Engine.is_editor_hint():
		return
	var show := closed_days > 0 or (state != State.NORMAL and repair_days > 0)
	if show and _scaffold == null:
		var tall := top_height() > 1.8 or model_name.begins_with("house_lv3") or model_name.contains("hospital")
		var path := "res://assets/models/binalar/insaat/%s.gltf" % ("scaffold_4floor" if tall else "scaffold_2floor")
		_scaffold = (load(path) as PackedScene).instantiate()
		_scaffold.scale = Vector3(1.0, 0.01, 1.0)
		add_child(_scaffold)
		_scaffold.create_tween().tween_property(_scaffold, "scale:y", 1.0, 0.6).set_trans(Tween.TRANS_BACK)
	elif not show and _scaffold != null:
		var sc := _scaffold
		_scaffold = null
		var tw := sc.create_tween()
		tw.tween_property(sc, "scale:y", 0.01, 0.4)
		tw.tween_callback(sc.queue_free)


## Risk haritasi: binayi renkli yari saydam katmanla boya (null = kapat).
func set_overlay(color: Variant) -> void:
	var mat: StandardMaterial3D = null
	if color != null:
		if _overlay_mat == null:
			_overlay_mat = StandardMaterial3D.new()
			_overlay_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_overlay_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_overlay_mat.albedo_color = color
		mat = _overlay_mat
	for m in _visual.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = mat
var _fire_nodes: Array[Node3D] = []
var _ring: MeshInstance3D


func display_name() -> String:
	return GameData.info(model_name).name


## Binada yasayan / calisan kisi sayisi (hasarli %70, yikik ve insaattaki 0).
func population() -> int:
	var base: int = GameData.info(model_name).pop
	if closed_days > 0:
		return 0
	match state:
		State.DAMAGED:
			return int(base * 0.7)
		State.COLLAPSED:
			return 0
	return base


func is_house() -> bool:
	return model_name.begins_with("house_")


## Gorunen modelin en yuksek noktasi (yangin / efekt yerlestirmek icin).
func top_height() -> float:
	var top := 0.5
	var model: Node3D = _models.get(state, _models.get(State.NORMAL))
	if model == null:
		return top
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var aabb := mi.get_aabb()
		top = maxf(top, (mi.global_transform * aabb).end.y - global_position.y)
	return top


## Yangin efekti ac / kapat: catidan ve pencerelerden cikan parcacikli alevler, kivilcim, duman
## sutunu, titreyen isik (fire_fx.gd) + oyunun tarzindaki alev modelleri. Sondurulunce alev
## kesilir, duman beyaz buhara doner.
func set_on_fire(on: bool, big := true) -> void:
	on_fire = on
	for n in _fire_nodes:
		FireFX.extinguish(n)
	_fire_nodes.clear()
	if not on:
		return
	var h := top_height()
	var fire_path := "res://assets/models/afet/%s.gltf" % ("fire_large" if big else "fire_small")
	for p in [Vector3(0.0, h - 0.05, 0.0), Vector3(-0.4, 0.12, 0.6)]:
		var f: Node3D = (load(fire_path) as PackedScene).instantiate()
		f.position = p
		f.scale = Vector3.ONE * randf_range(0.8, 1.1)
		add_child(f)
		_fire_nodes.append(f)
		_flicker(f)
	# catida genis alev + duman, on cephede pencereden tasan kucuk alev
	var roof := FireFX.make(Vector3(0.55, 0.08, 0.55), 1.15 if big else 0.85)
	roof.position = Vector3(0.0, h - 0.15, 0.0)
	add_child(roof)
	_fire_nodes.append(roof)
	var window := FireFX.make(Vector3(0.35, 0.15, 0.08), 0.7)
	window.light_energy = 0.0  # catidaki isik yeter (isik sayisi = GPU maliyeti)
	window.position = Vector3(0.25, h * 0.45, 0.85)
	add_child(window)
	_fire_nodes.append(window)


## Alev modeli: tek eksende pompalamak yerine dalgalanan, hafif donen, faz kaydirmali titresim.
static func _flicker(f: Node3D) -> void:
	var s := f.scale
	var tw := f.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	for i in 3:
		var k := randf_range(0.82, 1.3)
		var t := randf_range(0.12, 0.24)
		tw.tween_property(f, "scale", Vector3(s.x * (2.0 - k) * 0.5 + s.x * 0.5, s.y * k, s.z * (2.0 - k) * 0.5 + s.z * 0.5), t)
		tw.parallel().tween_property(f, "rotation:y", f.rotation.y + randf_range(-0.25, 0.25), t)


## Secim halkasi (oyuncu binaya tikladiginda).
func set_selected(on: bool) -> void:
	if on and _ring == null:
		_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 1.05
		torus.outer_radius = 1.18
		torus.rings = 32
		_ring.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.75, 0.1)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring.material_override = mat
		_ring.position.y = 0.14
		_ring.scale = Vector3(1, 0.3, 1)
		add_child(_ring)
		var tw := _ring.create_tween().set_loops()
		tw.tween_property(_ring, "scale", Vector3(1.06, 0.3, 1.06), 0.5)
		tw.tween_property(_ring, "scale", Vector3(1, 0.3, 1), 0.5)
	if _ring:
		_ring.visible = on
