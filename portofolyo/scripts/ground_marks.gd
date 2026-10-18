class_name GroundMarks
extends RefCounted
## Afet izleri (Decal ile yuzeye yansitilir, dokular calisma aninda kodla uretilir):
##  - deprem catlaklari: zeminde dallanan koyu yariklar (yikilan / hasarli binalarin onunde ve yollarda)
##  - is izi: yanan binanin duvarlarinda yukari dogru koyulasan kurum lekeleri (onarilinca kalkar)

static var _cracks: Array[ImageTexture] = []
static var _soot: Texture2D


## Catlak dokusu (3 farkli varyant, bir kez uretilir).
static func crack_texture() -> ImageTexture:
	if _cracks.is_empty():
		for v in 3:
			_cracks.append(ImageTexture.create_from_image(_make_crack(v)))
	return _cracks.pick_random()


static func _make_crack(seed_v: int) -> Image:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (seed_v + 1)
	# ana yarik: bir kenardan digerine zikzak; her adimda kalinlik ortada en fazla
	var a := rng.randf() * TAU
	var start := Vector2(n, n) * 0.5 - Vector2(cos(a), sin(a)) * n * 0.42
	_walk(img, rng, start, a, 70, 6.5, true)
	return img


static func _walk(img: Image, rng: RandomNumberGenerator, p: Vector2, a: float, steps: int, width: float, branch: bool) -> void:
	for i in steps:
		var t := float(i) / steps
		var w := width * (0.35 + 0.65 * sin(t * PI))  # uclarda incelir
		_disc(img, p, w + 2.5, Color(0.06, 0.05, 0.045, 0.4))  # yumusak kenar (toz)
		_disc(img, p, w, Color(0.03, 0.025, 0.02, 0.95))
		a += rng.randf_range(-0.55, 0.55)
		p += Vector2(cos(a), sin(a)) * 3.0
		if branch and i > 6 and i < steps - 8 and rng.randf() < 0.07:
			_walk(img, rng, p, a + rng.randf_range(0.7, 1.3) * (1.0 if rng.randf() < 0.5 else -1.0), rng.randi_range(10, 24), w * 0.55, false)


static func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	var n := img.get_width()
	for y in range(int(c.y - r), int(c.y + r) + 1):
		for x in range(int(c.x - r), int(c.x + r) + 1):
			if x < 0 or y < 0 or x >= n or y >= n:
				continue
			if Vector2(x, y).distance_to(c) > r:
				continue
			var old := img.get_pixel(x, y)
			if col.a > old.a:
				img.set_pixel(x, y, col)


## Deprem catlagi: p'de, size boyunda, rastgele yonde. Zamanla solup kaybolmasi icin dondurulur.
static func spawn_crack(parent: Node, p: Vector3, size: float) -> Decal:
	var d := Decal.new()
	d.texture_albedo = crack_texture()
	d.size = Vector3(size, 0.8, size)
	d.position = Vector3(p.x, 0.1, p.z)
	d.rotation.y = randf() * TAU
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.normal_fade = 0.6  # sadece zemin: bina duvarlarina karalama gibi yansimasin
	d.cull_mask = 1
	parent.add_child(d)
	d.modulate.a = 0.0
	d.create_tween().tween_property(d, "modulate:a", 1.0, 0.6)
	return d


## Kurum lekesi dokusu: yukari dogru koyulasan, lekeli gurultu (duvarlara dikey seritler halinde yansir).
static func soot_texture() -> Texture2D:
	if _soot == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.012
		noise.fractal_octaves = 4
		var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
		for y in 256:
			for x in 256:
				var v := noise.get_noise_2d(x, y) * 0.5 + 0.5
				var a := clampf((v - 0.38) * 2.6, 0.0, 1.0)
				img.set_pixel(x, y, Color(0.03, 0.025, 0.022, a * 0.85))
		_soot = ImageTexture.create_from_image(img)
	return _soot


## Yanan bina: binayi saran kutu yukaridan asagi kurum yansitir (cati koyu lekeli, duvarlarda seritler).
static func spawn_soot(b: Node3D, height: float) -> Decal:
	var d := Decal.new()
	d.texture_albedo = soot_texture()
	d.size = Vector3(2.1, height + 0.6, 2.1)
	d.position = Vector3(0.0, height * 0.5 + 0.1, 0.0)
	d.rotation.y = randf() * TAU
	d.normal_fade = 0.0  # dik duvarlar da alsin
	d.upper_fade = 0.05
	d.lower_fade = 0.6  # zemine yaklastikca azalir (is yukari dogru)
	d.cull_mask = 1
	b.add_child(d)
	d.modulate.a = 0.0
	d.create_tween().tween_property(d, "modulate:a", 1.0, 1.2)
	return d
