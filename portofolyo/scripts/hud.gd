extends CanvasLayer
## Oyun arayuzu (kodla kurulur). Yazi tipi: Fredoka (OFL). Ikonlar: UIIcon (kodla cizilir).
##   Sol ust   : para / nufus / farkindalik / belediye seviyesi (degisimler ucan sayilarla)
##   Sol alt   : ekipler (itfaiye, ambulans, AFAD: bosta / toplam)
##   Sag ust   : hava uyarisi karti + kisa bildirimler
##   Sag alt   : Magaza ve Risk haritasi butonlari (Gunu Gec butonu DayCycle'da)
##   Sol       : secili bina karti, afet raporu
##   Harita    : yardim isaretleri (IncidentMarker), haritaya bagli etiketler (world_toast)
##   Orta      : sadece karar pencereleri (olay karti, giris, oyun sonu) ve magaza

signal action_pressed(id: String)
signal building_action(id: String)
signal precaution_pressed(id: String)
signal risk_toggled(on: bool)
signal _modal_done(result: int)

const C_BG := Color(0.07, 0.09, 0.14, 0.9)
const C_CARD := Color(0.12, 0.15, 0.22, 1.0)
const C_LINE := Color(1, 1, 1, 0.09)
const C_TEXT := Color(0.94, 0.96, 1.0)
const C_MUTED := Color(0.63, 0.69, 0.8)
const C_GOLD := Color(1.0, 0.8, 0.3)
const C_GOOD := Color(0.45, 0.95, 0.55)
const C_BAD := Color(1.0, 0.45, 0.35)
const C_ACCENT := Color(1.0, 0.6, 0.2)
const C_BLUE := Color(0.4, 0.68, 1.0)
const KIND_COLORS := {"info": C_BLUE, "good": C_GOOD, "bad": C_BAD, "disaster": Color(1.0, 0.3, 0.25)}
const KIND_ICONS := {"info": "star", "good": "check", "bad": "warning", "disaster": "warning"}
const TAB_STYLE := {"aw": ["news", Color(0.4, 0.68, 1.0)], "infra": ["wave", Color(0.3, 0.8, 0.7)],
	"build": ["shield", Color(1.0, 0.62, 0.25)], "units": ["hall", Color(1.0, 0.45, 0.4)]}
const UNIT_ICONS := {"fire": ["fire", Color(1.0, 0.45, 0.3)], "medic": ["medic", Color(0.4, 0.75, 1.0)],
	"rescue": ["rescue", Color(1.0, 0.7, 0.25)]}
const FORECAST_ICONS := {"forest_fire": "tree", "flood": "wave", "house_fire": "fire"}
const RISK_TEXT := {"fire": "Yangın", "forest": "Orman yangını", "flood": "Sel", "quake": "Deprem"}

var game: Node  # GameManager (game_manager.gd _ready'de atar)
var font: Font
var bold: Font
var _theme: Theme

var _root: Control
var _markers: Control
var _money: Label
var _money_sub: Label
var _money_chip: Control
var _pop: Label
var _aw: Label
var _aw_chip: Control
var _aw_bar: ProgressBar
var _units := {}  # unit -> Label
var _units_panel: PanelContainer
var _right: VBoxContainer
var _forecast: PanelContainer
var _toasts: VBoxContainer
var _bpanel: PanelContainer
var _report: PanelContainer
var _alert: PanelContainer
var _alert_tw: Tween
var _response: PanelContainer
var _hint: PanelContainer
var _hint_label: Label
var _shop_btn: Button
var _risk_btn: Button
var _shop: Control
var _shop_tab := "aw"
var _modal_root: Control
var _world_toasts: Array = []  # [kontrol, dunya konumu, gecen sure, gecikme]
var _actions_enabled := true
var best_streak := 0  # gunun en iyi kurtarma serisi (gun ozeti)
var _streak := 0
var _streak_time := 0
var _flash: ColorRect
var _summary: PanelContainer
var _black: ColorRect


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS  # duraklatma menusu oyun dururken de calissin
	_make_theme()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme
	add_child(_root)
	_markers = Control.new()
	_markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_markers)
	_build_stats()
	_build_units()
	_build_right()
	_build_buttons()
	_build_center()
	_modal_root = Control.new()
	_modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_modal_root)
	_style_day_ui.call_deferred()
	# ilk kare siyah baslar (menuden gecis); GameManager fade_in ile acar
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 1)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_black)


# ------------------------------------------------------------------ tema ve yardimcilar
func _make_theme() -> void:
	font = load("res://assets/fonts/Fredoka.ttf")
	var fv := FontVariation.new()
	fv.base_font = font
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	bold = fv
	_theme = Theme.new()
	_theme.default_font = font
	_theme.default_font_size = 16
	_theme.set_font("bold_font", "RichTextLabel", bold)
	_theme.set_font("normal_font", "RichTextLabel", font)
	_theme.set_color("default_color", "RichTextLabel", C_TEXT)
	_theme.set_color("font_color", "Label", C_TEXT)
	_theme.set_stylebox("panel", "TooltipPanel", sb(Color(0.05, 0.06, 0.1, 0.96), 8, 1, C_LINE, 10, 6))
	_theme.set_color("font_color", "TooltipLabel", C_TEXT)
	_theme.set_font_size("font_size", "TooltipLabel", 14)


static func sb(color: Color, radius := 12, border := 0, border_color := Color.TRANSPARENT, mh := 12, mv := -1, shadow := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.content_margin_left = mh
	s.content_margin_right = mh
	s.content_margin_top = mv if mv >= 0 else mh
	s.content_margin_bottom = mv if mv >= 0 else mh
	s.anti_aliasing = true
	if shadow > 0:
		s.shadow_size = shadow
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_offset = Vector2(0, 3)
	return s


func _panel(parent: Node, color := C_BG, border_color := C_LINE, mh := 12, mv := -1, radius := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(color, radius, 1 if border_color.a > 0 else 0, border_color, mh, mv, 6))
	parent.add_child(p)
	return p


func _label(parent: Node, text: String, size := 16, color := C_TEXT, is_bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if is_bold:
		l.add_theme_font_override("font", bold)
	parent.add_child(l)
	return l


func _icon(parent: Node, kind: String, color: Color, s := 22) -> UIIcon:
	var i := UIIcon.new()
	i.kind = kind
	i.color = color
	i.custom_minimum_size = Vector2(s, s)
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(i)
	return i


func _hbox(parent: Node, sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	parent.add_child(h)
	return h


func _vbox(parent: Node, sep := 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	parent.add_child(v)
	return v


func _button(parent: Node, text: String, color := C_ACCENT, size := 16) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", bold)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", sb(color, 12, 0, Color.TRANSPARENT, 14, 8))
	b.add_theme_stylebox_override("hover", sb(color.lightened(0.15), 12, 0, Color.TRANSPARENT, 14, 8))
	b.add_theme_stylebox_override("pressed", sb(color.darkened(0.15), 12, 0, Color.TRANSPARENT, 14, 8))
	b.add_theme_stylebox_override("disabled", sb(Color(0.25, 0.28, 0.34, 0.9), 12, 0, Color.TRANSPARENT, 14, 8))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.65, 0.68, 0.75))
	b.mouse_entered.connect(func(): _sfx("hover"))
	parent.add_child(b)
	return b


## Kodla cizilen ikon + yazi iceren cip.
func _chip(parent: Node, icon: String, text: String, color: Color, size := 14, bg := Color(1, 1, 1, 0.07)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(bg, 10, 0, Color.TRANSPARENT, 8, 3))
	parent.add_child(p)
	var h := _hbox(p, 5)
	if icon != "":
		_icon(h, icon, color, size + 4)
	_label(h, text, size, color)
	return p


func _sfx(sound: String) -> void:
	var audio := get_node_or_null("../Audio")
	if audio:
		audio.play(sound)


func _clickable(c: Control, on_click: Callable) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			on_click.call())


# ------------------------------------------------------------------ DayCycle arayuzu (main.tscn/UI) ayni stile
func _style_day_ui() -> void:
	var ui := get_node_or_null("../UI")
	if ui == null:
		return
	for c in ui.get_children():
		if c is Control:
			c.theme = _theme
	var clock: PanelContainer = ui.get_node_or_null("ClockPanel")
	if clock:
		clock.add_theme_stylebox_override("panel", sb(C_BG, 16, 1, C_LINE, 16, 6, 6))
		var dl: Label = clock.get_node("HBox/DayLabel")
		dl.add_theme_font_override("font", bold)
		dl.add_theme_font_size_override("font_size", 28)
	var btn: Button = ui.get_node_or_null("EndDayButton")
	if btn:
		var col := Color(0.25, 0.62, 0.42)
		btn.add_theme_font_override("font", bold)
		btn.add_theme_font_size_override("font_size", 24)
		btn.add_theme_stylebox_override("normal", sb(col, 16, 0, Color.TRANSPARENT, 16, 8, 6))
		btn.add_theme_stylebox_override("hover", sb(col.lightened(0.12), 16, 0, Color.TRANSPARENT, 16, 8, 6))
		btn.add_theme_stylebox_override("pressed", sb(col.darkened(0.15), 16, 0, Color.TRANSPARENT, 16, 8, 6))
		btn.add_theme_stylebox_override("disabled", sb(Color(0.22, 0.25, 0.3, 0.9), 16, 0, Color.TRANSPARENT, 16, 8, 6))
		btn.text = "Günü Bitir  ›"
	var banner: Label = ui.get_node_or_null("DayBanner")
	if banner:
		banner.add_theme_font_override("font", bold)


# ------------------------------------------------------------------ sol ust: istatistikler
func _build_stats() -> void:
	var row := _hbox(_root, 8)
	row.position = Vector2(14, 14)
	# para
	var p := _panel(row, C_BG, C_LINE, 12, 6)
	_money_chip = p
	var h := _hbox(p, 8)
	_icon(h, "coin", C_GOLD, 28)
	var v := _vbox(h, -4)
	_money = _label(v, "", 22, C_GOLD, true)
	_money_sub = _label(v, "", 12, C_MUTED)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	# nufus
	p = _panel(row, C_BG, C_LINE, 12, 6)
	h = _hbox(p, 8)
	_icon(h, "people", Color(0.75, 0.85, 1.0), 26)
	_pop = _label(h, "", 20, C_TEXT, true)
	p.tooltip_text = "Nüfus: vergi geliri getirir"
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	# farkindalik
	p = _panel(row, C_BG, C_LINE, 12, 6)
	_aw_chip = p
	h = _hbox(p, 8)
	_icon(h, "shield", C_GOOD, 26)
	v = _vbox(h, 2)
	_aw = _label(v, "", 15, C_TEXT, true)
	_aw_bar = ProgressBar.new()
	_aw_bar.custom_minimum_size = Vector2(96, 7)
	_aw_bar.show_percentage = false
	_aw_bar.add_theme_stylebox_override("background", sb(Color(1, 1, 1, 0.1), 4, 0, Color.TRANSPARENT, 0, 0))
	v.add_child(_aw_bar)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var help := _panel(_root, Color(0.05, 0.06, 0.1, 0.55), Color.TRANSPARENT, 12, 3, 10)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(help, "Sol tık: seç  ·  Sağ tık / WASD: kaydır  ·  Tekerlek: yakınlaş  ·  Q/E: döndür  ·  R: risk  ·  ESC: menü", 13, Color(1, 1, 1, 0.7))
	help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	help.offset_top = -34
	help.offset_bottom = -10
	help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN


func update_stats(g: Node) -> void:
	_money.text = GameManager.fmt_money(g.money)
	var net: int = g.daily_income() - g.upkeep() - g.repair_cost_today()
	_money_sub.text = "%s%s / gün" % ["+" if net >= 0 else "", GameManager.fmt_money(net)]
	_money_sub.add_theme_color_override("font_color", C_MUTED if net >= 0 else C_BAD)
	_money_chip.tooltip_text = "Vergi +%s\nGider -%s\nOnarım -%s" % [GameManager.fmt_money(g.daily_income()),
		GameManager.fmt_money(g.upkeep()), GameManager.fmt_money(g.repair_cost_today())]
	_pop.text = str(g.population())
	var aw: float = g.awareness
	_aw.text = "Farkındalık %%%d" % int(aw)
	_aw_bar.value = aw
	var c := C_BAD.lerp(C_GOLD, clampf(aw / 50.0, 0, 1)).lerp(C_GOOD, clampf((aw - 50.0) / 50.0, 0, 1))
	_aw_bar.add_theme_stylebox_override("fill", sb(c, 4, 0, Color.TRANSPARENT, 0, 0))
	var river: String = ["yok", "ıslah", "ıslah + set"][g.flood_protection]
	_aw_chip.tooltip_text = "Halkın afet bilinci (mahalle ortalaması)\nTahliye başarısı: %%%d\nToplanma alanı: %d\nDere koruması: %s\nDeprem çantası: %s" % [
		int(g.evac_ratio(Vector3.INF) * 100), g.map_info.assembly_points.size(), river, "var" if g.kits > 0 else "yok"]
	for unit in _units:
		_units[unit].text = "%d/%d" % [g.units_free(unit), g.units_total(unit)]
	if _shop and _shop.visible:
		_fill_shop()


## Para degisimi: para cipinden ucan sayi.
func money_delta(v: int, _label_text := "") -> void:
	if v == 0:
		return
	_float_from(_money_chip, ("+" if v > 0 else "") + GameManager.fmt_money(v), C_GOOD if v > 0 else C_BAD)
	if v > 0:
		_sfx("coins")


func stat_delta(stat: String, v: float) -> void:
	if stat == "aw" and absf(v) >= 0.5:
		_float_from(_aw_chip, "%+d farkındalık" % int(v), C_GOOD if v > 0 else C_BAD)


func _float_from(c: Control, text: String, color: Color) -> void:
	var l := _label(_root, text, 18, color, true)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = c.global_position + Vector2(c.size.x * 0.3, c.size.y + 2)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y + 34, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(1.1)
	tw.chain().tween_callback(l.queue_free)


# ------------------------------------------------------------------ sol alt: ekipler
func _build_units() -> void:
	_units_panel = _panel(_root, C_BG, C_LINE, 12, 8)
	_units_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_units_panel.offset_left = 14
	_units_panel.offset_bottom = -14
	_units_panel.offset_top = -64
	_units_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var h := _hbox(_units_panel, 14)
	var cap := _label(h, "Ekipler", 13, C_MUTED)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for unit in ["fire", "medic", "rescue"]:
		var u := _hbox(h, 5)
		_icon(u, UNIT_ICONS[unit][0], UNIT_ICONS[unit][1], 24)
		_units[unit] = _label(u, "", 18, C_TEXT, true)
		u.tooltip_text = "%s: boşta / toplam araç. Binasını geliştirince +1" % GameData.UNIT_NAMES[unit]
		u.mouse_filter = Control.MOUSE_FILTER_STOP


# ------------------------------------------------------------------ sag: uyari + bildirimler
func _build_right() -> void:
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 8)
	_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_right.offset_left = -344
	_right.offset_right = -14
	_right.offset_top = 14
	_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_right)
	_forecast = _panel(_right, Color(0.2, 0.1, 0.05, 0.94), Color(1.0, 0.6, 0.2, 0.7), 14, 12)
	_forecast.visible = false
	_toasts = _vbox(_right, 6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Kisa bildirim (en fazla 3, 4 sn).
func toast(text: String, kind := "info") -> void:
	var col: Color = KIND_COLORS.get(kind, C_TEXT)
	var p := _panel(_toasts, Color(0.06, 0.08, 0.12, 0.9), Color(col.r, col.g, col.b, 0.35), 10, 7, 10)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := _hbox(p, 8)
	_icon(h, KIND_ICONS.get(kind, "star"), col, 18)
	var l := _label(h, text, 14, C_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 270
	while _toasts.get_child_count() > 3:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(4.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func show_message(text: String, kind := "info") -> void:
	toast(text, kind)


func show_forecast(type: String, title: String, text: String, actions: Array) -> void:
	for c in _forecast.get_children():
		c.queue_free()
	var v := _vbox(_forecast, 8)
	var h := _hbox(v, 10)
	var badge := _panel(h, Color(1.0, 0.55, 0.15), Color.TRANSPARENT, 6, 6, 20)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_icon(badge, FORECAST_ICONS.get(type, "warning"), Color.WHITE, 26)
	var tv := _vbox(h, 0)
	_label(tv, title.to_upper(), 12, Color(1.0, 0.75, 0.45), true)
	var l := _label(tv, text, 15, C_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 250
	var row := _hbox(v, 6)
	for a in actions:
		var b := _button(row, "%s  ·  %s" % [a.name, GameManager.fmt_money(a.cost)], Color(0.85, 0.45, 0.12), 14)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_precaution.bind(a.id, b))
	_forecast.visible = true
	_forecast.modulate.a = 0.0
	_forecast.create_tween().tween_property(_forecast, "modulate:a", 1.0, 0.3)


func _on_precaution(id: String, b: Button) -> void:
	_sfx("click")
	var before: int = game.money if game else 0
	precaution_pressed.emit(id)
	if id != "sandbag" and game and game.money < before:
		b.disabled = true
		b.text = "Alındı ✓"


func hide_forecast() -> void:
	_forecast.visible = false


# ------------------------------------------------------------------ sag alt: magaza + risk
func _build_buttons() -> void:
	var row := _hbox(_root, 8)
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	row.offset_right = -16
	row.offset_bottom = -92
	row.offset_left = -250
	row.offset_top = -158
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_shop_btn = _big_button(row, "shop", "Mağaza", Color(0.95, 0.55, 0.15))
	_shop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_btn.pressed.connect(func():
		_sfx("click")
		open_shop())
	_risk_btn = _big_button(row, "map", "Risk", Color(0.42, 0.36, 0.68))
	_risk_btn.custom_minimum_size.x = 96
	_risk_btn.toggle_mode = true
	_risk_btn.toggled.connect(func(on):
		_sfx("click")
		risk_toggled.emit(on))
	_risk_btn.tooltip_text = "Risk haritası (R): kırmızı binalar depremde en tehlikeli olanlar"


## Ikonlu buyuk buton (ikon ustte, yazi altta).
func _big_button(parent: Node, icon: String, text: String, color: Color) -> Button:
	var b := _button(parent, "", color, 15)
	b.custom_minimum_size = Vector2(110, 62)
	b.add_theme_stylebox_override("pressed", sb(color.lightened(0.25), 12, 2, Color.WHITE, 14, 8))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic := _icon(v, icon, Color.WHITE, 28)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := _label(v, text, 15, Color.WHITE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


func set_actions_enabled(on: bool) -> void:
	_actions_enabled = on
	_shop_btn.disabled = not on
	_shop_btn.modulate = Color.WHITE if on else Color(1, 1, 1, 0.5)
	if not on:
		close_shop()


func set_risk_button(on: bool) -> void:
	_risk_btn.set_pressed_no_signal(on)


func show_place_hint(text: String) -> void:
	_hint_label.text = text
	_hint.visible = true


func hide_place_hint() -> void:
	_hint.visible = false


# ------------------------------------------------------------------ orta: uyari bandi, mudahale, ipucu
func _build_center() -> void:
	_alert = _panel(_root, Color(0.55, 0.08, 0.06, 0.95), Color(1, 0.5, 0.4, 0.6), 22, 10, 18)
	_alert.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_alert.offset_top = 150
	_alert.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert.visible = false

	_response = _panel(_root, Color(0.08, 0.1, 0.16, 0.92), Color(1, 0.45, 0.35, 0.8), 16, 8, 20)
	_response.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_response.offset_top = -86
	_response.offset_bottom = -46
	_response.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_response.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_response.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := _hbox(_response, 8)
	_icon(h, "siren", C_BAD, 22)
	_label(h, "MÜDAHALE", 15, C_BAD, true)
	_label(h, "İşaretlere tıkla, ekip gönder", 15, C_TEXT)
	_response.visible = false

	_hint = _panel(_root, Color(0.1, 0.12, 0.2, 0.94), Color(1, 0.85, 0.4, 0.6), 16, 8, 20)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -120
	_hint.offset_bottom = -80
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hh := _hbox(_hint, 8)
	_icon(hh, "map", C_GOLD, 20)
	_hint_label = _label(hh, "", 16, C_GOLD, true)
	_hint.visible = false


## Afet / onemli olay bandi: ust ortada kayarak gelir, 3.5 sn kalir.
func show_alert(title: String, text: String, icon := "warning", color := Color(1.0, 0.32, 0.25)) -> void:
	for c in _alert.get_children():
		c.queue_free()
	_alert.add_theme_stylebox_override("panel", sb(color.darkened(0.55), 18, 2, color, 22, 10, 8))
	var h := _hbox(_alert, 14)
	var badge := _panel(h, color, Color.TRANSPARENT, 8, 8, 22)
	_icon(badge, icon, Color.WHITE, 30)
	var v := _vbox(h, -2)
	_label(v, title, 30, Color.WHITE, true)
	_label(v, text, 16, Color(1, 0.92, 0.88))
	_alert.visible = true
	_alert.reset_size()
	_alert.pivot_offset = _alert.size / 2.0
	if _alert_tw:
		_alert_tw.kill()
	_alert.modulate.a = 0.0
	_alert.scale = Vector2(0.8, 0.8)
	_alert_tw = create_tween()
	_alert_tw.set_parallel()
	_alert_tw.tween_property(_alert, "modulate:a", 1.0, 0.2)
	_alert_tw.tween_property(_alert, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_alert_tw.chain().tween_interval(3.5)
	_alert_tw.chain().tween_property(_alert, "modulate:a", 0.0, 0.5)
	_alert_tw.chain().tween_callback(func(): _alert.visible = false)


## Mudahale bandi + ekip paneli vurgusu.
func show_response(on: bool, g: Node) -> void:
	_response.visible = on
	update_stats(g)
	var border := Color(1, 0.45, 0.35, 0.9) if on else C_LINE
	_units_panel.add_theme_stylebox_override("panel", sb(C_BG, 14, 2 if on else 1, border, 12, 8, 6))


# ------------------------------------------------------------------ yardim isaretleri
func add_incident(inc: Incident) -> void:
	if game == null:
		return
	var m := IncidentMarker.new()
	_markers.add_child(m)
	m.setup(inc, game.city.camera_rig.camera, bold)
	m.clicked.connect(func(i: Incident):
		_sfx("click")
		if not game.assign_unit(i):
			m.deny())
	inc.resolved.connect(_on_incident_resolved.bind(m))


func _on_incident_resolved(inc: Incident, saved: int, lost: int, m: IncidentMarker) -> void:
	var at: Vector3 = inc.global_position + Vector3.UP * 1.4
	if inc.tile != Vector2i.ZERO:
		world_toast(at, "Söndürüldü" if saved > 0 else "Orman yandı", C_GOOD if saved > 0 else C_BAD, "check" if saved > 0 else "fire")
	if inc.tile == Vector2i.ZERO and saved > 0:
		world_toast(at, "%d kişi kurtarıldı" % saved, C_GOOD, "check")
		_sfx("success")
	if saved > 0:
		var now := Time.get_ticks_msec()
		_streak = _streak + 1 if now - _streak_time < 9000 else 1
		_streak_time = now
		best_streak = maxi(best_streak, _streak)
		if _streak >= 2 and is_instance_valid(m):
			_show_streak(m.position + m.size / 2.0)
	else:
		_streak = 0
		var dead := int(round(lost * float(Incident.KINDS[inc.kind].lethality)))
		if inc.tile == Vector2i.ZERO:
			world_toast(at, "%d can kaybı" % dead if dead > 0 else "Geç kalındı", C_BAD, "warning")
	if is_instance_valid(m):
		var tw := m.create_tween()
		tw.tween_property(m, "scale", Vector2(1.4, 1.4), 0.15)
		tw.tween_property(m, "scale", Vector2.ZERO, 0.25)
		tw.tween_callback(m.queue_free)


## "Seri x3!": arka arkaya hizli kurtarmalar. Her seride ses biraz daha tizlesir.
func _show_streak(at: Vector2) -> void:
	var l := _label(_root, "Seri x%d!" % _streak, 30 + mini(_streak, 6) * 3, C_GOLD, true)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0.35, 0.15, 0.0, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.reset_size()
	l.position = at - Vector2(l.size.x / 2.0, 80)
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(0.3, 0.3)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(0.6)
	tw.parallel().tween_property(l, "position:y", l.position.y - 40, 1.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.tween_callback(l.queue_free)
	var audio := get_node_or_null("../Audio")
	if audio:
		audio.play("coins", 1.0 + mini(_streak, 6) * 0.08)


## Oyun acilisi: siyahtan yavasca acilir (menuden gecisin devami).
func fade_in(sec := 1.4) -> void:
	var black := _black
	if black == null:
		return
	_black = null
	var tw := black.create_tween()
	tw.tween_property(black, "color:a", 0.0, sec).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(black.queue_free)


## Ekran flasi (afet basi): kenarlardan renkli parlama, 'times' kez yanip soner.
func flash(color: Color, times := 1) -> void:
	if _flash == null:
		_flash = ColorRect.new()
		_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0, 0.2, 0.1, 1.0);
uniform float strength = 0.0;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float v = smoothstep(0.25, 0.75, length(d) * 1.35);
	COLOR = vec4(tint.rgb, (0.18 + v * 0.82) * strength);
}"""
		var mat := ShaderMaterial.new()
		mat.shader = sh
		_flash.material = mat
		_root.add_child(_flash)
		_root.move_child(_flash, _modal_root.get_index())
	var m: ShaderMaterial = _flash.material
	m.set_shader_parameter("tint", color)
	var tw := _flash.create_tween()
	for i in times:
		tw.tween_method(func(v: float): m.set_shader_parameter("strength", v), 0.0, 0.75, 0.08)
		tw.tween_method(func(v: float): m.set_shader_parameter("strength", v), 0.75, 0.0, 0.35)


## Gun sonu ozeti: gece animasyonu sirasinda gorunen, tiklama gerektirmeyen kart.
func show_day_summary(d: Dictionary) -> void:
	hide_day_summary()
	hide_building()
	if _report and is_instance_valid(_report):
		var old := _report
		var t0 := old.create_tween()
		t0.tween_property(old, "modulate:a", 0.0, 0.3)
		t0.tween_callback(old.queue_free)
	_summary = _panel(_root, Color(0.06, 0.08, 0.13, 0.94), Color(1, 1, 1, 0.12), 20, 16, 18)
	_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary.custom_minimum_size = Vector2(420, 0)
	_summary.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_summary.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_summary.grow_vertical = Control.GROW_DIRECTION_BOTH
	_summary.offset_top = 40
	_root.move_child(_summary, _modal_root.get_index())
	var v := _vbox(_summary, 10)
	var head := _hbox(v, 10)
	var badge := _panel(head, Color(0.35, 0.4, 0.75), Color.TRANSPARENT, 6, 6, 12)
	_icon(badge, "star", Color.WHITE, 22)
	var tv := _vbox(head, -2)
	_label(tv, "GÜN SONU", 11, C_MUTED, true)
	_label(tv, "Gün %d Özeti" % d.day, 22, C_TEXT, true)
	var rows := _vbox(v, 6)
	var dm: int = d.money1 - d.money0
	_summary_row(rows, "coin", "Kasa", "%s  (%s%s)" % [GameManager.fmt_money(d.money1), "+" if dm >= 0 else "", GameManager.fmt_money(dm)],
		C_GOLD if dm >= 0 else C_BAD)
	var da: float = d.aw1 - d.aw0
	_summary_row(rows, "shield", "Farkındalık", "%%%d  (%+d)" % [int(d.aw1), int(round(da))], C_GOOD if da >= 0 else C_BAD)
	if d.saved > 0 or d.lost > 0:
		_summary_row(rows, "check", "Afet", "%d kurtarıldı · %d kayıp" % [d.saved, d.lost], C_GOOD if d.saved >= d.lost else C_BAD)
	if d.streak >= 2:
		_summary_row(rows, "star", "En iyi seri", "x%d" % d.streak, C_GOLD)
	var acts: Array = d.actions
	if not acts.is_empty():
		var txt := ", ".join(acts.slice(0, 3)) + (" +%d" % (acts.size() - 3) if acts.size() > 3 else "")
		_summary_row(rows, "shop", "Yatırımlar", txt, C_BLUE)
	else:
		_summary_row(rows, "shop", "Yatırımlar", "Bugün yatırım yapılmadı", C_MUTED)
	var foot := _panel(v, Color(1, 1, 1, 0.05), Color.TRANSPARENT, 12, 8, 10)
	var fh := _hbox(foot, 8)
	_icon(fh, "coin", C_GOLD, 16)
	_label(fh, "Yarın: %s%s" % ["+" if d.next >= 0 else "", GameManager.fmt_money(d.next)], 14, C_TEXT, true)
	if d.warning != "":
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fh.add_child(sp)
		_icon(fh, "warning", C_ACCENT, 16)
		_label(fh, d.warning, 14, C_ACCENT, true)
	var card := _summary
	card.modulate.a = 0.0
	card.reset_size()
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.92, 0.92)
	var tw := card.create_tween().set_parallel()
	tw.tween_property(card, "modulate:a", 1.0, 0.4).set_delay(0.6)
	tw.tween_property(card, "scale", Vector2.ONE, 0.45).set_delay(0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _summary_row(parent: Node, icon: String, caption: String, value: String, color: Color) -> void:
	var h := _hbox(parent, 10)
	_icon(h, icon, color, 18)
	var c := _label(h, caption, 14, C_MUTED)
	c.custom_minimum_size.x = 100
	var l := _label(h, value, 15, color, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 250


func hide_day_summary() -> void:
	if _summary and is_instance_valid(_summary):
		var card := _summary
		var tw := card.create_tween()
		tw.tween_property(card, "modulate:a", 0.0, 0.3)
		tw.tween_callback(card.queue_free)
	_summary = null


## Haritadaki bir noktaya bagli, yukari suzulen etiket (ornek: "AVM", "Güçlendiriliyor").
func world_toast(pos: Vector3, text: String, color: Color, icon := "", delay := 0.0) -> void:
	if pos == Vector3.INF:
		return
	var p := _panel(_markers, Color(0.06, 0.08, 0.12, 0.92), Color(color.r, color.g, color.b, 0.8), 10, 5, 12)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := _hbox(p, 6)
	if icon != "":
		_icon(h, icon, color, 18)
	_label(h, text, 15, color, true)
	p.modulate.a = 0.0
	p.visible = false
	_world_toasts.append([p, pos, 0.0, delay])


func _process(delta: float) -> void:
	if game == null or _world_toasts.is_empty():
		return
	var cam: Camera3D = game.city.camera_rig.camera
	for item in _world_toasts.duplicate():
		var p: PanelContainer = item[0]
		item[3] -= delta
		if item[3] > 0.0:
			continue
		item[2] += delta
		var t: float = item[2]
		var life := 3.2
		if t > life or not is_instance_valid(p):
			_world_toasts.erase(item)
			if is_instance_valid(p):
				p.queue_free()
			continue
		p.visible = not cam.is_position_behind(item[1])
		var sp := cam.unproject_position(item[1])
		p.reset_size()
		p.position = sp - Vector2(p.size.x / 2.0, p.size.y + 10.0 + t * 14.0)
		p.modulate.a = clampf(t * 5.0, 0.0, 1.0) * clampf((life - t) * 2.0, 0.0, 1.0)


# ------------------------------------------------------------------ magaza
func open_shop() -> void:
	if not _actions_enabled or game == null:
		return
	if _shop == null:
		_build_shop()
	_shop.visible = true
	_fill_shop()
	var card: Control = _shop.get_child(1)
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.92, 0.92)
	_shop.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_shop, "modulate:a", 1.0, 0.18)
	tw.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close_shop() -> void:
	if _shop:
		_shop.visible = false


var _shop_grid: GridContainer
var _shop_tabs := {}
var _shop_money: Label
var _shop_sub: Label


func _build_shop() -> void:
	_shop = Control.new()
	_shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_shop)
	_root.move_child(_shop, _modal_root.get_index())
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop.add_child(dim)
	_clickable(dim, close_shop)
	dim.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var card := _panel(_shop, Color(0.08, 0.1, 0.15, 0.98), Color(1, 1, 1, 0.12), 20, 18, 20)
	card.custom_minimum_size = Vector2(960, 0)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := _vbox(card, 14)
	# baslik
	var head := _hbox(v, 12)
	var badge := _panel(head, C_ACCENT, Color.TRANSPARENT, 8, 8, 14)
	_icon(badge, "shop", Color.WHITE, 30)
	var tv := _vbox(head, -2)
	_label(tv, "Belediye Mağazası", 26, C_TEXT, true)
	_shop_sub = _label(tv, "", 14, C_MUTED)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var mc := _panel(head, Color(1, 1, 1, 0.06), Color.TRANSPARENT, 12, 6, 12)
	mc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mh := _hbox(mc, 6)
	_icon(mh, "coin", C_GOLD, 22)
	_shop_money = _label(mh, "", 18, C_GOLD, true)
	var close := _button(head, "", Color(1, 1, 1, 0.08), 16)
	close.custom_minimum_size = Vector2(40, 40)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ci := _icon(close, "close", C_TEXT, 18)
	ci.position = Vector2(11, 11)
	close.pressed.connect(func():
		_sfx("click")
		close_shop())
	# sekmeler
	var tabs := _hbox(v, 8)
	for t in GameData.SHOP_TABS:
		var id: String = t[0]
		var b := _button(tabs, "", Color(1, 1, 1, 0.06), 15)
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var th := _hbox(b, 8)
		th.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		th.alignment = BoxContainer.ALIGNMENT_CENTER
		th.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon(th, TAB_STYLE[id][0], TAB_STYLE[id][1], 20)
		var tl := _label(th, t[1], 15, C_TEXT, true)
		tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func():
			_sfx("click")
			_shop_tab = id
			_fill_shop())
		_shop_tabs[id] = b
	# urunler
	_shop_grid = GridContainer.new()
	_shop_grid.columns = 4
	_shop_grid.add_theme_constant_override("h_separation", 10)
	_shop_grid.add_theme_constant_override("v_separation", 10)
	v.add_child(_shop_grid)


func _fill_shop() -> void:
	if game == null or _shop_grid == null:
		return
	_shop_money.text = GameManager.fmt_money(game.money)
	_shop_sub.text = "Belediye Sv %d · geliştirdikçe yeni yatırımlar açılır" % game.hall_level()
	for id in _shop_tabs:
		var b: Button = _shop_tabs[id]
		var tc: Color = TAB_STYLE[id][1]
		var active: bool = id == _shop_tab
		var bg := Color(tc.r, tc.g, tc.b, 0.28) if active else Color(1, 1, 1, 0.05)
		b.add_theme_stylebox_override("normal", sb(bg, 12, 2 if active else 0, tc, 14, 8))
		b.add_theme_stylebox_override("hover", sb(Color(tc.r, tc.g, tc.b, 0.2), 12, 2 if active else 0, tc, 14, 8))
	for c in _shop_grid.get_children():
		c.queue_free()
	var col: Color = TAB_STYLE[_shop_tab][1]
	for item in game.shop_items(_shop_tab):
		_shop_card(item, col)


func _shop_card(item: Dictionary, col: Color) -> void:
	var locked: bool = item.reason != ""
	var afford: bool = game.money >= item.cost
	var card := _panel(_shop_grid, C_CARD if not locked else Color(0.1, 0.12, 0.17), C_LINE, 12, 12, 14)
	card.custom_minimum_size = Vector2(222, 128)
	var v := _vbox(card, 6)
	var h := _hbox(v, 10)
	var badge := _panel(h, col if not locked else Color(0.3, 0.32, 0.38), Color.TRANSPARENT, 6, 6, 12)
	_icon(badge, item.icon, Color.WHITE, 24)
	var name_l := _label(h, item.name, 16, C_TEXT if not locked else C_MUTED, true)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var d := _label(v, item.desc, 13, C_MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 196
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if locked:
		var done: bool = item.reason in ["Yapıldı", "En üst seviye", "Hepsi sağlam"]
		var lc := _chip(v, "check" if done else "lock", item.reason, C_GOOD if done else C_MUTED, 13)
		lc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		return
	var b := _button(v, GameManager.fmt_money(item.cost), C_GOLD.darkened(0.15) if afford else Color(0.35, 0.3, 0.25), 15)
	if not afford:
		b.tooltip_text = "Bütçe yetersiz"
		b.add_theme_color_override("font_color", Color(1, 0.7, 0.6))
	b.pressed.connect(func():
		_sfx("click")
		if not afford:
			_sfx("error")
			toast("Bütçe yetersiz: %s gerekli" % GameManager.fmt_money(item.cost), "bad")
			return
		action_pressed.emit(item.id)
		close_shop())


# ------------------------------------------------------------------ sol: bina karti
func show_building(b: Building, options: Array, g: Node) -> void:
	if _bpanel and is_instance_valid(_bpanel):
		_bpanel.queue_free()
	_bpanel = _panel(_root, C_BG, C_LINE, 14, 12)
	_bpanel.position = Vector2(14, 82)
	_root.move_child(_bpanel, _modal_root.get_index())
	_bpanel.custom_minimum_size = Vector2(300, 0)
	var v := _vbox(_bpanel, 8)
	var info := GameData.info(b.model_name)
	var head := _hbox(v, 10)
	_icon(head, "house" if b.is_house() else "hall", C_GOLD, 28)
	var tv := _vbox(head, -2)
	_label(tv, b.display_name(), 19, C_TEXT, true)
	var d: int = g.map_info.district_of(b.position)
	_label(tv, "%s · farkındalık %%%d" % [g.map_info.district_names[d], int(g.district_aw[d])], 12, C_MUTED)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	v.add_child(chips)
	var st_col: Color = [C_GOOD, C_GOLD, C_BAD][b.state]
	_chip(chips, ["check", "warning", "rubble"][b.state], ["Sağlam", "Hasarlı", "Yıkık"][b.state], st_col, 13)
	if b.population() > 0:
		_chip(chips, "people", str(b.population()), Color(0.75, 0.85, 1.0), 13)
	var risk_txt: String = info.risk
	var risk_col := C_BAD if risk_txt.begins_with("Çok y") else (C_GOOD if risk_txt.ends_with("düşük") else C_GOLD)
	_chip(chips, "warning" if risk_col == C_BAD else "shield", "Deprem: " + risk_txt.to_lower(), risk_col, 13)
	for unit in GameData.SERVICES:
		if b.model_name.begins_with(GameData.SERVICES[unit]):
			_chip(chips, UNIT_ICONS[unit][0], "%d araç" % g.units_total(unit), UNIT_ICONS[unit][1], 13)
	if b.closed_days > 0:
		_chip(chips, "house", "İnşaat: %d gün" % b.closed_days, C_GOLD, 13)
	if b.state != Building.State.NORMAL and b.repair_days > 0:
		_chip(chips, "house", "Onarım: %d gün" % b.repair_days, C_GOLD, 13)
	for txt in [["kacak", "Kaçak kat taşıyıcı sistemi zayıflatır"], ["gecekondu", "Ruhsatsız, depremde ve selde ilk o gider"]]:
		if txt[0] in b.model_name:
			var w := _label(v, txt[1], 13, C_BAD)
			w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			w.custom_minimum_size.x = 270
	for o in options:
		_option_row(v, o)
	if GameData.REINFORCE.has(b.model_name):
		var tip := _label(v, "İpucu: Mağaza › Güçlendirme'de tüm mahalle %50 ucuz", 12, C_BLUE)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.custom_minimum_size.x = 270
	_bpanel.modulate.a = 0.0
	_bpanel.create_tween().tween_property(_bpanel, "modulate:a", 1.0, 0.15)


func _option_row(parent: Node, o: Dictionary) -> void:
	var locked: bool = o.locked != ""
	var gain: bool = o.cost < 0
	var col := Color(0.62, 0.22, 0.2) if o.id == "allow_kacak" else Color(0.22, 0.42, 0.7)
	if locked:
		col = Color(0.22, 0.24, 0.3)
	var b := _button(parent, "", col, 15)
	b.custom_minimum_size = Vector2(0, 40)
	var h := _hbox(b, 8)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -12
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		_icon(h, "lock", C_MUTED, 16)
	var l := _label(h, o.text, 15, Color.WHITE if not locked else C_MUTED, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var price := _label(h, o.locked if locked else (("+" if gain else "") + GameManager.fmt_money(absi(o.cost))), 14,
		C_MUTED if locked else (C_GOOD if gain else C_GOLD), true)
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		_sfx("click")
		building_action.emit(o.id))


func hide_building() -> void:
	if _bpanel and is_instance_valid(_bpanel):
		_bpanel.queue_free()
	_bpanel = null


# ------------------------------------------------------------------ afet raporu
const REPORT_ICONS := {"quake": "warning", "house_fire": "fire", "forest_fire": "tree", "flood": "wave"}


func show_report(r: Dictionary, modal := false) -> void:
	if _report and is_instance_valid(_report):
		_report.queue_free()
	var accent := C_GOOD if r.casualties == 0 else (C_GOLD if r.saved >= r.casualties else C_BAD)
	var holder: Control = _root
	var dim: ColorRect
	if modal:
		dim = _dim()
		holder = CenterContainer.new()
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.add_child(holder)
	var card := _panel(holder, Color(0.07, 0.09, 0.14, 0.96), Color(accent.r, accent.g, accent.b, 0.7), 16, 14, 16)
	card.custom_minimum_size = Vector2(340 if not modal else 520, 0)
	if not modal:
		card.position = Vector2(14, 82)
		_report = card
		_root.move_child(card, _modal_root.get_index())
	var v := _vbox(card, 10)
	var head := _hbox(v, 10)
	var badge := _panel(head, accent.darkened(0.2), Color.TRANSPARENT, 6, 6, 12)
	_icon(badge, REPORT_ICONS.get(r.type, "warning"), Color.WHITE, 24)
	var tv := _vbox(head, -2)
	_label(tv, "AFET RAPORU", 11, C_MUTED, true)
	_label(tv, ("Küçük " + r.title.to_lower()) if r.get("minor", false) else r.title, 20 if not modal else 26, C_TEXT, true)
	var stats := _hbox(v, 8)
	_stat(stats, "check", str(r.saved), "kurtarıldı", C_GOOD)
	_stat(stats, "warning", str(r.casualties), "can kaybı", C_BAD if r.casualties > 0 else C_MUTED)
	if r.collapsed > 0:
		_stat(stats, "rubble", str(r.collapsed), "yıkıldı", C_ACCENT)
	elif r.damaged > 0:
		_stat(stats, "house", str(r.damaged), "hasarlı", C_GOLD)
	if r.burned > 0:
		_stat(stats, "tree", "%d ha" % (r.burned * 4), "yandı", C_ACCENT)
	if r.get("prep_lives", 0) > 0 or r.get("held_count", 0) > 0:
		var pb := _panel(v, Color(0.3, 0.9, 0.45, 0.12), Color(0.3, 0.9, 0.45, 0.35), 10, 8, 10)
		var ph := _hbox(pb, 8)
		_icon(ph, "shield", C_GOOD, 20)
		var parts := []
		if r.get("held_count", 0) > 0:
			parts.append("%d bina dayandı" % r.held_count)
		if r.get("prep_lives", 0) > 0:
			parts.append("hazırlıksız şehre göre ~%d can kurtuldu" % r.prep_lives)
		var pl := _label(ph, "Hazırlık işe yaradı: " + ", ".join(parts), 13, C_GOOD, true)
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pl.custom_minimum_size.x = card.custom_minimum_size.x - 70
	if r.get("roads", 0) > 0:
		_chip(v, "rubble", "%d yol enkazla kapandı · bina onarılınca açılır" % r.roads, C_ACCENT, 12)
	if r.get("cause", "") != "":
		var c := _label(v, r.cause, 13, C_MUTED)
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.custom_minimum_size.x = card.custom_minimum_size.x - 34
	var tipbox := _panel(v, Color(0.3, 0.55, 1.0, 0.12), Color.TRANSPARENT, 10, 8, 10)
	var th := _hbox(tipbox, 8)
	_icon(th, "star", C_BLUE, 18)
	var tip := _label(th, r.tip, 13, Color(0.8, 0.88, 1.0))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size.x = card.custom_minimum_size.x - 70
	var close := _button(v, "Devam" if modal else "Tamam", Color(0.25, 0.4, 0.62), 15)
	if modal:
		close.pressed.connect(func():
			_sfx("click")
			_modal_done.emit(0))
		_pop_in(card, dim)
		await _modal_done
		dim.queue_free()
		return
	close.pressed.connect(func():
		_sfx("click")
		if is_instance_valid(card):
			card.queue_free())
	card.modulate.a = 0.0
	card.position.x = -360
	var tw := card.create_tween().set_parallel()
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	tw.tween_property(card, "position:x", 14.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var card_ref: WeakRef = weakref(card)  # kart erken kapanabilir (gun ozeti)
	get_tree().create_timer(16.0).timeout.connect(func():
		var c2: Control = card_ref.get_ref()
		if c2:
			var t2 := c2.create_tween()
			t2.tween_property(c2, "modulate:a", 0.0, 0.4)
			t2.tween_callback(c2.queue_free))


func _stat(parent: Node, icon: String, value: String, caption: String, color: Color) -> void:
	var p := _panel(parent, Color(1, 1, 1, 0.05), Color.TRANSPARENT, 10, 6, 10)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := _vbox(p, -2)
	var h := _hbox(v, 5)
	_icon(h, icon, color, 18)
	_label(h, value, 20, color, true)
	_label(v, caption, 11, C_MUTED)


# ------------------------------------------------------------------ karar pencereleri
func _dim() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_root.add_child(dim)
	return dim


func _pop_in(card: Control, dim: ColorRect) -> void:
	card.modulate.a = 0.0
	card.scale = Vector2(0.9, 0.9)
	await get_tree().process_frame
	card.pivot_offset = card.size / 2.0
	var tw := create_tween().set_parallel()
	tw.tween_property(dim, "color:a", 0.55, 0.25)
	tw.tween_property(card, "modulate:a", 1.0, 0.2)
	tw.tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Ortak pencere: baslik serit + icerik + butonlar. Doner: basilan butonun indeksi.
func _modal(title: String, icon: String, accent: Color, width: int, fill: Callable, buttons: Array) -> int:
	var dim := _dim()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var card := _panel(center, Color(0.08, 0.1, 0.15, 0.98), Color(accent.r, accent.g, accent.b, 0.6), 24, 20, 20)
	card.custom_minimum_size = Vector2(width, 0)
	var v := _vbox(card, 14)
	var head := _hbox(v, 12)
	var badge := _panel(head, accent, Color.TRANSPARENT, 8, 8, 16)
	_icon(badge, icon, Color.WHITE, 32)
	var t := _label(head, title, 28, C_TEXT, true)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.call(v, width - 48)
	if not buttons.is_empty():
		var row := _hbox(v, 10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for i in buttons.size():
			var b := _button(row, buttons[i], accent if i == 0 else Color(0.25, 0.4, 0.6), 18)
			b.custom_minimum_size = Vector2(200, 48)
			b.pressed.connect(func():
				_sfx("click")
				_modal_done.emit(i))
	_pop_in(card, dim)
	var result: int = await _modal_done
	dim.queue_free()
	return result


func _text(parent: Node, text: String, width: int, size := 17, color := C_TEXT) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(width, 0)
	rt.add_theme_font_size_override("normal_font_size", size)
	rt.add_theme_font_size_override("bold_font_size", size)
	rt.add_theme_color_override("default_color", color)
	rt.text = text
	parent.add_child(rt)
	return rt


func show_intro() -> void:
	await _modal("Afete Hazır Şehir", "hall", C_ACCENT, 640, _fill_intro, ["Göreve başla"])


func _fill_intro(v: VBoxContainer, w: int) -> void:
	_text(v, "Belediye başkanı sensin. [b]20 gün[/b] boyunca şehrini depreme, yangına ve sele hazırla.", w, 18)
	for row in [["news", C_BLUE, "Her sabah bir karar kartı gelir. Seçimin haritada iz bırakır."],
			["warning", C_ACCENT, "Uyarı gelince önlem al. Deprem ise asla haber vermez!"],
			["rescue", C_BAD, "Afette yardım işaretlerine tıkla, ekip gönder. Süre dolarsa can kaybı olur."],
			["shop", C_GOLD, "Mağazadan yatırım yap: farkındalık, altyapı, güçlendirme."]]:
		var col: Color = row[1]
		var h := _hbox(v, 12)
		var badge := _panel(h, Color(col.r, col.g, col.b, 0.18), Color.TRANSPARENT, 6, 6, 10)
		_icon(badge, row[0], col, 22)
		var l := _label(h, row[2], 16, C_TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = w - 60
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Olay karti: her secenek bir kart; altinda sonuclari gosteren cipler. Doner: secilen indeks.
func show_event(ev: Dictionary) -> int:
	var dim := _dim()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var accent := Color(0.4, 0.68, 1.0)
	var card := _panel(center, Color(0.08, 0.1, 0.15, 0.98), Color(accent.r, accent.g, accent.b, 0.5), 24, 20, 20)
	card.custom_minimum_size = Vector2(620, 0)
	var v := _vbox(card, 14)
	var head := _hbox(v, 12)
	var badge := _panel(head, accent, Color.TRANSPARENT, 8, 8, 16)
	_icon(badge, "news", Color.WHITE, 30)
	var tv := _vbox(head, -2)
	_label(tv, "GÜNÜN KARARI", 12, accent, true)
	_label(tv, ev.title, 26, C_TEXT, true)
	_text(v, ev.text, 572, 17, Color(0.85, 0.88, 0.95))
	for i in ev.choices.size():
		_choice_card(v, ev.choices[i], i)
	_pop_in(card, dim)
	var result: int = await _modal_done
	dim.queue_free()
	return result


func _choice_card(parent: Node, choice: Dictionary, index: int) -> void:
	var normal := sb(Color(1, 1, 1, 0.05), 14, 1, C_LINE, 14, 10)
	var hover := sb(Color(0.4, 0.68, 1.0, 0.16), 14, 2, Color(0.4, 0.68, 1.0, 0.9), 14, 10)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", normal)
	parent.add_child(p)
	var v := _vbox(p, 6)
	var h := _hbox(v, 10)
	var num := _panel(h, Color(1, 1, 1, 0.1), Color.TRANSPARENT, 8, 1, 8)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label(num, str(index + 1), 14, C_MUTED, true)
	var t := _label(h, choice.text, 17, C_TEXT, true)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	v.add_child(flow)
	for c in effect_chips(choice.effects):
		_chip(flow, c[0], c[1], c[2], 13, Color(c[2].r, c[2].g, c[2].b, 0.12))
	for c in p.find_children("*", "Control", true, false):
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clickable(p, func():
		_sfx("click")
		_modal_done.emit(index))
	p.mouse_entered.connect(func():
		p.add_theme_stylebox_override("panel", hover)
		_sfx("hover"))
	p.mouse_exited.connect(func(): p.add_theme_stylebox_override("panel", normal))


## Bir secenegin sonuclarini kisa ciplere cevir: [ikon, yazi, renk]
static func effect_chips(fx: Dictionary) -> Array:
	var out := []
	for k in fx:
		var v = fx[k]
		match k:
			"money":
				out.append(["coin", ("+" if int(v) > 0 else "") + GameManager.fmt_money(int(v)), C_GOLD if int(v) > 0 else C_BAD])
			"awareness":
				out.append(["shield", "Farkındalık %+d" % int(v), C_GOOD if float(v) > 0 else C_BAD])
			"risk_fire", "risk_forest", "risk_flood", "risk_quake":
				var up := float(v) > 1.0
				out.append(["warning" if up else "shield", "%s riski %s" % [RISK_TEXT[k.trim_prefix("risk_")], "artar" if up else "azalır"],
					C_BAD if up else C_GOOD])
			"kacak":
				out.append(["warning", "%d binaya kaçak kat" % int(v), C_BAD])
			"river_site":
				out.append(["warning", "Dere yatağına bina", C_BAD])
			"reinforce":
				out.append(["shield", "%d bina güçlenir" % int(v), C_GOOD])
			"upgrade":
				out.append(["house", "%d gecekondu yenilenir" % int(v), C_GOOD])
			"upgrade_service":
				out.append(["star", "%s gelişir" % GameData.UNIT_NAMES.get(v, "Birim"), C_GOOD])
			"kits":
				out.append(["kit", "Deprem çantası", C_GOOD])
			"drills":
				out.append(["drill", "Tatbikat", C_GOOD])
			"assembly":
				out.append(["flag", "Toplanma alanı %+d" % int(v), C_GOOD if int(v) > 0 else C_BAD])
			"build":
				out.append(["map", "Haritada: " + str(v.get("label", "yapı")), C_BLUE])
			"later":
				out.append(["warning", "Sonucu ileride çıkar", Color(1.0, 0.75, 0.4)])
	if out.is_empty():
		out.append(["check", "Değişiklik yok", C_MUTED])
	return out


func show_decision(title: String, text: String, buttons: Array) -> int:
	return await _modal(title, "warning", Color(1.0, 0.35, 0.28), 580, _fill_decision.bind(text), buttons)


func _fill_decision(v: VBoxContainer, w: int, text: String) -> void:
	_text(v, "[center]" + text + "[/center]", w, 18)


func show_end(g: Node) -> void:
	var gr: Array = g.grade()
	var col: Color = {"A": C_GOOD, "B": Color(0.6, 0.9, 0.4), "C": C_GOLD, "D": C_ACCENT, "F": C_BAD}[gr[0]]
	var choice: int = await _modal("20 Gün Tamamlandı", "star", col, 640, _fill_end.bind(g, gr, col), ["Yeniden Oyna", "Ana Menü"])
	Engine.time_scale = 1.0
	if choice == 1:
		get_tree().change_scene_to_file(MENU_SCENE)
	else:
		get_tree().reload_current_scene()


# ------------------------------------------------------------------ duraklatma menusu (ESC)
const MENU_SCENE := "res://scenes/menu.tscn"
var _pause: Control


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	if _pause:
		_close_pause()
	elif _shop and _shop.visible:
		close_shop()
	elif _modal_root.get_child_count() == 0:
		_open_pause()


func _open_pause() -> void:
	_sfx("click")
	get_tree().paused = true
	_pause = ColorRect.new()
	(_pause as ColorRect).color = Color(0.02, 0.03, 0.06, 0.6)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_pause)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	var card := _panel(center, Color(0.07, 0.09, 0.14, 0.97), Color(1, 1, 1, 0.12), 26, 22, 20)
	card.custom_minimum_size = Vector2(340, 0)
	var v := _vbox(card, 12)
	var head := _hbox(v, 12)
	var badge := _panel(head, Color(0.42, 0.36, 0.68), Color.TRANSPARENT, 8, 8, 14)
	_icon(badge, "pause", Color.WHITE, 24)
	_label(head, "Duraklatıldı", 26, C_TEXT, true)
	for item in [["play", "Devam", C_ACCENT, _close_pause], ["gear", "Ayarlar", Color(0.25, 0.4, 0.62), _pause_settings],
			["home", "Ana Menü", Color(0.25, 0.4, 0.62), _to_menu], ["exit", "Oyundan Çık", Color(0.55, 0.2, 0.2), func(): get_tree().quit()]]:
		var b := _button(v, "", item[2], 18)
		b.custom_minimum_size = Vector2(0, 48)
		var h := _hbox(b, 12)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 18
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon(h, item[0], Color.WHITE, 20)
		var l := _label(h, item[1], 18, Color.WHITE, true)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var action: Callable = item[3]
		b.pressed.connect(func():
			_sfx("click")
			action.call())
	_pause.modulate.a = 0.0
	create_tween().tween_property(_pause, "modulate:a", 1.0, 0.15)


func _close_pause() -> void:
	if _pause:
		_pause.queue_free()
		_pause = null
	get_tree().paused = false


func _pause_settings() -> void:
	var holder := ColorRect.new()
	holder.color = Color(0, 0, 0, 0.35)
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause.add_child(holder)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(center)
	var panel := SettingsPanel.new()
	center.add_child(panel)
	panel.closed.connect(holder.queue_free)


func _to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MENU_SCENE)


func _fill_end(v: VBoxContainer, w: int, g: Node, gr: Array, col: Color) -> void:
	var t: Dictionary = g.totals
	var msg := {"A": "Örnek bir şehir! Halkın bilinçli, binalar sağlam.",
		"B": "Çok iyi! Birkaç eksik dışında şehir afetlere hazırdı.",
		"C": "Fena değil, ama daha fazla hazırlık hayat kurtarırdı.",
		"D": "Şehir zor günler geçirdi. Önlemler geç kaldı.",
		"F": "Hazırlıksız yakalandık. Afetler değil, hazırlıksızlık yıkar."}
	var casualties: int = t.casualties
	var baseline := maxi(int(round(float(t.baseline))), casualties)
	var top := _hbox(v, 18)
	var circle := _panel(top, Color(col.r, col.g, col.b, 0.2), col, 26, 6, 60)
	_label(circle, gr[0], 64, col, true)
	var tv := _vbox(top, 2)
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label(tv, "Güvenlik puanı %d / 100" % gr[1], 20, C_TEXT, true)
	var m := _label(tv, msg[gr[0]], 16, C_MUTED)
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.custom_minimum_size.x = w - 160
	_label(v, "Hazırlığın kaç can kurtardı?", 16, C_TEXT, true)
	_bar(v, "Hiç hazırlık yapmasaydın", baseline, baseline, C_BAD, w)
	_bar(v, "Senin şehrin", casualties, baseline, C_GOOD, w)
	var row := _hbox(v, 8)
	_stat(row, "warning", str(t.disasters), "afet", C_ACCENT)
	_stat(row, "shield", str(t.prevented), "önlendi", C_GOOD)
	_stat(row, "check", str(t.saved), "kurtarıldı", C_GOOD)
	_stat(row, "rubble", str(t.collapsed), "yıkıldı", C_ACCENT)
	_stat(row, "tree", "%d ha" % (int(t.burned) * 4), "yandı", C_ACCENT)


func _bar(parent: Node, caption: String, value: int, max_value: int, color: Color, width: int) -> void:
	var h := _hbox(parent, 10)
	var l := _label(h, caption, 14, C_MUTED)
	l.custom_minimum_size.x = 190
	var bg := _panel(h, Color(1, 1, 1, 0.06), Color.TRANSPARENT, 0, 0, 8)
	bg.custom_minimum_size = Vector2(width - 280, 22)
	var fill := ColorRect.new()
	fill.color = color
	fill.custom_minimum_size = Vector2(0, 22)
	fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bg.add_child(fill)
	var target := (width - 280) * clampf(float(value) / maxf(1.0, float(max_value)), 0.0, 1.0)
	fill.create_tween().tween_property(fill, "custom_minimum_size:x", maxf(4.0, target), 1.2).set_delay(0.4).set_trans(Tween.TRANS_QUAD)
	_label(h, "%d can" % value, 16, color, true)
