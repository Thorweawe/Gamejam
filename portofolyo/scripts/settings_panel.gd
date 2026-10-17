class_name SettingsPanel
extends PanelContainer
## Ayarlar penceresi (menu ve oyun ici duraklatma ekrani ortak kullanir).

signal closed
signal to_menu  # oyun icinden ana menuye donus (onaydan sonra)

var in_game := false  # true: "Ana Menüye Dön" butonu gosterilir

const HUD := preload("res://scripts/hud.gd")
const C_TEXT := Color("#3b3330")
const C_MUTED := Color("#8a7666")
const C_ACCENT := Color("#d76f34")

var bold: Font
var _main: VBoxContainer  # ayarlar
var _controls: VBoxContainer  # kontroller listesi (sadece bilgi, degistirilemez)

## Tus sablonu: [tuslar], ne ise yarar. Tuslar kod ile ayni (camera_rig, game_manager, day_cycle, dialog_player).
const CONTROLS := [
	["KAMERA", [
		[["W", "A", "S", "D"], "Kamerayı kaydır (ok tuşları da olur)"],
		[["Sağ tık", "Sürükle"], "Haritayı fareyle kaydır"],
		[["Tekerlek"], "Yakınlaş / uzaklaş"],
		[["Z", "X"], "Yakınlaş / uzaklaş"],
		[["Q", "E"], "Kamerayı döndür"],
	]],
	["OYUN", [
		[["Sol tık"], "Bina seç · yardım işaretine ekip gönder"],
		[["R"], "Risk haritasını aç / kapat"],
		[["N"], "Günü bitir"],
		[["ESC"], "Duraklat (ayarlar, ana menü)"],
		[["Sağ tık"], "Mahalle / kum torbası seçimini iptal et"],
	]],
	["KONUŞMALAR", [
		[["Sol tık", "Boşluk", "Enter"], "Sonraki satır"],
		[["ESC"], "Konuşmayı atla"],
	]],
]


func _ready() -> void:
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Fredoka.ttf")
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	bold = fv
	add_theme_stylebox_override("panel", HUD.sb(Color("#fffaf2"), 20, 2, Color("#d9b98f"), 26, 22, 10))
	custom_minimum_size = Vector2(460, 0)
	var root := VBoxContainer.new()
	add_child(root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	root.add_child(v)
	_main = v
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", HUD.sb(Color(0.42, 0.36, 0.68), 14, 0, Color.TRANSPARENT, 8, 8))
	head.add_child(badge)
	var ic := UIIcon.new()
	ic.kind = "star"
	ic.custom_minimum_size = Vector2(26, 26)
	badge.add_child(ic)
	head.add_child(_label("Ayarlar", 28, C_TEXT, true))
	_section(v, "SES")
	_slider(v, "Genel ses", "master")
	_slider(v, "Müzik", "music")
	_slider(v, "Efektler", "sfx")
	_slider(v, "Ortam (dalga, kuş)", "ambience")
	_slider(v, "Seslendirme", "voice")
	_section(v, "GÖRÜNTÜ")
	_toggle(v, "Tam ekran", "fullscreen")
	_toggle(v, "Ekran sarsıntısı", "shake")
	var ctl := _flat_button("Kontroller", Color("#577893"))
	ctl.pressed.connect(func():
		_sfx("click")
		_show_controls(true))
	v.add_child(ctl)
	if in_game:
		var home := _flat_button("Ana Menüye Dön", Color("#bd5a46"))
		var confirm := [false]
		home.pressed.connect(func():
			_sfx("click")
			if not confirm[0]:  # ilk basis: uyar, ikinci basis: don
				confirm[0] = true
				home.text = "Emin misin? İlerleme kaybolur · tekrar bas"
				return
			to_menu.emit())
		v.add_child(home)
	_build_controls(root)
	var close := Button.new()
	close.text = "Tamam"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(0, 46)
	close.add_theme_font_override("font", bold)
	close.add_theme_font_size_override("font_size", 18)
	var col := C_ACCENT
	close.add_theme_stylebox_override("normal", HUD.sb(col, 12, 0, Color.TRANSPARENT, 14, 8))
	close.add_theme_stylebox_override("hover", HUD.sb(col.lightened(0.15), 12, 0, Color.TRANSPARENT, 14, 8))
	close.add_theme_stylebox_override("pressed", HUD.sb(col.darkened(0.15), 12, 0, Color.TRANSPARENT, 14, 8))
	close.pressed.connect(func():
		_sfx("click")
		closed.emit())
	v.add_child(close)


func _flat_button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_override("font", bold)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_stylebox_override("normal", HUD.sb(col, 12, 0, Color.TRANSPARENT, 14, 8))
	b.add_theme_stylebox_override("hover", HUD.sb(col.lightened(0.15), 12, 0, Color.TRANSPARENT, 14, 8))
	b.add_theme_stylebox_override("pressed", HUD.sb(col.darkened(0.15), 12, 0, Color.TRANSPARENT, 14, 8))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	return b


## Kontroller sayfasi: tus kapaklari + aciklama. Tuslar degistirilemez, sadece bilgi.
func _build_controls(root: Node) -> void:
	_controls = VBoxContainer.new()
	_controls.add_theme_constant_override("separation", 8)
	_controls.visible = false
	root.add_child(_controls)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_controls.add_child(head)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", HUD.sb(Color("#577893"), 14, 0, Color.TRANSPARENT, 8, 8))
	head.add_child(badge)
	var ic := UIIcon.new()
	ic.kind = "gear"
	ic.custom_minimum_size = Vector2(26, 26)
	badge.add_child(ic)
	head.add_child(_label("Kontroller", 28, C_TEXT, true))
	for group in CONTROLS:
		_section(_controls, group[0])
		for row in group[1]:
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 10)
			_controls.add_child(h)
			var keys := HBoxContainer.new()
			keys.add_theme_constant_override("separation", 4)
			keys.custom_minimum_size.x = 210
			h.add_child(keys)
			for k in row[0]:
				var cap := PanelContainer.new()
				# klavye tusu gorunumu: krem kapak, alt kenari kalin golge
				var st := HUD.sb(Color("#fbf3e6"), 7, 2, Color("#d9b98f"), 8, 2)
				st.border_width_bottom = 4
				cap.add_theme_stylebox_override("panel", st)
				var kl := _label(k, 14, C_TEXT, true)
				kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				kl.custom_minimum_size.x = 18
				cap.add_child(kl)
				keys.add_child(cap)
			var d := _label(row[1], 15, C_TEXT)
			d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(d)
	var back := _flat_button("Geri", C_ACCENT)
	back.custom_minimum_size.y = 46
	back.pressed.connect(func():
		_sfx("click")
		_show_controls(false))
	_controls.add_child(back)


func _show_controls(on: bool) -> void:
	_main.visible = not on
	_controls.visible = on
	custom_minimum_size.x = 560 if on else 460
	reset_size()


func _label(text: String, size: int, color: Color, is_bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if is_bold:
		l.add_theme_font_override("font", bold)
	return l


func _section(parent: Node, text: String) -> void:
	parent.add_child(_label(text, 12, C_MUTED, true))


func _slider(parent: Node, caption: String, key: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	parent.add_child(h)
	var l := _label(caption, 16, C_TEXT)
	l.custom_minimum_size.x = 170
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.value = float(Settings.get_value(key)) * 100.0
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	s.add_theme_stylebox_override("slider", HUD.sb(Color(0.47, 0.4, 0.34, 0.18), 4, 0, Color.TRANSPARENT, 0, 3))
	s.add_theme_stylebox_override("grabber_area", HUD.sb(C_ACCENT, 4, 0, Color.TRANSPARENT, 0, 3))
	s.add_theme_stylebox_override("grabber_area_highlight", HUD.sb(C_ACCENT.lightened(0.15), 4, 0, Color.TRANSPARENT, 0, 3))
	h.add_child(s)
	var val := _label("%d%%" % int(s.value), 15, C_ACCENT, true)
	val.custom_minimum_size.x = 50
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(val)
	s.value_changed.connect(func(x: float):
		val.text = "%d%%" % int(x)
		Settings.set_value(key, x / 100.0))
	s.drag_ended.connect(func(_c: bool): _sfx("click"))


func _toggle(parent: Node, caption: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = caption
	c.focus_mode = Control.FOCUS_NONE
	c.button_pressed = bool(Settings.get_value(key))
	c.add_theme_font_size_override("font_size", 16)
	c.add_theme_color_override("font_color", C_TEXT)
	c.add_theme_color_override("font_hover_color", C_TEXT)
	c.add_theme_color_override("font_pressed_color", C_TEXT)
	c.toggled.connect(func(on: bool):
		_sfx("click")
		Settings.set_value(key, on))
	parent.add_child(c)


func _sfx(sound: String) -> void:
	var a := get_tree().get_first_node_in_group("audio")
	if a:
		a.play(sound)
