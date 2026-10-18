extends Node
## Baslangic ekrani: arka planda gun batiminda yanan sehir (yanan binalar, orman yangini,
## kul parcaciklari, siren calan itfaiyeler), yavasca donen kamera. Solda Basla / Ayarlar / Cikis.

const HUD := preload("res://scripts/hud.gd")
const GAME_SCENE := "res://scenes/main.tscn"
const M := "res://assets/models/"
const C_TEXT := Color(0.96, 0.97, 1.0)
const C_MUTED := Color(0.72, 0.76, 0.86)
const C_ACCENT := Color(1.0, 0.58, 0.18)

var city: Node3D
var rig: Node3D
var camera: Camera3D
var audio: Node
var bold: Font
var _ui: Control
var _fade: ColorRect
var _buttons: Array[Button] = []
var _settings: Control
var _starting := false
var _t := 0.0
var _zoom := 31.0  # kamera uzakligi (gecis animasyonunda azalir)
var _hoff := -7.0  # sehri saga kaydiran kamera ofseti
var _spin := 0.035  # donus hizi
var _shade: Control
var _box: Control


func _ready() -> void:
	Settings.apply()
	city = (load("res://scenes/city_map.tscn") as PackedScene).instantiate()
	add_child(city)
	rig = city.get_node("CameraRig")
	camera = rig.get_node("Camera3D")
	rig.set_process(false)  # menu kamerayi kendisi dondurur
	rig.set_process_unhandled_input(false)
	rig.position = Vector3(1.0, 0.0, 3.0)
	rig.rotation.y = -0.35
	_dusk()
	_city_on_fire()
	audio = Node.new()
	audio.set_script(load("res://scripts/audio.gd"))
	add_child(audio)
	audio.set_music("calm")  # yangin citirtisi (fire_loop) menude cizirti gibi geliyordu: kaldirildi
	_build_ui()


func _process(delta: float) -> void:
	_t += delta
	rig.rotation.y += delta * _spin
	var zoom := _zoom + sin(_t * 0.15) * 3.0 * (_zoom / 31.0)
	camera.position = camera.position.lerp(rig._dir * zoom, minf(1.0, delta * (2.0 if not _starting else 6.0)))
	camera.h_offset = lerpf(camera.h_offset, _hoff, minf(1.0, delta * 2.0))  # sehir sagda, menu solda


# ------------------------------------------------------------------ sahne: gun batimi ve yanan sehir
func _dusk() -> void:
	var sun: DirectionalLight3D = city.get_node("Sun")
	sun.rotation = Vector3(deg_to_rad(-30.0), deg_to_rad(-40.0), 0.0)
	sun.light_color = Color(1.0, 0.62, 0.4)
	sun.light_energy = 1.1
	var env: Environment = (city.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.ambient_light_energy = 0.8
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	if sky:
		sky.sky_top_color = Color(0.16, 0.12, 0.28)
		sky.sky_horizon_color = Color(0.95, 0.45, 0.28)
		sky.ground_horizon_color = Color(0.95, 0.45, 0.28)
		sky.ground_bottom_color = Color(0.08, 0.06, 0.14)
	var sea := (city.get_node("Sea") as MeshInstance3D).mesh.material as ShaderMaterial
	if sea:
		sea.set_shader_parameter("light", 0.75)
	# pencere isiklari yansin
	await get_tree().process_frame
	for l in get_tree().get_nodes_in_group("night_lights"):
		l.light_energy = float(l.get_meta("energy", 1.0)) * 0.8
		l.visible = true


func _city_on_fire() -> void:
	var houses: Array = city.buildings().filter(func(b): return b.position.length() < 14.0 and b.model_name.begins_with("house"))
	houses.shuffle()
	var burning: Array = []
	var effects: Node3D = city.get_node("Effects")
	for b in houses.slice(0, 7):
		b.set_on_fire(true)
		burning.append(b)
		_big_fire(effects, b.global_position + Vector3(0, b.top_height() * 0.6, 0))
	for b in houses.slice(5, 8):
		b.state = Building.State.COLLAPSED
	# orman yangini: nehrin kuzeyindeki birkac orman karosu
	var map_info: MapInfo = city.get_node("MapInfo")
	var forest: Array = Array(map_info.forest_tiles)
	forest.sort_custom(func(a, b): return a.y > b.y)
	for p in forest.slice(0, 18).filter(func(_p): return randf() < 0.35):
		for i in 2:
			var f: Node3D = (load(M + "afet/fire_small.gltf") as PackedScene).instantiate()
			f.position = Vector3(p.x + randf_range(-0.6, 0.6), 0.1, p.y + randf_range(-0.6, 0.6))
			f.scale = Vector3.ONE * randf_range(1.4, 2.0)
			f.rotation.y = randf() * TAU
			effects.add_child(f)
			Building._flicker(f)
		var fx := FireFX.make(Vector3(0.85, 0.25, 0.85), 1.35)  # alev, kivilcim, duman, isik
		fx.position = Vector3(p.x, 0.15, p.y)
		effects.add_child(fx)
	_embers(effects)
	# itfaiye ve ambulanslar yanan binalara gider
	await get_tree().create_timer(1.5).timeout
	var traffic: Node = city.get_node("Traffic")
	for i in mini(3, burning.size()):
		traffic.dispatch("car_firetruck" if i < 2 else "car_ambulance", "firestation" if i < 2 else "hospital", burning[i].global_position)


## Menude uzaktan da gorunsun diye buyuk alev + kalin duman + guclu isik.
func _big_fire(parent: Node3D, at: Vector3) -> void:
	for i in 2:
		var f: Node3D = (load(M + "afet/fire_large.gltf") as PackedScene).instantiate()
		f.position = at + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
		f.scale = Vector3.ONE * randf_range(1.8, 2.4)
		parent.add_child(f)
		Building._flicker(f)
	# duman sutunu binanin kendi yangin efektinden (Building.set_on_fire -> FireFX) gelir
	var light := OmniLight3D.new()
	light.position = at + Vector3(0, 0.6, 0)
	light.light_color = Color(1.0, 0.45, 0.12)
	light.light_energy = 4.0
	light.omni_range = 4.5
	parent.add_child(light)
	var lt := light.create_tween().set_loops()
	lt.tween_property(light, "light_energy", 5.0, randf_range(0.12, 0.25))
	lt.tween_property(light, "light_energy", 3.2, randf_range(0.12, 0.25))


## Sehrin ustunde suzulen kor parcaciklari.
func _embers(parent: Node3D) -> void:
	var p := GPUParticles3D.new()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(20, 0.5, 18)
	m.direction = Vector3(0.3, 1, 0.1)
	m.spread = 25.0
	m.initial_velocity_min = 0.4
	m.initial_velocity_max = 1.2
	m.gravity = Vector3(0.15, 0.1, 0)
	m.scale_min = 0.5
	m.scale_max = 1.3
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.75, 0.3, 1.0))
	grad.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	m.color_ramp = gt
	p.process_material = m
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1, 1)
	mesh.material = mat
	p.draw_pass_1 = mesh
	p.amount = 260
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.position = Vector3(0, 0.6, 2)
	p.visibility_aabb = AABB(Vector3(-25, -2, -25), Vector3(50, 20, 50))
	parent.add_child(p)


# ------------------------------------------------------------------ arayuz
func _build_ui() -> void:
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Fredoka.ttf")
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	bold = fv
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	# sol tarafta okunurluk icin koyu gecis
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.03, 0.03, 0.07, 0.94))
	g.set_color(1, Color(0.03, 0.03, 0.07, 0.0))
	g.add_point(0.55, Color(0.03, 0.03, 0.07, 0.7))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 256
	gt.height = 4
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 760
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(shade)
	_shade = shade

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	box.offset_left = 90
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_ui.add_child(box)
	_box = box
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", HUD.sb(Color(1.0, 0.45, 0.15, 0.22), 10, 1, Color(1.0, 0.55, 0.2, 0.6), 12, 4))
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var title := _label("Porto Şehri", 78, C_TEXT, true)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	box.add_child(title)
	var title2 := _label("Afete Hazırlık", 78, C_ACCENT, true)
	title2.add_theme_constant_override("outline_size", 10)
	title2.add_theme_color_override("font_outline_color", Color(0.3, 0.08, 0.0, 0.6))
	box.add_child(title2)
	var sub := _label("Belediye başkanısın. 20 gün boyunca şehrini depreme,\nyangına ve sele hazırla. Hazırlık hayat kurtarır.", 18, C_MUTED)
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 30
	box.add_child(gap)
	_menu_button(box, "play", "Başla", C_ACCENT, true, _start)
	_menu_button(box, "gear", "Ayarlar", Color(1, 1, 1, 0.1), false, _open_settings)
	_menu_button(box, "exit", "Çıkış", Color(1, 1, 1, 0.1), false, func(): get_tree().quit())

	var foot := _label("Godot 4  ·  KayKit (CC0)  ·  Fredoka (OFL)  ·  Sesler ve ikonlar kodla üretildi", 12, Color(1, 1, 1, 0.45))
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	foot.offset_left = 90
	foot.offset_top = -40
	foot.offset_bottom = -18
	_ui.add_child(foot)
	var hint := _label("Enter: başla", 12, Color(1, 1, 1, 0.4))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -140
	hint.offset_top = -40
	hint.offset_bottom = -18
	hint.offset_right = -24
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui.add_child(hint)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE)
	# basliklar ve butonlar sirayla kayarak gelir
	var items: Array = [tag, title, title2, sub] + _buttons
	for i in items.size():
		var c: Control = items[i]
		c.modulate.a = 0.0
		var tw := c.create_tween()
		tw.tween_interval(0.5 + i * 0.09)
		tw.tween_property(c, "modulate:a", 1.0, 0.5)


func _label(text: String, size: int, color: Color, is_bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if is_bold:
		l.add_theme_font_override("font", bold)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _menu_button(parent: Node, icon: String, text: String, color: Color, primary: bool, action: Callable) -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(320, 62 if primary else 54)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var border := Color(1, 1, 1, 0.18) if not primary else Color.TRANSPARENT
	b.add_theme_stylebox_override("normal", HUD.sb(color, 16, 1 if not primary else 0, border, 18, 8, 6))
	b.add_theme_stylebox_override("hover", HUD.sb(color.lightened(0.18) if primary else Color(1, 1, 1, 0.2), 16, 2, Color(1, 1, 1, 0.5), 18, 8, 8))
	b.add_theme_stylebox_override("pressed", HUD.sb(color.darkened(0.15), 16, 0, Color.TRANSPARENT, 18, 8))
	b.add_theme_stylebox_override("disabled", HUD.sb(color, 16, 0, Color.TRANSPARENT, 18, 8))
	parent.add_child(b)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 22
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := UIIcon.new()
	ic.kind = icon
	ic.color = Color.WHITE
	ic.custom_minimum_size = Vector2(24, 24)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := _label(text, 24 if primary else 21, Color.WHITE, true)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	b.mouse_entered.connect(func():
		audio.play("hover")
		b.create_tween().tween_property(h, "offset_left", 32.0, 0.12))
	b.mouse_exited.connect(func(): b.create_tween().tween_property(h, "offset_left", 22.0, 0.12))
	b.pressed.connect(func():
		audio.play("click")
		action.call())
	_buttons.append(b)


## Oyuna gecis (~2.5 sn): buton parlar, menu sola kayip kaybolur, kamera donerek sehre alcalir,
## "vinn" + yukselen melodi calar, ekran kararir ve kisa bir cumle gorunur; sonra oyun acilir.
func _start() -> void:
	if _starting:
		return
	_starting = true
	for b in _buttons:
		b.disabled = true
	# oyun sahnesi animasyon sirasinda arka planda yuklensin (gecis aninda bekleme olmasin)
	ResourceLoader.load_threaded_request(GAME_SCENE)
	audio.play("start_game")
	for m in audio._music:
		create_tween().tween_property(m, "volume_db", -60.0, 1.6)
	# Basla butonu kucuk bir "basildi" sicramasi yapar
	var first: Button = _buttons[0]
	first.pivot_offset = first.size / 2.0
	var bt := first.create_tween()
	bt.tween_property(first, "scale", Vector2(1.08, 1.08), 0.1).set_trans(Tween.TRANS_BACK)
	bt.tween_property(first, "scale", Vector2.ONE, 0.15)
	# menu sola kayar ve kaybolur
	var ui := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	ui.tween_property(_box, "position:x", _box.position.x - 140.0, 0.6).set_delay(0.15)
	ui.tween_property(_box, "modulate:a", 0.0, 0.5).set_delay(0.15)
	ui.tween_property(_shade, "modulate:a", 0.0, 0.8).set_delay(0.2)
	# kamera donerek sehrin ortasina dalar
	var cam := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	cam.tween_property(self, "_zoom", 13.0, 2.0)
	cam.tween_property(self, "_hoff", 0.0, 1.2)
	cam.tween_property(self, "_spin", 0.6, 1.0)
	cam.tween_property(rig, "position", Vector3(-3.0, 0.0, 6.0), 2.0)
	# kararma + kisa cumle
	var line := _label("Şehir sana emanet.", 34, C_TEXT, true)
	line.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	line.grow_horizontal = Control.GROW_DIRECTION_BOTH
	line.grow_vertical = Control.GROW_DIRECTION_BOTH
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.modulate.a = 0.0
	_ui.add_child(line)
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(_fade, "color:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(line, "modulate:a", 1.0, 0.25)
	tw.tween_interval(0.45)
	tw.tween_property(line, "modulate:a", 0.0, 0.2)
	tw.tween_callback(_enter_game)


## Arka plandaki yukleme bitince oyuna gec. Sahne degisirken arada kalan kareler gri degil
## siyah gorunsun (kararma ile ayni renk) diye bos ekran rengi siyaha cekilir.
func _enter_game() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	while ResourceLoader.load_threaded_get_status(GAME_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var scene := ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
	if scene:
		get_tree().change_scene_to_packed(scene)
	else:
		get_tree().change_scene_to_file(GAME_SCENE)


func _open_settings() -> void:
	if _settings:
		return
	_settings = ColorRect.new()
	(_settings as ColorRect).color = Color(0, 0, 0, 0.5)
	_settings.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(_settings)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings.add_child(center)
	var panel := SettingsPanel.new()
	center.add_child(panel)
	panel.closed.connect(_close_settings)
	_settings.modulate.a = 0.0
	create_tween().tween_property(_settings, "modulate:a", 1.0, 0.2)


func _close_settings() -> void:
	if _settings:
		_settings.queue_free()
		_settings = null


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE and _settings:
		_close_settings()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and _settings == null:
		_start()
