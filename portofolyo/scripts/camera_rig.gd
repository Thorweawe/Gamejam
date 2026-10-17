extends Node3D
## Kus bakisi kamera.
## WASD / oklar: kaydir   Sag veya orta tik surukle: kaydir
## Tekerlek: yakinlas/uzaklas   Q / E: dondur

@export var move_speed := 14.0
@export var rotate_speed := 1.6
@export var zoom_min := 10.0
@export var zoom_max := 70.0
@export var bounds := Vector2(22.0, 20.0)

@onready var camera: Camera3D = $Camera3D

var _zoom := 0.0
var _dir := Vector3.ZERO
var _shake := 0.0


func _ready() -> void:
	_zoom = camera.position.length()
	_dir = camera.position.normalized()


func _process(delta: float) -> void:
	var input := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"))
			- float(Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left")),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"))
			- float(Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("ui_up")))
	var speed := move_speed * _zoom / 45.0
	position += Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, rotation.y) * speed * delta
	position.x = clampf(position.x, -bounds.x, bounds.x)
	position.z = clampf(position.z, -bounds.y, bounds.y)

	var turn := float(Input.is_physical_key_pressed(KEY_Q)) - float(Input.is_physical_key_pressed(KEY_E))
	rotation.y += turn * rotate_speed * delta

	camera.position = camera.position.lerp(_dir * _zoom, minf(1.0, delta * 10.0))

	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.25
		camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.25
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom * 0.9, zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom * 1.1, zoom_min, zoom_max)
	elif event is InputEventMouseMotion and event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
		var drag := Vector3(-event.relative.x, 0.0, -event.relative.y) * _zoom * 0.0025
		position += drag.rotated(Vector3.UP, rotation.y)


## Deprem vb. icin kamera sarsintisi (saniye).
func shake(duration: float = 1.5) -> void:
	if not bool(Settings.get_value("shake")):
		return  # ayarlardan kapatilabilir
	_shake = maxf(_shake, duration)


## Kamerayi bir noktaya kaydir (afet yerine odaklanmak icin).
func focus(target: Vector3, zoom := -1.0, duration := 1.2) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "position", Vector3(target.x, 0.0, target.z), duration)
	if zoom > 0.0:
		tw.parallel().tween_property(self, "_zoom", clampf(zoom, zoom_min, zoom_max), duration)
