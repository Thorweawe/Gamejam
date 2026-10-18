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
var _brow_y := 0.165  # kaslarin dinlenme yuksekligi
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
var _rim := false  # true: kumas parcalari govdenin ust kenarini (y 0.955) yumusakca asar (yeni kiyafetler)

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
	var style := String(l.get("style", ""))
	_rim = style != "suit" and style != "blouse"
	if style == "suit":
		_suit(l, outfit, outfit2)
	elif style == "blouse":
		_blouse(l, outfit, outfit2)
	elif style == "blazer":
		_blazer(l, outfit, outfit2)
	elif style == "vest":
		_vest(l, outfit, outfit2)
	elif style == "fire":
		_fire(l, outfit, outfit2)
	elif style == "safety":
		_safety(l, outfit, outfit2)
	elif style == "teacher":
		_teacher(l, outfit, outfit2)
	elif style == "press":
		_press(l, outfit, outfit2)
	elif style == "labcoat":
		_labcoat(l, outfit, outfit2)
	elif style == "apron":
		_apron(l, outfit, outfit2)
	elif style == "doctor":
		_doctor(l, outfit, outfit2)
	else:
		_part(self, _box(Vector3(0.28, 0.5, 0.06)), outfit2, Vector3(0, 0.72, 0.4), Vector3(-0.2, 0, 0))  # gomlek on
		if l.has("tie"):
			_part(self, _box(Vector3(0.09, 0.42, 0.05), 0.6), l.tie, Vector3(0, 0.72, 0.445), Vector3(-0.2, 0, 0))
	match String(l.get("extra", "") if style == "" else ""):  # kiyafet stili kendi aksesuarini cizer
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
		if style == "fire" or style == "safety":  # kolda reflektor bant
			var ap := Vector3(side * 0.05 + sin(side * 0.12) * 0.18, -0.3 - cos(0.12) * 0.18, 0)
			_part(pivot, _cyl(0.13, 0.13, 0.075), outfit2 if style == "fire" else Color(0.85, 0.87, 0.9), ap, Vector3(0, 0, side * 0.12))
			if style == "fire":
				_part(pivot, _cyl(0.134, 0.134, 0.025), Color(0.82, 0.84, 0.88), ap, Vector3(0, 0, side * 0.12))
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
		brow.position = Vector3(side * 0.14, _brow_y, 0.372)
		# gunes gozlugu kas hizasina kadar cikiyor: kas camin ustunde ikinci bir cerceve gibi duruyordu -> gizli
		brow.visible = String(l.get("glasses", "")) != "sun"
		head.add_child(brow)
		if String(l.get("brow", "")) == "unibrow":
			# Selim Karatas: kalin tek kas; iki yarim ortada birlesir (ifadelerle yine ayri ayri oynar)
			_part(brow, _box(Vector3(0.23, 0.075, 0.06), 0.6), hair_col.darkened(0.45), Vector3(side * -0.04, 0.0, 0.0))
			_part(brow, _box(Vector3(0.1, 0.066, 0.058), 0.5), hair_col.darkened(0.45), Vector3(side * -0.13, -0.004, -0.002))
		else:
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


# ------------------------------------------------------------------ kiyafet detaylari (govdeye oturan parcalar)
## Govde yuzeyinin on tarafi: konik silindir (y 0..0.955) + omuz kubbesi (y 0.93 merkezli basik kure).
static func _body_z(x: float, y: float, rim := false) -> float:
	var z := 0.0
	if y <= 0.955:
		var r := lerpf(0.52, 0.4, clampf(y / 0.955, 0.0, 1.0))
		z = sqrt(maxf(r * r - x * x, 0.0))
	var dy := (y - 0.93) / (0.42 * 0.36)
	if absf(dy) < 1.0:
		var k := sqrt(1.0 - dy * dy)
		var rx := 0.42 * k
		if absf(x) < rx:
			z = maxf(z, 0.42 * 0.92 * k * sqrt(1.0 - pow(x / rx, 2.0)))
	if rim and y > 0.955 and y < 1.02:  # govde kenari kubbeden disari tasar: parca kenarin ustunden gecsin
		z = maxf(z, lerpf(sqrt(maxf(0.16 - x * x, 0.0)), z, smoothstep(0.955, 1.02, y)))
	return z


## Boyun ile yaka arasi: omuz kubbesinin boynu saran kismini kaplar (ceket / hirka rengi gorunmesin).
func _neck_band(color: Color, off: float) -> void:
	_patch(PackedVector2Array([Vector2(-0.15, 0.975), Vector2(-0.19, 1.02), Vector2(-0.12, 1.068), Vector2(0.0, 1.082),
		Vector2(0.12, 1.068), Vector2(0.19, 1.02), Vector2(0.15, 0.975)]), color, off)


## Govdenin onune, yuzeyin kivrimina oturan ince parca (kumas, yaka, kravat...).
## pts: (x, y) govde koordinati; off: yuzeyden yukseklik (ust uste binen parcalar icin artar).
func _patch(pts: PackedVector2Array, color: Color, off: float) -> void:
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		return
	var tris: Array = []
	for i in range(0, idx.size(), 3):
		tris.append([pts[idx[i]], pts[idx[i + 1]], pts[idx[i + 2]]])
	for _lvl in 3:  # inceltilir: buyuk ucgenler kivrimi takip etsin
		var nt: Array = []
		for t in tris:
			var a: Vector2 = t[0]
			var b: Vector2 = t[1]
			var c: Vector2 = t[2]
			var ab := (a + b) / 2.0
			var bc := (b + c) / 2.0
			var ca := (c + a) / 2.0
			nt.append_array([[a, ab, ca], [ab, b, bc], [ca, bc, c], [ab, bc, ca]])
		tris = nt
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for t in tris:
		var v := []
		for p in t:
			v.append(Vector3(p.x, p.y, _body_z(p.x, p.y, _rim) + off))
		var n: Vector3 = (v[1] - v[0]).cross(v[2] - v[0])
		if n.z < 0.0:  # one bakan yuz (Godot: saat yonu)
			st.add_vertex(v[0]); st.add_vertex(v[1]); st.add_vertex(v[2])
		else:
			st.add_vertex(v[0]); st.add_vertex(v[2]); st.add_vertex(v[1])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(color)
	add_child(mi)


func _on_body(x: float, y: float, off: float) -> Vector3:
	return Vector3(x, y, _body_z(x, y, _rim) + off)


static func _mirror(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(pts.size() - 1, -1, -1):
		out.append(Vector2(-pts[i].x, pts[i].y))
	return out


## Baskan: lacivert takim, beyaz gomlek + sivri yaka, dugumlu kravat, koyu reverler, cep mendili,
## yakada bayrak rozeti, iki dugme.
func _suit(l: Dictionary, jacket: Color, shirt: Color) -> void:
	var tie: Color = l.get("tie", Color(0.8, 0.15, 0.15))
	var lapel := jacket.darkened(0.22)
	_patch(PackedVector2Array([Vector2(-0.14, 0.985), Vector2(0.14, 0.985), Vector2(0.0, 0.5)]), shirt, 0.004)  # gomlek
	_neck_band(shirt, 0.004)  # gomlek boynu sarar
	for sx in [-1.0, 1.0]:  # gomlek yakasi (sivri uclar, boyundan baslar)
		var col := PackedVector2Array([Vector2(-0.025, 0.985), Vector2(-0.11, 1.055), Vector2(-0.165, 1.0), Vector2(-0.115, 0.875)])
		_patch(col if sx < 0 else _mirror(col), shirt.darkened(0.04), 0.016)
	_patch(PackedVector2Array([Vector2(-0.038, 0.965), Vector2(0.038, 0.965), Vector2(0.03, 0.895), Vector2(-0.03, 0.895)]), tie.darkened(0.12), 0.02)  # dugum
	_patch(PackedVector2Array([Vector2(-0.03, 0.895), Vector2(0.03, 0.895), Vector2(0.058, 0.575), Vector2(0.0, 0.51), Vector2(-0.058, 0.575)]), tie, 0.012)
	for y in [0.8, 0.7, 0.6]:  # kravat cizgileri
		_patch(PackedVector2Array([Vector2(-0.045, y), Vector2(0.045, y + 0.035), Vector2(0.045, y + 0.05), Vector2(-0.045, y + 0.015)]), tie.lightened(0.25), 0.016)
	for sx in [-1.0, 1.0]:  # reverler (centikli)
		var lp := PackedVector2Array([Vector2(-0.14, 0.985), Vector2(-0.004, 0.49), Vector2(-0.075, 0.47),
			Vector2(-0.215, 0.76), Vector2(-0.18, 0.79), Vector2(-0.26, 0.93)])
		_patch(lp if sx < 0 else _mirror(lp), lapel, 0.018)
	# cep: dikis cizgisi + beyaz mendil (karakterin sol gogsu, izleyicinin sagi)
	_patch(PackedVector2Array([Vector2(0.17, 0.67), Vector2(0.32, 0.665), Vector2(0.32, 0.68), Vector2(0.17, 0.685)]), lapel, 0.012)
	_patch(PackedVector2Array([Vector2(0.19, 0.683), Vector2(0.215, 0.735), Vector2(0.245, 0.7), Vector2(0.27, 0.74), Vector2(0.3, 0.68)]), shirt, 0.016)
	# yakada bayrak rozeti (kirmizi disk + beyaz ay-yildiz izlenimi)
	var pin := _part(self, _cyl(0.03, 0.03, 0.012), Color(0.85, 0.12, 0.15), _on_body(-0.185, 0.86, 0.03), Vector3(PI / 2 - 0.25, 0, 0))
	_part(pin, _cyl(0.012, 0.012, 0.014), Color.WHITE, Vector3(0.006, 0.002, 0.0))
	for y in [0.43, 0.32]:  # dugmeler
		_part(self, _sphere(0.022), jacket.darkened(0.45), _on_body(0.035, y, 0.01), Vector3.ZERO, Vector3(1, 1, 0.5))


## Nermin Hanim: krem bluz + yuvarlak yaka, mor hirka (acik mor kenar bantlari), altin dugmeler,
## inci kolye, gogsunde cicek bros ve kucuk isim karti.
func _blouse(l: Dictionary, cardigan: Color, blouse: Color) -> void:
	var band := cardigan.lightened(0.18)
	_patch(PackedVector2Array([Vector2(-0.17, 0.985), Vector2(0.17, 0.985), Vector2(0.0, 0.6)]), blouse, 0.004)  # bluz
	_neck_band(Color(1.0, 0.99, 0.97), 0.004)  # yaka boynu sarar
	for sx in [-1.0, 1.0]:  # yuvarlak (Peter Pan) yaka
		var lobe := PackedVector2Array()
		for i in 13:
			var a := PI * i / 12.0
			lobe.append(Vector2(-0.085 + cos(a) * -0.085, 0.95 - sin(a) * 0.085))
		lobe.append(Vector2(-0.0, 0.99))
		lobe.append(Vector2(-0.17, 0.99))
		var lb := lobe if sx < 0 else _mirror(lobe)
		_patch(lb, cardigan.lightened(0.35), 0.014)  # yaka kenari (lila)
		var inner := PackedVector2Array()
		for q in lb:
			inner.append(Vector2(q.x * 0.9 + (0.0085 if sx < 0 else -0.0085), 0.99 - (0.99 - q.y) * 0.82))
		_patch(inner, Color(1.0, 0.99, 0.97), 0.02)  # beyaz yaka
	for sx in [-1.0, 1.0]:  # hirka kenar bantlari: V boyunca inip ortada kapanir
		var b := PackedVector2Array([Vector2(-0.17, 0.985), Vector2(-0.0, 0.6), Vector2(0.0, 0.0), Vector2(-0.045, 0.0),
			Vector2(-0.045, 0.6), Vector2(-0.21, 0.975)])
		_patch(b if sx < 0 else _mirror(b), band, 0.012)
	for y in [0.52, 0.4, 0.28]:  # altin dugmeler
		_part(self, _sphere(0.022), Color(0.95, 0.75, 0.3), _on_body(0.0, y, 0.016), Vector3.ZERO, Vector3(1, 1, 0.5))
	# inci kolye: yakanin altinda U seklinde
	for i in 11:
		var a := PI * (0.12 + 0.76 * i / 10.0)
		var x := cos(a) * 0.15
		var y := 0.85 - sin(a) * 0.07
		_part(self, _sphere(0.023), Color(0.98, 0.96, 0.9), _on_body(x, y, 0.035))
	# bros: altin cicek (5 yaprak + pembe ortasi), izleyicinin soluna (karakterin sagi)
	var c := _on_body(-0.23, 0.76, 0.03)
	for i in 5:
		var a := TAU * i / 5.0
		_part(self, _sphere(0.02), Color(0.98, 0.8, 0.35), c + Vector3(cos(a) * 0.025, sin(a) * 0.025, 0), Vector3.ZERO, Vector3(1, 1, 0.5))
	_part(self, _sphere(0.016), Color(0.95, 0.45, 0.6), c + Vector3(0, 0, 0.008), Vector3.ZERO, Vector3(1, 1, 0.6), true)
	# isim karti (krem, mor serit)
	_patch(PackedVector2Array([Vector2(0.17, 0.64), Vector2(0.3, 0.64), Vector2(0.3, 0.71), Vector2(0.17, 0.71)]), Color(0.99, 0.97, 0.93), 0.014)
	_patch(PackedVector2Array([Vector2(0.17, 0.695), Vector2(0.3, 0.695), Vector2(0.3, 0.71), Vector2(0.17, 0.71)]), cardigan.darkened(0.1), 0.018)
	_patch(PackedVector2Array([Vector2(0.19, 0.66), Vector2(0.28, 0.66), Vector2(0.28, 0.67), Vector2(0.19, 0.67)]), Color(0.45, 0.4, 0.45), 0.018)


# ------------------------------------------------------------------ diger karakterlerin kiyafetleri
## Duz sayi listesinden nokta dizisi: [x0, y0, x1, y1, ...]
static func _pts(c: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, c.size(), 2):
		out.append(Vector2(c[i], c[i + 1]))
	return out


## U seklinde yaka egrisi: x -w..w, ortada y0, uclarda y0 + rise.
static func _u_curve(w: float, y0: float, rise: float, n := 9) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var t := lerpf(-1.0, 1.0, float(i) / (n - 1))
		out.append(Vector2(w * t, y0 + rise * t * t))
	return out


## Parca + ayna kopyasi (pts: sol taraf).
func _sym(pts: PackedVector2Array, color: Color, off: float) -> void:
	_patch(pts, color, off)
	_patch(_mirror(pts), color, off)


## Cizgi seklinde parca (kordon, fermuar, serit): pts boyunca w kalinliginda.
func _stroke(pts: PackedVector2Array, w: float, color: Color, off: float) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in pts.size():
		var d := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var n := Vector2(-d.y, d.x) * w * 0.5
		left.append(pts[i] + n)
		right.append(pts[i] - n)
	right.reverse()
	left.append_array(right)
	_patch(left, color, off)


func _rect(x0: float, y0: float, x1: float, y1: float, color: Color, off: float) -> void:
	_patch(_pts([x0, y0, x1, y0, x1, y1, x0, y1]), color, off)


func _stud(x: float, y: float, r: float, color: Color, off: float) -> void:
	_part(self, _sphere(r), color, _on_body(x, y, off), Vector3.ZERO, Vector3(1, 1, 0.5))


## Govdeyi saran serit (reflektor bant).
func _band(y: float, h: float, color: Color, grow: float) -> void:
	var rt := lerpf(0.52, 0.4, (y + h / 2.0) / 0.955) + grow
	var rb := lerpf(0.52, 0.4, (y - h / 2.0) / 0.955) + grow
	_part(self, _cyl(rt, rb, h), color, Vector3(0, y, 0))


## Klasik sivri gomlek yakasi (boyundan baslar).
func _shirt_collar(color: Color) -> void:
	_sym(_pts([-0.025, 0.985, -0.11, 1.055, -0.165, 1.0, -0.115, 0.875]), color, 0.016)


## Selim: krem ceket, koyu gomlek; genis yaka ceketin ustune tasar, acik yakada altin zincir + madalyon,
## altin cep mendili ve dugmeler.
func _blazer(l: Dictionary, jacket: Color, shirt: Color) -> void:
	var skin: Color = l.get("skin", Color(0.9, 0.72, 0.58))
	var gold := Color(1.0, 0.8, 0.25)
	var lapel := jacket.darkened(0.12)
	_patch(_pts([-0.15, 0.985, 0.15, 0.985, 0.0, 0.5]), shirt, 0.01)
	_neck_band(shirt, 0.01)
	_patch(_pts([-0.07, 0.99, 0.07, 0.99, 0.0, 0.83]), skin, 0.014)  # acik yaka
	_sym(_pts([-0.15, 0.985, -0.004, 0.49, -0.075, 0.47, -0.215, 0.76, -0.18, 0.79, -0.26, 0.93]), lapel, 0.018)
	_sym(_pts([-0.07, 0.99, -0.11, 1.055, -0.21, 0.985, -0.13, 0.82]), shirt.lightened(0.1), 0.024)
	for i in 15:  # zincir
		var a := PI * (0.08 + 0.84 * i / 14.0)
		_part(self, _sphere(0.016), gold, _on_body(cos(a) * 0.11, 0.97 - sin(a) * 0.12, 0.034), Vector3.ZERO, Vector3(1, 1, 0.6))
	_part(self, _cyl(0.03, 0.03, 0.01), gold, _on_body(0.0, 0.825, 0.04), Vector3(PI / 2 - 0.2, 0, 0))  # madalyon
	_patch(_pts([0.17, 0.67, 0.32, 0.665, 0.32, 0.68, 0.17, 0.685]), lapel.darkened(0.1), 0.012)
	_patch(_pts([0.19, 0.683, 0.215, 0.735, 0.245, 0.7, 0.27, 0.74, 0.3, 0.68]), gold, 0.016)
	for y: float in [0.43, 0.32]:
		_stud(0.035, y, 0.022, gold, 0.01)


## Husnu Amca (muhtar): kahve orgu yelek, acik renk gomlek, kemik dugmeler, cepte kalem,
## yelek cebine giden altin kostek.
func _vest(_l: Dictionary, vest: Color, shirt: Color) -> void:
	var rib := vest.darkened(0.18)
	var gold := Color(0.95, 0.75, 0.3)
	_patch(_pts([-0.17, 0.985, 0.17, 0.985, 0.0, 0.5]), shirt, 0.01)
	_neck_band(shirt, 0.01)
	_stroke(_pts([0.0, 0.975, 0.0, 0.52]), 0.03, shirt.darkened(0.05), 0.013)  # patlet
	for y: float in [0.9, 0.78, 0.66]:
		_stud(0.0, y, 0.012, shirt.darkened(0.3), 0.017)
	_shirt_collar(shirt.darkened(0.06))
	_sym(_pts([-0.17, 0.985, 0.0, 0.5, 0.0, 0.0, -0.045, 0.0, -0.045, 0.5, -0.215, 0.975]), rib, 0.012)  # orgu kenar
	for y: float in [0.44, 0.33, 0.22]:
		_stud(0.0, y, 0.024, Color(0.3, 0.2, 0.12), 0.02)
	_sym(_pts([-0.32, 0.62, -0.17, 0.62, -0.17, 0.645, -0.32, 0.645]), rib, 0.012)  # cepler
	_rect(-0.285, 0.64, -0.267, 0.72, Color(0.2, 0.35, 0.7), 0.01)  # kalem
	_rect(-0.288, 0.7, -0.264, 0.725, Color(0.85, 0.85, 0.88), 0.014)
	var a := Vector2(0.03, 0.44)
	var b := Vector2(0.24, 0.645)
	var c := Vector2(0.11, 0.43)
	for i in 11:  # kostek zinciri
		var t := i / 10.0
		var p := a * (1 - t) * (1 - t) + c * 2.0 * (1 - t) * t + b * t * t
		_part(self, _sphere(0.009), gold, _on_body(p.x, p.y, 0.022))


## Murat Sef: koyu itfaiye montu, ortada kapak + metal tokalar, sari/gumus reflektor bantlar, telsiz, isim bandi.
func _fire(_l: Dictionary, coat: Color, trim: Color) -> void:
	var silver := Color(0.82, 0.84, 0.88)
	_rect(-0.065, 0.0, 0.065, 1.0, coat.lightened(0.08), 0.008)  # firtina kapagi
	for y: float in [0.9, 0.78, 0.5, 0.38]:
		_rect(-0.05, y - 0.014, 0.05, y + 0.014, silver, 0.014)
		_rect(-0.03, y - 0.004, 0.03, y + 0.004, coat.darkened(0.3), 0.018)
	for y: float in [0.64, 0.28]:
		_band(y, 0.085, trim, 0.01)
		_band(y, 0.028, silver, 0.014)
	var rp := _on_body(-0.22, 0.8, 0.045)
	var radio := _part(self, _box(Vector3(0.1, 0.16, 0.06), 0.25), Color(0.12, 0.12, 0.13), rp, Vector3(-0.15, atan2(rp.x, rp.z), 0))
	_part(radio, _cyl(0.01, 0.012, 0.13), Color(0.1, 0.1, 0.1), Vector3(0.028, 0.14, 0))
	_part(radio, _sphere(0.012), Color(0.3, 1.0, 0.4), Vector3(-0.025, 0.06, 0.03), Vector3.ZERO, Vector3.ONE, true)
	for i in 3:
		_part(radio, _box(Vector3(0.06, 0.008, 0.01), 0.2), Color(0.3, 0.3, 0.32), Vector3(0, -0.01 - i * 0.022, 0.03))
	_rect(0.15, 0.79, 0.32, 0.85, trim, 0.012)  # isim bandi
	for i in 3:
		_rect(0.17 + i * 0.045, 0.812, 0.2 + i * 0.045, 0.828, coat, 0.016)


## Elif (AFAD): turuncu mont, lacivert gomlek yakasi, fermuar, gumus reflektor bantlar, AFAD arması ve bayrak.
func _safety(_l: Dictionary, jacket: Color, shirt: Color) -> void:
	var silver := Color(0.85, 0.87, 0.9)
	var red := Color(0.85, 0.12, 0.15)
	_patch(_pts([-0.15, 0.985, 0.15, 0.985, 0.0, 0.7]), shirt, 0.01)
	_neck_band(shirt, 0.01)
	_shirt_collar(shirt.lightened(0.12))
	_sym(_pts([-0.15, 0.985, 0.0, 0.7, -0.03, 0.7, -0.185, 0.975]), shirt, 0.013)  # yaka kenari serit
	_stroke(_pts([0.0, 0.7, 0.0, 0.0]), 0.02, jacket.darkened(0.4), 0.008)  # fermuar
	_rect(-0.018, 0.64, 0.018, 0.7, silver, 0.014)
	for y: float in [0.56, 0.26]:
		_band(y, 0.06, silver, 0.01)
	_rect(0.13, 0.74, 0.32, 0.83, shirt, 0.012)  # AFAD armasi
	for i in 4:
		_rect(0.15 + i * 0.042, 0.765, 0.175 + i * 0.042, 0.805, Color.WHITE, 0.016)
	_rect(-0.31, 0.75, -0.17, 0.83, red, 0.012)  # bayrak
	_stud(-0.255, 0.79, 0.022, Color.WHITE, 0.014)
	_stud(-0.248, 0.79, 0.018, red, 0.02)
	_stud(-0.218, 0.79, 0.008, Color.WHITE, 0.018)


## Ayse Ogretmen: yesil burgu orgu kazak, beyaz gomlek yakasi disarida, boynunda okul kimlik karti.
func _teacher(_l: Dictionary, sweater: Color, shirt: Color) -> void:
	var rib := sweater.darkened(0.14)
	var knit := sweater.darkened(0.07)
	_neck_band(shirt, 0.01)
	_patch(_u_curve(0.2, 0.935, 0.085), shirt, 0.01)
	for x: float in [-0.17, 0.17]:  # burgu desen
		var y := 0.86
		while y > 0.05:
			_patch(_pts([x, y, x + 0.03, y - 0.035, x, y - 0.07, x - 0.03, y - 0.035]), knit, 0.006)
			y -= 0.09
		_stroke(_pts([x - 0.06, 0.88, x - 0.06, 0.0]), 0.012, knit, 0.006)
		_stroke(_pts([x + 0.06, 0.88, x + 0.06, 0.0]), 0.012, knit, 0.006)
	_stroke(_u_curve(0.215, 0.925, 0.095, 11), 0.045, rib, 0.012)  # yaka ribi
	_sym(_pts([-0.01, 0.94, -0.11, 0.995, -0.165, 0.93, -0.09, 0.85]), shirt.darkened(0.03), 0.018)
	var cord := Color(0.85, 0.3, 0.3)
	_stroke(_pts([-0.14, 1.0, -0.035, 0.665]), 0.016, cord, 0.024)
	_stroke(_pts([0.14, 1.0, 0.035, 0.665]), 0.016, cord, 0.024)
	_rect(-0.065, 0.53, 0.065, 0.67, Color(0.99, 0.99, 0.98), 0.026)
	_rect(-0.065, 0.64, 0.065, 0.67, sweater, 0.03)
	_rect(-0.05, 0.56, -0.01, 0.62, Color(0.75, 0.8, 0.85), 0.03)
	_rect(0.0, 0.6, 0.05, 0.61, Color(0.6, 0.6, 0.62), 0.03)
	_rect(0.0, 0.575, 0.04, 0.585, Color(0.6, 0.6, 0.62), 0.03)
	_stud(0.0, 0.67, 0.014, Color(0.8, 0.82, 0.86), 0.03)


## Tolga (gazeteci): acik mavi gomlek ustu acik, altinda tisort, gogus cebinde kalem, boynunda BASIN karti.
func _press(l: Dictionary, shirt: Color, tee: Color) -> void:
	var skin: Color = l.get("skin", Color(0.9, 0.72, 0.58))
	var edge := shirt.darkened(0.1)
	_patch(_pts([-0.17, 0.985, 0.17, 0.985, 0.1, 0.0, -0.1, 0.0]), tee, 0.01)
	_neck_band(skin, 0.01)
	_patch(_u_curve(0.15, 0.945, 0.06), skin, 0.013)
	_stroke(_u_curve(0.16, 0.94, 0.065, 11), 0.03, tee.darkened(0.1), 0.016)  # tisort yakasi
	_sym(_pts([-0.17, 0.985, -0.1, 0.0, -0.145, 0.0, -0.215, 0.975]), edge, 0.014)  # patlar
	for y: float in [0.8, 0.62, 0.44]:
		_stud(-0.17 + 0.07 * (0.985 - y) / 0.985 - 0.022, y, 0.014, Color(0.95, 0.95, 0.95), 0.018)
	_sym(_pts([-0.17, 0.985, -0.125, 1.055, -0.255, 0.985, -0.22, 0.85]), shirt.lightened(0.08), 0.02)  # yaka
	_rect(0.17, 0.58, 0.32, 0.73, shirt.darkened(0.05), 0.012)  # cep
	_rect(0.165, 0.705, 0.325, 0.745, edge, 0.016)
	_rect(0.275, 0.715, 0.292, 0.8, Color(0.12, 0.12, 0.14), 0.02)  # kalem
	_rect(0.27, 0.735, 0.297, 0.75, Color(0.85, 0.85, 0.88), 0.024)
	var cord := Color(0.15, 0.15, 0.18)
	_stroke(_pts([-0.11, 0.99, -0.03, 0.62]), 0.014, cord, 0.022)
	_stroke(_pts([0.11, 0.99, 0.03, 0.62]), 0.014, cord, 0.022)
	_rect(-0.075, 0.47, 0.075, 0.62, Color(0.98, 0.98, 0.98), 0.026)  # BASIN karti
	_rect(-0.075, 0.585, 0.075, 0.62, Color(0.85, 0.15, 0.15), 0.03)
	_rect(-0.05, 0.598, 0.05, 0.606, Color.WHITE, 0.034)
	_rect(-0.055, 0.545, 0.055, 0.555, Color(0.6, 0.6, 0.62), 0.03)
	_rect(-0.055, 0.515, 0.03, 0.525, Color(0.6, 0.6, 0.62), 0.03)


## Prof. Oguz: beyaz laboratuvar onlugu, mavi gomlek + puantiyeli kravat, cepte renkli kalemler.
func _labcoat(l: Dictionary, coat: Color, shirt: Color) -> void:
	var tie: Color = l.get("tie", Color(0.3, 0.3, 0.6))
	var lapel := coat.darkened(0.08)
	_patch(_pts([-0.14, 0.985, 0.14, 0.985, 0.0, 0.5]), shirt, 0.01)
	_neck_band(shirt, 0.01)
	_shirt_collar(shirt.lightened(0.12))
	_patch(_pts([-0.038, 0.965, 0.038, 0.965, 0.03, 0.895, -0.03, 0.895]), tie.darkened(0.12), 0.02)
	_patch(_pts([-0.03, 0.895, 0.03, 0.895, 0.058, 0.575, 0.0, 0.51, -0.058, 0.575]), tie, 0.012)
	for p: Vector2 in [Vector2(-0.015, 0.83), Vector2(0.02, 0.76), Vector2(-0.02, 0.69), Vector2(0.02, 0.62)]:
		_stud(p.x, p.y, 0.01, tie.lightened(0.45), 0.016)
	_sym(_pts([-0.14, 0.985, -0.004, 0.49, -0.085, 0.46, -0.24, 0.76, -0.2, 0.795, -0.28, 0.93]), lapel, 0.018)
	var pens := [Color(0.2, 0.35, 0.8), Color(0.85, 0.2, 0.2), Color(0.15, 0.15, 0.17)]
	for i in 3:  # kalemler (cebin icinden cikar)
		var x := 0.19 + i * 0.035
		var col: Color = pens[i]
		_rect(x, 0.6, x + 0.022, 0.74, col, 0.008)
		_rect(x, 0.715, x + 0.022, 0.745, col.darkened(0.3), 0.01)
	_rect(0.16, 0.5, 0.33, 0.66, coat.darkened(0.04), 0.012)  # cep
	_stroke(_pts([0.16, 0.66, 0.33, 0.66]), 0.01, lapel.darkened(0.1), 0.016)
	for y: float in [0.43, 0.32]:
		_stud(0.035, y, 0.022, coat.darkened(0.3), 0.01)


## Riza Usta (esnaf): krem gomlek, kirmizi cizgili beyaz esnaf onlugu, kirmizi askilar, cepte kursun kalem.
func _apron(_l: Dictionary, shirt: Color, trim: Color) -> void:
	var apron := Color(0.98, 0.97, 0.94)
	_shirt_collar(shirt.darkened(0.08))
	_stroke(_pts([0.0, 0.975, 0.0, 0.79]), 0.028, shirt.darkened(0.05), 0.008)
	for y: float in [0.92, 0.84]:
		_stud(0.0, y, 0.012, shirt.darkened(0.3), 0.014)
	_stroke(_pts([-0.17, 0.79, -0.165, 0.95, -0.14, 1.03, -0.1, 1.07]), 0.035, trim, 0.012)  # askilar
	_stroke(_pts([0.17, 0.79, 0.165, 0.95, 0.14, 1.03, 0.1, 1.07]), 0.035, trim, 0.012)
	_patch(_pts([-0.19, 0.8, 0.19, 0.8, 0.22, 0.52, 0.42, 0.47, 0.4, 0.0, -0.4, 0.0, -0.42, 0.47, -0.22, 0.52]), apron, 0.01)
	for x: float in [-0.15, -0.1, -0.05, 0.0, 0.05, 0.1, 0.15]:
		_stroke(_pts([x, 0.79, x, 0.0]), 0.008, trim.lightened(0.15), 0.013)
	_stroke(_pts([-0.19, 0.795, 0.19, 0.795]), 0.025, trim, 0.016)
	_stroke(_pts([-0.19, 0.8, -0.22, 0.52, -0.42, 0.47]), 0.018, trim, 0.016)  # kenar biyesi
	_stroke(_pts([0.19, 0.8, 0.22, 0.52, 0.42, 0.47]), 0.018, trim, 0.016)
	_rect(0.045, 0.66, 0.062, 0.77, Color(1.0, 0.8, 0.2), 0.015)  # kalem
	_rect(0.045, 0.755, 0.062, 0.775, Color(0.95, 0.55, 0.6), 0.018)
	_rect(-0.105, 0.575, 0.105, 0.7, trim, 0.0165)  # cep (kirmizi cerceve)
	_rect(-0.095, 0.585, 0.095, 0.69, apron, 0.017)
	_stroke(_pts([-0.1, 0.7, 0.1, 0.7]), 0.018, trim, 0.02)


## Dr. Zeynep: beyaz doktor onlugu, turkuaz cerrahi forma (V yaka), boynunda stetoskop, hastane kimligi.
func _doctor(l: Dictionary, coat: Color, scrub: Color) -> void:
	var skin: Color = l.get("skin", Color(0.9, 0.72, 0.58))
	var lapel := coat.darkened(0.08)
	var tube := Color(0.18, 0.2, 0.24)
	var steel := Color(0.8, 0.82, 0.86)
	_patch(_pts([-0.16, 0.985, 0.16, 0.985, 0.0, 0.5]), scrub, 0.01)
	_neck_band(scrub, 0.01)
	_patch(_pts([-0.075, 0.995, 0.075, 0.995, 0.0, 0.85]), skin, 0.013)
	_stroke(_pts([-0.075, 0.995, 0.0, 0.85]), 0.018, scrub.darkened(0.15), 0.016)
	_stroke(_pts([0.075, 0.995, 0.0, 0.85]), 0.018, scrub.darkened(0.15), 0.016)
	_sym(_pts([-0.16, 0.985, -0.004, 0.49, -0.085, 0.46, -0.24, 0.76, -0.2, 0.795, -0.28, 0.93]), lapel, 0.018)
	_stroke(_pts([-0.2, 1.04, -0.19, 0.95, -0.16, 0.82, -0.13, 0.7, -0.12, 0.64]), 0.03, tube, 0.03)  # stetoskop
	var cp := _part(self, _cyl(0.042, 0.042, 0.018), steel, _on_body(-0.12, 0.61, 0.04), Vector3(PI / 2 - 0.25, 0, 0))
	_part(cp, _cyl(0.028, 0.028, 0.02), Color(0.3, 0.32, 0.36), Vector3(0, 0.002, 0))
	_stroke(_pts([0.2, 1.04, 0.19, 0.95, 0.165, 0.84, 0.15, 0.78]), 0.03, tube, 0.03)
	_stroke(_pts([0.15, 0.785, 0.125, 0.74]), 0.016, steel, 0.034)
	_stroke(_pts([0.15, 0.785, 0.18, 0.74]), 0.016, steel, 0.034)
	_stud(0.123, 0.735, 0.014, tube, 0.036)
	_stud(0.183, 0.735, 0.014, tube, 0.036)
	_rect(0.17, 0.56, 0.3, 0.68, Color(0.99, 0.99, 0.99), 0.022)  # kimlik
	_rect(0.17, 0.65, 0.3, 0.68, scrub, 0.026)
	_rect(0.185, 0.58, 0.225, 0.635, Color(0.75, 0.8, 0.85), 0.026)
	_rect(0.235, 0.615, 0.285, 0.625, Color(0.6, 0.6, 0.62), 0.026)
	_rect(0.235, 0.59, 0.275, 0.6, Color(0.6, 0.6, 0.62), 0.026)
	_stud(0.235, 0.69, 0.012, steel, 0.03)
	for y: float in [0.43, 0.32]:
		_stud(0.035, y, 0.022, coat.darkened(0.3), 0.01)


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
			for side in [-1.0, 1.0]:  # altin menteseler (ustteki altin cubuk kas gibi duruyordu)
				_part(head, _box(Vector3(0.05, 0.035, 0.05), 0.6), Color(1.0, 0.8, 0.25), Vector3(side * 0.27, 0.09, 0.39))
			_part(head, _box(Vector3(0.36, 0.022, 0.03), 0.7), Color(0.55, 0.6, 0.75), Vector3(-0.03, 0.095, 0.437), Vector3(0, 0, 0.12), Vector3.ONE, true)  # cam yansimasi


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
			var tweed := Color(0.36, 0.31, 0.27)
			_part(head, _hemi(0.44), tweed, Vector3(0, 0.17, -0.02), Vector3(-0.12, 0, 0), Vector3(1.04, 0.62, 1.04))  # tepe
			_part(head, _sphere(0.3), tweed.lightened(0.04), Vector3(0, 0.35, 0.14), Vector3(-0.3, 0, 0), Vector3(1.32, 0.42, 1.0))  # one tasan kubbe
			_part(head, _box(Vector3(0.5, 0.035, 0.2), 0.75), tweed.darkened(0.2), Vector3(0, 0.225, 0.4), Vector3(0.22, 0, 0))  # siperlik
			_part(head, _torus(0.425, 0.455), tweed.darkened(0.12), Vector3(0, 0.18, -0.02), Vector3(-0.12, 0, 0), Vector3(1.0, 0.6, 1.0))  # bant
			_part(head, _sphere(0.035), tweed.darkened(0.25), Vector3(0, 0.44, 0.0))  # dugme


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
		_brows[i].position.y = _brow_y + _cur[1] + _open * 0.012
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
