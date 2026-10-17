class_name Bubbles
extends Node3D
## Haritadaki tiklanabilir baloncuklar (CityMap'in cocugu; GameManager kurar).
##  - Muze baloncugu: muze ilk acildiginda catisinin ustunde belirir, tiklanana kadar kalir.
##    Patlayinca ek farkindalik verir (muze ziyaretcileri).
##  - Gunun baloncuklari: karar karti kapandiktan sonra (oyuncu serbestken, gunduz) rastgele bir anda
##    4 baloncuk ayni anda evlerin, ormanin, parklarin ustunde cikar; bunlar bitince o gun baska cikmaz.
##    Gece / gun gecisinde / afette cikmaz. Kisa surede tiklanirsa farkindalik ya da para verir.
## Belirgin olsun diye: arkada nabiz atan parlak hale, kalin renkli zar, belirirken isilti + ses.
## Patlama: parlama + damlaciklar + isiltilar + halka dalgasi + "pop" sesi (ses kodla uretilir).
## Tiklama GameManager._unhandled_input'tan try_pop() ile gelir.

const MUSEUM_REWARD := 4.0  # muze baloncugu: tum sehre farkindalik
const RANDOM_LIFE := 14.0  # rastgele baloncugun omru (sn): dordunu de yakalamaya yetsin
const FIRST_GAP := Vector2(4.0, 20.0)  # karar karti kapandiktan sonra baloncuklarin gelecegi an (sn, rastgele)
const BATCH := 4  # gunde bir kez ayni anda cikan baloncuk sayisi; bunlar bitince o gun baska cikmaz
const RADIUS := 0.7
const MUSEUM_ICONS := {
	"deprem": ["res://assets/textures/deprem_muze_1_klasik.png", Color(0.95, 0.62, 0.25)],
	"sel": ["res://assets/textures/sel_muze_1_klasik.png", Color(0.3, 0.62, 1.0)],
	"yangin": ["res://assets/textures/yangin_muze_1_klasik.png", Color(1.0, 0.38, 0.3)],
}
const KINDS := {
	"aw": ["res://assets/textures/topluluk_1_grup.png", Color(0.35, 0.9, 0.6)],
	"money": ["res://assets/textures/para_1lira_altin.png", Color(1.0, 0.8, 0.25)],
}

var game: Node  # GameManager
var camera: Camera3D

var _bubbles: Array[Dictionary] = []  # {node, kind, color, life, museum, t}
var _next := 0.0
var _was_free := false  # oyuncu bir onceki karede serbest miydi (karar karti kapandi mi)
var _batch_day := -1  # gunun baloncuklarinin ciktigi gun
var _hovered := -1
var _hinted := false
var _player: AudioStreamPlayer
var _chime: AudioStreamPlayer

static var _sphere: SphereMesh
static var _bubble_mat: ShaderMaterial
static var _ring_mat: ShaderMaterial
static var _halo_mat: ShaderMaterial
static var _ring_mesh: QuadMesh
static var _drop_mesh: SphereMesh
static var _spark_mesh: QuadMesh
static var _proc := {}  # renk -> [damla, isilti] surec malzemeleri
static var _pop_stream: AudioStreamWAV
static var _chime_stream: AudioStreamWAV


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "SFX"
	add_child(_player)
	_chime = AudioStreamPlayer.new()
	_chime.bus = "SFX"
	add_child(_chime)
	if _pop_stream == null:
		_pop_stream = _make_pop()
		_chime_stream = _make_chime()


# ------------------------------------------------------------------ olusturma
## Muze acildi: catisinin ustunde baloncuk (bina yukselme animasyonu bitince belirir).
func add_museum(at: Vector3, kind: String) -> void:
	if at == Vector3.INF or not MUSEUM_ICONS.has(kind):
		return
	await get_tree().create_timer(1.3).timeout
	var info: Array = MUSEUM_ICONS[kind]
	_spawn(at + Vector3(0, 3.0, 0), "museum", info[0], info[1], INF, true)


func _spawn(pos: Vector3, kind: String, icon_path: String, color: Color, life: float, museum := false) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	# arkadaki parlak hale (uzaktan da gozu ceker)
	var halo := MeshInstance3D.new()
	halo.mesh = _get_ring_mesh()
	_get_bubble_mat()
	halo.material_override = _halo_mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.set_instance_shader_parameter("tint", color)
	halo.set_instance_shader_parameter("fade", 1.0)
	root.add_child(halo)
	var ball := MeshInstance3D.new()
	ball.mesh = _get_sphere()
	ball.material_override = _get_bubble_mat()
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.set_instance_shader_parameter("tint", color)
	ball.set_instance_shader_parameter("fade", 1.0)
	ball.set_instance_shader_parameter("flash", 0.0)
	root.add_child(ball)
	var icon := Sprite3D.new()
	var tex := load(icon_path) as Texture2D
	icon.texture = tex
	icon.pixel_size = (RADIUS * 1.3) / maxf(1.0, float(tex.get_width())) if tex else 0.01
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.shaded = false
	icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.render_priority = 0  # baloncuk zari ikonun ustune cizilir (render_priority 1)
	icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(icon)
	root.scale = Vector3.ONE * 0.01
	var b := {"node": root, "ball": ball, "icon": icon, "halo": halo, "kind": kind, "color": color, "life": life,
		"museum": museum, "t": randf() * TAU, "age": 0.0, "base_y": pos.y, "size": 1.0}
	_bubbles.append(b)
	# belirme: isilti serpintisi + yumusak cinlama (oyuncu fark etsin)
	_burst(_get_procs(color)[1], _get_spark_mesh(), pos, 1.0, 10, 0.8)
	_sfx(_chime_stream, 1.5, -12.0, _chime)


# ------------------------------------------------------------------ guncelleme
func _process(delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	_spawn_random(delta)
	var mouse := get_viewport().get_mouse_position()
	var hovered := -1 if _blocked_input() else _pick(mouse)
	if hovered != _hovered:
		_hovered = hovered
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered >= 0 else Input.CURSOR_ARROW)
	for i in range(_bubbles.size() - 1, -1, -1):
		var b: Dictionary = _bubbles[i]
		var root: Node3D = b.node
		b.age += delta
		b.t += delta
		var left: float = b.life - b.age
		if left <= 0.0:
			_bubbles.remove_at(i)
			_fizzle(b)
			if _hovered == i:
				_hovered = -1
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			continue
		# uzaktan da secilsin: kamera uzaklastikca biraz buyur
		var dist := camera.global_position.distance_to(root.global_position)
		var target := clampf(dist / 24.0, 1.0, 2.8) * (1.15 if i == hovered else 1.0)
		if b.museum:
			target *= 1.0 + sin(b.t * 3.0) * 0.05  # muze baloncugu "beni patlat" diye nabiz atar
		b.size = lerpf(b.size, target, minf(1.0, delta * 10.0)) if b.age > 0.45 else target
		var grow := clampf(b.age / 0.45, 0.0, 1.0)
		grow = 1.0 + 2.70158 * pow(grow - 1.0, 3) + 1.70158 * pow(grow - 1.0, 2)  # geri tepen buyume (back ease)
		root.scale = Vector3.ONE * maxf(0.01, b.size * grow)
		root.position.y = b.base_y + sin(b.t * 1.7) * 0.12
		root.position.x += sin(b.t * 0.9) * 0.002
		# son 2.5 saniye: yanip soner, kuculur (acele et)
		if left < 2.5:
			var blink := 0.55 + 0.45 * absf(cos(left * 7.0))
			(b.ball as MeshInstance3D).set_instance_shader_parameter("fade", blink)
			(b.halo as MeshInstance3D).set_instance_shader_parameter("fade", blink)
			(b.icon as Sprite3D).modulate.a = blink
			root.scale *= 0.75 + 0.25 * left / 2.5


## Tiklanabilir mi: diyalog / kart acikken, oyun bittiginde ya da hedef secerken baloncuk patlamaz.
func _blocked_input() -> bool:
	if game == null:
		return true
	return game.game_over or game.place_mode != "" or (game.hud.dialog != null and game.hud.dialog.active)


## Ekrandaki fare konumunun ustundeki baloncuk (en yakin olan); yoksa -1.
func _pick(mouse: Vector2) -> int:
	var best := -1
	var best_d := INF
	var right := camera.global_transform.basis.x
	for i in _bubbles.size():
		var root: Node3D = _bubbles[i].node
		var c := root.global_position
		if camera.is_position_behind(c):
			continue
		var sp := camera.unproject_position(c)
		var edge := camera.unproject_position(c + right * RADIUS * root.scale.x)
		var r := maxf(18.0, sp.distance_to(edge) * 1.15)
		var d := sp.distance_to(mouse)
		var cam_d := camera.global_position.distance_to(c)
		if d <= r and cam_d < best_d:
			best_d = cam_d
			best = i
	return best


## GameManager cagirir: tiklanan yerde baloncuk varsa patlat. Doner: patladi mi.
func try_pop(screen_pos: Vector2) -> bool:
	if _blocked_input():
		return false
	var i := _pick(screen_pos)
	if i < 0:
		return false
	var b: Dictionary = _bubbles[i]
	_bubbles.remove_at(i)
	_hovered = -1
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_pop(b)
	_reward(b)
	return true


func _reward(b: Dictionary) -> void:
	var at: Vector3 = (b.node as Node3D).global_position + Vector3.UP * 0.3
	var hud: Node = game.hud
	match String(b.kind):
		"museum":
			game.add_awareness(MUSEUM_REWARD)
			hud.stat_delta("aw", MUSEUM_REWARD)
			hud.world_toast(at, "Müze ziyareti · +%d farkındalık" % int(MUSEUM_REWARD), Color(0.45, 0.95, 0.55), "star")
			_sfx(_chime_stream, 1.0, -6.0, _chime)
		"aw":
			var v := 1.0
			game.add_awareness(v)
			hud.stat_delta("aw", v)
			hud.world_toast(at, "+%d farkındalık" % int(v), Color(0.45, 0.95, 0.55), "people")
			_sfx(_chime_stream, 1.25, -9.0, _chime)
		"money":
			var v := randi_range(3, 8) * 50
			game.money += v
			hud.money_delta(v)  # para sesi HUD'dan
			hud.world_toast(at, "+" + GameManager.fmt_money(v), Color(1.0, 0.82, 0.3), "coin")
	game.stats_changed.emit()


# ------------------------------------------------------------------ rastgele baloncuklar
func _spawn_random(delta: float) -> void:
	# oyuncu serbest = gunun karar karti kapandi, afet / gun gecisi yok, gunduz
	var free: bool = game != null and not game.busy and not game.game_over and not game.disasters.responding \
		and not game.day_cycle.transitioning and not game.day_cycle.is_night()
	if not free:
		_was_free = false
		_clear_random()
		return
	if game.hud.dialog != null and game.hud.dialog.active:
		return
	if not _was_free:
		# karar karti yeni kapandi: gunun baloncuklari rastgele bir anda gelir
		_was_free = true
		_next = randf_range(FIRST_GAP.x, FIRST_GAP.y)
	if _batch_day == game.day:
		return  # bugunun baloncuklari cikti: bitince (patlatilinca / sonunce) baska yok
	_next -= delta
	if _next > 0.0:
		return
	# gunde bir kez: BATCH baloncuk ayni anda (birkac salise arayla, sehrin farkli yerlerine dagilmis)
	var spots := _pick_batch_spots()
	if spots.size() < 2:
		_next = 2.0  # ekranda uygun yer yok (kamera denize bakiyor): az sonra tekrar dene
		return
	_batch_day = game.day
	for i in spots.size():
		var kind := "aw" if randf() < 0.6 else "money"
		_spawn_later(spots[i], kind, i * 0.18)
	if not _hinted:
		_hinted = true
		game.hud.toast("Baloncuklar kısa süre kalır: tıkla, farkındalık ya da para kazan!", "info")


func _spawn_later(spot: Vector3, kind: String, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if _batch_day != game.day or game.busy:
		return  # bu arada afet / gun gecisi basladi
	_spawn(spot, kind, KINDS[kind][0], KINDS[kind][1], RANDOM_LIFE)


## 4 baloncugun birbirine cok yakin cikmamasi icin ekranda ve dunyada ayrik noktalar secer.
func _pick_batch_spots() -> Array[Vector3]:
	var city: Node = game.city
	var map_info: MapInfo = game.map_info
	var options: Array[Vector3] = []
	for bld in city.buildings():
		if bld.is_house() and bld.state == Building.State.NORMAL and not bld.on_fire:
			options.append(bld.global_position + Vector3(0, bld.top_height() + 1.4, 0))
	for p in map_info.forest_tiles:
		options.append(MapInfo.to3(p, 3.0))
	for p in map_info.park_tiles:
		options.append(MapInfo.to3(p, 2.4))

	var vp := get_viewport().get_visible_rect().size
	var candidates: Array[Dictionary] = []
	for o in options:
		if camera.is_position_behind(o):
			continue
		var sp := camera.unproject_position(o)
		# ust / alt panellerin altinda kalmasin, kenarlara yapismasin
		if sp.x > 120 and sp.x < vp.x - 120 and sp.y > 150 and sp.y < vp.y - 170:
			if not _near_other(o, sp):
				candidates.append({
					"pos": o,
					"screen": sp,
					"district": map_info.district_of(o)
				})

	if candidates.size() < 2:
		return []

	# Kademeli mesafe esikleri (3D dunya mesafesi ve ekran piksel mesafesi)
	# Ilk kademe baloncuklarin sehrin farkli mahallelerine ve ekranin ayri koselerine dagilmasini saglar
	var tiers := [
		{"world": 13.0, "screen": 220.0},
		{"world": 9.5, "screen": 160.0},
		{"world": 7.0, "screen": 110.0},
	]
	for tier in tiers:
		for attempt in 4:
			var result := _try_pick_spots(candidates, BATCH, float(tier.world), float(tier.screen))
			if result.size() >= BATCH:
				return result

	# Eger ekran kucukse veya kamera cok yakinlasmissa, bulunan en iyi sonucu al
	for tier in tiers:
		var result := _try_pick_spots(candidates, BATCH, float(tier.world), float(tier.screen))
		if result.size() >= 2:
			return result

	return []


func _try_pick_spots(candidates: Array[Dictionary], count: int, min_world: float, min_screen: float) -> Array[Vector3]:
	var pool := candidates.duplicate()
	pool.shuffle()
	var chosen: Array[Dictionary] = [pool.pop_back()]

	for _step in count - 1:
		var best_idx := -1
		var best_score := -INF
		for i in pool.size():
			var cand: Dictionary = pool[i]
			var cp: Vector3 = cand.pos
			var cs: Vector2 = cand.screen
			var min_w_dist := INF
			var min_s_dist := INF
			for c in chosen:
				var wd: float = cp.distance_to(c.pos)
				var sd: float = cs.distance_to(c.screen)
				if wd < min_w_dist:
					min_w_dist = wd
				if sd < min_s_dist:
					min_s_dist = sd
			if min_w_dist >= min_world and min_s_dist >= min_screen:
				# Farkli mahallede olmasi ve daha uzak olmasi ek puan kazandirir
				var diff_district := 1.0 if not chosen.any(func(c): return c.district == cand.district) else 0.0
				var score := min_w_dist + min_s_dist * 0.04 + diff_district * 5.0
				if score > best_score:
					best_score = score
					best_idx = i
		if best_idx >= 0:
			chosen.append(pool[best_idx])
			pool.remove_at(best_idx)
		else:
			break

	var out: Array[Vector3] = []
	for c in chosen:
		out.append(c.pos)
	return out


func _near_other(p: Vector3, sp: Vector2 = Vector2.ZERO) -> bool:
	for b in _bubbles:
		var bp: Vector3 = (b.node as Node3D).global_position
		if bp.distance_to(p) < 8.0:
			return true
		if sp != Vector2.ZERO and camera != null and not camera.is_position_behind(bp):
			if camera.unproject_position(bp).distance_to(sp) < 140.0:
				return true
	return false


func _clear_random() -> void:
	for i in range(_bubbles.size() - 1, -1, -1):
		if not _bubbles[i].museum:
			var b: Dictionary = _bubbles[i]
			_bubbles.remove_at(i)
			_fizzle(b)
	if _hovered >= _bubbles.size():
		_hovered = -1
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


# ------------------------------------------------------------------ patlama
func _pop(b: Dictionary) -> void:
	var root: Node3D = b.node
	var ball: MeshInstance3D = b.ball
	var col: Color = b.color
	var pos := root.global_position
	var s := root.scale.x
	_sfx(_pop_stream, randf_range(0.92, 1.1), -2.0)
	# 1) zar parlayip sisip kaybolur
	(b.icon as Sprite3D).visible = false
	(b.halo as MeshInstance3D).visible = false
	var tw := root.create_tween().set_parallel()
	tw.tween_property(root, "scale", Vector3.ONE * s * 1.35, 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): ball.set_instance_shader_parameter("flash", v), 0.0, 1.0, 0.08)
	tw.tween_method(func(v: float): ball.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.12).set_delay(0.04)
	tw.chain().tween_callback(root.queue_free)
	# 2) ikon yukari ucup kaybolur
	var ghost := Sprite3D.new()
	ghost.texture = (b.icon as Sprite3D).texture
	ghost.pixel_size = (b.icon as Sprite3D).pixel_size * s
	ghost.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ghost.shaded = false
	ghost.no_depth_test = true
	ghost.position = pos
	add_child(ghost)
	var gt := ghost.create_tween().set_parallel()
	gt.tween_property(ghost, "position:y", pos.y + 1.4 * s, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	gt.tween_property(ghost, "scale", Vector3.ONE * 1.35, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gt.tween_property(ghost, "modulate:a", 0.0, 0.35).set_delay(0.35)
	gt.chain().tween_callback(ghost.queue_free)
	# 3) damlaciklar + isiltilar
	var procs: Array = _get_procs(col)
	_burst(procs[0], _get_drop_mesh(), pos, s, 26, 0.9)
	_burst(procs[1], _get_spark_mesh(), pos, s, 14, 0.7)
	# 4) halka dalgasi
	var ring := MeshInstance3D.new()
	ring.mesh = _get_ring_mesh()
	_get_bubble_mat()
	ring.material_override = _ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = pos
	ring.scale = Vector3.ONE * s
	ring.set_instance_shader_parameter("tint", col)
	ring.set_instance_shader_parameter("t", 0.0)
	add_child(ring)
	var rt := ring.create_tween()
	rt.tween_method(func(v: float): ring.set_instance_shader_parameter("t", v), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rt.tween_callback(ring.queue_free)


## Tiklanmayan baloncuk sessizce soner: yukari suzulup saydamlasir.
func _fizzle(b: Dictionary) -> void:
	var root: Node3D = b.node
	if not is_instance_valid(root):
		return
	var ball: MeshInstance3D = b.ball
	var halo: MeshInstance3D = b.halo
	var icon: Sprite3D = b.icon
	var tw := root.create_tween().set_parallel()
	tw.tween_property(root, "position:y", root.position.y + 0.6, 0.5)
	tw.tween_property(root, "scale", root.scale * 0.4, 0.5)
	tw.tween_property(icon, "modulate:a", 0.0, 0.3)
	tw.tween_method(func(v: float):
		ball.set_instance_shader_parameter("fade", v)
		halo.set_instance_shader_parameter("fade", v), 0.6, 0.0, 0.5)
	tw.chain().tween_callback(root.queue_free)


func _burst(proc: ParticleProcessMaterial, mesh: Mesh, pos: Vector3, s: float, amount: int, life: float) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.process_material = proc
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	p.position = pos
	p.scale = Vector3.ONE * s
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _sfx(stream: AudioStream, pitch: float, db: float, player: AudioStreamPlayer = null) -> void:
	var pl := player if player else _player
	if pl == _player and pl.playing and db < -10.0:
		return  # belirme sesi patlamanin ustune binmesin
	pl.stream = stream
	pl.pitch_scale = pitch
	pl.volume_db = db
	pl.play()


# ------------------------------------------------------------------ paylasilan kaynaklar
static func _get_sphere() -> SphereMesh:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = RADIUS
		_sphere.height = RADIUS * 2.0
		_sphere.radial_segments = 32
		_sphere.rings = 16
	return _sphere


## Sabun kopugu: kenarda kalinlasan yanardoner zar (fresnel), iki parlak isik lekesi,
## hafif jole gibi titresim. Rengi ve saydamligi baloncuk basina (instance uniform).
## Patlama halkasinin malzemesi (_ring_mat) de burada kurulur.
static func _get_bubble_mat() -> ShaderMaterial:
	if _bubble_mat:
		return _bubble_mat
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(0.4, 0.9, 1.0, 1.0);
instance uniform float fade = 1.0;
instance uniform float flash = 0.0;
void vertex() {
	float w = sin(TIME * 3.1 + VERTEX.y * 7.0) * 0.5 + sin(TIME * 2.3 + VERTEX.x * 6.0) * 0.5;
	VERTEX += NORMAL * w * 0.018;
}
void fragment() {
	float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - nv, 2.0);
	vec3 irid = 0.5 + 0.5 * cos(6.2831 * (fres * 1.4 + TIME * 0.12 + vec3(0.0, 0.33, 0.67)));
	vec3 film = mix(tint.rgb, irid, 0.22 + fres * 0.3);
	float s1 = pow(clamp(dot(NORMAL, normalize(vec3(-0.45, 0.55, 0.7))), 0.0, 1.0), 48.0);
	float s2 = pow(clamp(dot(NORMAL, normalize(vec3(0.4, -0.35, 0.85))), 0.0, 1.0), 120.0) * 0.6;
	vec3 col = film * (0.75 + fres * 1.0) + vec3(s1 + s2) * 1.6;
	col = mix(col, vec3(1.6), flash);
	ALBEDO = col;
	ALPHA = clamp(0.3 + fres * 0.8 + s1 + s2 + flash * 0.6, 0.0, 1.0) * fade;
}"""
	# hale: baloncugun arkasinda nabiz atan yumusak renkli parlama
	var halo_sh := Shader.new()
	halo_sh.code = """shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float fade = 1.0;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float pulse = 0.7 + 0.3 * sin(TIME * 4.0);
	float glow = exp(-d * d * 4.5) * smoothstep(1.0, 0.75, d);
	float rim = smoothstep(0.08, 0.0, abs(d - mix(0.5, 0.62, pulse))) * 0.6;
	ALBEDO = mix(tint.rgb, vec3(1.0), 0.25) * 1.3;
	ALPHA = (glow * 0.55 * pulse + rim * 0.5) * fade;
}"""
	_halo_mat = ShaderMaterial.new()
	_halo_mat.shader = halo_sh
	_halo_mat.render_priority = -1
	_bubble_mat = ShaderMaterial.new()
	_bubble_mat.shader = sh
	_bubble_mat.render_priority = 1
	var ring_sh := Shader.new()
	ring_sh.code = """shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float t = 0.0;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float r = mix(0.25, 1.0, t);
	float w = mix(0.16, 0.03, t);
	float ring = smoothstep(w, 0.0, abs(d - r));
	ALBEDO = mix(vec3(1.0), tint.rgb, 0.5) * 1.6;
	ALPHA = ring * (1.0 - t);
}"""
	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = ring_sh
	_ring_mat.render_priority = 2
	return _bubble_mat


static func _get_ring_mesh() -> QuadMesh:
	if _ring_mesh == null:
		_ring_mesh = QuadMesh.new()
		_ring_mesh.size = Vector2(RADIUS * 4.4, RADIUS * 4.4)
	return _ring_mesh


static func _get_drop_mesh() -> SphereMesh:
	if _drop_mesh == null:
		_drop_mesh = SphereMesh.new()
		_drop_mesh.radius = 0.045
		_drop_mesh.height = 0.09
		_drop_mesh.radial_segments = 8
		_drop_mesh.rings = 4
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_drop_mesh.material = m
	return _drop_mesh


## Isilti: dort kollu parlak yildiz (eklenerek cizilir, parlama efektine girer).
static func _get_spark_mesh() -> QuadMesh:
	if _spark_mesh == null:
		_spark_mesh = QuadMesh.new()
		_spark_mesh.size = Vector2(0.32, 0.32)
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
void vertex() {
	mat4 m = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	m = m * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * m * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float star = max(0.0, 1.0 - abs(p.x * p.y) * 22.0 - d * 0.85);
	float core = exp(-d * d * 14.0);
	float a = clamp(star + core, 0.0, 1.0) * smoothstep(1.0, 0.6, d);
	ALBEDO = COLOR.rgb * 2.2;
	ALPHA = a * COLOR.a;
}"""
		var m := ShaderMaterial.new()
		m.shader = sh
		_spark_mesh.material = m
	return _spark_mesh


static func _get_procs(col: Color) -> Array:
	var key := col.to_html()
	if _proc.has(key):
		return _proc[key]
	# damlaciklar: kure yuzeyinden disari firlar, yercekimiyle duser, kuculur
	var drop := ParticleProcessMaterial.new()
	drop.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	drop.emission_sphere_radius = RADIUS * 0.9
	drop.direction = Vector3.UP
	drop.spread = 180.0
	drop.radial_velocity_min = 1.8
	drop.radial_velocity_max = 3.4
	drop.initial_velocity_min = 0.2
	drop.initial_velocity_max = 0.8
	drop.gravity = Vector3(0, -6.0, 0)
	drop.damping_min = 1.5
	drop.damping_max = 3.0
	drop.scale_min = 0.6
	drop.scale_max = 1.3
	drop.scale_curve = _curve_tex([Vector2(0, 1), Vector2(1, 0.1)])
	drop.color = Color(col.lerp(Color.WHITE, 0.45), 0.9)
	drop.color_ramp = _grad_tex(Color(1, 1, 1, 1), Color(1, 1, 1, 0))
	# isiltilar: yavas, donerek suzulur, beyazdan renge
	var spark := ParticleProcessMaterial.new()
	spark.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	spark.emission_sphere_radius = RADIUS * 0.7
	spark.direction = Vector3.UP
	spark.spread = 180.0
	spark.radial_velocity_min = 0.8
	spark.radial_velocity_max = 1.8
	spark.gravity = Vector3(0, 0.6, 0)
	spark.damping_min = 2.0
	spark.damping_max = 3.0
	spark.angle_min = 0.0
	spark.angle_max = 90.0
	spark.angular_velocity_min = -180.0
	spark.angular_velocity_max = 180.0
	spark.scale_min = 0.5
	spark.scale_max = 1.1
	spark.scale_curve = _curve_tex([Vector2(0, 0.2), Vector2(0.15, 1.0), Vector2(1, 0.0)])
	spark.color_ramp = _grad_tex(Color(1, 1, 0.95, 1), Color(col.r, col.g, col.b, 0))
	_proc[key] = [drop, spark]
	return _proc[key]


static func _curve_tex(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


static func _grad_tex(a: Color, b: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


# ------------------------------------------------------------------ sesler (kodla uretilir)
## "Pop": hizla dusen perdeli kisa bir blup + tik + kucuk bir isilti.
static func _make_pop() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.3)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var ph := 0.0
	var ph2 := 0.0
	var low := 0.0
	for i in n:
		var t := float(i) / rate
		var f := 300.0 + 1150.0 * exp(-t * 45.0)
		ph += TAU * f / rate
		var body := sin(ph) * exp(-t * 30.0) * minf(1.0, t * 1500.0)
		low = lerpf(low, rng.randf() * 2.0 - 1.0, 0.35)  # yumusatilmis gurultu: islak "cit"
		var click := low * exp(-t * 260.0) * 0.9
		ph2 += TAU * 2637.0 / rate
		var tail := sin(ph2) * exp(-maxf(0.0, t - 0.03) * 22.0) * (0.18 if t > 0.03 else 0.0)
		var v := clampf(body * 0.85 + click + tail, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 30000.0))
	return _wav(data, rate)


## Odul cinlamasi: yukselen uc nota (do-mi-sol), cansiz olmasin diye hafif titresimli.
static func _make_chime() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.75)
	var data := PackedByteArray()
	data.resize(n * 2)
	var notes := [1046.5, 1318.5, 1568.0]
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		for k in notes.size():
			var t0: float = k * 0.07
			if t < t0:
				continue
			var tt := t - t0
			var f: float = notes[k] * (1.0 + sin(tt * 30.0) * 0.002)
			v += (sin(TAU * f * tt) + sin(TAU * f * 2.0 * tt) * 0.25) * exp(-tt * 6.5) * minf(1.0, tt * 400.0) * 0.3
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	return _wav(data, rate)


static func _wav(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s
