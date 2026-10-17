extends Node3D
## Harita koku. Oyun mantigi main.tscn'deki Game / Disasters dugumlerinde.

@onready var camera_rig := $CameraRig
@onready var traffic := $Traffic
@onready var map_info: MapInfo = $MapInfo


func _ready() -> void:
	# golge optimizasyonu + yavas makinede kademeli grafik kalitesi (bkz. graphics_quality.gd)
	var quality: Node = preload("res://scripts/graphics_quality.gd").new()
	quality.name = "GraphicsQuality"
	add_child(quality)
	# zemin / dag renk uyumu ve ortam isigi (bkz. map_visuals.gd)
	var visuals: Node = preload("res://scripts/map_visuals.gd").new()
	visuals.name = "MapVisuals"
	add_child(visuals)


func buildings() -> Array[Node]:
	return get_tree().get_nodes_in_group("buildings")


## Fare isininin zemin (y = 0.1) ile kesistigi nokta; yoksa Vector3.INF.
func ground_point(screen_pos: Vector2) -> Vector3:
	var cam: Camera3D = camera_rig.camera
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 1e-4:
		return Vector3.INF
	var t := (0.1 - from.y) / dir.y
	return from + dir * t if t > 0.0 else Vector3.INF


func building_at(p: Vector3) -> Building:
	if p == Vector3.INF:
		return null
	var k := MapInfo.key(p)
	for b in buildings():
		var bk := MapInfo.key(b.position)
		if absi(bk.x - k.x) <= 1 and absi(bk.y - k.y) <= 1:
			return b
	return null
