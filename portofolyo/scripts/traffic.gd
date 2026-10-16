extends Node3D
## Sehri canlandirir: yollardaki arabalar, kaldirimdaki yayalar, meydanda gezenler.
## Yol agi, Roads altindaki karolardan otomatik cikarilir (karo = 2x2 birim).

const CARS := {  # model: agirlik
	"car_sedan": 4, "car_hatchback": 4, "car_stationwagon": 3, "car_taxi": 3, "car_police": 1,
	"car_bus": 2, "car_ambulance": 1, "car_firetruck": 1, "car_afad_rescue": 1, "car_tv_van": 1,
	"car_dumptruck": 1,
}
const PEOPLE := ["person_a", "person_b", "person_c", "person_d", "person_e", "person_f", "person_g",
	"person_h", "person_afad", "person_doctor"]
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

@export var car_count := 22
@export var walker_count := 40
@export var wanderer_count := 14
@export var roads_path: NodePath = ^"../Roads"
@export var ground_path: NodePath = ^"../Ground"

var road := {}  # Vector2i -> true
var cars: Array[Agent] = []
var people: Array[Agent] = []
var _plaza: Array[Vector3] = []


func _ready() -> void:
	for r in get_node(roads_path).get_children():
		road[_key(r.position)] = true
	for g in get_node(ground_path).get_children():
		if String(g.name).begins_with("plaza_"):
			_plaza.append(g.position)
	if road.is_empty():
		return
	var tiles: Array = road.keys()
	var pool := _weighted_pool()
	for i in car_count:
		var a := _spawn(Agent.Kind.CAR, "araclar/" + pool.pick_random(), tiles.pick_random())
		a.lane = 0.45
		a.speed = randf_range(1.6, 2.4)
		a.height = 0.1307
		cars.append(a)
	for i in walker_count:
		var a := _spawn(Agent.Kind.WALKER, "insanlar/" + PEOPLE.pick_random(), tiles.pick_random())
		a.lane = 0.98 if randf() < 0.5 else -0.98
		a.speed = randf_range(0.3, 0.45)
		a.height = 0.1
		people.append(a)
	if not _plaza.is_empty():
		for i in wanderer_count:
			var a := _spawn(Agent.Kind.WANDERER, "insanlar/" + PEOPLE.pick_random(), tiles.pick_random())
			a.speed = randf_range(0.25, 0.4)
			a.height = 0.1
			people.append(a)
	# serit/hiz degerleri atandiktan sonra yolu planla
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


func neighbors(k: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		if road.has(k + d * 2):
			out.append(d)
	return out


## Karodan cikis yonu: geri donus haric rastgele; cikmazda geri don.
func pick_exit(k: Vector2i, heading: Vector2i) -> Vector2i:
	var options := neighbors(k).filter(func(d): return d != -heading)
	return options.pick_random() if not options.is_empty() else -heading


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


## Deprem aninda: araclar durur, yayalar kosar.
func panic(duration: float) -> void:
	get_tree().call_group("agents", "panic", duration)
