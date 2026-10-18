class_name Agent
extends Node3D
## Haritada dolasan arac / yaya. Yol karolarindan olusan agda serit takip eder.
## Davranislar:
##   NORMAL  : rastgele dolasir (arac kavsakta yol verir, oncekine carpmaz)
##   EVAC    : rota ile en yakin toplanma alanina gider (yaya)
##   GATHER  : yoldan cikip toplanma noktasina yurur, orada bekler (HOLD)
##   RESPOND : acil durum araci; olay yerine rota ile gider, sireni calar
##   RETURN  : tahliye bitince yola geri doner

signal arrived  # acil durum araci olay yerine vardi

enum Kind { CAR, WALKER, WANDERER, PICNIC }
enum Mode { NORMAL, EVAC, GATHER, HOLD, RESPOND, RETURN }

var kind := Kind.CAR
var mode := Mode.NORMAL
var traffic: Node  # traffic.gd
var tile := Vector2i.ZERO  # su an icinde bulunulan yol karosu (dunya koordinati, 2'lik adim)
var dir := Vector2i.ZERO  # karoya giris yonu (birim)
var lane := 0.45  # serit ofseti: + sag, - sol
var speed := 2.0
var height := 0.1307
var night_threshold := 2.0  # gece etkisi bu degeri gecince gizlenir (2 = hic gizlenme)
var route: Array[Vector2i] = []  # izlenecek yonler (bos ise rastgele)
var wander_center := Vector3.ZERO
var wander_radius := 0.85
var emergency := false
var despawn_on_arrival := false

var _p0 := Vector3.ZERO
var _p1 := Vector3.ZERO
var _p2 := Vector3.ZERO
var _t := 0.0
var _len := 1.0
var _next := Vector2i.ZERO
var _speed_k := 1.0
var _blocked_time := 0.0
var _panic := 0.0
var _phase := randf() * TAU
var _wait := 0.0
var _target := Vector3.ZERO  # GATHER / RETURN / gezinme hedefi
var _resume_tile := Vector2i.ZERO
var _resume_dir := Vector2i.ZERO
var _model: Node3D
var _wheels: Array[Node3D] = []
var _limbs := {}
var _siren: OmniLight3D
var _siren_t := 0.0
var _kit: Node3D
var kit_roll := randf()  # farkindalik bu degeri gecince deprem cantasi tasir
## Gecici sakin (depremde evden cikan, yangini izlemeye gelen komsu, kurtarilan): is bitince
## home_tile'a (evinin onundeki yol) yurur ve kaybolur.
var is_temp := false
var home_tile := Vector2i.ZERO
var _look := Vector3.INF  # HOLD'da bu noktaya bakar (yangin izleyicisi)
## Yagmurda yayalar hizlanir ve semsiye acar (Disasters sel sirasinda ayarlar).
static var hurry := 1.0
static var raining := false
const UMBRELLA_COLORS := [Color(0.85, 0.2, 0.2), Color(0.2, 0.45, 0.85), Color(0.95, 0.75, 0.15),
	Color(0.2, 0.65, 0.4), Color(0.6, 0.3, 0.7), Color(0.15, 0.15, 0.2)]
static var _umbrella_mesh: CylinderMesh
static var _stick_mesh: CylinderMesh
static var _umbrella_mats := []
var _umbrella: Node3D


func setup(manager: Node, model: Node3D, start_tile: Vector2i, start_dir: Vector2i) -> void:
	traffic = manager
	_model = model
	add_child(model)
	tile = start_tile
	dir = start_dir
	for n in model.find_children("*", "Node3D", true, false):
		var nm := String(n.name)
		if "wheel" in nm:
			_wheels.append(n)
		for limb in ["leg_l", "leg_r", "arm_l", "arm_r"]:
			if nm.ends_with(limb):
				_limbs[limb] = n
	if kind == Kind.CAR:
		_add_headlights()
	if kind == Kind.WANDERER or kind == Kind.PICNIC:
		position = _random_wander_point()
		position.y = height
		_pick_wander_target()
	else:
		_plan()
		_t = randf() * 0.8
		_update_transform()


## Deprem vb.: araclar durur, yayalar kosar (acil durum araclari haric).
func panic(duration: float) -> void:
	if not emergency:
		_panic = duration


func set_siren(on: bool) -> void:
	if on and _siren == null:
		_siren = OmniLight3D.new()
		_siren.position = Vector3(0, 0.5, 0)
		_siren.omni_range = 2.2
		_siren.light_energy = 2.5
		add_child(_siren)
	if _siren:
		_siren.visible = on


## Toplanma alanina git. goal: yol agindaki hedef karo, target: toplanma noktasi.
func evacuate(goal: Vector2i, target: Vector3) -> void:
	if kind == Kind.WANDERER:
		mode = Mode.HOLD  # meydan zaten acik alan
		return
	if kind == Kind.PICNIC:
		mode = Mode.GATHER
		_target = target
		return
	route = traffic.find_route(tile + _next * 2, goal)
	_target = target
	mode = Mode.EVAC


## Yangini izle: yoldan cikip target'a yurur, orada look'a donup bekler (stop_watching ile doner).
func watch(target: Vector3, look: Vector3) -> void:
	if kind == Kind.WALKER:
		_resume_tile = tile
		_resume_dir = dir
	_target = target
	_look = look
	mode = Mode.GATHER


func is_watching() -> bool:
	return _look != Vector3.INF


func stop_watching() -> void:
	if is_watching():
		end_evacuation()


## Gecici sakin evine doner (yol agi uzerinden) ve varinca kaybolur.
func go_home() -> void:
	route = traffic.find_route(tile + _next * 2, home_tile)
	if route.is_empty():
		traffic.remove_agent(self)
		return
	mode = Mode.RESPOND
	despawn_on_arrival = true


## Tahliye bitti: yola geri don ve normal hayata devam et.
func end_evacuation() -> void:
	_look = Vector3.INF
	match mode:
		Mode.NORMAL:
			if is_temp:
				go_home()
		Mode.EVAC:
			route.clear()
			mode = Mode.NORMAL
			if is_temp:
				go_home()
		Mode.GATHER, Mode.HOLD:
			if kind == Kind.WALKER:
				var d := Vector3(_resume_dir.x, 0, _resume_dir.y)
				_target = Vector3(_resume_tile.x, height, _resume_tile.y) - d + _right(d) * lane
				mode = Mode.RETURN
			else:
				mode = Mode.NORMAL
				_pick_wander_target()


## Acil durum araci olarak olay yerine git.
func respond(goal: Vector2i) -> void:
	emergency = true
	mode = Mode.RESPOND
	var from := tile + _next * 2
	route = traffic.find_route(from, goal)
	if route.is_empty() and from != goal:
		# hedef yol agina bagli degil (kopuk patika): rota bos kalirsa arac hemen "vardim" sanip
		# sehrin icinde calisirdi. Ulasilabilen en yakin noktaya git.
		route = traffic.find_route(from, traffic.reachable_road(from, Vector3(goal.x, 0, goal.y)))
	set_siren(true)


## Gorev bitti: istasyona don ve kaybol.
func return_to_station(goal: Vector2i) -> void:
	route = traffic.find_route(tile + _next * 2, goal)
	mode = Mode.RESPOND
	despawn_on_arrival = true
	set_siren(false)


func _process(delta: float) -> void:
	if _panic > 0.0:
		_panic -= delta
	if _siren and _siren.visible:
		_siren_t += delta
		_siren.light_color = Color(1, 0.15, 0.1) if fmod(_siren_t, 0.5) < 0.25 else Color(0.15, 0.35, 1)

	var target_k := 1.0
	if mode == Mode.HOLD:
		target_k = 0.0
	elif kind == Kind.CAR:
		if emergency:
			target_k = 1.5
		elif _panic > 0.0:
			target_k = 0.0
		elif _is_blocked():
			_blocked_time += delta
			target_k = 0.0 if _blocked_time < 2.5 else 1.0  # kilitlenmeyi coz
		else:
			_blocked_time = 0.0
	elif is_watching():
		target_k = 2.4 if mode == Mode.GATHER else 1.0  # merakla kosar adim gelir
	elif _panic > 0.0 or mode == Mode.EVAC or mode == Mode.GATHER:
		target_k = 2.6  # kosar
	_speed_k = move_toward(_speed_k, target_k, delta * 3.0)
	var dist := speed * _speed_k * delta
	if kind != Kind.CAR:
		dist *= hurry

	match mode:
		Mode.GATHER, Mode.RETURN:
			_walk_straight(dist, delta)
		Mode.HOLD:
			if is_watching():  # yangina don
				rotation.y = lerp_angle(rotation.y, atan2(_look.x - position.x, _look.z - position.z), minf(1.0, delta * 5.0))
		_:
			if kind == Kind.WANDERER or kind == Kind.PICNIC:
				_wander(delta, dist)
			else:
				_follow_road(dist)
	_animate(dist, delta)


# ------------------------------------------------------------------ yol takibi
func _follow_road(dist: float) -> void:
	_t += dist / _len
	while _t >= 1.0:
		_t -= 1.0
		traffic.leave_tile(tile, self)
		tile += _next * 2
		dir = _next
		traffic.enter_tile(tile, self)
		if route.is_empty() and _on_route_end():
			return
		_plan()
	_update_transform()


## Rota bittiginde ne olacak. true donerse yol takibi durur.
func _on_route_end() -> bool:
	match mode:
		Mode.EVAC:
			_resume_tile = tile
			_resume_dir = dir
			mode = Mode.GATHER
			return true
		Mode.RESPOND:
			if despawn_on_arrival:
				traffic.remove_agent(self)
			else:
				mode = Mode.HOLD
				arrived.emit()
			return true
	return false


func _plan() -> void:
	_next = traffic.next_dir(self)
	var c := Vector3(tile.x, 0.0, tile.y)
	var din := Vector3(dir.x, 0.0, dir.y)
	var dout := Vector3(_next.x, 0.0, _next.y)
	_p0 = c - din + _right(din) * lane
	_p2 = c + dout + _right(dout) * lane
	var d := din.dot(dout)
	if d > 0.9:
		_p1 = (_p0 + _p2) * 0.5
	elif d < -0.9:  # cikmaz: geri don
		_p1 = c + din * 0.6
	else:
		_p1 = _p0 + din * din.dot(_p2 - _p0)
	_len = maxf(0.2, _p0.distance_to(_p1) + _p1.distance_to(_p2))


func _update_transform() -> void:
	var u := 1.0 - _t
	var p := _p0 * u * u + _p1 * 2.0 * u * _t + _p2 * _t * _t
	var tangent := (_p1 - _p0) * 2.0 * u + (_p2 - _p1) * 2.0 * _t
	position = Vector3(p.x, height, p.z)
	if tangent.length_squared() > 1e-6:
		rotation.y = atan2(tangent.x, tangent.z)


func _right(d: Vector3) -> Vector3:
	return Vector3(-d.z, 0.0, d.x)


func _is_blocked() -> bool:
	var fwd := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	for o in traffic.cars:
		if o == self or not o.visible:
			continue
		var d: Vector3 = o.position - position
		var ahead := d.dot(fwd)
		if ahead > 0.0 and ahead < 1.25 and absf(d.dot(_right(fwd))) < 0.3:
			return true
	# kavsakta yol ver: siradaki kavsakta baska arac varsa bekle
	return _t > 0.7 and traffic.junction_busy(tile + _next * 2, self)


# ------------------------------------------------------------------ yurume (yol disi)
func _walk_straight(dist: float, delta: float) -> void:
	var to := _target - position
	to.y = 0.0
	if to.length() < 0.06:
		if mode == Mode.GATHER:
			mode = Mode.HOLD
			rotation.y = randf() * TAU
		elif mode == Mode.RETURN:
			mode = Mode.NORMAL
			tile = _resume_tile
			dir = _resume_dir
			_plan()
			_t = 0.0
			if is_temp:
				go_home()
		return
	position += to.normalized() * minf(dist, to.length())
	position.y = height
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, delta * 10.0))


func _random_wander_point() -> Vector3:
	if kind == Kind.PICNIC:
		var a := randf() * TAU
		return wander_center + Vector3(cos(a), 0, sin(a)) * randf_range(0.2, wander_radius)
	return traffic.random_wander_point(position if position != Vector3.ZERO else Vector3.INF)


func _pick_wander_target() -> void:
	_target = _random_wander_point()
	_wait = randf_range(0.5, 3.0) if randf() < (0.7 if kind == Kind.PICNIC else 0.4) else 0.0


func _wander(delta: float, dist: float) -> void:
	if _wait > 0.0 and _panic <= 0.0:
		_wait -= delta
		return
	var to := _target - position
	to.y = 0.0
	if to.length() < 0.05:
		_pick_wander_target()
		return
	position += to.normalized() * minf(dist, to.length())
	position.y = height
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, delta * 8.0))


# ------------------------------------------------------------------ gorunum
## Sirtta deprem cantasi (farkindalik arttikca daha cok insan tasir).
func set_kit(on: bool) -> void:
	if kind == Kind.CAR or _model == null:
		return
	if on and _kit == null:
		_kit = (load("res://assets/models/afet/earthquake_kit.gltf") as PackedScene).instantiate()
		_kit.scale = Vector3.ONE * 0.55
		_kit.position = Vector3(0.0, 0.125, -0.05)
		_kit.rotation.y = PI
		_model.add_child(_kit)
	if _kit:
		_kit.visible = on

func _add_headlights() -> void:
	# aracin boyu modelden (otobus / kamyon uzun): farlar onde, stoplar arkada
	var box := AABB()
	var first := true
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh == null:
			continue
		var b: AABB = (global_transform.affine_inverse() * m3.global_transform) * m3.mesh.get_aabb()  # araca gore
		box = b if first else box.merge(b)
		first = false
	var front := box.end.z if not first else 0.5
	var back := box.position.z if not first else -0.5
	var half := (box.size.x * 0.5 if not first else 0.22) * 0.62
	var y := (box.position.y + box.size.y * 0.32) if not first else 0.15
	var k := WindowLights.night()  # gece yeni cikan arac da isiklari acik dogsun
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(0.0, y, front - 0.05)
	lamp.rotation = Vector3(-0.3, PI, 0.0)  # spot -Z'ye bakar, araba +Z'ye
	lamp.light_color = Color(1.0, 0.93, 0.75)
	lamp.spot_range = 2.4
	lamp.spot_angle = 32.0
	lamp.set_meta("energy", 3.0)
	lamp.light_energy = 3.0 * k
	lamp.visible = k > 0.01
	lamp.add_to_group("night_lights")
	add_child(lamp)
	# gorunen far ve stop lambalari (parlama ile isildar)
	var bulbs := Node3D.new()
	bulbs.visible = k > 0.15
	bulbs.add_to_group("night_meshes")
	add_child(bulbs)
	for side in [-1.0, 1.0]:
		var hl := MeshInstance3D.new()
		hl.mesh = _bulb_mesh()
		hl.material_override = _bulb_mat(Color(3.2, 2.9, 2.2))
		hl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hl.position = Vector3(side * half, y, front + 0.005)
		bulbs.add_child(hl)
		var tl := MeshInstance3D.new()
		tl.mesh = _bulb_mesh()
		tl.material_override = _bulb_mat(Color(2.4, 0.12, 0.08))
		tl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tl.position = Vector3(side * half, y + 0.03, back - 0.005)
		tl.scale = Vector3(1.1, 0.7, 1.0)
		bulbs.add_child(tl)


static var _bulb: SphereMesh
static var _bulb_mats := {}


static func _bulb_mesh() -> SphereMesh:
	if _bulb == null:
		_bulb = SphereMesh.new()
		_bulb.radius = 0.048
		_bulb.height = 0.096
		_bulb.radial_segments = 8
		_bulb.rings = 4
	return _bulb


static func _bulb_mat(c: Color) -> StandardMaterial3D:
	if not _bulb_mats.has(c):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c  # 1'in ustu: HDR parlama (glow) esigini gecer
		_bulb_mats[c] = m
	return _bulb_mats[c]


## Yagmurda yayalarin elinde semsiye (modeller arasi paylasilan mesh / malzemeler).
func _update_umbrella() -> void:
	if kind == Kind.CAR or _model == null:
		return
	if raining and _umbrella == null:
		if _umbrella_mesh == null:
			_umbrella_mesh = CylinderMesh.new()
			_umbrella_mesh.top_radius = 0.004
			_umbrella_mesh.bottom_radius = 0.12
			_umbrella_mesh.height = 0.05
			_umbrella_mesh.radial_segments = 8
			_umbrella_mesh.rings = 1
			_stick_mesh = CylinderMesh.new()
			_stick_mesh.top_radius = 0.004
			_stick_mesh.bottom_radius = 0.004
			_stick_mesh.height = 0.2
			_stick_mesh.radial_segments = 4
			for c in UMBRELLA_COLORS:
				var m := StandardMaterial3D.new()
				m.albedo_color = c
				_umbrella_mats.append(m)
		_umbrella = Node3D.new()
		_umbrella.position = Vector3(0.035, 0.0, 0.01)
		var stick := MeshInstance3D.new()
		stick.mesh = _stick_mesh
		stick.position.y = 0.32
		_umbrella.add_child(stick)
		var top := MeshInstance3D.new()
		top.mesh = _umbrella_mesh
		top.material_override = _umbrella_mats.pick_random()
		top.position.y = 0.43
		_umbrella.add_child(top)
		_model.add_child(_umbrella)
	if _umbrella:
		_umbrella.visible = raining


func _animate(dist: float, delta: float) -> void:
	if raining != (_umbrella != null and _umbrella.visible):
		_update_umbrella()
	for w in _wheels:
		w.rotation.x += dist / 0.075
	if _limbs.is_empty():
		return
	var idle := (kind == Kind.WANDERER or kind == Kind.PICNIC) and _wait > 0.0
	var moving := dist > 0.0001 and not idle
	_phase += delta * speed * _speed_k * 28.0 if moving else delta * 2.0
	var swing := sin(_phase) * 0.7 if moving else 0.0
	if not moving and kind == Kind.PICNIC and mode == Mode.NORMAL:
		swing = sin(_phase * 2.0) * 0.15  # mangal basinda sohbet
	if mode == Mode.HOLD and kind != Kind.CAR:
		swing = sin(_phase * 3.0) * 0.25  # toplanma alaninda bekler
		if is_watching():
			swing = sin(_phase * 1.2) * 0.1  # yangini izler, agirligini bir ayagindan otekine verir
	for limb in _limbs:
		var s := swing if limb in ["leg_l", "arm_r"] else -swing
		var node: Node3D = _limbs[limb]
		node.rotation.x = lerpf(node.rotation.x, s, minf(1.0, delta * 12.0))
