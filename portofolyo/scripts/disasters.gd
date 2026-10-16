class_name Disasters
extends Node
## Afetler: deprem, ev yangini, orman yangini, sel ve final zinciri.
## Afet anindaki kayiplari oyuncu belirler: yardim gereken yerlerde Incident (isaret) cikar,
## oyuncu birim gonderir; zamaninda ulasilanlar kurtulur.
## Her afet bir rapor sozlugu dondurur (await ile):
##   {type, title, cause, collapsed, damaged, casualties, saved, evacuated, burned, flooded, baseline, tip}
## baseline: ayni afet hic hazirliksiz bir sehirde olsaydi tahmini can kaybi (oyun sonu karsilastirmasi).

signal response_changed(active: bool)

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


func _ready() -> void:
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
		"saved": 0, "evacuated": 0, "burned": 0, "flooded": 0, "baseline": 0.0,
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
	return inc


func work_time(unit: String) -> float:
	var lvl: int = game.service_level(unit)
	match unit:
		"rescue":
			return maxf(1.5, 4.5 - (lvl - 1) * 1.2 - mini(game.drills, 3) * 0.3)
		"fire":
			return maxf(1.2, 3.5 - (lvl - 1) * 1.0)
	return maxf(1.0, 2.5 - (lvl - 1) * 0.6)


## Enkaz altindakilerin dayanma suresi: farkindalik (dogru pozisyon), deprem cantasi (su, duduk).
func rescue_time() -> float:
	return 32.0 + game.awareness * 0.15 + mini(game.kits, 2) * 5.0


func incident_at(screen_pos: Vector2) -> Incident:
	var cam: Camera3D = camera_rig.camera
	var best: Incident = null
	var best_d := 60.0
	for inc in get_tree().get_nodes_in_group("incidents"):
		if inc.state != Incident.State.WAITING:
			continue
		for h in [0.3, 1.4, 2.9]:
			var sp := cam.unproject_position(inc.global_position + Vector3.UP * h)
			var d := sp.distance_to(screen_pos)
			if d < best_d:
				best_d = d
				best = inc
	return best


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
func _spawn_clustered(kind: String, items: Array, ratio: float, seconds: float, r: Dictionary) -> void:
	var clusters: Array = []  # [konum, kisi, bina]
	for item in items:
		var b: Node3D = item[0]
		var people := int(round(item[1] * ratio * (1.0 - game.evac_ratio(b.position))))
		if people <= 0:
			continue
		var merged := false
		for c in clusters:
			if c[0].distance_to(b.global_position) < 3.2:
				c[1] += people
				merged = true
				break
		if not merged:
			clusters.append([b.global_position, people, b])
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
	var collapsed: Array = []
	var damaged: Array = []
	var collapse_k := 0.45 if magnitude > 1.3 else 0.3
	for b in city.buildings():
		if b.state == Building.State.COLLAPSED:
			continue
		# hazirlik (guclendirme, gelistirme, kacak kat yikma) sayesinde onlenen yikimlar
		var init: String = b.get_meta("initial_model", b.model_name)
		var saved_risk := GameData.quake_risk(init) - GameData.quake_risk(b.model_name)
		if saved_risk > 0.0:
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
	r.collapsed = collapsed.size()
	r.damaged = damaged.size()
	await _wait(2.6)
	_spawn_clustered("rubble", collapsed, 0.5, rescue_time(), r)
	_spawn_clustered("injured", damaged.filter(func(_d): return randf() < 0.45), 0.12, 30.0 + game.service_level("medic") * 3.0, r)
	await respond(r)
	return r


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
	b.set_on_fire(true)
	var people := maxi(1, int(round(b.population() * 0.3 * (1.0 - game.evac_ratio(b.position)))))
	var inc := spawn_incident("fire", b.global_position, people, seconds, b)
	_track(inc, r)
	if b.population() > 0 and randf() < 0.6:
		_track(spawn_incident("injured", b.global_position + Vector3(0.6, 0, 0.6), maxi(1, people / 2), 30.0, b), r)
	inc.resolved.connect(func(_i, saved, _lost):
		b.set_on_fire(false)
		if saved > 0:
			if b.state == Building.State.NORMAL:
				b.damage()
				r.damaged += 1
			return
		b.collapse()
		r.collapsed += 1
		# sondurulemeyen yangin komsuya sicrar
		for o in city.buildings():
			if o != b and o.state != Building.State.COLLAPSED and not o.on_fire and o.position.distance_to(b.position) < 2.3:
				if randf() < 0.55 * game.risk.fire:
					game.notify.emit("Yangın söndürülemedi ve yan binaya sıçradı!", "disaster")
					_ignite(o, r, 12.0)
				break)


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
		var inc := spawn_incident("fire", Vector3(k.x, 0, k.y), 4, 11.0)
		inc.tile = k
		inc.subject = "hektar"
		burning[k] = inc
		inc.resolved.connect(func(_i, saved, _lost):
			for f in props[k]:
				f.queue_free()
			props.erase(k)
			burning.erase(k)
			if saved == 0:
				_burn_tile(k)
				r.burned += 1)
	ignite.call(start)
	var spread: float = 0.03 * game.risk.forest
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
	for i in 3:
		var f: Node3D = (load(M + "afet/fire_small.gltf") as PackedScene).instantiate()
		f.position = Vector3(k.x + randf_range(-0.6, 0.6), 0.1, k.y + randf_range(-0.6, 0.6))
		f.scale = Vector3.ONE * randf_range(1.4, 2.2)
		effects.add_child(f)
		var tw := f.create_tween().set_loops()
		tw.tween_property(f, "scale:y", f.scale.y * 1.35, randf_range(0.15, 0.3))
		tw.tween_property(f, "scale:y", f.scale.y * 0.8, randf_range(0.15, 0.3))
		out.append(f)
	var smoke: Node3D = (load(M + "afet/smoke_column.gltf") as PackedScene).instantiate()
	smoke.position = Vector3(k.x, 0.3, k.y)
	smoke.scale = Vector3.ONE * 1.3
	effects.add_child(smoke)
	out.append(smoke)
	var light := OmniLight3D.new()
	light.position = Vector3(k.x, 0.6, k.y)
	light.light_color = Color(1.0, 0.5, 0.15)
	light.light_energy = 2.0
	light.omni_range = 3.0
	effects.add_child(light)
	out.append(light)
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
				continue
		var weak := 1.6 if ("gecekondu" in b.model_name or "kacak" in b.model_name) else 1.0
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
		var people := int(round(pop * 0.4 * (1.0 - game.evac_ratio(b.position))))
		if people > 0:
			_track(spawn_incident("stranded", b.global_position, people, 24.0, b), r)
	await respond(r)
	_set_rain(false)
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
	game.audio.set_rain(on)


# ------------------------------------------------------------------ final (20. gun)
## Buyuk afet zinciri: siddetli deprem -> artci yanginlar + orman yangini -> sel.
func finale() -> Dictionary:
	var total := _report("quake", "Büyük Afet Zinciri", "")
	var parts: Array[Dictionary] = []
	parts.append(await earthquake(1.45))
	game.notify.emit("Deprem sonrası gaz kaçakları ve devrilen sobalar yangın çıkardı!", "disaster")
	var fires := _report("house_fire", "Yangınlar", "")
	for i in 3:
		var b := pick_fire_building()
		if b:
			_ignite(b, fires, 18.0)
	parts.append(await forest_fire(forest_fire_start(), false))
	parts.append(fires)
	game.notify.emit("Ardından gelen sağanak nehri taşırdı!", "disaster")
	parts.append(await flood(1.35))
	for p in parts:
		for k in ["collapsed", "damaged", "casualties", "saved", "burned", "flooded", "baseline"]:
			total[k] += p.get(k, 0)
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
		map_info.assembly_points.remove_at(map_info.assembly_points.size() - 1)
