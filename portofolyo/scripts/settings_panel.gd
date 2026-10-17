class_name SettingsPanel
extends PanelContainer
## Ayarlar penceresi (menu ve oyun ici duraklatma ekrani ortak kullanir).

signal closed

const HUD := preload("res://scripts/hud.gd")
const C_TEXT := Color(0.94, 0.96, 1.0)
const C_MUTED := Color(0.63, 0.69, 0.8)
const C_ACCENT := Color(1.0, 0.6, 0.2)

var bold: Font


func _ready() -> void:
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Fredoka.ttf")
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	bold = fv
	add_theme_stylebox_override("panel", HUD.sb(Color(0.07, 0.09, 0.14, 0.97), 20, 1, Color(1, 1, 1, 0.12), 26, 22, 10))
	custom_minimum_size = Vector2(460, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)
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
	_section(v, "GÖRÜNTÜ")
	_toggle(v, "Tam ekran", "fullscreen")
	_toggle(v, "Ekran sarsıntısı", "shake")
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
	s.add_theme_stylebox_override("slider", HUD.sb(Color(1, 1, 1, 0.12), 4, 0, Color.TRANSPARENT, 0, 3))
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
	c.add_theme_color_override("font_hover_color", Color.WHITE)
	c.add_theme_color_override("font_pressed_color", C_TEXT)
	c.toggled.connect(func(on: bool):
		_sfx("click")
		Settings.set_value(key, on))
	parent.add_child(c)


func _sfx(sound: String) -> void:
	var a := get_tree().get_first_node_in_group("audio")
	if a:
		a.play(sound)
