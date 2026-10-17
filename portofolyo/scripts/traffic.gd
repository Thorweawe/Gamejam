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
	Agent.hurry = 1.0  # onceki sahneden (yagmur) kalmasin
	Agent.raining = false
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
	picnickers.erase(a)
	leave_tile(a.tile, a)
	if a.kind == Agent.Kind.CAR:
		a.queue_free()
		return
	# yaya kaybolurken kuculur (eve / binaya girdi)
	a.set_process(false)
	var tw := a.create_tween()
	tw.tween_property(a, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(a.queue_free)


# ------------------------------------------------------------------ afet aninda kalabalik
const MAX_TEMP := 70  # ayni anda en fazla gecici yaya (performans)
const MAX_TEMP_CARS := 24  # ayni anda en fazla kacis araci
var _onlookers: Array = []  # [Agent, yangin konumu]


func _temp_count(list: Array = people) -> int:
	var n := 0
	for a in list:
		if a.is_temp:
			n += 1
	return n


## Gecici yaya: evinin onundeki yol karosunda kapidan cikiyormus gibi buyuyerek belirir.
func _spawn_temp(at: Vector2i, model := "") -> Agent:
	var a := _spawn(Agent.Kind.WALKER, "insanlar/" + (model if model != "" else PEOPLE.pick_random()), at)
	a.lane = 0.98 if randf() < 0.5 else -0.98
	a.speed = randf_range(0.3, 0.45)
	a.height = 0.1
	a.is_temp = true
	a.home_tile = at
	a.setup(self, a.get_meta("model"), at, a.dir)
	people.append(a)
	a.scale = Vector3.ONE * 0.01
	a.create_tween().tween_property(a, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return a


## Yangin izleyicileri: yakindaki yayalar (yetmezse komsular evden cikar) yangina yurur ve guvenli
## mesafede yarim halka olup izler. aware (0-1, mahalle farkindaligi) yuksekse daha az kisi gelir
## ve daha geride durur.
func gather_onlookers(center: Vector3, aware: float, count := -1) -> void:
	if count < 0:
		count = int(round(lerpf(10.0, 4.0, aware)))
	var dist := lerpf(1.6, 2.7, aware)
	# yakindan gecen yayalar (en fazla yarisi; gerisi komsular)
	var cand: Array = people.filter(func(a): return a.visible and a.mode == Agent.Mode.NORMAL \
		and not a.is_temp and a.kind == Agent.Kind.WALKER and a.position.distance_to(center) < 7.0)
	cand.sort_custom(func(a, b): return a.position.distance_squared_to(center) < b.position.distance_squared_to(center))
	cand = cand.slice(0, count / 2)
	# komsular: yangin cevresindeki evlerden hemen cikanlar (kalabalik cabuk olussun)
	var homes: Array = get_tree().get_nodes_in_group("buildings").filter(func(b): return b.is_house() \
		and b.state != Building.State.COLLAPSED and not b.on_fire and b.position.distance_to(center) < 7.0)
	if homes.is_empty():
		homes = [{"position": center}]
	homes.shuffle()
	var i := 0
	while cand.size() < count and _temp_count() < MAX_TEMP:
		cand.append(_spawn_temp(nearest_road(homes[i % homes.size()].position, true)))
		i += 1
	# binanin onundeki caddede, yangina bakan bir yay halinde dururlar (kamera acisindan gorunur)
	var rk := nearest_road(center, true)
	var street := Vector3(rk.x, 0.0, rk.y)
	var to_fire := Vector3(center.x - street.x, 0.0, center.z - street.z)
	to_fire = to_fire.normalized() if to_fire.length() > 0.05 else Vector3.FORWARD
	var side := Vector3(-to_fire.z, 0.0, to_fire.x)
	var back := lerpf(0.0, 0.7, aware)  # bilincli mahallede daha geride, kalabalik daha seyrek
	for j in cand.size():
		var a: Agent = cand[j]
		var u := (float(j) / maxf(1.0, cand.size() - 1.0) - 0.5) * 2.0  # -1..1
		var spot := street + side * u * (0.6 + dist * 0.35) - to_fire * (back + absf(u) * 0.25 + randf_range(-0.12, 0.12))
		spot.y = a.height
		a.watch(spot, Vector3(center.x, a.height, center.z))
		_onlookers.append([a, center])


## Yangin sondu / bina coktu: izleyiciler dagilir.
func release_onlookers(center: Vector3) -> void:
	for item in _onlookers.duplicate():
		if item[1].distance_to(center) > 0.5:
			continue
		_onlookers.erase(item)
		if is_instance_valid(item[0]):
			item[0].stop_watching()


## Deprem: evlerden insanlar sokaga dokulur (bina nufusuna gore). evac_at(konum) -> 0-1 tahliye
## orani: o kadari toplanma alanina yurur (farkindalik arttikca alanlar kalabaliklasir), gerisi
## sokakta panikle kosusturur. Ertesi sabah (end_evacuation) evlerine donup kaybolurlar.
## Kurtarilanlar / izleyiciler icin yer kalsin diye en fazla MAX_TEMP - 15 kisi.
func residents_out(buildings: Array, evac_at: Callable) -> int:
	var list := buildings.filter(func(b): return b.is_house() and b.population() > 0)
	list.shuffle()
	var n := 0
	for b in list:
		for j in clampi(int(round(b.population() / 12.0)), 1, 3):
			if _temp_count() >= MAX_TEMP - 15:
				return n
			var a := _spawn_temp(nearest_road(b.position, true))
			n += 1
			if map_info and not map_info.assembly_points.is_empty() and randf() < float(evac_at.call(b.position)):
				var target := map_info.nearest(map_info.assembly_points, b.position)
				var t3 := MapInfo.to3(target, 0.1) + Vector3(randf_range(-0.85, 0.85), 0, randf_range(-0.85, 0.85))
				a.evacuate(nearest_road(t3), t3)
			else:
				a.panic(randf_range(6.0, 12.0))
	return n


## Kurtarilanlar: yardim noktasinin yanindaki yoldan cikip toplanma alanina yururler.
func rescued_walk(at: Vector3, n: int) -> void:
	if map_info == null or map_info.assembly_points.is_empty():
		return
	for i in n:
		if _temp_count() >= MAX_TEMP:
			return
		var a := _spawn_temp(nearest_road(at, true))
		var target := map_info.nearest(map_info.assembly_points, at)
		var t3 := MapInfo.to3(target, 0.1) + Vector3(randf_range(-0.85, 0.85), 0, randf_range(-0.85, 0.85))
		a.evacuate(nearest_road(t3), t3)


## Sel: dere kenarindan araclar sehirden uzaklasir (kacis trafigi). Araclar araliklarla cikar,
## dereden en uzak yollara rota ile gider ve orada kaybolur. Kapali (su basan) yollardan kacinirlar.
func flee_traffic(river_z: float, n: int) -> void:
	var tiles: Array = road.keys()
	var near: Array = tiles.filter(func(k): return absf(k.y - river_z) < 8.0 and not blocked.has(k))
	var far: Array = tiles.filter(func(k): return absf(k.y - river_z) > 14.0)
	temp_cars(near, far, n, Vector2(0.25, 0.6), Vector2(2.0, 2.6))


## Gecici araclar: starts'tan cikip ends'e rota ile gider, varinca kaybolur (araliklarla cikarlar).
func temp_cars(starts: Array, ends: Array, n: int, gap := Vector2(0.25, 0.6), spd := Vector2(1.6, 2.4)) -> void:
	if starts.is_empty() or ends.is_empty():
		return
	var pool := _weighted_pool()
	for i in n:
		if _temp_count(cars) >= MAX_TEMP_CARS:
			return
		var start: Vector2i = starts.pick_random()
		var a := _spawn(Agent.Kind.CAR, "araclar/" + pool.pick_random(), start)
		a.lane = 0.45
		a.speed = randf_range(spd.x, spd.y)
		a.height = 0.1307
		a.is_temp = true
		a.setup(self, a.get_meta("model"), start, a.dir)
		cars.append(a)
		a.route = find_route(a.tile + a._next * 2, ends.pick_random())
		a.mode = Agent.Mode.RESPOND
		a.despawn_on_arrival = true
		await get_tree().create_timer(randf_range(gap.x, gap.y)).timeout


## Sabah trafigi: evlerin onundeki yollardan is yerlerine / kamu binalarina giden araclar.
func morning_commute(n: int) -> void:
	var homes: Array = []
	var work: Array = []
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.state == Building.State.COLLAPSED:
			continue
		var k := nearest_road(b.position, true)
		if b.is_house():
			homes.append(k)
		else:
			work.append(k)
	temp_cars(homes, work, n, Vector2(0.3, 0.9), Vector2(1.8, 2.4))


## Tatbikat grubu: toplanma alanina bir AFAD gorevlisi ve birkac mahalleli yurur, orada bekler
## (toplanma animasyonu). Donen dizi: gruptaki ajanlar (end_drill ile dagitilir).
func drill_group(point: Vector2, n: int) -> Array:
	var group: Array = []
	var start := nearest_road(MapInfo.to3(point), true)
	for i in n:
		if _temp_count() >= MAX_TEMP:
			break
		var d: Vector2i = DIRS.pick_random()
		var from: Vector2i = start + d * 2 * randi_range(0, 2)
		if not road.has(from):
			from = start
		var a := _spawn_temp(from, "person_afad" if i == 0 else "")
		var t3 := MapInfo.to3(point, 0.1) + Vector3(randf_range(-0.7, 0.7), 0, randf_range(-0.7, 0.7))
		if i == 0:
			t3 = MapInfo.to3(point, 0.1) + Vector3(0.0, 0, -0.75)  # gorevli grubun onunde
		a.evacuate(nearest_road(t3), t3)
		group.append(a)
	return group


func end_drill(group: Array) -> void:
	for a in group:
		if is_instance_valid(a):
			a.end_evacuation()


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
