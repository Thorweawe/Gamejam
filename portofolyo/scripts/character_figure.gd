class_name CharacterFigure
extends Node3D
## Kodla kurulan, yumusak hatli cizgi film karakteri (portreler: diyalog, karar karti, kisa replik).
## Parcalar ayri dugum: kafa, gozler, kaslar, agiz, kollar -> yuz ifadesi, konusma ve jestler.
## Yuzeyler puruzsuz: yuksek bolumlu kure / silindir / kapsul, kutular yerine yuvarlatilmis kutu
## (superelipsoid). Isik yumusak sarmali (wrap) + kenar parlamasi; agiz shader ile cizilir
## (kenarlari kirpilmis, dudak cizgisi, ust disler, dil; gulumseme egrisi ve sesli harf bicimi).
##   set_mood("neutral" | "happy" | "angry" | "worried" | "surprised")
##   talk = 0..1 (agiz acikligi; dudak senkronu bunu her karede gunceller)
##   vowel = 0..1 (agiz bicimi: 0 genis "e/i", 0.5 "a", 1 yuvarlak "o/u")
##   gesture("wave" | "shrug" | "facepalm" | "point" | "jump" | "nod" | "shake" | "tea" | "angry" | "warn")

const MOODS := {
	# kas acisi (ic uc yukari +), kas yuksekligi, goz yuksekligi, agiz kose acisi (+ gulumseme), agiz genisligi
	"neutral": [0.0, 0.0, 1.0, 0.1, 1.0],
	"happy": [-0.15, 0.03, 0.78, 0.75, 1.15],
	"angry": [-0.55, -0.03, 0.72, -0.55, 0.9],
	"worried": [0.45, 0.02, 1.0, -0.4, 0.85],
	"surprised": [0.1, 0.07, 1.3, 0.0, 0.75],
}

var look: Dictionary = {}
var talk := 0.0
var vowel := 0.5
var mood := "neutral"

var head: Node3D
var _eyes: Array[Node3D] = []
var _brows: Array[Node3D] = []
var _mouth: MeshInstance3D
var _mouth_mat: ShaderMaterial
var _arms: Array[Node3D] = []  # omuz pivotlari [sol, sag]
var _blush: Array[Node3D] = []
var _cur := [0.0, 0.0, 1.0, 0.0, 1.0]
var _vowel := 0.5
var _open := 0.0
var _blink := 0.0
var _next_blink := 2.0
var _t := 0.0
var _gesture_tw: Tween
var _mats := {}

static var _mesh_cache := {}  # parca bicimleri tum portrelerde paylasilir


func build(l: Dictionary) -> void:
	look = l
	for c in get_children():
		c.queue_free()
	_eyes.clear()
	_brows.clear()
	_arms.clear()
	_blush.clear()
	var skin: Color = l.get("skin", Color(0.9, 0.72, 0.58))
	var outfit: Color = l.get("outfit", Color(0.3, 0.4, 0.6))
	var outfit2: Color = l.get("outfit2", Color(0.95, 0.95, 0.95))
	var hair_col: Color = l.get("hair_color", Color(0.2, 0.15, 0.1))
	# govde: konik silindir + yuvarlak omuzlar
	_part(self, _cyl(0.4, 0.52, 0.95), outfit, Vector3(0, 0.48, 0))
	_part(self, _sphere(0.42), outfit, Vector3(0, 0.93, 0), Vector3.ZERO, Vector3(1.0, 0.36, 0.92))
	_part(self, _cyl(0.17, 0.2, 0.2), skin, Vector3(0, 1.02, 0))  # boyun
	_part(self, _box(Vector3(0.28, 0.5, 0.06)), outfit2, Vector3(0, 0.72, 0.4), Vector3(-0.2, 0, 0))  # gomlek on
	if l.has("tie"):
		_part(self, _box(Vector3(0.09, 0.42, 0.05), 0.6), l.tie, Vector3(0, 0.72, 0.445), Vector3(-0.2, 0, 0))
	match String(l.get("extra", "")):
		"pearls":
			for i in 9:
				var a := PI * (0.15 + 0.7 * i / 8.0)
				_part(self, _sphere(0.035), Color(0.98, 0.96, 0.9), Vector3(cos(a) * 0.24, 0.94 - sin(a) * 0.12, 0.2 + sin(a) * 0.14))
		"chain":
			_part(self, _torus(0.2, 0.235), Color(1.0, 0.8, 0.25), Vector3(0, 0.92, 0.12), Vector3(1.1, 0, 0))
		"stripes":
			for y in [0.35, 0.62]:
				_part(self, _cyl(0.47 - y * 0.08, 0.48 - y * 0.08, 0.06), Color(0.95, 0.95, 0.4), Vector3(0, y, 0))
		"apron":
			_part(self, _box(Vector3(0.6, 0.7, 0.05)), Color(0.95, 0.95, 0.92), Vector3(0, 0.45, 0.47), Vector3(-0.13, 0, 0))
		"stethoscope":
			_part(self, _torus(0.2, 0.235), Color(0.3, 0.32, 0.36), Vector3(0, 0.92, 0.12), Vector3(1.0, 0, 0))
			_part(self, _sphere(0.05), Color(0.7, 0.72, 0.75), Vector3(0.12, 0.6, 0.47))
		"badge":
			_part(self, _box(Vector3(0.16, 0.2, 0.04)), Color(0.95, 0.95, 0.95), Vector3(0.22, 0.7, 0.45), Vector3(-0.2, 0, 0))
	# kollar (omuz pivotu -> kapsul kol -> el)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.45, 0.9, 0.0)
		add_child(pivot)
		_part(pivot, _capsule(0.12, 0.7), outfit, Vector3(side * 0.05, -0.3, 0), Vector3(0, 0, side * 0.12))
		_part(pivot, _sphere(0.1), skin, Vector3(side * 0.09, -0.66, 0.02))
		_arms.append(pivot)
	# kafa
	head = Node3D.new()
	head.position = Vector3(0, 1.48, 0)
	add_child(head)
	_part(head, _sphere(0.4), skin, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.05, 0.95))
	for side in [-1.0, 1.0]:
		_part(head, _sphere(0.08), skin, Vector3(side * 0.39, -0.02, 0), Vector3.ZERO, Vector3(0.6, 1.0, 1.0))  # kulak
	_part(head, _sphere(0.065), skin.darkened(0.06), Vector3(0, -0.05, 0.385), Vector3.ZERO, Vector3(0.85, 1.0, 0.9))  # burun
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.14, 0.06, 0.335)
		head.add_child(eye)
		_part(eye, _sphere(0.075), Color(0.98, 0.98, 0.98), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.6))
		_part(eye, _sphere(0.047), Color(0.12, 0.1, 0.1), Vector3(0, -0.005, 0.03), Vector3.ZERO, Vector3(1, 1, 0.6))
		# goz parlamasi: canli bakis
		_part(eye, _sphere(0.016), Color(1, 1, 1), Vector3(0.018, 0.02, 0.06), Vector3.ZERO, Vector3.ONE, true)
		_eyes.append(eye)
		var brow := Node3D.new()
		brow.position = Vector3(side * 0.14, 0.165, 0.372)
		head.add_child(brow)
		_part(brow, _box(Vector3(0.16, 0.04, 0.045), 0.7), hair_col.darkened(0.2), Vector3.ZERO)
		_brows.append(brow)
		if l.get("blush", false):
			var b := _part(head, _sphere(0.06), Color(1.0, 0.55, 0.55), Vector3(side * 0.22, -0.1, 0.32), Vector3.ZERO, Vector3(1.2, 0.6, 0.4))
			_blush.append(b)
	# agiz: yuzun egrisine uyan shader'li yama (bkz. _make_mouth)
	_mouth = _make_mouth()
	_mouth.position = Vector3(0, -0.2, 0.372)
	head.add_child(_mouth)
	if l.has("mustache"):
		var big: bool = l.mustache == "big"
		_part(head, _box(Vector3(0.3 if big else 0.22, 0.07 if big else 0.035, 0.07), 0.7), hair_col if not big else hair_col.lerp(Color(0.6, 0.6, 0.6), 0.3), Vector3(0, -0.13, 0.39))
	if l.get("beard", false):
		_part(head, _sphere(0.3), hair_col, Vector3(0, -0.2, 0.08), Vector3.ZERO, Vector3(1.1, 0.55, 1.0))
		_mouth.position.z = 0.405
	_hair(l, hair_col)
	_glasses(String(l.get("glasses", "")))
	_hat(String(l.get("hat", "")))
	set_mood(mood, true)


func _hair(l: Dictionary, col: Color) -> void:
	var style := String(l.get("hair", "short"))
	# sac takkesi: kafayi saran yarim kure, one dogru yukari egik -> on tarafta sac cizgisi kaslarin
	# ustunde (alin ve gozler acik), arkada ense hizasina iner. (Tam kure alni / gozleri ortuyordu.)
	if style != "bald_sides" and not String(l.get("hat", "")) in ["fire_helmet", "hardhat"]:
		_part(head, _hemi(0.425), col, Vector3(0, -0.02, -0.01), Vector3(-0.62, 0, 0), Vector3(1.04, 1.12, 1.02))
	match style:
		"bun":
			_part(head, _sphere(0.17), col, Vector3(0, 0.38, -0.25))
		"long":
			_part(head, _box(Vector3(0.78, 0.75, 0.25), 0.55), col, Vector3(0, -0.25, -0.22))
		"pony":
			_part(head, _sphere(0.13), col, Vector3(0, 0.05, -0.45), Vector3.ZERO, Vector3(0.8, 1.6, 0.8))
		"bob":
			for side in [-1.0, 1.0]:
				_part(head, _box(Vector3(0.14, 0.5, 0.5), 0.55), col, Vector3(side * 0.37, -0.08, -0.05))
			_part(head, _box(Vector3(0.82, 0.52, 0.2), 0.55), col, Vector3(0, -0.06, -0.3))
		"slick":
			# geriye taranmis kabarik sac: takkenin ustunde biraz daha buyuk, daha yukari egik ikinci kat
			_part(head, _hemi(0.44), col, Vector3(0, 0.0, -0.03), Vector3(-0.8, 0, 0), Vector3(1.0, 0.95, 1.08))
		"messy", "wild":
			# tutamlar kafa yuzeyine oturur (tepede ve arkada; kulak gibi yanlara tasmaz)
			var n := 11 if style == "messy" else 13
			var s := 0.085 if style == "messy" else 0.12
			for i in n:
				var a := TAU * i / n + 0.3
				var e := (0.35 if i % 2 == 0 else 0.75) + sin(i * 2.3) * 0.08  # dikeyden aci
				var dir := Vector3(sin(e) * cos(a), cos(e), sin(e) * sin(a) - 0.25).normalized()
				_part(head, _sphere(s), col, dir * (0.41 if style == "messy" else 0.43) + Vector3(0, 0.02, 0),
					Vector3(i * 0.7, i * 1.3, 0), Vector3(1.0, 1.25, 1.0))
		"bald_sides":
			for side in [-1.0, 1.0]:
				_part(head, _box(Vector3(0.1, 0.22, 0.4), 0.6), col, Vector3(side * 0.37, 0.02, -0.08))
			_part(head, _box(Vector3(0.6, 0.2, 0.12), 0.6), col, Vector3(0, 0.0, -0.36))


func _glasses(kind: String) -> void:
	match kind:
		"round":
			for side in [-1.0, 1.0]:
				_part(head, _torus(0.085, 0.105), Color(0.15, 0.12, 0.12), Vector3(side * 0.14, 0.06, 0.4), Vector3(PI / 2, 0, 0))
			_part(head, _box(Vector3(0.08, 0.02, 0.02), 0.7), Color(0.15, 0.12, 0.12), Vector3(0, 0.07, 0.41))
		"sun":
			_part(head, _box(Vector3(0.52, 0.13, 0.05), 0.5), Color(0.05, 0.05, 0.1), Vector3(0, 0.06, 0.41))
			_part(head, _box(Vector3(0.54, 0.025, 0.055), 0.7), Color(1.0, 0.8, 0.25), Vector3(0, 0.13, 0.41))


func _hat(kind: String) -> void:
	match kind:
		# kask / baret: kubbe yarim kure (tam kure gozleri ortuyordu), siperlik one dogru hafif kalkik
		"fire_helmet":
			_part(head, _hemi(0.47), Color(0.85, 0.12, 0.1), Vector3(0, 0.08, -0.02), Vector3(-0.25, 0, 0), Vector3(1.0, 0.95, 1.05))
			_part(head, _cyl(0.56, 0.6, 0.04), Color(0.75, 0.1, 0.08), Vector3(0, 0.08, -0.04), Vector3(-0.25, 0, 0))
			_part(head, _box(Vector3(0.14, 0.14, 0.04), 0.6), Color(1.0, 0.85, 0.25), Vector3(0, 0.47, 0.25), Vector3(-0.75, 0, 0))
		"hardhat":
			_part(head, _hemi(0.45), Color(0.97, 0.97, 0.95), Vector3(0, 0.1, -0.02), Vector3(-0.2, 0, 0), Vector3(1.0, 0.9, 1.05))
			_part(head, _cyl(0.5, 0.5, 0.03), Color(0.92, 0.92, 0.9), Vector3(0, 0.1, 0.03), Vector3(-0.2, 0, 0))
		"cap":
			_part(head, _cyl(0.42, 0.44, 0.14), Color(0.35, 0.3, 0.28), Vector3(0, 0.27, -0.02))
			_part(head, _box(Vector3(0.5, 0.03, 0.22), 0.6), Color(0.32, 0.27, 0.25), Vector3(0, 0.22, 0.38))


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
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_gesture_tw = tw
	match kind:
		"wave":
			tw.tween_property(r, "rotation", Vector3(0, 0, 2.6), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			for i in 3:
				tw.tween_property(r, "rotation:z", 2.25, 0.16)
				tw.tween_property(r, "rotation:z", 2.75, 0.16)
		"shrug":
			tw.set_parallel()
			tw.tween_property(l, "rotation", Vector3(0, 0, -0.9), 0.22)
			tw.tween_property(r, "rotation", Vector3(0, 0, 0.9), 0.22)
			tw.tween_property(head, "rotation:z", 0.15, 0.22)
			tw.chain().tween_interval(0.5)
		"facepalm":
			tw.tween_property(r, "rotation", Vector3(-2.3, 0.0, 0.5), 0.28)
			tw.parallel().tween_property(head, "rotation:x", 0.25, 0.28)
			tw.tween_interval(0.7)
		"point":
			tw.tween_property(r, "rotation", Vector3(-1.4, 0, 0.3), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.7)
		"tea":
			tw.tween_property(r, "rotation", Vector3(-1.9, 0, 0.6), 0.32)
			tw.parallel().tween_property(head, "rotation:x", -0.15, 0.32)
			tw.tween_interval(0.6)
		"jump":
			tw.tween_property(self, "position:y", position.y + 0.18, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(l, "rotation", Vector3(0, 0, -2.2), 0.16)
			tw.parallel().tween_property(r, "rotation", Vector3(0, 0, 2.2), 0.16)
			tw.tween_property(self, "position:y", position.y, 0.24).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"nod":
			for i in 2:
				tw.tween_property(head, "rotation:x", 0.2, 0.14)
				tw.tween_property(head, "rotation:x", -0.05, 0.14)
		"shake":
			for i in 3:
				tw.tween_property(head, "rotation:y", 0.3, 0.11)
				tw.tween_property(head, "rotation:y", -0.3, 0.11)
		"angry":
			tw.set_parallel()
			tw.tween_property(l, "rotation", Vector3(-0.4, 0, -0.5), 0.15)
			tw.tween_property(r, "rotation", Vector3(-0.4, 0, 0.5), 0.15)
			tw.chain().tween_property(self, "position:x", position.x + 0.05, 0.05)
			tw.chain().tween_property(self, "position:x", position.x - 0.05, 0.05)
			tw.chain().tween_property(self, "position:x", position.x, 0.05)
			tw.chain().tween_interval(0.4)
		"warn":
			# "Aman ha!": sol elle ekranin sol ustundeki gostergeye isaret, bakis oraya; sonra sol el
			# endiseyle gogse, sag el havada "dikkat!" diye uc kez sallanir, bas hafifce "yok yok"
			# (l: ekranin solundaki kol; kollar ekran duzleminde, konusma kutusunun ustunde kalacak yukseklikte)
			tw.tween_property(l, "rotation", Vector3(-0.3, 0, -2.75), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(head, "rotation", Vector3(-0.15, -0.3, 0.1), 0.32)
			tw.tween_property(l, "rotation:z", -2.55, 0.18)  # "iste bu!" diye bir kez vurgular
			tw.tween_property(l, "rotation:z", -2.75, 0.18)
			tw.tween_interval(0.3)
			tw.tween_property(l, "rotation", Vector3(-1.15, 0, 0.75), 0.28)
			tw.parallel().tween_property(r, "rotation", Vector3(-0.35, 0, 2.75), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(head, "rotation", Vector3(0.05, 0.0, 0.0), 0.28)
			for i in 3:
				tw.tween_property(r, "rotation:z", 3.0, 0.13)
				tw.parallel().tween_property(head, "rotation:y", 0.13, 0.13)
				tw.tween_property(r, "rotation:z", 2.45, 0.13)
				tw.parallel().tween_property(head, "rotation:y", -0.13, 0.13)
			tw.tween_property(r, "rotation:z", 2.75, 0.1)
			tw.parallel().tween_property(head, "rotation:y", 0.0, 0.1)
			tw.tween_interval(0.45)
	# her jestten sonra rahat durusa yumusakca don
	tw.chain().set_parallel(true)
	tw.tween_property(l, "rotation", Vector3.ZERO, 0.4)
	tw.tween_property(r, "rotation", Vector3.ZERO, 0.4)
	tw.tween_property(head, "rotation", Vector3.ZERO, 0.4)


func _process(delta: float) -> void:
	if head == null:
		return
	_t += delta
	var target: Array = MOODS[mood]
	for i in _cur.size():
		_cur[i] = lerpf(_cur[i], target[i], minf(1.0, delta * 8.0))
	# agiz: hizli acilir, yumusak kapanir (harf harf titremez, hece gibi akar)
	var want := clampf(talk, 0.0, 1.0)
	_open = lerpf(_open, want, minf(1.0, delta * (30.0 if want > _open else 14.0)))
	_vowel = lerpf(_vowel, clampf(vowel, 0.0, 1.0), minf(1.0, delta * 12.0))
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.16
		_next_blink = randf_range(2.0, 4.5)
	if _blink > 0.0:
		_blink -= delta
	_apply()
	# nefes + konusurken hafif bas sallanmasi ve cene ile birlikte inen kafa
	position.y = sin(_t * 1.9) * 0.006
	head.position.y = 1.48 + sin(_t * 2.0) * 0.006 - _open * 0.012
	if _gesture_tw == null or not _gesture_tw.is_running():
		head.rotation.z = sin(_t * 1.3) * 0.03 + _open * sin(_t * 6.0) * 0.035
		head.rotation.x = _open * 0.05 + sin(_t * 5.0) * _open * 0.02
		head.rotation.y = sin(_t * 0.7) * 0.04


func _apply() -> void:
	var brow_angle: float = _cur[0]
	for i in _brows.size():
		var side := -1.0 if i == 0 else 1.0
		_brows[i].rotation.z = brow_angle * -side
		_brows[i].position.y = 0.165 + _cur[1] + _open * 0.012
	# goz kirpma: yumusak egriyle kapanip acilir
	var blink := 1.0
	if _blink > 0.0:
		blink = absf(_blink - 0.08) / 0.08
	var eye_open: float = _cur[2] * lerpf(0.06, 1.0, blink)
	for e in _eyes:
		e.scale = Vector3(1, maxf(0.06, eye_open), 1)
	if _mouth_mat:
		_mouth_mat.set_shader_parameter("open", _open)
		_mouth_mat.set_shader_parameter("smile", _cur[3] * (1.0 - _open * 0.5))
		_mouth_mat.set_shader_parameter("width", _cur[4] * lerpf(1.12, 0.72, _vowel) * (1.0 - _open * 0.08))
		_mouth_mat.set_shader_parameter("roundness", _vowel)
	for b in _blush:
		b.visible = mood in ["happy", "surprised"] or look.get("blush_always", false)


# ------------------------------------------------------------------ agiz
## Yuze oturan kavisli yama + agiz shader'i. Disari tasan kisim saydam; kenarlar her
## cozunurlukte yumusak (fwidth). Kapali: ince dudak cizgisi; acik: koyu ic, ust disler, dil.
func _make_mouth() -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.34, 0.26)
	mesh.subdivide_width = 8
	mesh.subdivide_depth = 6
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, diffuse_lambert_wrap, specular_disabled;
uniform float open = 0.0;
uniform float smile = 0.0;
uniform float width = 1.0;
uniform float roundness = 0.5;
uniform vec3 lip = vec3(0.55, 0.2, 0.2);
void vertex() {
	VERTEX.z -= (VERTEX.x * VERTEX.x) * 1.35 + (VERTEX.y * VERTEX.y) * 0.9;  // yuzun kavsi
}
void fragment() {
	vec2 p = (UV - 0.5) * vec2(2.0, -2.0) * vec2(1.0, 0.765);
	float hw = 0.56 * width;
	float x = p.x / hw;
	float curve = smile * 0.2 * (x * x - 0.35);  // gulumseme / somurtma: koseler yukari / asagi
	float h = mix(0.075, 0.36, open) * mix(1.0, 1.3, roundness);
	float top = h * (1.0 - smile * 0.25);
	float y = p.y - curve;
	float yy = y > 0.0 ? y / top : y / h;
	float e = length(vec2(x, yy)) - 1.0;
	float aa = fwidth(e) * 1.2;
	float inside = 1.0 - smoothstep(-aa, aa, e);
	float lipline = smoothstep(-0.32 - aa, -0.32 + aa, e);
	vec3 col = vec3(0.2, 0.03, 0.06);
	// ust disler (agiz biraz acilinca gorunur)
	float teeth = step(0.2, open) * smoothstep(0.38 - aa, 0.38 + aa, yy) * step(abs(x), 0.82);
	col = mix(col, vec3(0.97, 0.95, 0.92), teeth);
	// dil
	float tongue = 1.0 - smoothstep(0.55 - aa, 0.55 + aa, length(vec2(x * 0.9, (yy + 0.95) * 1.3)));
	col = mix(col, vec3(0.85, 0.38, 0.42), tongue * step(0.25, open));
	col = mix(col, lip, clamp(lipline * smoothstep(0.1, 0.0, open) + lipline * 0.45, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.6;
	ALPHA = inside;
}"""
	_mouth_mat = ShaderMaterial.new()
	_mouth_mat.shader = sh
	var lip: Color = (look.get("skin", Color(0.9, 0.72, 0.58)) as Color).lerp(Color(0.34, 0.07, 0.09), 0.85)
	_mouth_mat.set_shader_parameter("lip", Vector3(lip.r, lip.g, lip.b))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mouth_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ------------------------------------------------------------------ yumusak parcalar
func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, glow := false) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, glow)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


## Yumusak cizgi film malzemesi: sarmali (wrap) isik golgeyi yumusatir, kenar parlamasi (rim)
## karakteri arka plandan ayirir, hafif parlaklik yuzeye hacim verir.
func _mat(c: Color, glow := false) -> StandardMaterial3D:
	var key := c.to_html() + ("g" if glow else "")
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		m.roughness = 0.62
		m.metallic_specular = 0.25
		m.rim_enabled = true
		m.rim = 0.35
		m.rim_tint = 0.6
		if glow:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats[key] = m
	return _mats[key]


static func _cached(key: String, make: Callable) -> Mesh:
	if not _mesh_cache.has(key):
		_mesh_cache[key] = make.call()
	return _mesh_cache[key]


static func _sphere(r: float) -> Mesh:
	return _cached("s%.3f" % r, func():
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = 32
		s.rings = 16
		return s)


## Yarim kure (y = 0 .. r); sac takkesi, kask kubbesi.
static func _hemi(r: float) -> Mesh:
	return _cached("h%.3f" % r, func():
		var s := SphereMesh.new()
		s.radius = r
		s.height = r
		s.is_hemisphere = true
		s.radial_segments = 32
		s.rings = 10
		return s)


static func _cyl(top: float, bottom: float, h: float) -> Mesh:
	return _cached("c%.3f_%.3f_%.3f" % [top, bottom, h], func():
		var c := CylinderMesh.new()
		c.top_radius = top
		c.bottom_radius = bottom
		c.height = h
		c.radial_segments = 32
		c.rings = 1
		return c)


static func _capsule(r: float, h: float) -> Mesh:
	return _cached("k%.3f_%.3f" % [r, h], func():
		var c := CapsuleMesh.new()
		c.radius = r
		c.height = h
		c.radial_segments = 20
		c.rings = 8
		return c)


static func _torus(inner: float, outer: float) -> Mesh:
	return _cached("t%.3f_%.3f" % [inner, outer], func():
		var t := TorusMesh.new()
		t.inner_radius = inner
		t.outer_radius = outer
		t.rings = 32
		t.ring_segments = 12
		return t)


## Yuvarlatilmis kutu (superelipsoid): kure kafesi |x|^e ile kutuya dogru sikistirilir,
## normaller analitik hesaplanir (dikis / koseli golge yok). roundness: 0.2 kosemsi .. 1 elipsoid.
static func _box(size: Vector3, roundness := 0.45) -> Mesh:
	return _cached("b%.3f_%.3f_%.3f_%.2f" % [size.x, size.y, size.z, roundness], func():
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 24
		s.rings = 12
		var arr := s.get_mesh_arrays()
		var src: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		verts.resize(src.size())
		norms.resize(src.size())
		var half := size * 0.5
		var e := roundness
		for i in src.size():
			var v := src[i].normalized()
			var p := Vector3(_spow(v.x, e) * half.x, _spow(v.y, e) * half.y, _spow(v.z, e) * half.z)
			var n := Vector3(_spow(v.x, 2.0 - e) / half.x, _spow(v.y, 2.0 - e) / half.y, _spow(v.z, 2.0 - e) / half.z)
			verts[i] = p
			norms[i] = n.normalized() if n.length_squared() > 0.0 else v
		var out := []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = verts
		out[Mesh.ARRAY_NORMAL] = norms
		out[Mesh.ARRAY_INDEX] = arr[Mesh.ARRAY_INDEX]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
		return m)


static func _spow(v: float, e: float) -> float:
	return signf(v) * pow(absf(v), e)
