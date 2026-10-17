extends Node3D
## Haritayi canlandiran hayvanlar ve tekneler:
##   martilar  : deniz ve kumsal ustunde daireler cizer, kanat cirpar/suzulur
##   kuslar    : orman ve daglarin ustunde
##   geyikler  : ormanda otlar, yavasca dolasir
##   kopekler  : parklarda ve meydanda gezer
##   tekneler  : denizde yavasca seyreder, dalgayla sallanir

@export var seagull_count := 12
@export var bird_count := 10
@export var deer_count := 8
@export var dog_count := 6
@export var goat_count := 12
@export var eagle_count := 4
@export var boat_count := 5
@export var map_info_path: NodePath = ^"../MapInfo"

const M := "res://assets/models/"

var _flyers: Array[Dictionary] = []
var _walkers: Array[Dictionary] = []
var _boats: Array[Dictionary] = []

@onready var map_info: MapInfo = get_node_or_null(map_info_path)


func _ready() -> void:
	if map_info == null:
		return
	var coast := map_info.beach_tiles + map_info.sea_points
	for i in seagull_count:
		_add_flyer("canlilar/seagull", coast, randf_range(1.6, 3.2), randf_range(1.5, 4.5), 1.0)
	var wild := map_info.forest_tiles + map_info.mountain_tiles
	for i in bird_count:
		_add_flyer("canlilar/bird_small", wild, randf_range(2.0, 3.5), randf_range(1.0, 3.0), 1.0)
	for i in deer_count:
		_add_walker("canlilar/deer", map_info.forest_tiles, 0.65, 0.18, 0.7)
	# dag keçileri: daglarin sehre bakan eteklerinde (zirvelerin icinden gecmesinler)
	var foothills := PackedVector2Array()
	var east := -INF
	for p in map_info.mountain_tiles:
		east = maxf(east, p.x)
	for p in map_info.mountain_tiles:
		if p.x >= east - 3.0 or p.y > 18.0:
			foothills.append(p)
	for i in goat_count:
		_add_walker("canlilar/goat", foothills, 1.0, 0.14, 0.8)
	# kartallar: daglarin ustunde yuksekte suzulur
	for i in eagle_count:
		_add_flyer("canlilar/bird_small", map_info.mountain_tiles, randf_range(4.5, 6.0), randf_range(3.0, 5.0), 2.2)
	var parks := map_info.park_tiles + map_info.plaza_tiles + map_info.assembly_points
	for i in dog_count:
		_add_walker("canlilar/dog", parks, 1.0, 0.35, 0.85)
	for i in boat_count:
		_add_boat()


func _instance(path: String) -> Node3D:
	var n: Node3D = (load(M + path + ".gltf") as PackedScene).instantiate()
	add_child(n)
	return n


func _parts(n: Node, suffixes: Array) -> Dictionary:
	var out := {}
	for c in n.find_children("*", "Node3D", true, false):
		for s in suffixes:
			if String(c.name).ends_with(s):
				out[s] = c
	return out


func _add_flyer(path: String, area: PackedVector2Array, height: float, radius: float, scale_k: float) -> void:
	if area.is_empty():
		return
	var n := _instance(path)
	n.scale = Vector3.ONE * scale_k
	var c := area[randi() % area.size()]
	_flyers.append({
		"node": n, "center": Vector3(c.x, height, c.y), "radius": radius, "angle": randf() * TAU,
		"speed": randf_range(0.35, 0.7) * (1 if randf() < 0.5 else -1), "phase": randf() * TAU,
		"wings": _parts(n, ["wing_l", "wing_r"]), "glide": 0.0,
	})


func _add_walker(path: String, area: PackedVector2Array, scale_k: float, speed: float, spread: float) -> void:
	if area.is_empty():
		return
	var n := _instance(path)
	n.scale = Vector3.ONE * scale_k
	var c := area[randi() % area.size()]
	n.position = Vector3(c.x, 0.1, c.y)
	_walkers.append({
		"node": n, "area": area, "home": Vector2(c.x, c.y), "target": n.position, "wait": randf() * 3.0,
		"speed": speed, "spread": spread, "phase": randf() * TAU,
		"legs": _parts(n, ["leg_fl", "leg_fr", "leg_bl", "leg_br"]),
	})


func _add_boat() -> void:
	if map_info.sea_points.is_empty():
		return
	var n := _instance("araclar/boat_fishing")
	var c := map_info.sea_points[randi() % map_info.sea_points.size()]
	_boats.append({"node": n, "center": Vector3(c.x, 0.02, c.y), "radius": randf_range(3.0, 7.0),
		"angle": randf() * TAU, "speed": randf_range(0.03, 0.06) * (1 if randf() < 0.5 else -1), "phase": randf() * TAU})


## Mini adalar (islands.gd) kurulunca cagirir: rotasi bir adaya degen tekne baska yere tasinir.
## spots: [x, z, yaricap, yukseklik]
func avoid_islands(spots: Array) -> void:
	for b in _boats:
		for attempt in 30:
			var hit := false
			for s in spots:
				var d := Vector2(b.center.x, b.center.z).distance_to(Vector2(s.x, s.y))
				if absf(d - b.radius) < s.z * 2.3 + 1.0:
					hit = true
					break
			if not hit:
				break
			var c := map_info.sea_points[randi() % map_info.sea_points.size()]
			b.center = Vector3(c.x, 0.02, c.y)
			b.radius = randf_range(3.0, 7.0)


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for f in _flyers:
		f.angle += f.speed * delta
		var n: Node3D = f.node
		var p: Vector3 = f.center + Vector3(cos(f.angle), 0, sin(f.angle)) * f.radius
		p.y += sin(t * 0.8 + f.phase) * 0.25
		var heading := Vector3(-sin(f.angle), 0, cos(f.angle)) * signf(f.speed)
		n.position = p
		n.rotation.y = atan2(heading.x, heading.z)
		n.rotation.z = -signf(f.speed) * 0.25  # donuse yatis
		# arada bir suzulur
		f.glide = fmod(t + f.phase, 6.0)
		var flap := sin(t * 14.0 + f.phase) * 0.7 if f.glide < 3.5 else 0.12
		if f.wings.has("wing_l"):
			f.wings.wing_l.rotation.z = flap
			f.wings.wing_r.rotation.z = -flap
	for w in _walkers:
		var n: Node3D = w.node
		if w.wait > 0.0:
			w.wait -= delta
			_animate_legs(w, 0.0, delta)
			continue
		var to: Vector3 = w.target - n.position
		to.y = 0.0
		if to.length() < 0.05:
			var c: Vector2 = w.home if randf() < 0.6 else w.area[randi() % w.area.size()]
			w.home = c
			w.target = Vector3(c.x + randf_range(-w.spread, w.spread), 0.1, c.y + randf_range(-w.spread, w.spread))
			w.wait = randf_range(1.0, 5.0)  # otlar / koklar
			continue
		var step := minf(w.speed * delta, to.length())
		n.position += to.normalized() * step
		n.rotation.y = lerp_angle(n.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 5.0))
		_animate_legs(w, step, delta)
	for b in _boats:
		b.angle += b.speed * delta
		var n: Node3D = b.node
		var p: Vector3 = b.center + Vector3(cos(b.angle), 0, sin(b.angle)) * b.radius
		p.y = 0.02 + sin(t * 1.3 + b.phase) * 0.03
		var heading := Vector3(-sin(b.angle), 0, cos(b.angle)) * signf(b.speed)
		n.position = p
		n.rotation = Vector3(sin(t * 1.1 + b.phase) * 0.05, atan2(heading.x, heading.z), sin(t * 0.9 + b.phase) * 0.07)


func _animate_legs(w: Dictionary, step: float, delta: float) -> void:
	if w.legs.is_empty():
		return
	w.phase += step * 40.0
	var s := sin(w.phase) * (0.6 if step > 0.0 else 0.0)
	for k in w.legs:
		var side := 1.0 if k in ["leg_fl", "leg_br"] else -1.0
		w.legs[k].rotation.x = lerpf(w.legs[k].rotation.x, s * side, minf(1.0, delta * 10.0))
