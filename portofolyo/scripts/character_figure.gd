class_name CharacterFigure
extends Node3D
## Kodla kurulan low-poly karakter (oyunun KayKit tarzina uygun koseli yuzeyler).
## Parcalar ayri dugum: kafa, gozler, kaslar, agiz, kollar -> yuz ifadesi, konusma ve jestler.
##   set_mood("neutral" | "happy" | "angry" | "worried" | "surprised")
##   talk = 0..1 (agiz acikligi; dudak senkronu bunu her karede gunceller)
##   gesture("wave" | "shrug" | "facepalm" | "point" | "jump" | "nod" | "shake" | "tea")

const MOODS := {
	# kas acisi (ic uc yukari +), kas yuksekligi, goz yuksekligi, agiz kose acisi (+ gulumseme), agiz genisligi
	"neutral": [0.0, 0.0, 1.0, 0.0, 1.0],
	"happy": [-0.15, 0.03, 0.75, 0.45, 1.25],
	"angry": [-0.55, -0.03, 0.7, -0.4, 0.9],
	"worried": [0.45, 0.02, 1.0, -0.3, 0.85],
	"surprised": [0.1, 0.07, 1.3, 0.0, 0.7],
}

var look: Dictionary = {}
var talk := 0.0
var mood := "neutral"

var head: Node3D
var _eyes: Array[Node3D] = []
var _brows: Array[Node3D] = []
var _mouth: MeshInstance3D
var _corners: Array[Node3D] = []
var _arms: Array[Node3D] = []  # omuz pivotlari [sol, sag]
var _blush: Array[Node3D] = []
var _cur := [0.0, 0.0, 1.0, 0.0, 1.0]
var _blink := 0.0
var _next_blink := 2.0
var _t := 0.0
var _gesture_tw: Tween
var _mats := {}


func build(l: Dictionary) -> void:
	look = l
	for c in get_children():
		c.queue_free()
	_eyes.clear()
	_brows.clear()
	_corners.clear()
	_arms.clear()
	_blush.clear()
	var skin: Color = l.get("skin", Color(0.9, 0.72, 0.58))
	var outfit: Color = l.get("outfit", Color(0.3, 0.4, 0.6))
	var outfit2: Color = l.get("outfit2", Color(0.95, 0.95, 0.95))
	var hair_col: Color = l.get("hair_color", Color(0.2, 0.15, 0.1))
	# govde
	_part(self, _cyl(0.4, 0.52, 0.95, 7), outfit, Vector3(0, 0.48, 0))
	_part(self, _cyl(0.17, 0.2, 0.18, 6), skin, Vector3(0, 1.0, 0))  # boyun
	_part(self, _box(Vector3(0.28, 0.5, 0.05)), outfit2, Vector3(0, 0.72, 0.4), Vector3(-0.2, 0, 0))  # gomlek on
	if l.has("tie"):
		_part(self, _box(Vector3(0.09, 0.42, 0.04)), l.tie, Vector3(0, 0.72, 0.44), Vector3(-0.2, 0, 0))
	match String(l.get("extra", "")):
		"pearls":
			for i in 9:
				var a := PI * (0.15 + 0.7 * i / 8.0)
				_part(self, _sphere(0.035, 6), Color(0.98, 0.96, 0.9), Vector3(cos(a) * 0.24, 0.92 - sin(a) * 0.12, 0.2 + sin(a) * 0.12))
		"chain":
			_part(self, _torus(0.2, 0.235), Color(1.0, 0.8, 0.25), Vector3(0, 0.9, 0.12), Vector3(1.1, 0, 0))
		"stripes":
			for y in [0.35, 0.62]:
				_part(self, _cyl(0.47 - y * 0.08, 0.48 - y * 0.08, 0.06, 7), Color(0.95, 0.95, 0.4), Vector3(0, y, 0))
		"apron":
			_part(self, _box(Vector3(0.6, 0.7, 0.04)), Color(0.95, 0.95, 0.92), Vector3(0, 0.45, 0.47), Vector3(-0.13, 0, 0))
		"stethoscope":
			_part(self, _torus(0.2, 0.235), Color(0.3, 0.32, 0.36), Vector3(0, 0.9, 0.12), Vector3(1.0, 0, 0))
			_part(self, _sphere(0.05, 6), Color(0.7, 0.72, 0.75), Vector3(0.12, 0.6, 0.47))
		"badge":
			_part(self, _box(Vector3(0.16, 0.2, 0.03)), Color(0.95, 0.95, 0.95), Vector3(0.22, 0.7, 0.45), Vector3(-0.2, 0, 0))
	# kollar (omuz pivotu -> kol -> el)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.47, 0.88, 0.0)
		add_child(pivot)
		_part(pivot, _cyl(0.12, 0.11, 0.62, 6), outfit, Vector3(side * 0.05, -0.3, 0), Vector3(0, 0, side * 0.12))
		_part(pivot, _sphere(0.1, 6), skin, Vector3(side * 0.09, -0.65, 0.02))
		_arms.append(pivot)
	# kafa
	head = Node3D.new()
	head.position = Vector3(0, 1.48, 0)
	add_child(head)
	_part(head, _sphere(0.4, 9, 6), skin, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.05, 0.95))
	for side in [-1.0, 1.0]:
		_part(head, _sphere(0.08, 6), skin, Vector3(side * 0.39, -0.02, 0))  # kulak
	_part(head, _box(Vector3(0.09, 0.12, 0.08)), skin.darkened(0.08), Vector3(0, -0.05, 0.4))  # burun
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.14, 0.06, 0.34)
		head.add_child(eye)
		_part(eye, _sphere(0.075, 7), Color(0.98, 0.98, 0.98), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.6))
		_part(eye, _sphere(0.045, 6), Color(0.12, 0.1, 0.1), Vector3(0, 0, 0.04), Vector3.ZERO, Vector3(1, 1, 0.6))
		_eyes.append(eye)
		var brow := Node3D.new()
		brow.position = Vector3(side * 0.14, 0.19, 0.37)
		head.add_child(brow)
		_part(brow, _box(Vector3(0.15, 0.035, 0.04)), hair_col.darkened(0.2), Vector3.ZERO)
		_brows.append(brow)
		if l.get("blush", false):
			var b := _part(head, _sphere(0.06, 6), Color(1.0, 0.55, 0.55), Vector3(side * 0.22, -0.1, 0.32), Vector3.ZERO, Vector3(1.2, 0.6, 0.4))
			_blush.append(b)
	# agiz: koyu oval (y olcegi = aciklik) + iki kose (gulumseme / somurtma)
	_mouth = _part(head, _cyl(0.085, 0.085, 0.03, 8), Color(0.35, 0.08, 0.1), Vector3(0, -0.2, 0.37), Vector3(PI / 2, 0, 0)) as MeshInstance3D
	for side in [-1.0, 1.0]:
		var c := Node3D.new()
		c.position = Vector3(side * 0.08, -0.2, 0.375)
		head.add_child(c)
		_part(c, _box(Vector3(0.06, 0.022, 0.02)), Color(0.35, 0.08, 0.1), Vector3(side * 0.025, 0, 0))
		_corners.append(c)
	if l.has("mustache"):
		var big: bool = l.mustache == "big"
		_part(head, _box(Vector3(0.3 if big else 0.22, 0.07 if big else 0.03, 0.06)), hair_col if not big else hair_col.lerp(Color(0.6, 0.6, 0.6), 0.3), Vector3(0, -0.13, 0.39))
	if l.get("beard", false):
		_part(head, _sphere(0.3, 8, 5), hair_col, Vector3(0, -0.2, 0.08), Vector3.ZERO, Vector3(1.1, 0.55, 1.0))
		_mouth.position.z = 0.41
		for c in _corners:
			c.position.z = 0.415
	_hair(l, hair_col)
	_glasses(String(l.get("glasses", "")))
	_hat(String(l.get("hat", "")))
	set_mood(mood, true)


func _hair(l: Dictionary, col: Color) -> void:
	var style := String(l.get("hair", "short"))
	if style != "bald_sides" and not String(l.get("hat", "")) in ["fire_helmet", "hardhat"]:
		_part(head, _sphere(0.42, 9, 6), col, Vector3(0, 0.08, -0.04), Vector3(-0.15, 0, 0), Vector3(1.03, 0.82, 0.98))
	match style:
		"bun":
			_part(head, _sphere(0.17, 7), col, Vector3(0, 0.38, -0.25))
		"long":
			_part(head, _box(Vector3(0.78, 0.75, 0.25)), col, Vector3(0, -0.25, -0.22))
		"pony":
			_part(head, _sphere(0.13, 6), col, Vector3(0, 0.05, -0.45), Vector3.ZERO, Vector3(0.8, 1.6, 0.8))
		"bob":
			for side in [-1.0, 1.0]:
				_part(head, _box(Vector3(0.14, 0.5, 0.5)), col, Vector3(side * 0.37, -0.08, -0.05))
			_part(head, _box(Vector3(0.82, 0.52, 0.2)), col, Vector3(0, -0.06, -0.3))
		"slick":
			_part(head, _sphere(0.43, 9, 6), col, Vector3(0, 0.12, -0.08), Vector3(-0.35, 0, 0), Vector3(1.0, 0.6, 1.0))
		"messy", "wild":
			var n := 7 if style == "messy" else 10
			for i in n:
				var a := TAU * i / n
				var s := 0.12 if style == "messy" else 0.15
				_part(head, _box(Vector3(s, s, s)), col, Vector3(cos(a) * 0.3, 0.32 + sin(i * 2.3) * 0.05, sin(a) * 0.25 - 0.05),
					Vector3(i * 0.7, i * 1.3, 0))
		"bald_sides":
			for side in [-1.0, 1.0]:
				_part(head, _box(Vector3(0.1, 0.22, 0.4)), col, Vector3(side * 0.37, 0.02, -0.08))
			_part(head, _box(Vector3(0.6, 0.2, 0.12)), col, Vector3(0, 0.0, -0.36))


func _glasses(kind: String) -> void:
	match kind:
		"round":
			for side in [-1.0, 1.0]:
				_part(head, _torus(0.085, 0.105), Color(0.15, 0.12, 0.12), Vector3(side * 0.14, 0.06, 0.4), Vector3(PI / 2, 0, 0))
			_part(head, _box(Vector3(0.08, 0.02, 0.02)), Color(0.15, 0.12, 0.12), Vector3(0, 0.07, 0.41))
		"sun":
			_part(head, _box(Vector3(0.52, 0.13, 0.05)), Color(0.05, 0.05, 0.1), Vector3(0, 0.06, 0.41))
			_part(head, _box(Vector3(0.54, 0.025, 0.055)), Color(1.0, 0.8, 0.25), Vector3(0, 0.13, 0.41))


func _hat(kind: String) -> void:
	match kind:
		"fire_helmet":
			_part(head, _sphere(0.45, 9, 6), Color(0.85, 0.12, 0.1), Vector3(0, 0.12, -0.02), Vector3.ZERO, Vector3(1.0, 0.7, 1.0))
			_part(head, _cyl(0.55, 0.58, 0.04, 10), Color(0.75, 0.1, 0.08), Vector3(0, 0.1, -0.05))
			_part(head, _box(Vector3(0.14, 0.14, 0.04)), Color(1.0, 0.85, 0.25), Vector3(0, 0.33, 0.33), Vector3(-0.5, 0, 0))
		"hardhat":
			_part(head, _sphere(0.44, 9, 6), Color(0.97, 0.97, 0.95), Vector3(0, 0.12, -0.02), Vector3.ZERO, Vector3(1.0, 0.7, 1.0))
			_part(head, _cyl(0.5, 0.5, 0.03, 10), Color(0.92, 0.92, 0.9), Vector3(0, 0.1, 0.05))
		"cap":
			_part(head, _cyl(0.42, 0.44, 0.14, 9), Color(0.35, 0.3, 0.28), Vector3(0, 0.27, -0.02))
			_part(head, _box(Vector3(0.5, 0.03, 0.22)), Color(0.32, 0.27, 0.25), Vector3(0, 0.22, 0.38))


# ------------------------------------------------------------------ animasyon
func set_mood(m: String, instant := false) -> void:
	mood = m if MOODS.has(m) else "neutral"
	if instant:
		_cur = MOODS[mood].duplicate()
		_apply()


func gesture(kind: String) -> void:
	if _arms.size() < 2:
		return
	if _gesture_tw:
		_gesture_tw.kill()
	var l: Node3D = _arms[0]
	var r: Node3D = _arms[1]
	var tw := create_tween()
	_gesture_tw = tw
	match kind:
		"wave":
			tw.tween_property(r, "rotation", Vector3(0, 0, 2.6), 0.25).set_trans(Tween.TRANS_BACK)
			for i in 3:
				tw.tween_property(r, "rotation:z", 2.25, 0.15)
				tw.tween_property(r, "rotation:z", 2.75, 0.15)
		"shrug":
			tw.set_parallel()
			tw.tween_property(l, "rotation", Vector3(0, 0, -0.9), 0.2)
			tw.tween_property(r, "rotation", Vector3(0, 0, 0.9), 0.2)
			tw.tween_property(head, "rotation:z", 0.15, 0.2)
			tw.chain().tween_interval(0.5)
		"facepalm":
			tw.tween_property(r, "rotation", Vector3(-2.3, 0.0, 0.5), 0.25)
			tw.parallel().tween_property(head, "rotation:x", 0.25, 0.25)
			tw.tween_interval(0.7)
		"point":
			tw.tween_property(r, "rotation", Vector3(-1.4, 0, 0.3), 0.2).set_trans(Tween.TRANS_BACK)
			tw.tween_interval(0.7)
		"tea":
			tw.tween_property(r, "rotation", Vector3(-1.9, 0, 0.6), 0.3)
			tw.parallel().tween_property(head, "rotation:x", -0.15, 0.3)
			tw.tween_interval(0.6)
		"jump":
			tw.tween_property(self, "position:y", position.y + 0.18, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(l, "rotation", Vector3(0, 0, -2.2), 0.15)
			tw.parallel().tween_property(r, "rotation", Vector3(0, 0, 2.2), 0.15)
			tw.tween_property(self, "position:y", position.y, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"nod":
			for i in 2:
				tw.tween_property(head, "rotation:x", 0.2, 0.12)
				tw.tween_property(head, "rotation:x", -0.05, 0.12)
		"shake":
			for i in 3:
				tw.tween_property(head, "rotation:y", 0.3, 0.1)
				tw.tween_property(head, "rotation:y", -0.3, 0.1)
		"angry":
			tw.set_parallel()
			tw.tween_property(l, "rotation", Vector3(-0.4, 0, -0.5), 0.15)
			tw.tween_property(r, "rotation", Vector3(-0.4, 0, 0.5), 0.15)
			tw.chain().tween_property(self, "position:x", position.x + 0.05, 0.05)
			tw.chain().tween_property(self, "position:x", position.x - 0.05, 0.05)
			tw.chain().tween_property(self, "position:x", position.x, 0.05)
			tw.chain().tween_interval(0.4)
	# her jestten sonra rahat durusa don
	tw.chain().set_parallel(true)
	tw.tween_property(l, "rotation", Vector3.ZERO, 0.35)
	tw.tween_property(r, "rotation", Vector3.ZERO, 0.35)
	tw.tween_property(head, "rotation", Vector3.ZERO, 0.35)


func _process(delta: float) -> void:
	if head == null:
		return
	_t += delta
	var target: Array = MOODS[mood]
	for i in _cur.size():
		_cur[i] = lerpf(_cur[i], target[i], minf(1.0, delta * 10.0))
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.14
		_next_blink = randf_range(2.0, 4.5)
	if _blink > 0.0:
		_blink -= delta
	_apply()
	# nefes + konusurken hafif bas sallanmasi
	head.position.y = 1.48 + sin(_t * 2.0) * 0.008 + talk * 0.015
	if _gesture_tw == null or not _gesture_tw.is_running():
		head.rotation.z = sin(_t * 1.3) * 0.03 + talk * sin(_t * 9.0) * 0.04
		head.rotation.x = talk * sin(_t * 7.0) * 0.03


func _apply() -> void:
	var brow_angle: float = _cur[0]
	for i in _brows.size():
		var side := -1.0 if i == 0 else 1.0
		_brows[i].rotation.z = brow_angle * -side
		_brows[i].position.y = 0.19 + _cur[1]
	var eye_open: float = _cur[2] * (0.1 if _blink > 0.0 else 1.0)
	for e in _eyes:
		e.scale = Vector3(1, maxf(0.08, eye_open), 1)
	var open := clampf(talk, 0.0, 1.0)
	_mouth.scale = Vector3(_cur[4] * (1.0 - open * 0.25), 1.0, 0.25 + open * 1.3)
	for i in _corners.size():
		var side := -1.0 if i == 0 else 1.0
		_corners[i].rotation.z = _cur[3] * side * (1.0 - open * 0.6)
		_corners[i].position.x = side * 0.08 * _cur[4]
	for b in _blush:
		b.visible = mood in ["happy", "surprised"] or look.get("blush_always", false)


# ------------------------------------------------------------------ low-poly parcalar
func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		_mats[key] = m
	return _mats[key]


static func _flat(src: PrimitiveMesh) -> ArrayMesh:
	## Koseli (flat) gorunum: her ucgenin kendi normali.
	var arr := src.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var count := idx.size() if idx.size() > 0 else verts.size()
	for i in range(0, count, 3):
		var i0: int = idx[i] if idx.size() > 0 else i
		var i1: int = idx[i + 1] if idx.size() > 0 else i + 1
		var i2: int = idx[i + 2] if idx.size() > 0 else i + 2
		var a := verts[i0]
		var b := verts[i1]
		var c := verts[i2]
		var n := (b - a).cross(c - a).normalized()
		# yonu orijinal (yumusak) normallere gore duzelt: disari baksin
		if norms.size() > 0 and n.dot(norms[i0] + norms[i1] + norms[i2]) < 0.0:
			n = -n
		out_v.append_array([a, b, c])
		out_n.append_array([n, n, n])
	var res := []
	res.resize(Mesh.ARRAY_MAX)
	res[Mesh.ARRAY_VERTEX] = out_v
	res[Mesh.ARRAY_NORMAL] = out_n
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, res)
	return m


static func _sphere(r: float, seg := 8, rings := 5) -> Mesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = rings
	return _flat(s)


static func _cyl(top: float, bottom: float, h: float, seg := 8) -> Mesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return _flat(c)


static func _box(size: Vector3) -> Mesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _torus(inner: float, outer: float) -> Mesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 12
	t.ring_segments = 5
	return _flat(t)
