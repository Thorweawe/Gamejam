extends Node
## Sehri canlandiran gunluk ve afet sonrasi detaylar (Disasters'in cocugu; sadece oyun sahnesinde).
##  Gunluk:
##   - Tatbikat gruplari: farkindaligi yuksek mahallelerde toplanma alaninda AFAD gorevlisiyle egitim
##     (farkindalik arttikca daha sik ve daha kalabalik)
##   - Sabah trafigi: her yeni gun evlerden is yerlerine akan araclar
##  Afet sonrasi:
##   - Yikilan binalarin basinda bekleyen komsular (ertesi sabah dagilir)
##   - Toplanma alanlarinda cadirlar, yardim paleti, ilk yardim kutusu (3 gun kalir)
##   - Cadir alanina yardim getiren, orada bekleyen AFAD araci
##   - Enkazla kapanan yollarda vinc / kamyon (yol acilinca istasyona doner)

const M := "res://assets/models/"
const CAMP_DAYS := 3
const DRILL_TIME := 22.0  # tatbikat grubunun toplanma alaninda kalma suresi (sn)

var dis: Disasters
var _day_cycle: DayCycle
var _drill_wait := 15.0
var _drill: Array = []
var _drill_left := 0.0
var _camps: Array = []  # {nodes, until, point, vehicle}
var _cleanup := {}  # Vector2i -> Agent (enkaz temizleyen arac)
var _check := 0.0


func _ready() -> void:
	dis = get_parent()
	_day_cycle = dis.get_node_or_null("../DayCycle")
	if _day_cycle:
		_day_cycle.day_started.connect(_on_day_started)


func _traffic() -> Node:
	return dis.traffic


func _process(delta: float) -> void:
	if dis.game == null:
		return
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		_update_cleanup()
	# tatbikat: gunduz, afet / gece gecisi yokken
	if _drill_left > 0.0:
		_drill_left -= delta
		if _drill_left <= 0.0 or dis.responding:
			_traffic().end_drill(_drill)
			_drill.clear()
			_drill_left = 0.0
		return
	if dis.responding or (_day_cycle and (_day_cycle.transitioning or _day_cycle.is_night())):
		return
	_drill_wait -= delta
	if _drill_wait > 0.0:
		return
	_drill_wait = randf_range(18.0, 32.0)
	_try_drill()


func _try_drill() -> void:
	var mi: MapInfo = dis.map_info
	if mi.assembly_points.is_empty():
		return
	var p: Vector2 = mi.assembly_points[randi() % mi.assembly_points.size()]
	for c in _camps:
		if c.point == p:
			return  # cadir alaninda tatbikat yapilmaz
	var aw: float = dis.game.district_awareness(MapInfo.to3(p))
	if randf() > clampf((aw - 20.0) / 60.0, 0.0, 0.9):
		return
	_drill = _traffic().drill_group(p, 3 + int(aw / 18.0))
	_drill_left = DRILL_TIME


func _on_day_started(d: int) -> void:
	_traffic().morning_commute(clampi(6 + d / 2, 6, 14))
	for c in _camps.duplicate():
		if d < c.until:
			continue
		_camps.erase(c)
		for n: Node3D in c.nodes:
			if is_instance_valid(n):
				var tw: Tween = n.create_tween()
				tw.tween_property(n, "scale", Vector3(n.scale.x, 0.01, n.scale.z), 0.5)
				tw.tween_callback(n.queue_free)
		if c.vehicle and is_instance_valid(c.vehicle):
			_traffic().release(c.vehicle)


# ------------------------------------------------------------------ afet sonrasi
## Yikilan binanin basinda birkac komsu bekler (ertesi sabah evlerine doner).
func mourners(b: Building, n := 3) -> void:
	if not is_instance_valid(b):
		return
	_traffic().gather_onlookers(b.global_position, dis.game.district_awareness(b.position) / 100.0, n)


## Deprem mudahalesi bitti: komsular yikintilarin basinda, cadirlar kurulur, yardim gelir,
## kapanan yollara temizlik araci gider.
func after_quake(r: Dictionary) -> void:
	var fallen: Array = dis.city.buildings().filter(func(b): return b.state == Building.State.COLLAPSED)
	fallen.shuffle()
	for b in fallen.slice(0, 6):
		mourners(b)
	if int(r.collapsed) + int(r.damaged) > 0:
		_build_camps(fallen, int(r.collapsed))
	var i := 0
	for k in dis._road_blocks.keys():
		if i >= 2:
			break
		_send_cleanup(k)
		i += 1


func _build_camps(fallen: Array, collapsed: int) -> void:
	var mi: MapInfo = dis.map_info
	if mi.assembly_points.is_empty():
		return
	# yikintilara en yakin toplanma alanlari (en fazla 2)
	var points: Array = []
	for b in fallen.slice(0, 4):
		var p := mi.nearest(mi.assembly_points, b.position)
		if not points.has(p):
			points.append(p)
	if points.is_empty():
		points.append(mi.assembly_points[0])
	var tents := clampi(1 + collapsed / 3, 1, 3)
	for idx in mini(points.size(), 2):
		var p: Vector2 = points[idx]
		var exists := false
		for c in _camps:
			if c.point == p:
				c.until = dis.game.day + CAMP_DAYS
				exists = true
		if exists:
			continue
		var nodes: Array = []
		var slots := [Vector3(-0.5, 0, -0.45), Vector3(0.5, 0, -0.45), Vector3(-0.5, 0, 0.45)]
		for t in tents:
			nodes.append(_place("afet/tent_disaster", MapInfo.to3(p, 0.1) + slots[t], 0.7,randf_range(-0.2, 0.2) + (PI if t == 2 else 0.0)))
		nodes.append(_place("afet/aid_pallet", MapInfo.to3(p, 0.1) + Vector3(0.55, 0, 0.5), 0.8, randf() * TAU))
		nodes.append(_place("afet/first_aid_box", MapInfo.to3(p, 0.1) + Vector3(0.25, 0, 0.6), 0.8, randf() * TAU))
		var v: Agent = null
		if idx == 0:
			v = _traffic().dispatch("car_afad_rescue", "afad", MapInfo.to3(p))
			v.arrived.connect(func(): v.set_siren(false), CONNECT_ONE_SHOT)
		_camps.append({"nodes": nodes, "until": dis.game.day + CAMP_DAYS, "point": p, "vehicle": v})


func _place(path: String, pos: Vector3, s: float, yaw: float) -> Node3D:
	var n: Node3D = (load(M + path + ".gltf") as PackedScene).instantiate()
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3(s, 0.01, s)
	dis.effects.add_child(n)
	n.create_tween().tween_property(n, "scale", Vector3.ONE * s, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return n


func _send_cleanup(k: Vector2i) -> void:
	if _cleanup.has(k):
		return
	var model: String = ["car_cranetruck", "car_dumptruck"].pick_random()
	var a: Agent = _traffic().dispatch(model, "afad", Vector3(k.x, 0, k.y))
	a.set_siren(false)  # is makinesi: siren yok
	_cleanup[k] = a


## Yol acildiysa (bina onarildi) temizlik araci doner.
func _update_cleanup() -> void:
	for k in _cleanup.keys():
		if not dis._road_blocks.has(k):
			var a: Agent = _cleanup[k]
			_cleanup.erase(k)
			if is_instance_valid(a):
				_traffic().release(a)
