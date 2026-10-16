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

var _visual: Node3D
var _models := {}
var _busy := false


func _ready() -> void:
	add_to_group("buildings")
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_build()


static func find_model(name: String) -> String:
	for dir in MODEL_DIRS:
		var path := "res://assets/models/%s/%s.gltf" % [dir, name]
		if ResourceLoader.exists(path):
			return path
	return ""


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
		_spawn_debris(18))
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
	state_changed.emit(state)


# ------------------------------------------------------------------ modeller
func _model_path(s: State) -> String:
	var path := find_model(model_name + SUFFIX[s])
	if path == "" and s != State.NORMAL:
		# kacak / guclendirilmis versiyonun ozel hali yoksa temel seviyeninkini kullan
		var base := model_name.replace("_kacak", "").replace("_reinforced", "")
		path = find_model(base + SUFFIX[s])
	return path


func _build() -> void:
	for child in _visual.get_children():
		_visual.remove_child(child)
		child.queue_free()
	_models.clear()
	for s in SUFFIX:
		var path := _model_path(s)
		if path != "":
			var model := (load(path) as PackedScene).instantiate() as Node3D
			_visual.add_child(model)
			_models[s] = model
	_apply_visibility()


func _apply_visibility() -> void:
	var shown: int = state
	while shown > State.NORMAL and not _models.has(shown):
		shown -= 1
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
