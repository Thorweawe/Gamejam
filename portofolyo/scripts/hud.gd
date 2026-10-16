extends CanvasLayer
## Oyun arayuzu (kodla kurulur, tum renkler/olculer burada).
##   Sol ust   : para, nufus, gelir/gider, farkindalik, hazirlik
##   Sag ust   : hava / afet uyarisi + onlem butonlari, altinda mesaj akisi
##   Orta ust  : afet uyari bandi, mudahale (birim) bandi
##   Sol alt   : belediye eylemleri (belediye seviyesine gore kilitli)
##   Sag alt   : risk haritasi (Gunu Gec butonu DayCycle'da)
##   Sol       : secili bina paneli, afet raporu
##   Orta      : sadece KARAR pencereleri (olay karti, giris, oyun sonu)

signal action_pressed(id: String)
signal building_action(id: String)
signal precaution_pressed(id: String)
signal risk_toggled(on: bool)
signal _modal_done(result: int)

const ACCENT := Color(0.95, 0.55, 0.15)
const PANEL_BG := Color(0.08, 0.1, 0.16, 0.82)
const KIND_COLORS := {"info": Color(0.85, 0.9, 1.0), "good": Color(0.55, 0.95, 0.55),
	"bad": Color(1.0, 0.6, 0.45), "disaster": Color(1.0, 0.35, 0.3)}
const ACTION_COLORS := {"news": Color(0.25, 0.55, 0.85), "drill": Color(0.2, 0.62, 0.55), "forest": Color(0.3, 0.58, 0.3),
	"assembly": Color(0.25, 0.62, 0.35), "tv": Color(0.38, 0.45, 0.85), "kits": Color(0.88, 0.5, 0.15),
	"river": Color(0.15, 0.52, 0.75), "warning": Color(0.8, 0.3, 0.3), "renewal": Color(0.6, 0.45, 0.25),
	"levee": Color(0.2, 0.45, 0.65)}

var _money: Label
var _pop: Label
var _flow: Label
var _aw_bar: ProgressBar
var _aw_label: Label
var _prep: Label
var _feed: VBoxContainer
var _actions := {}  # id -> Button
var _bpanel: PanelContainer
var _bbox: VBoxContainer
var _forecast: PanelContainer
var _forecast_box: VBoxContainer
var _response: PanelContainer
var _response_label: Label
var _alert: Label
var _alert_tw: Tween
var _report: PanelContainer
var _hint: Label
var _risk_btn: Button
var _modal_root: Control


func _ready() -> void:
	layer = 10
	_build_stats()
	_build_feed()
	_build_actions()
	_build_side_panels()
	_modal_root = Control.new()
	_modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_modal_root)


# ------------------------------------------------------------------ yardimcilar
static func box(color: Color, radius := 10, border := 0, border_color := Color.TRANSPARENT, margin := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_color
	sb.set_content_margin_all(margin)
	return sb


func _panel(parent: Node, color := PANEL_BG, border_color := Color.TRANSPARENT) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, 10, 2 if border_color.a > 0 else 0, border_color))
	parent.add_child(p)
	return p


func _label(parent: Node, text: String, size := 18, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, color := ACCENT, size := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", box(color, 10, 0, Color.TRANSPARENT, 9))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.15), 10, 0, Color.TRANSPARENT, 9))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.15), 10, 0, Color.TRANSPARENT, 9))
	b.add_theme_stylebox_override("disabled", box(Color(0.3, 0.32, 0.38, 0.85), 10, 0, Color.TRANSPARENT, 9))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.75, 0.75, 0.8))
	b.mouse_entered.connect(func(): _sfx("hover"))
	parent.add_child(b)
	return b


func _sfx(sound: String) -> void:
	var audio := get_node_or_null("../Audio")
	if audio:
		audio.play(sound)


# ------------------------------------------------------------------ sol ust: istatistik
func _build_stats() -> void:
	var p := _panel(self)
	p.position = Vector2(12, 12)
	p.custom_minimum_size = Vector2(275, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	_money = _label(v, "", 24, Color(1.0, 0.88, 0.45))
	_flow = _label(v, "", 13, Color(0.8, 0.85, 0.95))
	_pop = _label(v, "", 16)
	_aw_label = _label(v, "", 16)
	_aw_bar = ProgressBar.new()
	_aw_bar.custom_minimum_size = Vector2(240, 14)
	_aw_bar.show_percentage = false
	_aw_bar.add_theme_stylebox_override("background", box(Color(1, 1, 1, 0.12), 7, 0, Color.TRANSPARENT, 0))
	v.add_child(_aw_bar)
	_prep = _label(v, "", 13, Color(0.8, 0.85, 0.95))
	var help := _label(self, "Sol tık: bina seç   WASD / sağ tık: kaydır   Tekerlek: yakınlaş   Q/E: döndür   R: risk haritası   N: günü geç",
		13, Color(1, 1, 1, 0.85))
	help.add_theme_constant_override("outline_size", 5)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_top = -176
	help.offset_left = 14


func update_stats(game: Node) -> void:
	_money.text = GameManager.fmt_money(game.money)
	_flow.text = "Günlük: vergi +%s  gider -%s  onarım -%s" % [GameManager.fmt_money(game.daily_income()),
		GameManager.fmt_money(game.upkeep()), GameManager.fmt_money(game.repair_cost_today())]
	_pop.text = "Nüfus: %d    Belediye: Sv %d" % [game.population(), game.hall_level()]
	var aw: float = game.awareness
	_aw_label.text = "Farkındalık (şehir ort.): %%%d" % int(aw)
	_aw_bar.value = aw
	var c := Color(0.95, 0.3, 0.25).lerp(Color(0.95, 0.8, 0.2), clampf(aw / 50.0, 0, 1)).lerp(Color(0.3, 0.85, 0.4), clampf((aw - 50.0) / 50.0, 0, 1))
	_aw_bar.add_theme_stylebox_override("fill", box(c, 7, 0, Color.TRANSPARENT, 0))
	var river: String = ["Yok", "Islah", "Islah + set"][game.flood_protection]
	_prep.text = "Birimler: İtfaiye %d  Ambulans %d  AFAD %d\nDere: %s   Tahliye: %%%d   Toplanma: %d" % [
		game.units_total("fire"), game.units_total("medic"), game.units_total("rescue"),
		river, int(game.evac_ratio(Vector3.INF) * 100), game.map_info.assembly_points.size()]
	for id in _actions:
		var b: Button = _actions[id]
		var a: Dictionary = game.action_def(id)
		var reason: String = game.action_block_reason(id)
		if reason != "":
			b.text = "%s\n%s" % [a.name, reason]
		else:
			b.text = "%s\n%s" % [a.name, GameManager.fmt_money(a.cost)]
		b.set_meta("ok", reason == "" and game.money >= a.cost)
		b.modulate = Color.WHITE if b.get_meta("ok") else Color(1, 1, 1, 0.5)


# ------------------------------------------------------------------ sag: uyari + mesajlar
func _build_feed() -> void:
	_forecast = _panel(self, Color(0.35, 0.15, 0.05, 0.9), Color(1.0, 0.6, 0.2))
	_forecast.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_forecast.offset_left = -380
	_forecast.offset_right = -14
	_forecast.offset_top = 12
	_forecast.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_forecast_box = VBoxContainer.new()
	_forecast_box.add_theme_constant_override("separation", 6)
	_forecast.add_child(_forecast_box)
	_forecast.visible = false
	_feed = VBoxContainer.new()
	_feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_feed.offset_left = -380
	_feed.offset_right = -14
	_feed.offset_top = 175
	_feed.add_theme_constant_override("separation", 5)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)


func show_message(text: String, kind := "info") -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color(0.06, 0.08, 0.13, 0.85), 8, 0, Color.TRANSPARENT, 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 345
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", KIND_COLORS.get(kind, Color.WHITE))
	p.add_child(l)
	_feed.add_child(p)
	while _feed.get_child_count() > 6:
		var old := _feed.get_child(0)
		_feed.remove_child(old)
		old.queue_free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(7.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.8)
	tw.tween_callback(p.queue_free)


func show_forecast(title: String, text: String, actions: Array, _game: Node) -> void:
	for c in _forecast_box.get_children():
		c.queue_free()
	_label(_forecast_box, "UYARI: " + title, 18, Color(1.0, 0.8, 0.4))
	var l := _label(_forecast_box, text, 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 340
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_forecast_box.add_child(row)
	for a in actions:
		var b := _button(row, "%s\n%s" % [a.name, GameManager.fmt_money(a.cost)], Color(0.85, 0.45, 0.1), 14)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			_sfx("click")
			precaution_pressed.emit(a.id)
			if a.id != "sandbag":
				b.disabled = true)
	_forecast.visible = true


func hide_forecast() -> void:
	_forecast.visible = false


# ------------------------------------------------------------------ alt: eylemler
func _build_actions() -> void:
	var p := _panel(self, Color(0.08, 0.1, 0.16, 0.75))
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	p.offset_left = 12
	p.offset_top = -130
	p.offset_bottom = -12
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var v := VBoxContainer.new()
	p.add_child(v)
	_label(v, "Belediye Eylemleri  (kilitliler belediye geliştirilince açılır)", 13, Color(1.0, 0.88, 0.45))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for a in GameData.ACTIONS:
		var b := _button(grid, a.name, ACTION_COLORS.get(a.id, ACCENT), 12)
		b.custom_minimum_size = Vector2(116, 44)
		b.tooltip_text = a.desc
		b.pressed.connect(func():
			_sfx("click")
			action_pressed.emit(a.id))
		_actions[a.id] = b
	_risk_btn = _button(self, "Risk Haritası (R)", Color(0.35, 0.3, 0.5), 15)
	_risk_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_risk_btn.offset_left = -250
	_risk_btn.offset_right = -16
	_risk_btn.offset_top = -126
	_risk_btn.offset_bottom = -88
	_risk_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_risk_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_risk_btn.toggle_mode = true
	_risk_btn.toggled.connect(func(on):
		_sfx("click")
		risk_toggled.emit(on))
	_hint = _label(self, "", 17, Color(1.0, 0.9, 0.5))
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -190
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.visible = false


func set_actions_enabled(on: bool) -> void:
	for id in _actions:
		_actions[id].disabled = not on


func set_risk_button(on: bool) -> void:
	_risk_btn.set_pressed_no_signal(on)


func show_place_hint(text: String) -> void:
	_hint.text = text
	_hint.visible = true


func hide_place_hint() -> void:
	_hint.visible = false


# ------------------------------------------------------------------ yan paneller
func _build_side_panels() -> void:
	_bpanel = _panel(self)
	_bpanel.position = Vector2(12, 205)
	_bpanel.custom_minimum_size = Vector2(285, 0)
	_bbox = VBoxContainer.new()
	_bbox.add_theme_constant_override("separation", 6)
	_bpanel.add_child(_bbox)
	_bpanel.visible = false

	_response = _panel(self, Color(0.4, 0.08, 0.06, 0.9), Color(1.0, 0.4, 0.3))
	_response.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_response.offset_top = 92
	_response.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_response_label = _label(_response, "", 16)
	_response_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_response.visible = false

	_alert = _label(self, "", 26, Color(1.0, 0.35, 0.3))
	_alert.add_theme_constant_override("outline_size", 12)
	_alert.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_alert.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_alert.offset_top = 160
	_alert.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert.modulate.a = 0.0


func show_building(b: Building, options: Array, game: Node) -> void:
	for c in _bbox.get_children():
		c.queue_free()
	var info := GameData.info(b.model_name)
	_label(_bbox, b.display_name(), 21, Color(1.0, 0.88, 0.45))
	var d: int = game.map_info.district_of(b.position)
	_label(_bbox, "%s  (farkındalık %%%d)" % [game.map_info.district_names[d], int(game.district_aw[d])], 13, Color(0.75, 0.85, 1.0))
	var state_txt: String = ["Sağlam", "Hasarlı", "Yıkık"][b.state]
	_label(_bbox, "Durum: %s   Nüfus: %d" % [state_txt, b.population()], 15)
	var risk_txt: String = info.risk
	var risk_col := Color(1, 0.5, 0.4) if risk_txt.begins_with("Çok y") else (Color(0.6, 1, 0.6) if risk_txt.ends_with("düşük") else Color(1, 0.9, 0.6))
	_label(_bbox, "Deprem riski: %s" % risk_txt, 15, risk_col)
	for unit in GameData.SERVICES:
		if b.model_name.begins_with(GameData.SERVICES[unit]):
			_label(_bbox, "%s birimi: %d araç (geliştirince +1)" % [GameData.UNIT_NAMES[unit], game.units_total(unit)], 14, Color(0.6, 0.9, 1.0))
	if b.model_name.begins_with("building_townhall"):
		var w := _label(_bbox, "Belediyeyi geliştirmek yeni eylemleri ve güçlendirmeyi açar.", 13, Color(0.6, 0.9, 1.0))
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if b.closed_days > 0:
		_label(_bbox, "İnşaatta: %d gün (bina boş)" % b.closed_days, 14, Color(1, 0.85, 0.4))
	if b.state != Building.State.NORMAL and b.repair_days > 0:
		_label(_bbox, "Kendiliğinden onarılıyor: %d gün" % b.repair_days, 14, Color(1, 0.85, 0.4))
	for txt in [["kacak", "Kaçak kat taşıyıcı sistemi zayıflatır! Hızlı nüfus, büyük risk."],
			["gecekondu", "Ruhsatsız ve dayanıksız. Dere yatağındaysa selde ilk o gider."]]:
		if txt[0] in b.model_name:
			var w := _label(_bbox, txt[1], 13, Color(1, 0.6, 0.45))
			w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for o in options:
		var cost_txt: String = ("+" + GameManager.fmt_money(-o.cost)) if o.cost < 0 else GameManager.fmt_money(o.cost)
		var label: String = "%s  (%s)" % [o.text, cost_txt]
		if o.locked != "":
			label = "%s  [%s]" % [o.text, o.locked]
		var col := Color(0.75, 0.3, 0.25) if o.id == "allow_kacak" else ACCENT
		var btn := _button(_bbox, label, col, 14)
		btn.modulate = Color(1, 1, 1, 0.55) if o.locked != "" else Color.WHITE
		btn.pressed.connect(func():
			_sfx("click")
			building_action.emit(o.id))
	_bpanel.visible = true


func hide_building() -> void:
	_bpanel.visible = false


## Afet uyari bandi (pencere degil): birkac saniye gorunur.
func show_alert(title: String, text: String) -> void:
	_alert.text = title + "\n" + text
	if _alert_tw:
		_alert_tw.kill()
	_alert.modulate.a = 0.0
	_alert_tw = create_tween()
	_alert_tw.tween_property(_alert, "modulate:a", 1.0, 0.25)
	_alert_tw.tween_interval(5.0)
	_alert_tw.tween_property(_alert, "modulate:a", 0.0, 0.8)
	show_message(title + " " + text.replace("\n", " "), "disaster")


## Mudahale bandi: bos birimler ve ipucu.
func show_response(on: bool, game: Node) -> void:
	_response.visible = on
	if not on:
		return
	var parts := []
	for unit in ["rescue", "fire", "medic"]:
		parts.append("%s %d/%d" % [GameData.UNIT_NAMES[unit], game.units_free(unit), game.units_total(unit)])
	_response_label.text = "MÜDAHALE: işaretlere tıklayıp birim gönder\nBoşta: " + "   ".join(parts)


## Afet raporu: kenarda acilan panel (oyunu durdurmaz). modal=true ise kapatilana kadar bekler.
func show_report(r: Dictionary, _game: Node, modal := false) -> void:
	if _report and is_instance_valid(_report):
		_report.queue_free()
	var lines := "[i]%s[/i]\n\n" % r.get("cause", "")
	if r.collapsed > 0:
		lines += "Yıkılan bina: [color=#ff7766]%d[/color]  (2-3 günde onarılır)\n" % r.collapsed
	if r.damaged > 0:
		lines += "Hasar gören bina: [color=#ffcc66]%d[/color]\n" % r.damaged
	if r.burned > 0:
		lines += "Yanan orman: [color=#ff9955]%d hektar[/color]\n" % (r.burned * 4)
	lines += "Kurtarılan: [color=#77ee88]%d[/color]   Can kaybı: [color=#ff7766]%d[/color]\n" % [r.saved, r.casualties]
	if r.evacuated > 0:
		lines += "Toplanma alanına ulaşan: [color=#77ee88]%d kişi[/color]\n" % r.evacuated
	lines += "\n[color=#9fd0ff][b]Biliyor muydunuz?[/b] %s[/color]" % r.tip
	if modal:
		await _modal("Afet Raporu: " + r.title, lines, ["Devam"], Color(0.95, 0.75, 0.3), 600)
		return
	_report = _panel(self, Color(0.07, 0.09, 0.15, 0.94), Color(0.95, 0.75, 0.3))
	_report.position = Vector2(310, 205)
	_report.custom_minimum_size = Vector2(430, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_report.add_child(v)
	_label(v, "Afet Raporu: " + r.title, 20, Color(0.95, 0.75, 0.3))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(400, 0)
	rt.add_theme_font_size_override("normal_font_size", 15)
	rt.add_theme_font_size_override("italics_font_size", 15)
	rt.add_theme_font_size_override("bold_font_size", 15)
	rt.text = lines
	v.add_child(rt)
	var panel := _report
	var close := _button(v, "Tamam", Color(0.3, 0.45, 0.65), 15)
	close.pressed.connect(func():
		_sfx("click")
		if is_instance_valid(panel):
			panel.queue_free())
	get_tree().create_timer(25.0).timeout.connect(func():
		if is_instance_valid(panel):
			panel.queue_free())


# ------------------------------------------------------------------ karar pencereleri
func _modal(title: String, body: String, buttons: Array, accent := ACCENT, width := 560) -> int:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color(0.07, 0.09, 0.15, 0.96), 14, 3, accent, 22))
	p.custom_minimum_size = Vector2(width, 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var t := _label(v, title, 30, accent)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(width - 44, 0)
	rt.add_theme_font_size_override("normal_font_size", 18)
	rt.add_theme_font_size_override("bold_font_size", 18)
	rt.add_theme_font_size_override("italics_font_size", 18)
	rt.text = body
	v.add_child(rt)
	var row: BoxContainer = VBoxContainer.new() if buttons.size() > 2 else HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if row is HBoxContainer:
		row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for i in buttons.size():
		var b := _button(row, buttons[i], accent if i == 0 else Color(0.25, 0.4, 0.6), 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _modal_done.emit(i))
	p.pivot_offset = Vector2(width / 2.0, 120)
	p.scale = Vector2(0.85, 0.85)
	p.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(dim, "color:a", 0.45, 0.25)
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var result: int = await _modal_done
	dim.queue_free()
	return result


func show_intro() -> void:
	await _modal("Afete Hazır Şehir",
		"Belediye başkanı oldun! Şehrin [b]20 gün[/b] boyunca depreme, yangına ve sele hazırlanacak.\n\n" +
		"• Her sabah bir [b]olay kartı[/b] gelir. Kısa vadeli kazanç mı, uzun vadeli güvenlik mi?\n" +
		"• Sağ üstte [b]hava uyarıları[/b] çıkar: önlem al! [b]Deprem ise asla haber vermez.[/b]\n" +
		"• Afet olunca yardım işaretlerine [b]tıklayıp itfaiye, ambulans, AFAD gönder.[/b] Geç kalırsan can kaybı olur.\n" +
		"• Binalara tıkla: geliştir, güçlendir. İtfaiye, hastane ve AFAD geliştikçe birim sayısı artar.\n" +
		"• Gazete ilanı ve tatbikatı bir [b]mahalleye[/b] tıklayarak verirsin. [b]R[/b]: risk haritası.\n\n" +
		"İlk iki gün sakin. Her afetten sonra 2 gün nefes alırsın, sonra risk yeniden artar. 20. gün şehrin en büyük sınavı!",
		["Göreve başla"], ACCENT, 680)


## Olay karti: secilen secenegin indeksini dondurur.
func show_event(ev: Dictionary) -> int:
	var texts: Array = []
	for c in ev.choices:
		texts.append(c.text)
	return await _modal(ev.title, ev.text, texts, Color(0.35, 0.65, 0.95), 600)


func show_decision(title: String, text: String, buttons: Array) -> int:
	return await _modal(title, "[center]" + text + "[/center]", buttons, Color(1.0, 0.32, 0.25), 580)


func show_end(game: Node) -> void:
	var g: Array = game.grade()
	var t: Dictionary = game.totals
	var msg := {"A": "Örnek bir şehir! Halkın bilinçli, binalar sağlam.",
		"B": "Çok iyi! Birkaç eksik dışında şehir afetlere hazırdı.",
		"C": "Fena değil, ama daha fazla hazırlık hayat kurtarırdı.",
		"D": "Şehir zor günler geçirdi. Önlemler geç kaldı.",
		"F": "Hazırlıksız yakalandık. Afetler değil, hazırlıksızlık yıkar."}
	var baseline := int(round(t.baseline))
	var body := "[center][font_size=72][b]%s[/b][/font_size]\nGüvenlik puanı: %d / 100\n\n%s\n\n" % [g[0], g[1], msg[g[0]]]
	body += "[font_size=22]Hiç hazırlık yapmasaydın: [color=#ff7766]~%d can kaybı[/color]\nSenin şehrin: [color=#77ee88]%d can kaybı[/color][/font_size][/center]\n\n" % [baseline, t.casualties]
	body += "Yaşanan afet: %d   Önlenen afet: %d\nKurtarılan: %d   Yıkılan bina: %d\nYanan orman: %d hektar   Son farkındalık: %%%d   Kasa: %s" % [
		t.disasters, t.prevented, t.saved, t.collapsed, t.burned * 4, int(game.awareness), GameManager.fmt_money(game.money)]
	await _modal("20 Gün Tamamlandı", body, ["Yeniden Oyna"], Color(0.4, 0.85, 0.5), 620)
	get_tree().reload_current_scene()
