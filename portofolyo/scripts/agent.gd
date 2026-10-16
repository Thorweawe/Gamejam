class_name Agent
extends Node3D
## Haritada dolasan arac / yaya. Yol karolarindan olusan agda serit takip eder,
## kavsaklarda rastgele yon secer. Traffic tarafindan olusturulur.

enum Kind { CAR, WALKER, WANDERER }

var kind := Kind.CAR
var traffic: Node  # traffic.gd
var tile := Vector2i.ZERO  # su an icinde bulunulan yol karosu (dunya koordinati, 2'lik adim)
var dir := Vector2i.ZERO  # karoya giris yonu (birim)
var lane := 0.45  # serit ofseti: + sag, - sol
var speed := 2.0
var height := 0.1307

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
var _model: Node3D
var _wheels: Array[Node3D] = []
var _limbs := {}


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
	if kind == Kind.WANDERER:
		position = traffic.random_wander_point(Vector3.INF)
		_pick_wander_target()
	else:
		_plan()
		_t = randf() * 0.8
		_update_transform()


## Deprem vb.: araclar durur, yayalar kosar.
func panic(duration: float) -> void:
	_panic = duration


func _process(delta: float) -> void:
	if _panic > 0.0:
		_panic -= delta
	var target_k := 1.0
	if kind == Kind.CAR:
		if _panic > 0.0:
			target_k = 0.0
		elif _is_blocked():
			_blocked_time += delta
			target_k = 0.0 if _blocked_time < 2.5 else 1.0  # kilitlenmeyi coz
		else:
			_blocked_time = 0.0
	elif _panic > 0.0:
		target_k = 2.4
	_speed_k = move_toward(_speed_k, target_k, delta * 3.0)
	var dist := speed * _speed_k * delta

	if kind == Kind.WANDERER:
		_wander(delta, dist)
	else:
		_t += dist / _len
		while _t >= 1.0:
			_t -= 1.0
			tile += _next * 2
			dir = _next
			_plan()
		_update_transform()
	_animate(dist, delta)


# ------------------------------------------------------------------ yol takibi
func _plan() -> void:
	_next = traffic.pick_exit(tile, dir)
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
		if o == self:
			continue
		var d: Vector3 = o.position - position
		var ahead := d.dot(fwd)
		if ahead > 0.0 and ahead < 1.25 and absf(d.dot(_right(fwd))) < 0.3:
			return true
	return false


# ------------------------------------------------------------------ meydanda gezinme
func _pick_wander_target() -> void:
	_p2 = traffic.random_wander_point(position)
	_wait = randf_range(0.0, 2.5) if randf() < 0.4 else 0.0


func _wander(delta: float, dist: float) -> void:
	if _wait > 0.0 and _panic <= 0.0:
		_wait -= delta
		return
	var to := _p2 - position
	to.y = 0.0
	if to.length() < 0.05:
		_pick_wander_target()
		return
	position += to.normalized() * minf(dist, to.length())
	position.y = height
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, delta * 8.0))


# ------------------------------------------------------------------ animasyon
func _animate(dist: float, delta: float) -> void:
	for w in _wheels:
		w.rotation.x += dist / 0.075
	if _limbs.is_empty():
		return
	var moving := dist > 0.0001 and not (kind == Kind.WANDERER and _wait > 0.0)
	_phase += delta * speed * _speed_k * 28.0 if moving else 0.0
	var swing := sin(_phase) * (0.7 if moving else 0.0)
	for limb in _limbs:
		var s := swing if limb in ["leg_l", "arm_r"] else -swing
		var node: Node3D = _limbs[limb]
		node.rotation.x = lerpf(node.rotation.x, s, minf(1.0, delta * 12.0))
