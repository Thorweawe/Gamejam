extends Node3D
## Sehri canlandirir: yollardaki arabalar, kaldirimdaki yayalar, meydanda gezenler,
## ormanda mangal yapanlar. Yol agi Roads altindaki karolardan otomatik cikarilir.
## Ayrica: rota bulma (BFS), kavsak yonetimi, tahliye ve acil durum araclari.

const CARS := {  # model: agirlik
	"car_sedan": 4, "car_hatchback": 4, "car_stationwagon": 3, "car_taxi": 3, "car_police": 1,
	"car_bus": 2, "car_dumptruck": 1, "car_tv_van": 1,
}
const PEOPLE := ["person_a", "person_b", "person_c", "person_d", "person_e", "person_f", "person_g",
	"person_h", "person_afad", "person_doctor"]
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

@export var car_count := 30
@export var walker_count := 55
@export var wanderer_count := 14
@export var picnickers_per_spot := 3
@export var roads_path: NodePath = ^"../Roads"
@export var map_info_path: NodePath = ^"../MapInfo"

var road := {}  # Vector2i -> true
var junctions := {}  # Vector2i -> sahibi Agent (kavsaktaki arac)
var cars: Array[Agent] = []
var people: Array[Agent] = []
var picnickers: Array[Agent] = []
var blocked := {}  # Vector2i -> true: enkazla kapanan yol karolari (araclar etrafindan dolasir)
var _plaza: Array[Vector3] = []

@onready var map_info: MapInfo = get_node_or_null(map_info_path)


func _ready() -> void:
	for r in get_node(roads_path).get_children():
		road[_key(r.position)] = true
	for k in road:
		if neighbors(k).size() >= 3:
			junctions[k] = null
	if map_info:
		for p in map_info.plaza_tiles:
			_plaza.append(MapInfo.to3(p, 0.0))
	if road.is_empty():
		return
	var tiles: Array = road.keys()
	var pool := _weighted_pool()
	for i in car_count:
		var a := _spawn(Agent.Kind.CAR, "araclar/" + pool.pick_random(), tiles.pick_random())
		a.lane = 0.45
		a.speed = randf_range(1.6, 2.4)
		a.height = 0.1307
		if randf() < 0.45:
			a.night_threshold = randf_range(0.35, 0.95)  # gece eve donen araclar
		cars.append(a)
	for i in walker_count:
		var a := _spawn(Agent.Kind.WALKER, "insanlar/" + PEOPLE.pick_random(), tiles.pick_random())
		a.lane = 0.98 if randf() < 0.5 else -0.98
		a.speed = randf_range(0.3, 0.45)
		a.height = 0.1
		if randf() < 0.75:
			a.night_threshold = randf_range(0.2, 0.9)
		people.append(a)
	if not _plaza.is_empty():
		for i in wanderer_count:
			var a := _spawn(Agent.Kind.WANDERER, "insanlar/" + PEOPLE.pick_random(), tiles.pick_random())
			a.speed = randf_range(0.25, 0.4)
			a.height = 0.1
			if randf() < 0.75:
				a.night_threshold = randf_range(0.2, 0.9)
			people.append(a)
	if map_info:
		for spot in map_info.picnic_spots:
			for i in picnickers_per_spot:
				var a := _spawn(Agent.Kind.PICNIC, "insanlar/" + PEOPLE.pick_random(), tiles.pick_random())
				a.wander_center = MapInfo.to3(spot, 0.1)
				a.wander_radius = 0.7
				a.speed = randf_range(0.2, 0.32)
				a.height = 0.1
				a.night_threshold = randf_range(0.15, 0.6)
				people.append(a)
				picnickers.append(a)
	for a in cars + people:
		a.setup(self, a.get_meta("model"), a.tile, a.dir)


func _spawn(kind: Agent.Kind, model: String, start: Vector2i) -> Agent:
	var a := Agent.new()
	a.kind = kind
	var ns := neighbors(start)
	a.tile = start
	a.dir = -ns.pick_random() if not ns.is_empty() else Vector2i(0, 1)
	var scene: PackedScene = load("res://assets/models/%s.gltf" % model)
	a.set_meta("model", scene.instantiate())
	a.add_to_group("agents")
	add_child(a)
	return a


func _weighted_pool() -> Array[String]:
	var pool: Array[String] = []
	for k in CARS:
		for i in CARS[k]:
			pool.append(k)
	return pool


static func _key(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x), roundi(p.z))


func neighbors(k: Vector2i, avoid_blocked := true) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		var n := k + d * 2
		if road.has(n) and not (avoid_blocked and blocked.has(n)):
			out.append(d)
	return out


## Enkaz yolu kapatti / acildi.
func set_blocked(k: Vector2i, on: bool) -> void:
	if on:
		blocked[k] = true
	else:
		blocked.erase(k)


## Karodan cikis yonu: rota varsa onu izler, yoksa geri donus haric rastgele.
func next_dir(a: Agent) -> Vector2i:
	if not a.route.is_empty():
		var d: Vector2i = a.route.pop_front()
		var n := a.tile + d * 2
		if road.has(n) and (a.emergency or not blocked.has(n)):
			return d
		a.route.clear()
	var options := neighbors(a.tile).filter(func(d): return d != -a.dir)
	return options.pick_random() if not options.is_empty() else -a.dir


## Yol agi uzerinde en kisa rota (yon listesi). Kapali yollardan kacinir; baska yol yoksa
## enkazin arasindan gecer (acil durum araclari icin). Ulasilamazsa bos.
func find_route(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var dirs := _bfs(from, to, true)
	if dirs.is_empty() and from != to:
		dirs = _bfs(from, to, false)
	return dirs


func _bfs(from: Vector2i, to: Vector2i, avoid: bool) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []
	if from == to or not road.has(from) or not road.has(to):
		return dirs
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == to:
			break
		for d in neighbors(cur, false):
			var n := cur + d * 2
			if avoid and blocked.has(n) and n != to:
				continue
			if not prev.has(n):
				prev[n] = cur
				queue.append(n)
	if not prev.has(to):
		return dirs
	var cur := to
	while cur != from:
		var p: Vector2i = prev[cur]
		dirs.push_front((cur - p) / 2)
		cur = p
	return dirs


func nearest_road(p: Vector3, skip_blocked := false) -> Vector2i:
	var best := Vector2i.ZERO
	var best_d := INF
	for k in road:
		if skip_blocked and blocked.has(k):
			continue
		var d := Vector2(k.x - p.x, k.y - p.z).length_squared()
		if d < best_d:
			best_d = d
			best = k
	return best


# ------------------------------------------------------------------ kavsaklar
func junction_busy(k: Vector2i, a: Agent) -> bool:
	if not junctions.has(k):
		return false
	var owner = junctions[k]
	return owner != null and owner != a and is_instance_valid(owner) and owner.visible and owner.tile == k


func enter_tile(k: Vector2i, a: Agent) -> void:
	if a.kind == Agent.Kind.CAR and junctions.has(k) and not junction_busy(k, a):
		junctions[k] = a


func leave_tile(k: Vector2i, a: Agent) -> void:
	if junctions.has(k) and junctions[k] == a:
		junctions[k] = null


# ------------------------------------------------------------------ meydan / gezinme
## Meydanda yeni hedef: ayni ya da komsu meydan karosunda (aradaki binalarin icinden gecmesin).
func random_wander_point(from: Vector3) -> Vector3:
	var c: Vector3 = _plaza.pick_random()
	if from != Vector3.INF:
		var here := _plaza.filter(func(p): return absf(p.x - from.x) <= 1.0 and absf(p.z - from.z) <= 1.0)
		if not here.is_empty():
			var h: Vector3 = here[0]
			var near := _plaza.filter(func(p): return absf(p.x - h.x) + absf(p.z - h.z) <= 2.1)
			c = near.pick_random()
	return Vector3(c.x + randf_range(-0.85, 0.85), 0.1, c.z + randf_range(-0.85, 0.85))


# ------------------------------------------------------------------ afet davranislari
## Deprem aninda: araclar durur, yayalar kosar.
func panic(duration: float) -> void:
	get_tree().call_group("agents", "panic", duration)


## Tahliye: farkindalik orani kadar yaya en yakin toplanma alanina gider.
## only_picnic: sadece ormandakiler kacar (orman yangini). Doner: tahliye edilen kisi sayisi.
func evacuate(ratio: float, only_picnic := false) -> int:
	if map_info == null or map_info.assembly_points.is_empty():
		return 0
	var count := 0
	for a in people:
		if not a.visible or a.mode != Agent.Mode.NORMAL:
			continue
		if a.kind == Agent.Kind.PICNIC:
			a.evacuate(Vector2i.ZERO, _forest_exit() + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.4, 0.4)))
			count += 1
			continue
		if only_picnic:
			continue
		if randf() > ratio:
			a.panic(4.0)  # farkindaligi dusuk olanlar panikle kosusturur
			continue
		var target := map_info.nearest(map_info.assembly_points, a.position)
		var t3 := MapInfo.to3(target, 0.1) + Vector3(randf_range(-0.7, 0.7), 0, randf_range(-0.7, 0.7))
		a.evacuate(nearest_road(t3), t3)
		count += 1
	return count


func end_evacuation() -> void:
	for a in people:
		a.end_evacuation()


func _forest_exit() -> Vector3:
	# ormandan kacanlar koprunun kuzey basinda (nehrin orman tarafi) toplanir
	for p in map_info.river_tiles:
		if road.has(Vector2i(roundi(p.x), roundi(p.y))):
			return Vector3(p.x + 1.3, 0.1, p.y - 2.0)
	return Vector3.ZERO


## Acil durum araci gonder: istasyondan cikar, olay yerine gider, sireni calar.
func dispatch(model: String, station_model: String, target: Vector3) -> Agent:
	var start := nearest_road(_station_pos(station_model, target))
	var a := _spawn(Agent.Kind.CAR, "araclar/" + model, start)
	a.lane = 0.45
	a.speed = 2.4
	a.setup(self, a.get_meta("model"), start, a.dir)
	a.set_meta("station", start)
	a.respond(nearest_road(target, true))
	cars.append(a)
	return a


func release(a: Agent) -> void:
	if is_instance_valid(a):
		a.return_to_station(a.get_meta("station", a.tile))


func remove_agent(a: Agent) -> void:
	cars.erase(a)
	people.erase(a)
	leave_tile(a.tile, a)
	a.queue_free()


func _station_pos(station_model: String, fallback: Vector3) -> Vector3:
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.model_name.contains(station_model) and b.state != Building.State.COLLAPSED:
			return b.global_position
	return fallback


## Farkindalik gorseli: mahallesinin farkindaligi yuksek olanlar deprem cantasi tasir.
func update_kits(aw_at: Callable) -> void:
	for a in people:
		a.set_kit(a.kit_roll * 100.0 < float(aw_at.call(a.position)) * 0.9)


## Tatbikat: mahalledeki yayalar toplanma alanina yurur (ertesi sabah normale doner).
func drill(center: Vector3, radius := 9.0) -> void:
	var n := 0
	for a in people:
		if n >= 14 or not a.visible or a.mode != Agent.Mode.NORMAL or a.kind != Agent.Kind.WALKER:
			continue
		if a.position.distance_to(center) > radius:
			continue
		var target := map_info.nearest(map_info.assembly_points, a.position)
		var t3 := MapInfo.to3(target, 0.1) + Vector3(randf_range(-0.7, 0.7), 0, randf_range(-0.7, 0.7))
		a.evacuate(nearest_road(t3), t3)
		n += 1


## Olay karti (kamp / festival): bir noktaya yeni piknikciler ekle.
func add_picnickers(center: Vector3, n: int) -> void:
	var start := nearest_road(center)
	for i in n:
		var a := _spawn(Agent.Kind.PICNIC, "insanlar/" + PEOPLE.pick_random(), start)
		a.wander_center = Vector3(center.x, 0.1, center.z)
		a.wander_radius = 1.0
		a.speed = randf_range(0.2, 0.32)
		a.height = 0.1
		a.night_threshold = randf_range(0.15, 0.6)
		people.append(a)
		picnickers.append(a)
		a.setup(self, a.get_meta("model"), a.tile, a.dir)


## Piknik yasagi: piknikciler o gun ormana gelmez.
var _picnic_off_until := 0


func set_picnic(on: bool, day: int) -> void:
	if not on:
		_picnic_off_until = day
	elif day <= _picnic_off_until:
		return
	for a in picnickers:
		if a.has_meta("burned"):
			continue  # piknik alani yandi, kimse gelmez
		a.visible = on
		a.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


## Gece etkisi (0 gunduz, 1 gece): her ajan kendi esiginde gizlenir, sabah geri gelir.
func set_night(k: float) -> void:
	for a in cars + people:
		if a.emergency or a.mode != Agent.Mode.NORMAL:
			continue
		var show := k < a.night_threshold
		if a.visible != show:
			a.visible = show
			a.process_mode = Node.PROCESS_MODE_INHERIT if show else Node.PROCESS_MODE_DISABLED
			if not show:
				leave_tile(a.tile, a)
