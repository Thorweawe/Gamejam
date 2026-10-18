class_name DialogPlayer
extends Control
## Animasyonlu konusmalar.
##   await play_scene(Dialogs.INTRO)  -> tam ekran sahne: solda Baskan, sagda konusan karakter (oyun bekler)
##   bark("first_quake")              -> kucuk kutu: oyunu durdurmayan kisa replik
## Seslendirme dosyasi varsa calinir, agiz hareketi sesin siddetinden (Voice yolundaki spektrum olcer) okunur.
## Yoksa yazi akarken harflere gore agiz oynar ve karakterin perdesinde kisa hece sesleri ("mirildanma") calar.
## Tikla / Bosluk / Enter: sonraki satir.  ESC / "Atla": sahneyi gec.

const HUD := preload("res://scripts/hud.gd")
const C_TEXT := Color("#3b3330")
const C_MUTED := Color("#8a7666")
const VOWELS := {"a": "a", "ı": "a", "e": "e", "i": "i", "o": "o", "ö": "o", "u": "o", "ü": "o"}
## Harf -> agiz bicimi (CharacterFigure.vowel: 0 genis "i/e" .. 1 yuvarlak "o/u")
const SHAPES := {"a": 0.45, "ı": 0.3, "e": 0.15, "i": 0.0, "o": 0.85, "ö": 0.8, "u": 1.0, "ü": 0.95}
const LIPS_CLOSED := ["m", "b", "p"]  # dudaklar birlesir
const PUNCT := [",", ".", "!", "?", "…", ":", ";", "\"", "'"]
const CHARS_PER_SEC := 40.0

var hud: Node  # odak hedefleri icin (hud.target_rect)
var bold: Font
var active := false

var _left: Portrait
var _right: Portrait
var _shade: TextureRect
var _spot: ColorRect
var _frame: Panel
var _box: PanelContainer
var _name_tag: PanelContainer
var _name: Label
var _text: Label
var _more: UIIcon
var _skip_btn: Button
var _voice: AudioStreamPlayer
var _blips: Array[AudioStreamPlayer] = []
var _blip_streams := {}
var _spectrum: AudioEffectSpectrumAnalyzerInstance
var _skip := false
var _advance := false
var _talker: Portrait
var _talk_target := 0.0
var _t := 0.0
var _left_home := Vector2.ZERO
var _right_home := Vector2.ZERO

# kisa replik (bark)
var _bark_box: Control
var _bark_portrait: Portrait
var _bark_text: Label
var _bark_voice: AudioStreamPlayer
var _bark_busy := false
var _bark_speaking := false  # kisa replik su an konusuyor (yazi / ses akiyor)
var _bark_cut := false  # cut_bark: konusan replik hemen biter
var _saying := 0  # karar kartinda konusan karakter sayisi (say)
var _bark_queue: Array = []
var _bark_talk := 0.0
var _extra := {}  # baska yerlerdeki portreler (karar karti) -> agiz acikligi
var _card_voice: AudioStreamPlayer  # karar karti karakterinin sesi
var _card_talker: Portrait


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Fredoka.ttf")
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	bold = fv
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	add_child(_voice)
	_bark_voice = AudioStreamPlayer.new()
	_bark_voice.bus = "Voice"
	add_child(_bark_voice)
	_card_voice = AudioStreamPlayer.new()
	_card_voice.bus = "Voice"
	add_child(_card_voice)
	for i in 3:
		var b := AudioStreamPlayer.new()
		b.bus = "Voice"
		b.volume_db = -6.0
		add_child(b)
		_blips.append(b)
	for v in ["a", "e", "i", "o"]:
		_blip_streams[v] = load("res://assets/audio/blip_%s.wav" % v)
	var bus := AudioServer.get_bus_index("Voice")
	if bus >= 0 and AudioServer.get_bus_effect_count(bus) > 0:
		_spectrum = AudioServer.get_bus_effect_instance(bus, 0) as AudioEffectSpectrumAnalyzerInstance
	_build_scene_ui()
	_build_bark_ui()
	_set_scene_visible(false)


# ------------------------------------------------------------------ kurulum
func _build_scene_ui() -> void:
	_shade = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.03, 0.07, 0.0))
	g.set_color(1, Color(0.02, 0.03, 0.07, 0.85))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	_shade.texture = gt
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	# ogretici: hedef disini karartan, hedefi aydinlik birakan katman
	_spot = ColorRect.new()
	_spot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 hole = vec4(0.0);
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform float strength = 0.0;
void fragment() {
	vec2 p = UV * rect_size;
	vec2 c = hole.xy + hole.zw * 0.5;
	vec2 d = abs(p - c) - hole.zw * 0.5 - vec2(10.0);
	float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
	float a = smoothstep(0.0, 18.0, dist) * 0.62 * strength;
	COLOR = vec4(0.01, 0.02, 0.05, a);
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	_spot.material = sm
	sm.set_shader_parameter("strength", 0.0)
	sm.set_shader_parameter("hole", Vector4.ZERO)
	add_child(_spot)
	_frame = Panel.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := HUD.sb(Color(0, 0, 0, 0), 14, 3, Color(1.0, 0.8, 0.3), 0, 0)
	_frame.add_theme_stylebox_override("panel", fs)
	_frame.visible = false
	add_child(_frame)

	_left = Portrait.new()
	_left.custom_minimum_size = Vector2(300, 340)
	_left.size = _left.custom_minimum_size
	add_child(_left)
	_left.setup("baskan")
	_right = Portrait.new()
	_right.custom_minimum_size = Vector2(300, 340)
	_right.size = _right.custom_minimum_size
	add_child(_right)
	_right.setup("nermin")

	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", HUD.sb(Color("#fffaf2"), 18, 2, Color("#d9b98f"), 24, 18, 10))
	_box.custom_minimum_size = Vector2(620, 128)
	add_child(_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_box.add_child(v)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(570, 80)
	_text.add_theme_font_size_override("font_size", 20)
	_text.add_theme_color_override("font_color", C_TEXT)
	v.add_child(_text)
	# alt satir: solda "Atla" (kutunun icinde, gozden kacmasin), sagda devam oku
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	v.add_child(bottom)
	_skip_btn = Button.new()
	_skip_btn.text = "Sahneyi atla  »"
	_skip_btn.tooltip_text = "ESC"
	_skip_btn.focus_mode = Control.FOCUS_NONE
	_skip_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_skip_btn.add_theme_font_override("font", bold)
	_skip_btn.add_theme_font_size_override("font_size", 14)
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		_skip_btn.add_theme_color_override(st, Color("#a0552a") if st != "font_color" else C_MUTED)
	var accent := Color("#d76f34")
	_skip_btn.add_theme_stylebox_override("normal", HUD.sb(Color(accent.r, accent.g, accent.b, 0.08), 10, 1, Color(accent.r, accent.g, accent.b, 0.35), 12, 3))
	_skip_btn.add_theme_stylebox_override("hover", HUD.sb(Color(accent.r, accent.g, accent.b, 0.18), 10, 1, Color(accent.r, accent.g, accent.b, 0.7), 12, 3))
	_skip_btn.add_theme_stylebox_override("pressed", HUD.sb(Color(accent.r, accent.g, accent.b, 0.28), 10, 1, Color(accent.r, accent.g, accent.b, 0.8), 12, 3))
	_skip_btn.pressed.connect(func(): _skip = true)
	bottom.add_child(_skip_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(spacer)
	_more = UIIcon.new()
	_more.kind = "play"
	_more.color = accent
	_more.custom_minimum_size = Vector2(16, 16)
	_more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(_more)
	_name_tag = PanelContainer.new()
	add_child(_name_tag)
	_name = Label.new()
	_name.add_theme_font_override("font", bold)
	_name.add_theme_font_size_override("font_size", 18)
	_name.add_theme_color_override("font_color", Color.WHITE)
	_name_tag.add_child(_name)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var s := size if size.x > 10 else get_viewport_rect().size
	_left_home = Vector2(10, s.y - 340)
	_right_home = Vector2(s.x - 310, s.y - 340)
	_left.position = _left_home
	_right.position = _right_home
	_box.position = Vector2((s.x - 620) / 2.0, s.y - 175)
	_name_tag.position = _box.position + Vector2(26, -22)
	(_spot.material as ShaderMaterial).set_shader_parameter("rect_size", s)


func _build_bark_ui() -> void:
	_bark_box = Control.new()
	_bark_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bark_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_bark_box.offset_left = 10
	_bark_box.offset_top = -210
	_bark_box.offset_bottom = -76
	add_child(_bark_box)
	_bark_portrait = Portrait.new()
	_bark_portrait.custom_minimum_size = Vector2(120, 136)
	_bark_portrait.size = _bark_portrait.custom_minimum_size
	_bark_box.add_child(_bark_portrait)
	_bark_portrait.setup("nermin")
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", HUD.sb(Color("#fffaf2"), 14, 2, Color(0.85, 0.45, 0.9), 14, 10, 6))
	bubble.position = Vector2(118, 22)
	bubble.custom_minimum_size = Vector2(300, 0)
	_bark_box.add_child(bubble)
	_bark_text = Label.new()
	_bark_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bark_text.custom_minimum_size = Vector2(272, 0)
	_bark_text.add_theme_font_size_override("font_size", 15)
	_bark_text.add_theme_color_override("font_color", C_TEXT)
	bubble.add_child(_bark_text)
	_bark_box.visible = false


func _set_scene_visible(on: bool) -> void:
	for c in [_shade, _spot, _frame, _left, _right, _box, _name_tag, _skip_btn]:
		c.visible = on
	_frame.visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


# ------------------------------------------------------------------ tam ekran sahne
func play_scene(lines: Array) -> void:
	if lines.is_empty():
		return
	active = true
	_skip = false
	_layout()
	_set_scene_visible(true)
	var first_other := "nermin"
	for l in lines:
		if l.who != "baskan":
			first_other = l.who
			break
	if _right.char_id != first_other:
		_right.setup(first_other)
	_left.figure.set_mood("neutral", true)
	_right.figure.set_mood("neutral", true)
	# giris: portreler yanlardan kayarak, kutu asagidan
	_left.position = _left_home + Vector2(-340, 0)
	_right.position = _right_home + Vector2(340, 0)
	_box.modulate.a = 0.0
	_name_tag.modulate.a = 0.0
	_shade.modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_shade, "modulate:a", 1.0, 0.3)
	tw.tween_property(_left, "position", _left_home, 0.5)
	tw.tween_property(_right, "position", _right_home, 0.5).set_delay(0.1)
	tw.tween_property(_box, "modulate:a", 1.0, 0.3).set_delay(0.2)
	tw.tween_property(_name_tag, "modulate:a", 1.0, 0.3).set_delay(0.2)
	await tw.finished
	for line in lines:
		if _skip:
			break
		await _scene_line(line)
	_voice.stop()
	_talker = null
	_hide_focus()
	if hud and hud.has_method("demo_forecast"):
		hud.demo_forecast(false)
	var out := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	out.tween_property(_left, "position", _left_home + Vector2(-340, 0), 0.35)
	out.tween_property(_right, "position", _right_home + Vector2(340, 0), 0.35)
	out.tween_property(_box, "modulate:a", 0.0, 0.25)
	out.tween_property(_name_tag, "modulate:a", 0.0, 0.25)
	out.tween_property(_shade, "modulate:a", 0.0, 0.35)
	await out.finished
	_set_scene_visible(false)
	active = false
	_skip = false


func _scene_line(line: Dictionary) -> void:
	var who: String = line.who
	var p: Portrait = _left if who == "baskan" else _right
	if p == _right and _right.char_id != who:
		var sw := create_tween()
		sw.tween_property(_right, "position", _right_home + Vector2(340, 0), 0.2)
		await sw.finished
		_right.setup(who)
		var back := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		back.tween_property(_right, "position", _right_home, 0.35)
	var other: Portrait = _right if p == _left else _left
	p.figure.set_mood(line.get("mood", "neutral"))
	if line.has("anim"):
		p.figure.gesture(line.anim)
	# konusan one cikar, dinleyen soner
	var em := create_tween().set_parallel()
	em.tween_property(p, "modulate", Color.WHITE, 0.2)
	em.tween_property(other, "modulate", Color(0.55, 0.58, 0.68), 0.2)
	p.pivot_offset = p.size / 2.0
	other.pivot_offset = other.size / 2.0
	em.tween_property(p, "scale", Vector2(1.05, 1.05), 0.2)
	em.tween_property(other, "scale", Vector2(0.94, 0.94), 0.2)
	var info := Characters.info(who)
	var col: Color = info.color
	_name.text = info.name
	_name_tag.reset_size()  # onceki uzun isimden ("Nermin Hanım") kalan genislik kalmasin
	_name_tag.add_theme_stylebox_override("panel", HUD.sb(col.darkened(0.25), 10, 0, Color.TRANSPARENT, 14, 4, 4))
	_box.add_theme_stylebox_override("panel", HUD.sb(Color("#fffaf2"), 18, 3, col, 24, 18, 10))
	if hud and hud.has_method("demo_forecast"):
		hud.demo_forecast(line.get("focus", "") == "forecast_area")
		await get_tree().process_frame
		await get_tree().process_frame
	_focus(line.get("focus", ""), p, other)
	await _speak(p, line, _text, _voice, true)


## Bir satiri konustur: ses dosyasi varsa calar (yazi sesle birlikte akar), yoksa yazi + mirildanma.
## wait_click: tam ekran sahnede tiklama bekler (seste ses bitince kendiliginden gecer).
func _speak(p: Portrait, line: Dictionary, label: Label, player: AudioStreamPlayer, wait_click: bool) -> void:
	var text: String = line.text
	label.text = text
	label.visible_characters = 0
	_advance = false
	if wait_click:
		_more.visible = false
	var path := Dialogs.voice_path(line.get("id", ""))
	var speed := CHARS_PER_SEC
	var voiced := path != ""
	if voiced:
		player.stream = load(path)
		player.play()
		speed = maxf(12.0, text.length() / maxf(0.5, player.stream.get_length() * 0.9))
	if wait_click:
		_talker = p
	var pitch: float = Characters.info(p.char_id).get("pitch", 1.0)
	var shown := 0.0
	var last_blip := -10
	while label.visible_characters < text.length():
		if (wait_click and (_skip or _advance)) or (not wait_click and _bark_cut):
			break
		await get_tree().process_frame
		shown += speed * get_process_delta_time()
		var n := mini(text.length(), int(shown))
		if n != label.visible_characters:
			label.visible_characters = n
			var ch := text.substr(n - 1, 1).to_lower()
			var mouth := _mouth_for(ch, p.figure)
			if wait_click:
				_talk_target = mouth
			else:
				_bark_talk = mouth
			if not voiced and mouth > 0.0 and n - last_blip >= 2:
				last_blip = n
				_blip(VOWELS.get(ch, ["a", "e", "o"].pick_random()), pitch)
	label.visible_characters = -1
	_advance = false
	if wait_click:
		_talk_target = 0.0
		_more.visible = true
		if voiced:
			while player.playing and not _advance and not _skip:
				await get_tree().process_frame
			if not _advance and not _skip:
				await get_tree().create_timer(0.35).timeout
		else:
			while not _advance and not _skip:
				await get_tree().process_frame
		player.stop()
		_advance = false
	else:
		_bark_talk = 0.0
		if voiced:
			while player.playing:
				await get_tree().process_frame
		_bark_speaking = false  # sozu bitti; kutu okunsun diye biraz daha ekranda kalir
		var t := 1.6 + text.length() * 0.02
		while t > 0.0 and not _bark_cut:
			await get_tree().process_frame
			t -= get_process_delta_time()


## Herhangi bir portreyi konustur (karar karti): yazi akar, agiz oynar.
## line: metin ya da {id, text} satiri; id'nin ses dosyasi varsa calinir, yoksa karakter mirildanir.
func say(p: Portrait, line: Variant, label: Label, speed := 45.0) -> void:
	var text: String = line.get("text", "") if line is Dictionary else str(line)
	var path := Dialogs.voice_path(line.get("id", "")) if line is Dictionary else ""
	var voiced := path != ""
	# once Nermin'in kisa repligi (bark) bitsin, sonra karttaki karakter konussun (sesler ust uste binmesin)
	if _bark_speaking and is_instance_valid(label):
		label.text = ""
		while _bark_speaking:
			await get_tree().process_frame
			if not is_instance_valid(label) or not is_instance_valid(p):
				return
	_saying += 1
	await _say_line(p, text, path, voiced, label, speed)
	_saying -= 1


func _say_line(p: Portrait, text: String, path: String, voiced: bool, label: Label, speed: float) -> void:
	_card_voice.stop()
	_card_talker = p if voiced else null
	if voiced:
		_card_voice.stream = load(path)
		_card_voice.play()
		speed = maxf(12.0, text.length() / maxf(0.5, _card_voice.stream.get_length() * 0.9))
	label.text = text
	label.visible_characters = 0
	var pitch: float = Characters.info(p.char_id).get("pitch", 1.0)
	var shown := 0.0
	var last_blip := -10
	while is_instance_valid(label) and label.visible_characters < text.length() and label.visible_characters >= 0:
		await get_tree().process_frame
		if not is_instance_valid(label) or not is_instance_valid(p):
			_card_voice.stop()
			return
		shown += speed * get_process_delta_time()
		var n := mini(text.length(), int(shown))
		if n != label.visible_characters:
			label.visible_characters = n
			var ch := text.substr(n - 1, 1).to_lower()
			var mouth := _mouth_for(ch, p.figure)
			_extra[p] = mouth
			if not voiced and mouth > 0.0 and n - last_blip >= 2:
				last_blip = n
				_blip(VOWELS.get(ch, ["a", "e", "o"].pick_random()), pitch)
	if is_instance_valid(label):
		label.visible_characters = -1
	# ses bitene kadar bekle (kart kapanirsa kes)
	while voiced and _card_voice.playing and _card_talker == p:
		await get_tree().process_frame
		if not is_instance_valid(p):
			_card_voice.stop()
			break
	if _card_talker == p:
		_card_talker = null
	_extra[p] = 0.0


## Yazidan dudak senkronu: sesli harf acar (bicimi harfe gore), m/b/p dudaklari kapatir,
## diger sessizler yari acik, bosluk / noktalama kapali. Acilip kapanma yumusakligi figurde.
func _mouth_for(ch: String, fig: CharacterFigure) -> float:
	if SHAPES.has(ch):
		fig.vowel = SHAPES[ch]
		return 0.75 + SHAPES[ch] * 0.1 if ch != "i" else 0.6
	if ch in LIPS_CLOSED:
		return 0.0
	if ch.strip_edges() == "" or ch in PUNCT:
		return 0.0
	return 0.32


func _blip(vowel: String, pitch: float) -> void:
	for b in _blips:
		if not b.playing:
			b.stream = _blip_streams.get(vowel, _blip_streams["a"])
			b.pitch_scale = pitch * randf_range(0.92, 1.08)
			b.play()
			return


func _process(delta: float) -> void:
	_t += delta
	# hedef aciklik dogrudan verilir; CharacterFigure hizli acip yumusak kapatir (cift yumusatma
	# agzi agirlastiriyordu). Seslendirmede aciklik ses siddetinden, bicim spektrumdan gelir.
	var level := _talk_target
	if _voice.playing and _spectrum and _talker:
		level = _voice_level()
		_talker.figure.vowel = _voice_shape()
	if _talker:
		_talker.figure.talk = level
	for p in [_left, _right]:
		if p != _talker:
			p.figure.talk = 0.0
	var bl := _bark_talk
	if _bark_voice.playing and _spectrum:
		bl = _voice_level()
		_bark_portrait.figure.vowel = _voice_shape()
	_bark_portrait.figure.talk = bl
	for p in _extra.keys():
		if not is_instance_valid(p):
			_extra.erase(p)
			continue
		var lv: float = _extra[p]
		if p == _card_talker and _card_voice.playing and _spectrum:
			lv = _voice_level()
			p.figure.vowel = _voice_shape()
		p.figure.talk = lv
	if _more.visible:
		_more.position.y = sin(_t * 6.0) * 3.0
	if _frame.visible:
		_frame.modulate.a = 0.6 + sin(_t * 5.0) * 0.4


func _voice_level() -> float:
	var m := _spectrum.get_magnitude_for_frequency_range(90.0, 3500.0).length()
	return clampf((linear_to_db(maxf(m, 0.00001)) + 52.0) / 26.0, 0.0, 1.0)


## Seslendirmede agiz bicimi: tiz enerji (2-4 kHz, "i/e") genis agiz, pes formant (300-900 Hz,
## "o/u") yuvarlak agiz. Kaba ama canli: her hecede agiz bicim degistirir.
func _voice_shape() -> float:
	var low := _spectrum.get_magnitude_for_frequency_range(300.0, 900.0).length()
	var high := _spectrum.get_magnitude_for_frequency_range(2000.0, 4000.0).length()
	var r := high / maxf(low, 0.00001)
	return clampf(0.95 - r * 2.5, 0.0, 1.0)


# ------------------------------------------------------------------ ogretici odagi
func _focus(target: String, speaker: Portrait, other: Portrait) -> void:
	var m := _spot.material as ShaderMaterial
	if target == "" or hud == null or not hud.has_method("target_rect"):
		_hide_focus()
		create_tween().tween_property(_shade, "modulate:a", 1.0, 0.25)
		for p in [speaker, other]:
			_portrait_home(p, true)
		return
	var r: Rect2 = hud.target_rect(target)
	if r.size == Vector2.ZERO:
		_hide_focus()
		return
	# hedef silik gorunmesin: devre disi dugme odak suresince tam gorunur, alttaki koyu
	# gradyan cekilir (karartmayi spot katmani yapar, hedefin ustu aydinlik kalir)
	hud.tutorial_highlight(target)
	create_tween().tween_property(_shade, "modulate:a", 0.0, 0.25)
	m.set_shader_parameter("hole", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	create_tween().tween_method(func(v: float): m.set_shader_parameter("strength", v), float(m.get_shader_parameter("strength")), 1.0, 0.3)
	_frame.visible = true
	_frame.position = r.position - Vector2(8, 8)
	_frame.size = r.size + Vector2(16, 16)
	# hedefin ustune binen portre kenara cekilir
	for p in [speaker, other]:
		var pr := Rect2(_left_home if p == _left else _right_home, p.size)
		_portrait_home(p, not pr.grow(-30).intersects(r))


func _portrait_home(p: Portrait, show: bool) -> void:
	var home := _left_home if p == _left else _right_home
	var away := home + Vector2(-340 if p == _left else 340, 0)
	create_tween().set_trans(Tween.TRANS_CUBIC).tween_property(p, "position", home if show else away, 0.3)


func _hide_focus() -> void:
	var m := _spot.material as ShaderMaterial
	_frame.visible = false
	if hud and hud.has_method("tutorial_highlight"):
		hud.tutorial_highlight("")
	create_tween().tween_method(func(v: float): m.set_shader_parameter("strength", v), float(m.get_shader_parameter("strength")), 0.0, 0.25)


# ------------------------------------------------------------------ kisa replik
## Oyunu durdurmayan replik (Dialogs.BARKS anahtari ya da satir sozlugu). Sirayla oynar.
func bark(key_or_line: Variant) -> void:
	var line: Dictionary = Dialogs.BARKS.get(key_or_line, {}) if key_or_line is String else key_or_line
	if line.is_empty():
		return
	if _bark_busy:
		if _bark_queue.size() < 2:
			_bark_queue.append(line)
		return
	_bark_busy = true
	_bark_cut = false
	# karar kartindaki karakter konusuyorsa sozunu kesme: bitmesini bekle
	while _saying > 0 and not _bark_cut:
		await get_tree().process_frame
	if _bark_cut:
		_end_bark()
		return
	_bark_speaking = true
	if _bark_portrait.char_id != line.who:
		_bark_portrait.setup(line.who)
	_bark_portrait.figure.set_mood(line.get("mood", "neutral"), true)
	if line.has("anim"):
		_bark_portrait.figure.gesture(line.anim)
	_bark_box.visible = true
	_bark_box.modulate.a = 0.0
	_bark_box.position.x = -40
	var tw := create_tween().set_parallel()
	tw.tween_property(_bark_box, "modulate:a", 1.0, 0.2)
	tw.tween_property(_bark_box, "position:x", 10.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _speak(_bark_portrait, line, _bark_text, _bark_voice, false)
	if _bark_cut:
		_end_bark()
		return
	var out := create_tween()
	out.tween_property(_bark_box, "modulate:a", 0.0, 0.3)
	await out.finished
	_bark_box.visible = false
	_bark_busy = false
	if not _bark_queue.is_empty():
		bark(_bark_queue.pop_front())


## Kisa repligi hemen kes (gunu bitir: Nermin'in konusmasi ve yazisi ekranda kalmasin).
func cut_bark() -> void:
	_bark_queue.clear()
	if not _bark_busy:
		return
	_bark_cut = true
	_bark_voice.stop()
	_bark_box.visible = false


func _end_bark() -> void:
	_bark_voice.stop()
	_bark_box.visible = false
	_bark_speaking = false
	_bark_talk = 0.0
	_bark_busy = false
	_bark_cut = false


# ------------------------------------------------------------------ giris
func _gui_input(event: InputEvent) -> void:
	if active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance = true
		accept_event()


func _input(event: InputEvent) -> void:
	if not active or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_skip = true
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_advance = true
		get_viewport().set_input_as_handled()
