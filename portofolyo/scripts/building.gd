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


func repair() -> void:
	if state == State.NORMAL or _busy:
		return
	_rebuild_anim(func(): state = State.NORMAL)


func upgrade_to(new_model: String) -> void:
	if _busy or find_model(new_model) == "":
		return
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
	_apply_visibility()


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


## Yangin efekti ac / kapat (alev + duman modelleri).
func set_on_fire(on: bool, big := true) -> void:
	on_fire = on
	for n in _fire_nodes:
		n.queue_free()
	_fire_nodes.clear()
	if not on:
		return
	var h := top_height()
	var fire_path := "res://assets/models/afet/%s.gltf" % ("fire_large" if big else "fire_small")
	for p in [Vector3(0.0, h - 0.05, 0.0), Vector3(0.35, h * 0.5, 0.55), Vector3(-0.4, 0.12, 0.6)]:
		var f: Node3D = (load(fire_path) as PackedScene).instantiate()
		f.position = p
		f.scale = Vector3.ONE * randf_range(0.9, 1.3)
		add_child(f)
		_fire_nodes.append(f)
		var tw := f.create_tween().set_loops()
		tw.tween_property(f, "scale:y", f.scale.y * 1.3, randf_range(0.18, 0.3))
		tw.tween_property(f, "scale:y", f.scale.y * 0.85, randf_range(0.18, 0.3))
	var smoke: Node3D = (load("res://assets/models/afet/smoke_column.gltf") as PackedScene).instantiate()
	smoke.position = Vector3(0.1, h, 0.0)
	add_child(smoke)
	_fire_nodes.append(smoke)
	var light := OmniLight3D.new()
	light.position = Vector3(0, h * 0.6, 0.6)
	light.light_color = Color(1.0, 0.5, 0.15)
	light.light_energy = 2.5
	light.omni_range = 2.5
	add_child(light)
	_fire_nodes.append(light)


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
