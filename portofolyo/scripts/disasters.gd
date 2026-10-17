class_name Disasters
extends Node
## Afetler: deprem, ev yangini, orman yangini, sel ve final zinciri.
## Afet anindaki kayiplari oyuncu belirler: yardim gereken yerlerde Incident (isaret) cikar,
## oyuncu birim gonderir; zamaninda ulasilanlar kurtulur.
## Her afet bir rapor sozlugu dondurur (await ile):
##   {type, title, cause, collapsed, damaged, casualties, saved, evacuated, burned, flooded, baseline, tip}
## baseline: ayni afet hic hazirliksiz bir sehirde olsaydi tahmini can kaybi (oyun sonu karsilastirmasi).

signal response_changed(active: bool)
signal incident_spawned(inc: Incident)  # HUD ekrandaki isareti olusturur

const M := "res://assets/models/"
const BASE_EVAC := 0.29  # hic hazirliksiz sehrin tahliye orani

var game: Node  # GameManager
var responding := false
var river_evacuated := false  # uyari sonrasi kiyi tahliye edildi

@export var city_path: NodePath = ^"../CityMap"
@onready var city: Node3D = get_node(city_path)
@onready var traffic: Node = city.get_node("Traffic")
@onready var map_info: MapInfo = city.get_node("MapInfo")
@onready var camera_rig: Node3D = city.get_node("CameraRig")
@onready var effects: Node3D = city.get_node("Effects")

var _trees_by_tile := {}  # Vector2i -> Array[Node3D]
var _ground_by_tile := {}  # Vector2i -> Node3D
var _burned := {}  # Vector2i -> true (yanmis orman, oyun boyunca oyle kalir)
var _sandbags := {}  # Vector2i -> Node3D
var _grill_smoke: Array[Node3D] = []
var _rain: GPUParticles3D
var _flood_mat: StandardMaterial3D
var _used_spots := {}  # olay kartlariyla doldurulan yerler
var _quake_day := -100  # son deprem gunu (depremden hemen sonraki selde kacis trafigi yogun)
var life: Node  # city_life.gd: tatbikat gruplari, sabah trafigi, cadirlar, yikinti basindaki komsular


func _ready() -> void:
	life = preload("res://scripts/city_life.gd").new()
	life.name = "CityLife"
	add_child(life)
	for n in city.get_node("Nature").get_children():
		if String(n.name).begins_with("tree_"):
			var k := tile_key(n.position)
			if not _trees_by_tile.has(k):
				_trees_by_tile[k] = []
			_trees_by_tile[k].append(n)
	for g in city.get_node("Ground").get_children():
		if String(g.name).begins_with("forest_"):
			_ground_by_tile[tile_key(g.position)] = g
	# mangallardan tuten duman (farkindalik dusukken mangallar yanik birakilir)
	for p in city.get_node("Props").get_children():
		if String(p.name).begins_with("grill_"):
			var smoke: Node3D = (load(M + "afet/smoke_column.gltf") as PackedScene).instantiate()
			smoke.position = p.position + Vector3(0, 0.2, 0)
			smoke.scale = Vector3.ONE * 0.28
			effects.add_child(smoke)
			_grill_smoke.append(smoke)


static func tile_key(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / 2.0) * 2 + 1, floori(p.z / 2.0) * 2 + 1)


func _report(type: String, title: String, cause: String) -> Dictionary:
	return {"type": type, "title": title, "cause": cause, "collapsed": 0, "damaged": 0, "casualties": 0,
		"saved": 0, "evacuated": 0, "burned": 0, "flooded": 0, "baseline": 0.0, "held": [], "roads": 0,
		"tip": GameData.TIPS.get(type, GameData.TIPS["quake"]).pick_random()}


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## Farkindalik gorselleri: mangal dumani (dusuk farkindalikta mangallar yanik birakilir).
func update_awareness_visuals(awareness: float) -> void:
	for i in _grill_smoke.size():
		_grill_smoke[i].visible = awareness < 30.0 + i * 8.0


# ------------------------------------------------------------------ yardim isaretleri
func spawn_incident(kind: String, pos: Vector3, people: int, seconds: float, building: Node3D = null) -> Incident:
	var inc := Incident.new()
	inc.setup(kind, people, seconds, work_time(Incident.KINDS[kind].unit))
	inc.building = building
	inc.position = Vector3(pos.x, 0.1, pos.z)
	effects.add_child(inc)
	incident_spawned.emit(inc)
	# kurtarilanlar haritada gorunsun: yardim noktasindan toplanma alanina yururler
	inc.resolved.connect(func(i: Incident, saved: int, _lost: int):
		if saved > 0 and i.tile == Vector2i.ZERO:
			traffic.rescued_walk(i.global_position, mini(saved, 3)))
	return inc


func work_time(unit: String) -> float:
	var lvl: int = game.service_level(unit)
	var t := 0.0
	match unit:
		"rescue":
			t = maxf(1.5, 4.5 - (lvl - 1) * 1.2 - mini(game.drills, 3) * 0.3)
		"fire":
			t = maxf(1.2, 3.5 - (lvl - 1) * 1.0)
		_:
			t = maxf(1.0, 2.5 - (lvl - 1) * 0.6)
	if unit == "fire" and game.hydrants:
		t *= 0.75  # yangin muslugu
	if unit == "rescue" and game.volunteers:
		t *= 0.8  # mahalle gonulluleri
	return t * game.chief_factor(unit)  # sefle iliski


## Enkaz altindakilerin dayanma suresi: farkindalik (dogru pozisyon), deprem cantasi (su, duduk).
func rescue_time() -> float:
	return 32.0 + game.awareness * 0.15 + mini(game.kits, 2) * 5.0


## Mudahale asamasi: tum isaretler cozulene kadar bekle.
func respond(_r: Dictionary) -> void:
	responding = true
	response_changed.emit(true)
	while get_tree().get_nodes_in_group("incidents").size() > 0:
		await _wait(0.3)
	await _wait(1.2)
	responding = false
	response_changed.emit(false)


## Isareti rapora bagla. Baseline: ayni insanlar hic hazirliksiz sehirde (dusuk tahliye) ve
## hic kurtarma olmadan ne kadar kayip verirdi.
func _track(inc: Incident, r: Dictionary) -> void:
	var leth: float = Incident.KINDS[inc.kind].lethality
	if inc.tile == Vector2i.ZERO:
		var evac: float = game.evac_ratio(inc.global_position)
		r.baseline += inc.people * (1.0 - BASE_EVAC) / maxf(0.05, 1.0 - evac) * leth
	inc.resolved.connect(func(_i, saved, lost):
		if inc.tile != Vector2i.ZERO:
			return  # orman: hektar, can degil
		r.saved += saved
		r.casualties += int(round(lost * leth)))


## Yakin binalardaki yardim cagrilarini tek isarette topla (ekran okunur kalsin).
func _spawn_clustered(kind: String, items: Array, ratio: float, seconds: float, r: Dictionary, cap := 5) -> void:
	var clusters: Array = []  # [konum, kisi, bina]
	for item in items:
		var b: Node3D = item[0]
		var people := int(round(item[1] * ratio * (1.0 - game.evac_ratio(b.position))))
		if people <= 0:
			continue
		var merged := false
		for c in clusters:
			if c[0].distance_to(b.global_position) < 4.2:
				c[1] += people
				merged = true
				break
		if not merged:
			clusters.append([b.global_position, people, b])
	# ekran okunur kalsin: en fazla 'cap' isaret; en az kisili kume en yakin kumeye katilir
	while clusters.size() > cap:
		var small := 0
		for i in clusters.size():
			if clusters[i][1] < clusters[small][1]:
				small = i
		var c0: Array = clusters[small]
		clusters.remove_at(small)
		var near := 0
		for i in clusters.size():
			if clusters[i][0].distance_to(c0[0]) < clusters[near][0].distance_to(c0[0]):
				near = i
		clusters[near][1] += c0[1]
	for c in clusters:
		_track(spawn_incident(kind, c[0] + (Vector3(0.5, 0, 0.5) if kind == "injured" else Vector3.ZERO), c[1], seconds, c[2]), r)


# ------------------------------------------------------------------ deprem
func earthquake_cause(magnitude: float) -> String:
	return GameData.CAUSES.quake[0] % ("%.1f" % (5.2 + magnitude * 1.6))


func earthquake(magnitude: float) -> Dictionary:
	var r := _report("quake", "Deprem", earthquake_cause(magnitude))
	camera_rig.shake(2.0 + magnitude * 1.5)
	traffic.panic(5.0)
	r.evacuated = traffic.evacuate(game.evac_ratio(Vector3.INF))
	# herkes sokaga iner: farkindalik yuksekse toplanma alanlarina, dusukse sokakta panik
	traffic.residents_out(city.buildings(), func(p): return game.evac_ratio(p))
	_quake_day = game.day
	var collapsed: Array = []
	var damaged: Array = []
	var collapse_k := 0.45 if magnitude > 1.3 else 0.25
	for b in city.buildings():
		if b.state == Building.State.COLLAPSED:
			continue
		# hazirlik (guclendirme, gelistirme, kacak kat yikma) sayesinde onlenen yikimlar
		var init: String = b.get_meta("initial_model", b.model_name)
		var saved_risk := GameData.quake_risk(init) - GameData.quake_risk(b.model_name)
		var prepared := saved_risk > 0.0
		if prepared:
			r.baseline += saved_risk * magnitude * collapse_k * GameData.info(init).pop * 0.5 * (1.0 - BASE_EVAC) * 0.7
		var risk: float = GameData.quake_risk(b.model_name) * magnitude * game.risk.quake
		var roll := randf()
		var delay := randf_range(0.2, 1.8)
		if roll < risk * collapse_k:
			collapsed.append([b, b.population()])
			get_tree().create_timer(delay).timeout.connect(b.collapse)
		elif roll < risk and b.state == Building.State.NORMAL:
			damaged.append([b, b.population()])
			get_tree().create_timer(delay).timeout.connect(b.damage)
		if prepared and roll >= risk * collapse_k:
			# hazirliksiz halinde yikilacakti ama ayakta kaldi -> "Hazirlik ise yaradi" aninda parlar
			if roll < GameData.quake_risk(init) * magnitude * game.risk.quake * collapse_k:
				r.held.push_front(b)
			elif r.held.size() < 6 and randf() < 0.35:
				r.held.append(b)
	r.collapsed = collapsed.size()
	r.damaged = damaged.size()
	await _wait(2.6)
	var blocks := 0
	for c in collapsed:
		if blocks < 4 and randf() < 0.55 and block_road_near(c[0]):
			blocks += 1
	r.roads = blocks
	_spawn_clustered("rubble", collapsed, 0.5, rescue_time(), r, 3 + game.units_total("rescue"))
	_spawn_clustered("injured", damaged.filter(func(_d): return randf() < 0.45), 0.12, 30.0 + game.service_level("medic") * 3.0, r, 3)
	if magnitude > 1.3 or randf() < 0.7:
		_aftershock(r, magnitude)
	await respond(r)
	life.after_quake(r)
	return r


## Artci deprem: mudahale surerken gelir, hasarli binalarin bazilari coker, yeni isaretler cikar.
func _aftershock(r: Dictionary, magnitude: float) -> void:
	await _wait(randf_range(9.0, 13.0))
	if not responding:
		return
	camera_rig.shake(1.6)
	traffic.panic(2.5)
	game.audio.play("quake")
	game.hud.show_alert("ARTÇI DEPREM!", "Hasarlı binalar risk altında", "warning", Color(1.0, 0.5, 0.2))
	game.bark_once("aftershock")
	game.hud.flash(Color(1.0, 0.45, 0.2))
	var fallen: Array = []
	for b in city.buildings():
		if b.state == Building.State.DAMAGED and not b.is_busy() and randf() < 0.3 * magnitude:
			fallen.append([b, b.population()])
			get_tree().create_timer(randf_range(0.1, 1.0)).timeout.connect(b.collapse)
	r.collapsed += fallen.size()
	r.damaged = maxi(0, r.damaged - fallen.size())
	await _wait(1.4)
	if fallen.size() > 0:
		block_road_near(fallen[0][0])
	_spawn_clustered("rubble", fallen, 0.4, rescue_time() * 0.8, r, 2)


# ------------------------------------------------------------------ enkazla kapanan yollar
var _road_blocks := {}  # Vector2i -> Node3D (enkaz + bariyer)


## Yikilan binanin enkazi yanindaki yolu kapatir; bina onarilinca yol acilir.
func block_road_near(b: Building) -> bool:
	if not is_instance_valid(b):
		return false
	var k: Vector2i = traffic.nearest_road(b.position, true)
	if Vector2(k.x - b.position.x, k.y - b.position.z).length() > 2.3 or _road_blocks.has(k):
		return false
	traffic.set_blocked(k, true)
	var root := Node3D.new()
	root.position = Vector3(k.x, 0.1, k.y)
	effects.add_child(root)
	var to_b := Vector3(b.position.x - k.x, 0, b.position.z - k.y).normalized() * 0.35
	for item in [["afet/rubble_large", to_b, 1.0], ["afet/rubble_small", -to_b + Vector3(0.3, 0, 0.2), 1.1],
			["afet/road_barrier", Vector3(-0.6, 0, -0.6), 1.0], ["afet/traffic_cone", Vector3(0.7, 0, -0.5), 1.0]]:
		var n: Node3D = (load(M + item[0] + ".gltf") as PackedScene).instantiate()
		n.position = item[1]
		n.rotation.y = randf() * TAU
		n.scale = Vector3.ONE * 0.01
		root.add_child(n)
		n.create_tween().tween_property(n, "scale", Vector3.ONE * float(item[2]), 0.4).set_trans(Tween.TRANS_BACK)
	_road_blocks[k] = root
	game.hud.world_toast(root.position + Vector3.UP * 0.8, "Yol kapandı", Color(1.0, 0.6, 0.3), "rubble")
	var keys: Array = b.get_meta("road_blocks", [])
	keys.append(k)
	if not b.has_meta("road_blocks"):
		b.state_changed.connect(_on_blocker_state.bind(b))
	b.set_meta("road_blocks", keys)
	return true


func _on_blocker_state(st: int, b: Building) -> void:
	if st != Building.State.NORMAL:
		return
	for k in b.get_meta("road_blocks", []):
		unblock_road(k)
	b.set_meta("road_blocks", [])


func unblock_road(k: Vector2i) -> void:
	if not _road_blocks.has(k):
		return
	traffic.set_blocked(k, false)
	var root: Node3D = _road_blocks[k]
	_road_blocks.erase(k)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3(1, 0.01, 1), 0.5)
	tw.tween_callback(root.queue_free)


# ------------------------------------------------------------------ ev yangini
func pick_fire_building() -> Building:
	var options: Array = []
	for b in city.buildings():
		if b.state == Building.State.COLLAPSED or b.on_fire or b.closed_days > 0:
			continue
		var w := 1.0
		if "gecekondu" in b.model_name or "kacak" in b.model_name:
			w = 3.0
		elif b.model_name.begins_with("house_lv3"):
			w = 0.4
		elif not b.is_house():
			w = 0.5
		w *= 1.0 - game.district_awareness(b.position) / 100.0 * 0.6
		for i in maxi(1, int(w * 3)):
			options.append(b)
	return options.pick_random()


func house_fire_cause(b: Building) -> String:
	return GameData.CAUSES.house_fire.pick_random() % b.display_name()


func house_fire(b: Building, focus := true) -> Dictionary:
	var r := _report("house_fire", "Yangın", "")
	if b == null:
		return r
	if focus:
		camera_rig.focus(b.global_position, 26.0)
	_ignite(b, r, 16.0)
	await respond(r)
	return r


## Binayi tutustur: yangin isareti cikar. Zamaninda sondurulmezse bina coker ve komsuya sicrar.
func _ignite(b: Building, r: Dictionary, seconds: float) -> void:
	if game.extinguishers:
		seconds += 5.0  # halk yangin tupuyle ilk mudahaleyi yapar
	b.set_on_fire(true)
	traffic.gather_onlookers(b.global_position, game.district_awareness(b.position) / 100.0)
	var people := maxi(1, int(round(b.population() * 0.3 * (1.0 - game.evac_ratio(b.position)))))
	var inc := spawn_incident("fire", b.global_position, people, seconds, b)
	_track(inc, r)
	if b.population() > 0 and randf() < 0.6:
		_track(spawn_incident("injured", b.global_position + Vector3(0.6, 0, 0.6), maxi(1, people / 2), 30.0, b), r)
	_spread_while_burning(b, inc, r)
	inc.resolved.connect(func(_i, saved, _lost):
		b.set_on_fire(false)
		traffic.release_onlookers(b.global_position)
		if saved > 0:
			if b.state == Building.State.NORMAL:
				b.damage()
				r.damaged += 1
			return
		b.collapse()
		r.collapsed += 1
		life.mourners(b)
		# sondurulemeyen yangin komsulara sicrar (her komsu icin ayri zar, en fazla iki bina)
		var spread := 0
		for o in city.buildings():
			if spread >= 2:
				break
			if o != b and o.state != Building.State.COLLAPSED and not o.on_fire and o.position.distance_to(b.position) < 2.9:
				if randf() < clampf(0.6 * game.risk.fire, 0.2, 0.9):
					spread += 1
					game.notify.emit("Yangın söndürülemedi ve yan binaya sıçradı!", "disaster")
					_ignite(o, r, 12.0))


## Itfaiye calismaya baslayana kadar yangin komsu binalara sicrayabilir (bitisik nizam, ruzgar).
## Ilk birkac saniye guvenli; sonra her saniye sans. Hizli mudahale, yangin musluklari, mahalle
## farkindaligi ve yangin tupleri yayilmayi yavaslatir; riskli kararlar (risk.fire) hizlandirir.
const FIRE_SPREAD_GRACE := 4.0
const FIRE_SPREAD_MAX := 6  # bir yangin olayinda ayni anda en fazla yanan bina


func _spread_while_burning(b: Building, inc: Incident, r: Dictionary) -> void:
	var t := 0.0
	var ref: WeakRef = weakref(inc)
	while true:
		await _wait(1.0)
		var i: Incident = ref.get_ref()
		if i == null or i.state == Incident.State.DONE or not is_instance_valid(b) or not b.on_fire:
			return
		if i.state == Incident.State.WORKING:
			continue  # su sikiliyor: sicramaz
		t += 1.0
		if t < FIRE_SPREAD_GRACE:
			continue
		var p: float = 0.07 * game.risk.fire * (0.6 if game.hydrants else 1.0) * (0.8 if game.extinguishers else 1.0)
		p *= 1.0 - game.district_awareness(b.position) / 100.0 * 0.5
		if randf() >= p:
			continue
		var burning := 0
		for o in city.buildings():
			if o.on_fire:
				burning += 1
		if burning >= FIRE_SPREAD_MAX:
			return
		var target: Building = null
		var best := INF
		for o in city.buildings():
			if o == b or o.on_fire or o.state == Building.State.COLLAPSED or o.closed_days > 0:
				continue
			var d: float = o.position.distance_to(b.position)
			if d < 2.9 and d < best:
				best = d
				target = o
		if target == null:
			return
		game.notify.emit("Yangın yan binaya sıçradı: %s alevler içinde! Hemen itfaiye gönder" % target.display_name(), "disaster")
		get_tree().call_group("audio", "play", "alert_soft")
		_ignite(target, r, 14.0)
		t = 0.0  # bir sonraki sicrama icin yeniden bekle


# ------------------------------------------------------------------ orman yangini
func forest_fire_start() -> Vector2i:
	var river_z := _river_z()
	var spots: Array[Vector2i] = []
	for p in map_info.picnic_spots:
		var k := tile_key(MapInfo.to3(p))
		if not _burned.has(k):
			spots.append(k)
	if spots.is_empty():
		for p in map_info.forest_tiles:
			var k := tile_key(MapInfo.to3(p))
			if p.y < river_z and not _burned.has(k):
				spots.append(k)
	return spots.pick_random() if not spots.is_empty() else Vector2i(1, 1)


func forest_fire(start: Vector2i, focus := true) -> Dictionary:
	var r := _report("forest_fire", "Orman Yangını", "")
	r.baseline = 2.0
	var forest := {}
	for p in map_info.forest_tiles:
		forest[tile_key(MapInfo.to3(p))] = true
	if focus:
		camera_rig.focus(Vector3(start.x, 0, start.y + 3), 34.0)
	traffic.evacuate(0.0, true)
	var burning := {}  # karo -> Incident
	var props := {}
	var handled := {}
	var ignite := func(k: Vector2i):
		handled[k] = true
		props[k] = _spawn_tile_fire(k)
		var inc := spawn_incident("fire", Vector3(k.x, 0, k.y), 4, 16.0 if game.fire_plane else 11.0)
		inc.tile = k
		inc.subject = "hektar"
		burning[k] = inc
		inc.resolved.connect(func(_i, saved, _lost):
			for f in props[k]:
				FireFX.extinguish(f)
			props.erase(k)
			burning.erase(k)
			if saved == 0:
				_burn_tile(k)
				r.burned += 1)
	ignite.call(start)
	var spread: float = 0.03 * game.risk.forest * (0.5 if game.fire_plane else 1.0)
	var t := 0.0
	responding = true
	response_changed.emit(true)
	while not burning.is_empty():
		await _wait(0.8)
		t += 0.8
		if t > 45.0:
			for inc in burning.values():
				inc.time_left = 0.0  # cok uzun surerse kendiliginden biter
			continue
		for k in burning.keys():
			if not burning.has(k) or burning[k].state == Incident.State.WORKING:
				continue
			for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				var n: Vector2i = k + d
				if forest.has(n) and not handled.has(n) and not _burned.has(n) and handled.size() < 16 and randf() < spread:
					ignite.call(n)
	await respond(r)
	for a in traffic.picnickers:  # yanmis piknik alanlarina kimse donmez
		if _burned.has(tile_key(a.wander_center)):
			a.set_meta("burned", true)
			a.visible = false
			a.process_mode = Node.PROCESS_MODE_DISABLED
	return r


func _spawn_tile_fire(k: Vector2i) -> Array:
	var out := []
	for i in 2:
		var f: Node3D = (load(M + "afet/fire_small.gltf") as PackedScene).instantiate()
		f.position = Vector3(k.x + randf_range(-0.6, 0.6), 0.1, k.y + randf_range(-0.6, 0.6))
		f.scale = Vector3.ONE * randf_range(1.3, 1.9)
		f.rotation.y = randf() * TAU
		effects.add_child(f)
		Building._flicker(f)
		out.append(f)
	# agaclarin arasinda karo boyu alev, kivilcim, kalin duman (fire_fx.gd)
	var fx := FireFX.make(Vector3(0.85, 0.25, 0.85), 1.35)
	fx.light_energy = 2.2
	fx.position = Vector3(k.x, 0.15, k.y)
	effects.add_child(fx)
	out.append(fx)
	return out


func _burn_tile(k: Vector2i) -> void:
	_burned[k] = true
	for tree in _trees_by_tile.get(k, []):
		var bare: Node3D = (load(M + "doga/agac/Tree_Bare_%d_%s_Color1.gltf" % [randi_range(1, 2), ["A", "B", "C"].pick_random()]) as PackedScene).instantiate()
		bare.position = tree.position
		bare.rotation = tree.rotation
		bare.scale = tree.scale * 0.9
		effects.add_child(bare)
		tree.visible = false
	var g: Node3D = _ground_by_tile.get(k)
	if g:
		g.visible = false
		var burnt: Node3D = (load(M + "yol_zemin/tile_grass_burnt.gltf") as PackedScene).instantiate()
		burnt.position = g.position
		effects.add_child(burnt)
	for p in city.get_node("Props").get_children():
		var nm := String(p.name)
		if tile_key(p.position) == k and (nm.begins_with("grill_") or nm.begins_with("table_") or nm.begins_with("blanket_")):
			p.visible = false  # piknik alani kul oldu


func _river_z() -> float:
	return map_info.river_tiles[0].y if not map_info.river_tiles.is_empty() else 0.0


# ------------------------------------------------------------------ sel
func flood_cause() -> String:
	return (GameData.CAUSES.flood_protected if game.flood_protection >= 1 else GameData.CAUSES.flood).pick_random()


func flood(severity: float, focus := true) -> Dictionary:
	var r := _report("flood", "Sel", "")
	var protection: int = game.flood_protection
	if focus:
		camera_rig.focus(Vector3(0, 0, _river_z() + 3.0), 40.0)
	_set_rain(true)
	await _wait(1.5)
	traffic.panic(6.0)
	r.evacuated = traffic.evacuate(game.evac_ratio(Vector3.INF))
	var level: float = 0.05 + 0.16 * severity * game.risk.flood * (1.0 - protection * 0.4)
	var waters: Array[Node3D] = []
	var stranded: Array = []  # [bina, nufus]
	var tiles := PackedVector2Array(map_info.river_tiles)
	if protection < 2:
		for p in map_info.flood_tiles:
			if not _sandbags.has(tile_key(MapInfo.to3(p))):
				tiles.append(p)
	for p in tiles:
		var w: Node3D = (load(M + "yol_zemin/flood_water_overlay.gltf") as PackedScene).instantiate()
		w.position = Vector3(p.x, 0.0, p.y)
		effects.add_child(w)
		for mi in w.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = _flood_material()
		waters.append(w)
		w.create_tween().tween_property(w, "position:y", level + randf_range(-0.01, 0.01), 3.0).set_trans(Tween.TRANS_SINE)
	r.flooded = tiles.size()
	# su basan yollar kapanir; dere kenarindan araclar kacar (depremden hemen sonraysa cok daha yogun)
	var closed: Array[Vector2i] = []
	for p in tiles:
		var k := Vector2i(roundi(p.x), roundi(p.y))
		if traffic.road.has(k) and not traffic.blocked.has(k):
			traffic.set_blocked(k, true)
			closed.append(k)
	traffic.flee_traffic(_river_z(), 18 if game.day - _quake_day <= 2 else 8)
	await _wait(2.5)
	for b in city.buildings():
		if not _in_flood_zone(b.position):
			continue
		if b.state == Building.State.COLLAPSED:
			continue
		if protection >= 2 or _sandbags.has(tile_key(b.position)) or river_evacuated:
			# onlemler sayesinde kimse mahsur kalmadi: hazirliksiz sehirde ne olurdu?
			var init: String = b.get_meta("initial_model", b.model_name)
			r.baseline += GameData.info(init).pop * 0.4 * 0.5 * (1.0 - BASE_EVAC) * 0.5
			if protection >= 2 or _sandbags.has(tile_key(b.position)):
				r.held.append(b)
				continue
		if protection == 1 and randf() < 0.45:
			r.held.append(b)  # dere islahi suyu yavaslatti
		var weak := 1.6 if ("gecekondu" in b.model_name or "kacak" in b.model_name) else 1.0
		if game.flood_barriers:
			weak *= 0.7
		var k: float = severity * game.risk.flood * weak * (1.0 - protection * 0.45)
		var pop: int = b.population()
		var roll := randf()
		if roll < 0.32 * k:
			r.collapsed += 1
			b.collapse()
		elif roll < 0.75 * k and b.state == Building.State.NORMAL:
			r.damaged += 1
			b.damage()
		else:
			continue
		if river_evacuated:
			continue  # uyari sonrasi kiyi bosaltildi: kimse mahsur kalmadi
		stranded.append([b, pop])
	_spawn_clustered("stranded", stranded, 0.4, 24.0, r, 5)  # yakin binalar tek isarette
	await respond(r)
	_set_rain(false)
	for k in closed:
		traffic.set_blocked(k, false)
	for w in waters:
		var tw := w.create_tween()
		tw.tween_property(w, "position:y", -0.05, 3.0)
		tw.tween_callback(w.queue_free)
	river_evacuated = false
	return r


func _flood_material() -> StandardMaterial3D:
	if _flood_mat == null:
		_flood_mat = StandardMaterial3D.new()
		_flood_mat.albedo_color = Color(0.42, 0.5, 0.48, 0.82)  # camurlu sel suyu
		_flood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flood_mat.roughness = 0.2
		_flood_mat.metallic_specular = 0.8
	return _flood_mat


func _in_flood_zone(p: Vector3) -> bool:
	for t in map_info.flood_tiles:
		if absf(t.x - p.x) < 0.5 and absf(t.y - p.z) < 0.5:
			return true
	return false


func is_flood_tile(k: Vector2i) -> bool:
	for t in map_info.flood_tiles:
		if tile_key(MapInfo.to3(t)) == k:
			return true
	return false


## Kum torbasi: bu karoyu selden korur.
func place_sandbag(k: Vector2i) -> bool:
	if _sandbags.has(k) or not is_flood_tile(k):
		return false
	var root := Node3D.new()
	root.position = Vector3(k.x, 0.1, k.y)
	effects.add_child(root)
	for side in [-1.0, 1.0]:
		for dx in [-0.5, 0.5]:
			var s: Node3D = (load(M + "afet/sandbag_wall.gltf") as PackedScene).instantiate()
			s.position = Vector3(dx, 0, side * 0.9)
			s.scale = Vector3(1.2, 0.01, 1.2)
			root.add_child(s)
			s.create_tween().tween_property(s, "scale:y", 1.2, 0.5).set_trans(Tween.TRANS_BACK)
	_sandbags[k] = root
	return true


## Onlenen afet: tehlike gelir ama onlem sayesinde zarar vermez; oyuncu bunu gorur.
## Doner: {"title", "text", "held": [korunan binalar]}
func averted(type: String) -> Dictionary:
	var out := {"title": "AFET ÖNLENDİ!", "text": "", "held": []}
	match type:
		"flood":
			camera_rig.focus(Vector3(0, 0, _river_z() + 3.0), 40.0, 1.2)
			_set_rain(true)
			await _wait(1.5)
			var waters: Array[Node3D] = []
			for p in map_info.river_tiles:  # dere kabarir ama yatagindan tasmaz
				var w: Node3D = (load(M + "yol_zemin/flood_water_overlay.gltf") as PackedScene).instantiate()
				w.position = Vector3(p.x, 0.0, p.y)
				effects.add_child(w)
				for mi in w.find_children("*", "MeshInstance3D", true, false):
					mi.material_override = _flood_material()
				waters.append(w)
				w.create_tween().tween_property(w, "position:y", 0.12, 2.5).set_trans(Tween.TRANS_SINE)
			await _wait(3.0)
			for b in city.buildings():
				if _in_flood_zone(b.position):
					out.held.append(b)
			out.text = "Dere kabardı ama kum torbaları ve tahliye sayesinde kimse zarar görmedi."
			await _wait(1.5)
			_set_rain(false)
			for w in waters:
				var tw := w.create_tween()
				tw.tween_property(w, "position:y", -0.05, 2.5)
				tw.tween_callback(w.queue_free)
			river_evacuated = false
		"forest_fire":
			var p: Vector2 = map_info.picnic_spots[randi() % map_info.picnic_spots.size()] if not map_info.picnic_spots.is_empty() else Vector2.ZERO
			var at := Vector3(p.x, 0.1, p.y)
			camera_rig.focus(at, 24.0, 1.2)
			await _wait(1.4)
			var smoke: Node3D = (load(M + "afet/smoke_column.gltf") as PackedScene).instantiate()
			smoke.position = at + Vector3(-0.3, 0.2, 0.1)
			smoke.scale = Vector3.ONE * 0.6
			effects.add_child(smoke)
			game.hud.world_toast(at + Vector3.UP * 1.5, "Mangal yakılmadı · yasak işe yaradı", Color(0.45, 0.95, 0.55), "tree")
			await _wait(2.5)
			var tw := smoke.create_tween()
			tw.tween_property(smoke, "scale", Vector3.ONE * 0.01, 1.0)
			tw.tween_callback(smoke.queue_free)
			out.text = "Sıcak ve rüzgârlı havada ormanda ateş yakılmadı; yangın başlamadan önlendi."
		_:
			var b := pick_fire_building()
			if b:
				camera_rig.focus(b.global_position, 22.0, 1.2)
				await _wait(1.4)
				var smoke: Node3D = (load(M + "afet/smoke_column.gltf") as PackedScene).instantiate()
				smoke.position = Vector3(0.2, b.top_height(), 0.0)
				smoke.scale = Vector3.ONE * 0.5
				b.add_child(smoke)
				game.hud.world_toast(b.global_position + Vector3.UP * (b.top_height() + 0.8), "Arızalı soba söküldü", Color(0.45, 0.95, 0.55), "fire")
				await _wait(2.5)
				var tw := smoke.create_tween()
				tw.tween_property(smoke, "scale", Vector3.ONE * 0.01, 1.0)
				tw.tween_callback(smoke.queue_free)
				out.held.append(b)
			out.text = "Denetimde bulunan arızalı soba yangın çıkmadan söküldü."
	return out


## Yangin muslugu: sehrin yollarinin kenarina kirmizi musluklar dikilir (gorunur etki).
func place_hydrants() -> void:
	var keys: Array = traffic.road.keys().filter(func(k): return not traffic.dirt.has(k) and absf(k.x) < 18 and absf(k.y - 4) < 16)
	keys.shuffle()
	for i in mini(16, keys.size()):
		var k: Vector2i = keys[i]
		var h := _place("sokak/firehydrant", Vector3(k.x + 0.9 * (1 if i % 2 else -1), 0.1, k.y + 0.9), 0.0)
		h.scale = Vector3.ONE * 0.01
		var tw := h.create_tween()
		tw.tween_interval(0.5 + i * 0.08)
		tw.tween_property(h, "scale", Vector3.ONE * 1.3, 0.35).set_trans(Tween.TRANS_BACK)


## Uyarida "Kum Torbasi Diz": icinde bina olan dere kenari karolarina sirayla kum torbasi dizer.
func place_sandbags_auto() -> int:
	var keys := []
	for b in city.buildings():
		var k := tile_key(b.position)
		if is_flood_tile(k) and not _sandbags.has(k) and not keys.has(k):
			keys.append(k)
	keys.sort_custom(func(a, b): return a.x < b.x)
	for i in keys.size():
		get_tree().create_timer(0.6 + i * 0.12).timeout.connect(place_sandbag.bind(keys[i]))
	return keys.size()


func has_sandbag(k: Vector2i) -> bool:
	return _sandbags.has(k)


func _set_rain(on: bool) -> void:
	if on and _rain == null:
		_rain = GPUParticles3D.new()
		var mat := ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = Vector3(34, 1, 30)
		mat.direction = Vector3(0.15, -1, 0)
		mat.spread = 3.0
		mat.initial_velocity_min = 16.0
		mat.initial_velocity_max = 20.0
		mat.gravity = Vector3.ZERO
		_rain.process_material = mat
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.012, 0.4, 0.012)
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.75, 0.85, 1.0, 0.5)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material = sm
		_rain.draw_pass_1 = mesh
		_rain.amount = 3500
		_rain.lifetime = 0.9
		_rain.visibility_aabb = AABB(Vector3(-45, -20, -45), Vector3(90, 40, 90))
		_rain.position = Vector3(0, 14, 0)
		effects.add_child(_rain)
	if _rain:
		_rain.emitting = on
	Agent.hurry = 1.6 if on else 1.0  # yagmurda yayalar kosar adim, semsiye acar
	Agent.raining = on
	game.audio.set_rain(on)


# ------------------------------------------------------------------ final (20. gun)
## Buyuk afet zinciri: siddetli deprem -> artci yanginlar + orman yangini -> sel.
func finale() -> Dictionary:
	var total := _report("quake", "Büyük Afet Zinciri", "")
	var parts: Array[Dictionary] = []
	parts.append(await earthquake(1.45))
	game.notify.emit("Deprem sonrası gaz kaçakları ve devrilen sobalar yangın çıkardı!", "disaster")
	var fires := _report("house_fire", "Yangınlar", "")
	for i in (1 if game.gas_valves else 3):  # gaz vanalari deprem sonrasi yanginlari azaltir
		var b := pick_fire_building()
		if b:
			_ignite(b, fires, 18.0)
	parts.append(await forest_fire(forest_fire_start(), false))
	parts.append(fires)
	game.notify.emit("Ardından gelen sağanak nehri taşırdı!", "disaster")
	parts.append(await flood(1.35))
	for p in parts:
		for k in ["collapsed", "damaged", "casualties", "saved", "burned", "flooded", "baseline", "roads"]:
			total[k] += p.get(k, 0)
		total.held.append_array(p.get("held", []))
		total.evacuated = maxi(total.evacuated, p.evacuated)
	total.tip = "Afetler çoğu zaman zincirleme gelir: depremi yangın, yangını sel izleyebilir. Hazırlık her şeydir."
	return total


# ------------------------------------------------------------------ belediye yatirimlari
func build_river_walls(level: int) -> void:
	for p in map_info.river_tiles:
		if traffic.road.has(Vector2i(roundi(p.x), roundi(p.y))):
			continue  # kopru
		if level == 1:
			var w: Node3D = (load(M + "yol_zemin/river_wall.gltf") as PackedScene).instantiate()
			w.position = Vector3(p.x, 0.0, p.y)
			w.rotation.y = PI / 2.0
			w.scale = Vector3(1, 0.01, 1)
			effects.add_child(w)
			w.create_tween().tween_property(w, "scale:y", 1.0, randf_range(0.4, 0.9)).set_trans(Tween.TRANS_BACK)
		else:
			for side in [-1.0, 1.0]:
				for dx in [-0.5, 0.5]:
					var s: Node3D = (load(M + "afet/sandbag_wall.gltf") as PackedScene).instantiate()
					s.position = Vector3(p.x + dx, 0.1, p.y + side * 0.85)
					s.scale = Vector3(1.2, 0.01, 1.2)
					effects.add_child(s)
					s.create_tween().tween_property(s, "scale:y", 1.2, randf_range(0.4, 0.9)).set_trans(Tween.TRANS_BACK)


## Bir parki toplanma alanina cevir. Basarili ise true.
func add_assembly_point() -> bool:
	for p in map_info.park_tiles:
		if map_info.assembly_points.has(p):
			continue
		map_info.assembly_points.append(p)
		for item in [["afet/assembly_area_marker", Vector3(p.x, 0.11, p.y)], ["afet/sign_assembly_area", Vector3(p.x + 0.85, 0.1, p.y + 0.85)]]:
			var n: Node3D = (load(M + item[0] + ".gltf") as PackedScene).instantiate()
			n.position = item[1]
			n.scale = Vector3.ONE * 0.01
			effects.add_child(n)
			n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK)
		camera_rig.focus(Vector3(p.x, 0, p.y), 24.0)
		return true
	return false


func remove_assembly_point() -> void:
	if map_info.assembly_points.size() > 1:
		_remove_assembly_at(map_info.assembly_points[map_info.assembly_points.size() - 1])


## Muze arsasina muze kur: arsa (cit + tabela) kuculup kaybolur, bina yukselir. Doner: konum.
func build_museum(kind: String) -> Vector3:
	var i := map_info.museum_kinds.find(kind)
	if i < 0:
		return Vector3.INF
	var p: Vector2 = map_info.museum_lots[i]
	var c := Vector3(p.x, 0.0, p.y)
	var yaw := 0.0
	var lot: Node3D = city.get_node("Props").get_node_or_null("museum_lot_" + kind)
	if lot:
		yaw = lot.rotation.y
		_shrink(lot)
	var b := Building.new()
	b.model_name = "building_museum_" + kind
	b.set_meta("initial_model", b.model_name)
	b.position = c
	b.rotation.y = yaw
	city.get_node("Buildings").add_child(b)
	b.scale = Vector3(1, 0.01, 1)
	b.create_tween().tween_property(b, "scale:y", 1.0, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.3)
	_dust(c)
	return c


## Toplanma alanini kaldir: tabela ve zemin isareti kaybolur.
func _remove_assembly_at(p: Vector2) -> void:
	var i := map_info.assembly_points.find(p)
	if i < 0 or map_info.assembly_points.size() <= 1:
		return
	map_info.assembly_points.remove_at(i)
	for parent in [city.get_node("Props"), effects]:
		for n in parent.get_children():
			if n is Node3D and Vector2(n.position.x, n.position.z).distance_to(p) < 1.6 and \
					(String(n.name).begins_with("assembly") or String(n.name).contains("assembly") or n.scene_file_path.contains("assembly")):
				_shrink(n)


# ------------------------------------------------------------------ olay kartlarinin haritadaki sonuclari
## Olay kartindaki "build" etkisi: haritada gercekten bir sey insa eder. Doner: odak noktasi (yoksa INF).
##   forest/park/beach: alani temizleyip bina kurar (Building -> depremde yikilabilir, nufus getirir)
##   plaza: otopark (park etmis arabalar), camp: cadirlar, festival: cadir + mangal + kalabalik
func build_feature(fx: Dictionary) -> Vector3:
	var where: String = fx.get("where", "")
	var spot := _feature_spot(where)
	if spot == Vector2.INF:
		return Vector3.INF
	_used_spots[spot] = true
	var c := Vector3(spot.x, 0.0, spot.y)
	match where:
		"forest", "park", "beach":
			_clear_area(c, 1.5)
			if where == "park":
				_remove_assembly_at(spot)
			var b := Building.new()
			b.model_name = fx.get("model", "building_G")
			b.set_meta("initial_model", b.model_name)
			b.position = c
			b.rotation.y = _face_road(c)
			city.get_node("Buildings").add_child(b)
			b.scale = Vector3(1, 0.01, 1)
			b.create_tween().tween_property(b, "scale:y", 1.0, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_dust(c)
		"plaza":
			_clear_area(c, 1.1)
			var cars := ["car_sedan", "car_hatchback", "car_taxi", "car_stationwagon"]
			var i := 0
			for row in [-0.5, 0.5]:
				for col in [-0.6, 0.0, 0.6]:
					var car := _place("araclar/" + cars.pick_random(), c + Vector3(col, 0.1, row), PI / 2.0 if row < 0 else -PI / 2.0)
					car.scale = Vector3.ONE * 0.01
					var tw := car.create_tween()
					tw.tween_interval(i * 0.12)
					tw.tween_property(car, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK)
					i += 1
			for x in [-0.95, 0.95]:
				_place("afet/traffic_cone", c + Vector3(x, 0.1, 0.0), 0.0)
		"camp":
			_clear_area(c, 1.6, true)
			var festival: bool = fx.get("model", "") == "festival"
			var n := 4 if festival else 3
			for i in n:
				var a := TAU * i / n + randf() * 0.4
				var pos := c + Vector3(cos(a), 0.1, sin(a)) * 1.1
				var tent := _place("afet/tent_disaster", pos, randf() * TAU)
				tent.scale = Vector3.ONE * 0.01
				tent.create_tween().tween_property(tent, "scale", Vector3.ONE * 1.1, 0.5).set_trans(Tween.TRANS_BACK)
			if festival:
				for i in 3:
					var gp := c + Vector3(randf_range(-0.8, 0.8), 0.1, randf_range(-0.8, 0.8))
					var g := _place("doga/piknik/bbq_grill", gp, randf() * TAU)
					g.name = "grill_fest_%d" % i
					var smoke: Node3D = (load(M + "afet/smoke_column.gltf") as PackedScene).instantiate()
					smoke.position = gp + Vector3(0, 0.1, 0)
					smoke.scale = Vector3.ONE * 0.3
					effects.add_child(smoke)
			traffic.add_picnickers(c, 6 if festival else 3)
	return c


func _feature_spot(where: String) -> Vector2:
	var options: Array[Vector2] = []
	match where:
		"forest":
			var river_z := _river_z()
			var best_z := -INF
			for p in map_info.forest_tiles:
				if p.y >= river_z or _burned.has(tile_key(MapInfo.to3(p))) or map_info.picnic_spots.has(p):
					continue
				best_z = maxf(best_z, p.y)
			for p in map_info.forest_tiles:
				if is_equal_approx(p.y, best_z) and not map_info.picnic_spots.has(p):
					options.append(p)
		"park":
			for p in map_info.assembly_points:
				if map_info.park_tiles.has(p):
					options.append(p)
			if options.is_empty() or map_info.assembly_points.size() <= 1:
				options.assign(Array(map_info.park_tiles))
		"beach":
			var best := INF
			for p in map_info.beach_tiles:
				var rk: Vector2i = traffic.nearest_road(MapInfo.to3(p))
				var d := Vector2(rk).distance_to(p)
				if d < best - 0.1:
					best = d
					options.clear()
				if d <= best + 0.1:
					options.append(p)
		"plaza":
			for p in map_info.plaza_tiles:
				if p.distance_to(Vector2(-3, 7)) > 2.5:
					options.append(p)
		"camp":
			for p in map_info.picnic_spots:
				if not _burned.has(tile_key(MapInfo.to3(p))):
					options.append(p)
	options.assign(options.filter(func(p): return not _used_spots.has(p)))
	if options.is_empty():
		return Vector2.INF
	# sehrin ortasina en yakin olanlar one ciksin (oyuncu gorsun)
	options.sort_custom(func(a, b): return a.length() < b.length())
	return options[randi() % mini(3, options.size())]


func _face_road(c: Vector3) -> float:
	var rk: Vector2i = traffic.nearest_road(c)
	var d := Vector2(rk.x - c.x, rk.y - c.z)
	if d.length() < 0.1:
		return 0.0
	return snappedf(atan2(d.x, d.y), PI / 2.0)


func _place(path: String, pos: Vector3, yaw: float) -> Node3D:
	var n: Node3D = (load(M + path + ".gltf") as PackedScene).instantiate()
	n.position = pos
	n.rotation.y = yaw
	effects.add_child(n)
	return n


## Alandaki agac, bank, semsiye vb. kucultup gizle.
func _clear_area(c: Vector3, r: float, trees_only := false) -> void:
	var parents: Array = [city.get_node("Nature")] if trees_only else [city.get_node("Nature"), city.get_node("Props")]
	for parent in parents:
		for n in parent.get_children():
			if n is Node3D and n.visible and Vector2(n.position.x - c.x, n.position.z - c.z).length() < r:
				_shrink(n)


func _shrink(n: Node3D) -> void:
	var tw := n.create_tween()
	tw.tween_property(n, "scale", n.scale * 0.01, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): n.visible = false)


func _dust(c: Vector3) -> void:
	var p := GPUParticles3D.new()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(1.0, 0.1, 1.0)
	m.direction = Vector3(0, 1, 0)
	m.spread = 70.0
	m.initial_velocity_min = 0.5
	m.initial_velocity_max = 1.5
	m.gravity = Vector3(0, -0.5, 0)
	m.scale_min = 0.6
	m.scale_max = 1.4
	p.process_material = m
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.8, 0.72, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	p.draw_pass_1 = mesh
	p.amount = 40
	p.lifetime = 1.4
	p.one_shot = true
	p.explosiveness = 0.8
	p.position = c + Vector3(0, 0.2, 0)
	effects.add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)
