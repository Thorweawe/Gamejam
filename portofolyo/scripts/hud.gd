extends CanvasLayer
## Oyun arayuzu (kodla kurulur). Yazi tipi: Fredoka (OFL). Ikonlar: UIIcon (kodla cizilir).
##   Sol ust   : para / nufus / farkindalik / belediye seviyesi (degisimler ucan sayilarla)
##   Sol alt   : ekipler (itfaiye, ambulans, AFAD: bosta / toplam)
##   Sag ust   : hava uyarisi karti + kisa bildirimler
##   Sag alt   : Magaza ve Risk haritasi butonlari (Gunu Gec butonu DayCycle'da)
##   Sol       : secili bina karti, afet raporu
##   Harita    : yardim isaretleri (IncidentMarker), haritaya bagli etiketler (world_toast)
##   Orta      : sadece karar pencereleri (olay karti, giris, oyun sonu) ve magaza
##
## Nufus sistemi:
##   Sehrin maksimum nufusu MAX_POP (10.000). Oyun %40 nufusla (4.000) baslar:
##   ilk okunan gercek nufus 4.000'e olceklenir, sonraki degisimler ayni oranla yansir.
##   Nufus %25'in (2.500) altina duserse oyun biter.
##   Basari yuzdesi = nufus orani x farkindalik orani / 100

signal action_pressed(id: String)
signal building_action(id: String)
signal precaution_pressed(id: String)
signal risk_toggled(on: bool)
signal game_over  # nufus %25'in (2.500) altina dustu (GameManager dinleyebilir)
signal _modal_done(result: int)

## Renk paleti oyunun kendi dokusundan (KayKit citybits_texture.png): krem, ten, hardal, turuncu,
## kiremit, sicak kahve, gok mavisi, petrol, cimen yesili. Arayuz haritayla ayni sicak, canli tonlarda.
const C_BG := Color("#fbf3e6f5")  # krem panel
const C_CARD := Color("#fffaf2")  # pencere / kart
const C_LINE := Color("#d9b98f")  # ten rengi kenar
const C_TINT := Color(0.47, 0.4, 0.34, 0.1)  # kahve tonlu hafif zemin (cip, cubuk arka plani)
const C_TEXT := Color("#3b3330")  # koyu kahve yazi
const C_MUTED := Color("#8a7666")
const C_GOLD := Color("#c4851a")  # hardal (para)
const C_GOOD := Color("#12935a")  # cimen yesili
const C_BAD := Color("#d63f3f")
const C_ACCENT := Color("#d76f34")  # turuncu
const C_BLUE := Color("#2b8ac6")
const C_POP := Color("#577893")  # arduvaz mavisi
const KIND_COLORS := {"info": C_BLUE, "good": C_GOOD, "bad": C_BAD, "disaster": Color(1.0, 0.3, 0.25)}
const KIND_ICONS := {"info": "star", "good": "check", "bad": "warning", "disaster": "warning"}
const UNIT_ICONS := {"fire": ["fire", Color("#df4043")], "medic": ["medic", Color("#2799d3")],
	"rescue": ["rescue", Color("#e39a1f")]}
const FORECAST_ICONS := {"forest_fire": "tree", "flood": "wave", "house_fire": "fire"}
const RISK_TEXT := {"fire": "Yangın", "forest": "Orman yangını", "flood": "Sel", "quake": "Deprem"}

const MAX_POP := 10000           # sehrin maksimum nufusu
const START_POP_RATIO := 40.0    # oyun %40 nufusla baslar (4.000)
const MIN_POP_RATIO := 25.0      # bunun alti = oyun biter (2.500 kisi; Nermin ogreticide boyle soyler)
const ARRIVALS_PER_AW := 4       # her yeni gun, farkindaligin her yuzdesi icin gelen kisi (%100 = 400)
const MONEY_PER_AW := 20         # farkindalik 1 puan artinca kasaya +20 TL, azalinca -20 TL
const EMIGRATION_AW := 25        # farkindalik bunun altindaysa her sabah aileler sehri terk eder
const EMIGRATION_PER_AW := 10    # esigin altindaki her puan icin giden kisi (%15 -> 100, %0 -> 250)
const DEATH_FLIGHT := 4.0        # afette olen her kisi icin sehri kalici terk eden (oyun nufusu olcegiyle)
var _warned_exodus := false

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
var _pop_bar: ProgressBar
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
var shop: Node  # shop.tscn ornegi (ilk acilista olusturulur)
var _modal_root: Control
var _world_toasts: Array = []  # [kontrol, dunya konumu, gecen sure, gecikme]
var _actions_enabled := true
var best_streak := 0  # gunun en iyi kurtarma serisi (gun ozeti)
var _streak := 0
var _streak_time := 0
var _flash: ColorRect
var _summary: PanelContainer
var _black: ColorRect
var dialog: DialogPlayer
var _pop_scale := 0.0     # gercek nufus -> oyun nufusu carpani (ilk okumada hesaplanir)
var _game_over := false   # oyun sonu bir kez tetiklensin
var _pop_chip: Control
var _migrants := 0        # farkindalik sayesinde sehre tasinanlar (oyun nufusuna eklenir)
var _arrival_day := 0     # en son hangi gunun gocu islendi
var _last_aw := -1        # para hesabi icin son farkindalik puani (-1 = henuz okunmadi)


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
	dialog = DialogPlayer.new()
	dialog.hud = self
	_root.add_child(dialog)
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
	_theme.set_stylebox("panel", "TooltipPanel", sb(C_CARD, 8, 1, C_LINE, 10, 6))
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
		s.shadow_color = Color(0.25, 0.16, 0.08, 0.28)
		s.shadow_offset = Vector2(0, 3)
	return s


func _panel(parent: Node, color := C_BG, border_color := C_LINE, mh := 12, mv := -1, radius := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(color, radius, 2 if border_color.a > 0 else 0, border_color, mh, mv, 6))
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
	b.add_theme_stylebox_override("disabled", sb(Color("#c9b8a6"), 12, 0, Color.TRANSPARENT, 14, 8))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.95, 0.93, 0.9))
	b.mouse_entered.connect(func(): _sfx("hover"))
	parent.add_child(b)
	return b


## Kodla cizilen ikon + yazi iceren cip.
func _chip(parent: Node, icon: String, text: String, color: Color, size := 14, bg := C_TINT) -> PanelContainer:
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
		# sag ust kose: sol ustteki gostergelerle ust uste binmesin
		clock.add_theme_stylebox_override("panel", sb(C_BG, 16, 2, C_LINE, 14, 4, 6))
		clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		clock.offset_right = -14
		clock.offset_left = -14 - 236
		clock.offset_top = 14
		clock.offset_bottom = 14 + 62
		clock.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		var dl: Label = clock.get_node("HBox/DayLabel")
		dl.add_theme_font_override("font", bold)
		dl.add_theme_font_size_override("font_size", 26)
		dl.add_theme_color_override("font_color", C_TEXT)
		dl.add_theme_constant_override("outline_size", 0)
		var dial: Control = clock.get_node("HBox/Dial")
		dial.custom_minimum_size = Vector2(88, 46)
	var btn: Button = ui.get_node_or_null("EndDayButton")
	if btn:
		var col := Color("#12935a")
		btn.add_theme_font_override("font", bold)
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_stylebox_override("normal", sb(C_BG, 16, 3, col, 16, 8, 6))
		btn.add_theme_stylebox_override("hover", sb(col.lerp(C_CARD, 0.85), 16, 3, col, 16, 8, 6))
		btn.add_theme_stylebox_override("pressed", sb(col.lerp(C_CARD, 0.7), 16, 3, col.darkened(0.15), 16, 8, 6))
		btn.add_theme_stylebox_override("disabled", sb(Color(0.93, 0.9, 0.85, 0.85), 16, 2, C_LINE, 16, 8, 6))
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			btn.add_theme_color_override(k, col.darkened(0.15))
		btn.add_theme_color_override("font_disabled_color", Color("#b3a18f"))
		btn.text = "Günü Bitir"
		for st in ["normal", "hover", "pressed", "disabled"]:
			(btn.get_theme_stylebox(st) as StyleBoxFlat).content_margin_left = 64
		var badge := _panel(btn, col, Color.TRANSPARENT, 7, 7, 13)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.position = Vector2(14, 11)
		_icon(badge, "play", Color.WHITE, 28)
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
	# nufus (yazi + bar)
	p = _panel(row, C_BG, C_LINE, 12, 6)
	_pop_chip = p
	h = _hbox(p, 8)
	_icon(h, "people", C_POP, 26)
	var pv := _vbox(h, 2)
	_pop = _label(pv, "", 15, C_TEXT, true)
	_pop_bar = ProgressBar.new()
	_pop_bar.custom_minimum_size = Vector2(96, 7)
	_pop_bar.show_percentage = false
	_pop_bar.add_theme_stylebox_override("background", sb(C_TINT, 4, 0, Color.TRANSPARENT, 0, 0))
	_pop_bar.add_theme_stylebox_override("fill", sb(C_POP, 4, 0, Color.TRANSPARENT, 0, 0))
	pv.add_child(_pop_bar)
	p.tooltip_text = "Nüfus: vergi geliri getirir\nHer sabah farkındalık × %d kişi taşınır\nFarkındalık %%%d altındaysa aileler şehri terk eder\nAfette ölenlerin yakınları da şehirden gider\n%%%d'nin altına düşerse oyun biter" % [
		ARRIVALS_PER_AW, EMIGRATION_AW, int(MIN_POP_RATIO)]
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
	_aw_bar.add_theme_stylebox_override("background", sb(C_TINT, 4, 0, Color.TRANSPARENT, 0, 0))
	v.add_child(_aw_bar)
	p.mouse_filter = Control.MOUSE_FILTER_STOP


func update_stats(g: Node) -> void:
	_awareness_economy(g)  # once: para ve nufus degisimi asagidaki yazilara yansisin
	_money.text = GameManager.fmt_money(g.money)
	# her biri tum binalari geziyor: bir kez hesapla
	var income: int = g.daily_income()
	var upkeep: int = g.upkeep()
	var repair: int = g.repair_cost_today()
	var net: int = income - upkeep - repair
	_money_sub.text = "%s%s / gün" % ["+" if net >= 0 else "", GameManager.fmt_money(net)]
	_money_sub.add_theme_color_override("font_color", C_MUTED if net >= 0 else C_BAD)
	_money_chip.tooltip_text = "Vergi +%s\nGider -%s\nOnarım -%s" % [GameManager.fmt_money(income),
		GameManager.fmt_money(upkeep), GameManager.fmt_money(repair)]
	var pop := city_pop(g)
	_set_pop(pop)
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
	if shop_open():
		shop.refresh()
	_check_population(g, pop)


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


## Nufus gostergesi: sayi yeni degere sayarak gider, cip yesil / kirmizi parlar ve buyuyup kuculur.
var _shown_pop := -1
var _target_pop := -1
var _pop_tw: Tween


func _set_pop(pop: int) -> void:
	if _shown_pop < 0:
		_shown_pop = pop
		_target_pop = pop
	if pop == _target_pop:
		_pop.text = "%d / %d" % [_shown_pop, MAX_POP]
		_pop_bar.value = pop_ratio(_shown_pop)
		return
	var up := pop > _target_pop
	_target_pop = pop
	if _pop_tw:
		_pop_tw.kill()
	_pop_tw = create_tween()
	_pop_tw.tween_method(_show_pop_value, _shown_pop, pop, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var col := C_GOOD if up else C_BAD
	_pop_chip.add_theme_stylebox_override("panel", sb(col.lerp(C_BG, 0.75), 14, 3, col, 12, 6, 6))
	_pop_chip.pivot_offset = _pop_chip.size / 2.0
	var pulse := _pop_chip.create_tween()
	pulse.tween_property(_pop_chip, "scale", Vector2(1.12, 1.12), 0.15).set_trans(Tween.TRANS_BACK)
	pulse.tween_property(_pop_chip, "scale", Vector2.ONE, 0.3)
	pulse.tween_interval(1.0)
	pulse.tween_callback(func(): _pop_chip.add_theme_stylebox_override("panel", sb(C_BG, 14, 2, C_LINE, 12, 6, 6)))


func _show_pop_value(v: int) -> void:
	_shown_pop = v
	_pop.text = "%d / %d" % [v, MAX_POP]
	_pop_bar.value = pop_ratio(v)


## Haritada da gorunsun: tasinanlar sehre giren araclarla gelir, gidenler sehirden cikar.
func _show_migration(n: int) -> void:
	if game == null or n == 0:
		return
	var tr: Node = game.city.traffic
	var keys: Array = tr.road.keys().filter(func(k): return not tr.dirt.has(k))
	if keys.is_empty():
		return
	keys.sort_custom(func(a, b): return Vector2(a).length() < Vector2(b).length())
	var inner: Array = keys.slice(0, keys.size() / 3)
	var outer: Array = keys.slice(keys.size() * 2 / 3)
	var cars := clampi(absi(n) / 15, 2, 8)
	if n > 0:
		tr.temp_cars(outer, inner, cars)
		toast("Şehre %d kişi taşındı · güvenli şehir göç alıyor" % n, "good")
	else:
		tr.temp_cars(inner, outer, cars)
		toast("%d kişi şehri terk etti" % -n, "bad")


func _float_from(c: Control, text: String, color: Color) -> void:
	var l := _label(_root, text, 22, color, true)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(1, 0.98, 0.94, 0.95))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = c.global_position + Vector2(c.size.x * 0.3, c.size.y + 2)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y + 34, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(1.1)
	tw.chain().tween_callback(l.queue_free)


# ------------------------------------------------------------------ nufus orani ve basari yuzdesi
## Oyun nufusu: gercek nufus, oyun basinda MAX_POP'un %40'ina (4.000) denk gelecek sekilde olceklenir.
## Ornek: gercek baslangic 1.200 ise carpan 4000/1200 = 3.33; nufus 900'e duserse oyun nufusu 3.000 (%30) olur.
func city_pop(g: Node) -> int:
	var real: int = g.population()
	if _pop_scale <= 0.0:
		if real <= 0:
			return 0  # harita henuz yuklenmedi
		_pop_scale = MAX_POP * START_POP_RATIO / 100.0 / float(real)
	return clampi(int(round(real * _pop_scale)) + _migrants, 0, MAX_POP)


## Farkindalik ekonomisi (update_stats her cagrildiginda; degisim yoksa hicbir sey yapmaz):
##  - Kasa: farkindalik puani her degistiginde (puan farki) x MONEY_PER_AW TL eklenir / dusulur.
##    Ornek: %20 -> %40 = +400 TL, %40 -> %35 = -100 TL. Tam puanlar kullanilir: kucuk ondalik
##    oynamalar para yazmaz, toplam her zaman (son puan - ilk puan) x 20 olur.
##  - Goc: her yeni gun bir kez, o anki farkindalik x ARRIVALS_PER_AW kisi sehre tasinir (%20 = 80 kisi).
func _awareness_economy(g: Node) -> void:
	var aw := int(g.awareness)
	if _last_aw < 0:
		_last_aw = aw  # ilk okuma: baslangic farkindaligi para yazmaz
	elif aw != _last_aw:
		var gain := (aw - _last_aw) * MONEY_PER_AW
		_last_aw = aw
		var before: int = g.money
		g.money = maxi(0, g.money + gain)  # kasa eksiye dusmez
		money_delta(g.money - before)
	if g.day != _arrival_day and _pop_scale > 0.0:
		_arrival_day = g.day
		var n := aw * ARRIVALS_PER_AW
		# guvensiz sehirden goc: farkindalik EMIGRATION_AW altindaysa aileler sehri terk eder
		var leave := maxi(0, EMIGRATION_AW - aw) * EMIGRATION_PER_AW if g.day > 1 else 0
		_migrants += n - leave
		if n - leave != 0:
			_float_from(_pop_chip, "%+d kişi" % (n - leave), C_GOOD if n >= leave else C_BAD)
			_show_migration.call_deferred(n - leave)
		if leave > n and not _warned_exodus:
			_warned_exodus = true
			toast("Halk kendini güvende hissetmiyor: farkındalık %%%d altındayken aileler şehri terk ediyor!" % EMIGRATION_AW, "bad")


## Karar kartindan gelen nufus degisimi (oyun nufusu biriminde: + tasinan, - giden aileler).
func add_residents(n: int) -> void:
	if n == 0:
		return
	_migrants += n
	_float_from(_pop_chip, "%+d kişi" % n, C_GOOD if n > 0 else C_BAD)
	_show_migration.call_deferred(n)


## Afette olen her kisi icin ailesi ve korkan komsulari da sehri terk eder (kalici nufus kaybi;
## yikilan binalar onarilir ama giden insan geri gelmez).
func lose_residents(casualties: int) -> int:
	if casualties <= 0 or _pop_scale <= 0.0:
		return 0
	var n := int(round(casualties * _pop_scale * DEATH_FLIGHT))
	_migrants -= n
	_float_from(_pop_chip, "-%d kişi" % n, C_BAD)
	_show_migration.call_deferred(-n)
	return n


## Gercek nufus -> oyun nufusu carpani (rapor hesaplari icin).
func pop_scale() -> float:
	return _pop_scale


## Nufus orani: 0-100 (10.000 nufus = %100)
static func pop_ratio(pop: int) -> float:
	return clampf(float(pop) / float(MAX_POP) * 100.0, 0.0, 100.0)


## Basari yuzdesi = nufus orani x farkindalik orani / 100
static func success_rate(pop: int, awareness: float) -> float:
	var p := pop_ratio(pop)
	var a := clampf(awareness, 0.0, 100.0)
	return p * a / 100.0


## Nufus %25'in (2.500) altina duserse oyun biter (mevcut oyun sonu penceresi acilir).
func _check_population(g: Node, pop: int) -> void:
	if _game_over or _pop_scale <= 0.0:
		return
	if pop_ratio(pop) < MIN_POP_RATIO:
		_game_over = true
		_end_by_population.call_deferred(g)


func _end_by_population(g: Node) -> void:
	# acik bir karar penceresi varsa (olay karti, rapor) kapanmasini bekle
	while _modal_root.get_child_count() > 0:
		await get_tree().process_frame
	close_shop()
	hide_building()
	if _pause:
		_close_pause()
	get_tree().paused = true  # afetler ve zaman dursun (HUD calismaya devam eder)
	game_over.emit()
	await show_end(g, true)


# ------------------------------------------------------------------ sol alt: ekipler
func _build_units() -> void:
	_units_panel = _panel(_root, C_BG, C_LINE, 12, 8)
	_units_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_units_panel.offset_left = 14
	_units_panel.offset_bottom = -14
	_units_panel.offset_top = -64
	_units_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var h := _hbox(_units_panel, 12)
	var cap := _label(h, "EKİPLER", 12, C_MUTED, true)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for unit in ["fire", "medic", "rescue"]:
		var u := _hbox(h, 6)
		var badge := _panel(u, UNIT_ICONS[unit][1], Color.TRANSPARENT, 5, 5, 12)
		_icon(badge, UNIT_ICONS[unit][0], Color.WHITE, 20)
		_units[unit] = _label(u, "", 18, C_TEXT, true)
		_units[unit].size_flags_vertical = Control.SIZE_SHRINK_CENTER
		u.tooltip_text = "%s: boşta / toplam araç. Binasını geliştirince +1" % GameData.UNIT_NAMES[unit]
		u.mouse_filter = Control.MOUSE_FILTER_STOP


# ------------------------------------------------------------------ sag: uyari + bildirimler
func _build_right() -> void:
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 8)
	_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_right.offset_left = -344
	_right.offset_right = -14
	_right.offset_top = 86  # saatin altinda
	_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_right)
	_forecast = _panel(_right, C_CARD, C_ACCENT, 14, 12)
	_forecast.visible = false
	_toasts = _vbox(_right, 6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Kisa bildirim (en fazla 3, 4 sn).
func toast(text: String, kind := "info") -> void:
	var col: Color = KIND_COLORS.get(kind, C_TEXT)
	var p := _panel(_toasts, C_CARD, Color(col.r, col.g, col.b, 0.35), 10, 7, 10)
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


func show_forecast(type: String, title: String, text: String, actions: Array) -> void:
	for c in _forecast.get_children():
		c.queue_free()
	var v := _vbox(_forecast, 8)
	var h := _hbox(v, 10)
	var badge := _panel(h, Color(1.0, 0.55, 0.15), Color.TRANSPARENT, 6, 6, 20)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_icon(badge, FORECAST_ICONS.get(type, "warning"), Color.WHITE, 26)
	var tv := _vbox(h, 0)
	_label(tv, title.to_upper(), 12, C_ACCENT, true)
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
	if game and game.money < before:
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
	_shop_btn = _chip_button(row, "shop", "Mağaza", Color("#d76f34"))
	_shop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_btn.pressed.connect(func():
		_sfx("click")
		open_shop())
	_risk_btn = _chip_button(row, "map", "Risk", Color("#577893"))
	_risk_btn.custom_minimum_size.x = 104
	_risk_btn.toggle_mode = true
	_risk_btn.toggled.connect(func(on):
		_sfx("click")
		risk_toggled.emit(on))
	_risk_btn.tooltip_text = "Risk haritası (R): kırmızı binalar depremde en tehlikeli olanlar"
	var gear := _chip_button(_root, "gear", "", Color("#577893"))
	gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	gear.offset_right = -262
	gear.offset_left = -262 - 62
	gear.offset_top = 14
	gear.offset_bottom = 76
	gear.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	gear.tooltip_text = "Ayarlar: ses, müzik, efektler, tam ekran (ESC: menü)"
	gear.pressed.connect(func():
		_sfx("click")
		open_settings())


## HUD kartlariyla ayni tarz buton: krem zemin, ten rengi kenar, golge, renkli rozet icinde beyaz ikon,
## koyu kahve kalin yazi. Uzerine gelince / basiliyken kenar rozetin rengini alir.
func _chip_button(parent: Node, icon: String, text: String, color: Color, size := 16) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(62, 62)
	b.add_theme_stylebox_override("normal", sb(C_BG, 14, 2, C_LINE, 10, 6, 6))
	b.add_theme_stylebox_override("hover", sb(C_CARD, 14, 2, color, 10, 6, 6))
	b.add_theme_stylebox_override("pressed", sb(color.lerp(C_CARD, 0.82), 14, 3, color, 10, 6, 6))
	b.add_theme_stylebox_override("hover_pressed", sb(color.lerp(C_CARD, 0.78), 14, 3, color, 10, 6, 6))
	b.add_theme_stylebox_override("disabled", sb(Color(0.93, 0.9, 0.85, 0.85), 14, 2, C_LINE, 10, 6, 6))
	b.mouse_entered.connect(func(): _sfx("hover"))
	parent.add_child(b)
	var h := _hbox(b, 8)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := _panel(h, color, Color.TRANSPARENT, 6, 6, 12)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon(badge, icon, Color.WHITE, 24)
	if text != "":
		var l := _label(h, text, size, C_TEXT, true)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.set_meta("label", l)
	b.set_meta("badge", badge)
	return b


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
	_shop_btn.modulate = Color.WHITE if on else Color(1, 1, 1, 0.6)
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

	_response = _panel(_root, C_CARD, Color(1, 0.45, 0.35, 0.8), 16, 8, 20)
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

	_hint = _panel(_root, C_CARD, Color(1, 0.85, 0.4, 0.6), 16, 8, 20)
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
	_label(v, text, 16, Color(1, 1, 1, 0.92))
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
		if _streak >= 3 and game:
			game.bark_once("streak")
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


## Ogretici odagi: arayuz parcasinin ekrandaki dikdortgeni.
func target_rect(name: String) -> Rect2:
	var c: Control = null
	match name:
		"money":
			c = _money_chip
		"pop":
			c = _pop_chip
		"aw":
			c = _aw_chip
		"shop":
			c = _shop_btn
		"risk":
			c = _risk_btn
		"units":
			c = _units_panel
		"endday":
			c = get_node_or_null("../UI/EndDayButton")
		"clock":
			c = get_node_or_null("../UI/ClockPanel")
		"forecast_area":
			# uyari paneli saatin altinda (_build_right: offset_top 86); panel gizliyken de o alani goster
			if _forecast and _forecast.is_visible_in_tree():
				return _forecast.get_global_rect()
			var vp := _root.size
			return Rect2(vp.x - 344, 86, 330, 130)
	if c == null or not c.is_visible_in_tree():
		return Rect2()
	return c.get_global_rect()


## Ogretici odagi: anlatilan dugme oyun mesgulken devre disi (gri, yari saydam) gorunuyordu.
## Odak suresince tam gorunur yapilir; tiklama yine de gecmez (diyalog katmani fareyi tutar,
## Gunu Bitir zaten DayCycle.locked ile korunur). "" = onceki hedefi eski haline dondur.
var _lit: Control
var _lit_state := {}


func tutorial_highlight(name: String) -> void:
	if _lit and is_instance_valid(_lit):
		_lit.modulate = _lit_state.modulate
		if _lit is BaseButton:
			(_lit as BaseButton).disabled = _lit_state.disabled
		if _lit == _shop_btn:
			set_actions_enabled(_actions_enabled)  # magaza dugmesi kendi durumuna
	_lit = null
	var c: Control = {"shop": _shop_btn, "risk": _risk_btn, "endday": get_node_or_null("../UI/EndDayButton"),
		"money": _money_chip, "pop": _pop_chip, "aw": _aw_chip, "units": _units_panel}.get(name)
	if c == null:
		return
	_lit = c
	_lit_state = {"modulate": c.modulate, "disabled": (c as BaseButton).disabled if c is BaseButton else false}
	c.modulate = Color.WHITE
	if c is BaseButton:
		(c as BaseButton).disabled = false


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


## Gun ozeti: sabah, ekranin tam ortasinda; "Devam" ile kapanir (sonra gunun karar karti gelir).
func show_day_summary(d: Dictionary) -> void:
	await _modal("Gün %d Özeti" % d.day, "star", C_BLUE, 480, _fill_summary.bind(d), ["Devam"])


func _fill_summary(v: VBoxContainer, _w: int, d: Dictionary) -> void:
	var rows := _vbox(v, 8)
	var dm: int = d.money1 - d.money0
	_summary_row(rows, "coin", "Kasa", "%s  (%s%s)" % [GameManager.fmt_money(d.money1), "+" if dm >= 0 else "", GameManager.fmt_money(dm)],
		C_GOLD if dm >= 0 else C_BAD)
	if d.has("pop0"):
		var dp: int = d.pop1 - d.pop0
		_summary_row(rows, "people", "Nüfus", "%d  (%s%d)" % [d.pop1, "+" if dp >= 0 else "", dp], C_GOOD if dp >= 0 else C_BAD)
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
		_summary_row(rows, "shop", "Yatırımlar", "Dün yatırım yapılmadı", C_MUTED)
	var foot := _panel(v, C_TINT, Color.TRANSPARENT, 12, 8, 10)
	var fh := _hbox(foot, 8)
	_icon(fh, "coin", C_GOLD, 16)
	_label(fh, "Bu sabah kasaya: %s%s" % ["+" if d.next >= 0 else "", GameManager.fmt_money(d.next)], 14, C_TEXT, true)
	if d.warning != "":
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fh.add_child(sp)
		_icon(fh, "warning", C_ACCENT, 16)
		_label(fh, d.warning, 14, C_ACCENT, true)


func _summary_row(parent: Node, icon: String, caption: String, value: String, color: Color) -> void:
	var h := _hbox(parent, 10)
	_icon(h, icon, color, 18)
	var c := _label(h, caption, 14, C_MUTED)
	c.custom_minimum_size.x = 100
	var l := _label(h, value, 15, color, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 250


func hide_day_summary() -> void:
	pass


## Haritadaki bir noktaya bagli, yukari suzulen etiket (ornek: "AVM", "Güçlendiriliyor").
func world_toast(pos: Vector3, text: String, color: Color, icon := "", delay := 0.0) -> void:
	if pos == Vector3.INF:
		return
	if color.get_luminance() > 0.55:  # acik renk krem zeminde okunmaz: koyulastir
		color = color.darkened(0.42)
	var p := _panel(_markers, C_CARD, Color(color.r, color.g, color.b, 0.8), 10, 5, 12)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := _hbox(p, 6)
	if icon != "":
		_icon(h, icon, color, 18)
	_label(h, text, 15, color, true)
	p.modulate.a = 0.0
	p.visible = false
	_world_toasts.append([p, pos, 0.0, delay])


## Mahalle kartlari: haritaya bagli, krem zeminli okunakli etiket + farkindalik cubugu.
var _district_tags: Array = []  # [kart, dunya konumu]


func district_tags(items: Array) -> void:
	if items.size() != _district_tags.size():
		for t in _district_tags:
			t[0].queue_free()
		_district_tags.clear()
		for it in items:
			var p := _panel(_markers, C_CARD, C_LINE, 12, 6, 12)
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var v := _vbox(p, 2)
			_label(v, "", 16, C_TEXT, true)
			var row := _hbox(v, 6)
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(70, 7)
			bar.show_percentage = false
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.add_theme_stylebox_override("background", sb(C_TINT, 4, 0, Color.TRANSPARENT, 0, 0))
			row.add_child(bar)
			_label(row, "", 13, C_MUTED, true)
			_label(v, "", 13, C_GOLD, true)
			_district_tags.append([p, Vector3.ZERO])
	for i in items.size():
		var it: Dictionary = items[i]
		var p: PanelContainer = _district_tags[i][0]
		_district_tags[i][1] = it.pos
		var v := p.get_child(0)
		var aw: float = it.aw
		var col := C_BAD.lerp(C_GOLD, clampf(aw / 50.0, 0, 1)).lerp(C_GOOD, clampf((aw - 50.0) / 50.0, 0, 1))
		(v.get_child(0) as Label).text = it.name
		var bar := v.get_child(1).get_child(0) as ProgressBar
		bar.value = aw
		bar.add_theme_stylebox_override("fill", sb(col, 4, 0, Color.TRANSPARENT, 0, 0))
		var awl := v.get_child(1).get_child(1) as Label
		awl.text = "Farkındalık %%%d" % int(aw)
		awl.add_theme_color_override("font_color", col.darkened(0.2))
		var extra := v.get_child(2) as Label
		extra.visible = it.extra != ""
		extra.text = it.extra
		extra.add_theme_color_override("font_color", C_GOLD.darkened(0.1) if it.extra_ok else C_BAD)
		p.reset_size()
	_place_district_tags()


func _place_district_tags() -> void:
	if _district_tags.is_empty() or game == null:
		return
	var cam: Camera3D = game.city.camera_rig.camera
	var placed: Array[Rect2] = []
	var order := range(_district_tags.size())
	order.sort_custom(func(a, b): return cam.unproject_position(_district_tags[a][1]).y < cam.unproject_position(_district_tags[b][1]).y)
	for i in order:
		var p: PanelContainer = _district_tags[i][0]
		p.visible = not cam.is_position_behind(_district_tags[i][1])
		var r := Rect2(cam.unproject_position(_district_tags[i][1]) - p.size / 2.0, p.size)
		# ust uste binen kart asagi kayar (kartlar haritada sabit yerine yakin kalir)
		for _k in 4:
			var moved := false
			for q in placed:
				if r.grow(3).intersects(q):
					r.position.y = q.end.y + 4
					moved = true
			if not moved:
				break
		placed.append(r)
		p.position = r.position


func _process(delta: float) -> void:
	_place_district_tags()
	if game == null or _world_toasts.is_empty():
		return
	var cam: Camera3D = game.city.camera_rig.camera
	# sondan basa: her karede dizi kopyalamadan silinebilsin
	for idx in range(_world_toasts.size() - 1, -1, -1):
		var item: Array = _world_toasts[idx]
		var p: PanelContainer = item[0]
		item[3] -= delta
		if item[3] > 0.0:
			continue
		var first: bool = item[2] == 0.0
		item[2] += delta
		var t: float = item[2]
		var life := 3.2
		if t > life or not is_instance_valid(p):
			_world_toasts.remove_at(idx)
			if is_instance_valid(p):
				p.queue_free()
			continue
		p.visible = not cam.is_position_behind(item[1])
		var sp := cam.unproject_position(item[1])
		if first or p.size.x < 1.0:
			p.reset_size()  # yazi sabit: boyut bir kez hesaplanir
		p.position = sp - Vector2(p.size.x / 2.0, p.size.y + 10.0 + t * 14.0)
		p.modulate.a = clampf(t * 5.0, 0.0, 1.0) * clampf((life - t) * 2.0, 0.0, 1.0)


# ------------------------------------------------------------------ magaza (shop.tscn: ekip arkadaslarimizin arayuzu)
func open_shop() -> void:
	if not _actions_enabled or game == null:
		return
	if shop == null:
		shop = (load("res://scenes/shop.tscn") as PackedScene).instantiate()
		get_parent().add_child(shop)
		await get_tree().process_frame
	shop.open()


func close_shop() -> void:
	if shop and is_instance_valid(shop):
		shop.close()


func shop_open() -> bool:
	return shop != null and is_instance_valid(shop) and shop.is_open()


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
		_chip(chips, "people", str(b.population()), C_POP, 13)
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
		var tip := _label(v, "İpucu: Mağaza › Hazırlık › Deprem'de tüm mahalle %50 ucuz", 12, C_BLUE)
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
	b.custom_minimum_size = Vector2(0, 52 if locked else 40)  # kilitliyse neden ikinci satirda
	b.clip_contents = true
	var h := _hbox(b, 8)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -12
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		_icon(h, "lock", C_MUTED, 16)
	var tv := _vbox(h, -2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(tv, o.text, 15, Color.WHITE if not locked else Color(0.9, 0.9, 0.92), true)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	if locked:
		var why := _label(tv, o.locked, 12, Color(1.0, 0.82, 0.5), true)
		why.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		why.clip_text = true
	else:
		var price := _label(h, ("+" if gain else "") + GameManager.fmt_money(absi(o.cost)), 14,
			C_GOOD if gain else C_GOLD, true)
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
	var card := _panel(holder, C_CARD, Color(accent.r, accent.g, accent.b, 0.7), 16, 14, 16)
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
	# nufus neden dustu: can kaybi gercek kisi; nufus gostergesindeki dusus evsizler + sehri terk edenler
	var homeless: int = r.get("homeless", 0)
	var fled: int = r.get("fled", 0)
	if homeless + fled > 0:
		var np := _panel(v, Color(0.85, 0.3, 0.25, 0.08), Color(0.85, 0.3, 0.25, 0.25), 10, 8, 10)
		var nh := _hbox(np, 8)
		_icon(nh, "people", C_BAD, 20)
		var nv := _vbox(nh, 2)
		_label(nv, "Nüfus -%d" % (homeless + fled), 15, C_BAD, true)
		var lines := []
		if homeless > 0:
			lines.append("%d kişi evsiz kaldı (binalar onarılınca geri döner)" % homeless)
		if fled > 0:
			lines.append("%d kişi şehri terk etti (kaybedilenlerin yakınları)" % fled)
		for t in lines:
			var nl := _label(nv, t, 12, C_MUTED)
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.custom_minimum_size.x = card.custom_minimum_size.x - 80
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
	var tip := _label(th, r.tip, 13, C_BLUE.darkened(0.2))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size.x = card.custom_minimum_size.x - 70
	var close := _button(v, "Devam" if modal else "Tamam", Color("#577893"), 15)
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
	var p := _panel(parent, C_TINT, Color.TRANSPARENT, 10, 6, 10)
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
	var card := _panel(center, C_CARD, Color(accent.r, accent.g, accent.b, 0.6), 24, 20, 20)
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
			var b := _button(row, buttons[i], accent if i == 0 else Color("#577893"), 18)
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




## Olay karti: karti sunan karakter solda (iliskiye gore yuz ifadesi + selam), sagda uc secenek.
## Sonuclar secimden once gizli (sadece maliyet yazar); secince yesil ++ / kirmizi -- sonuc listesi
## cikar, karakter tepki verir, oyuncu Devam'a basinca kart kapanir. Doner: secilen indeks.
func show_event(ev: Dictionary, rel := 0) -> int:
	var dim := _dim()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var sp: Array = Characters.EVENT_SPEAKERS.get(ev.id, [])
	var who: String = sp[0] if not sp.is_empty() else ""
	var accent: Color = Characters.info(who).color if who != "" else Color(0.4, 0.68, 1.0)
	var card := _panel(center, C_CARD, Color(accent.r, accent.g, accent.b, 0.5), 22, 18, 20)
	var row := _hbox(card, 18)
	var portrait: Portrait = null
	var bubble_text: Label = null
	var hearts: Control = null
	if who != "":
		var left := _vbox(row, 6)
		var frame := _panel(left, Color(accent.r, accent.g, accent.b, 0.12), Color(accent.r, accent.g, accent.b, 0.35), 0, 0, 16)
		portrait = Portrait.new()
		portrait.custom_minimum_size = Vector2(190, 230)
		frame.add_child(portrait)
		portrait.setup(who, Characters.mood_for(rel))
		var info := Characters.info(who)
		var nm := _label(left, info.name, 16, C_TEXT, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.custom_minimum_size.x = 190
		var tl := _label(left, info.title, 12, C_MUTED)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.custom_minimum_size.x = 190
		hearts = _relation_hearts(rel)
		left.add_child(hearts)
	var v := _vbox(row, 12)
	v.custom_minimum_size.x = 540
	var head := _hbox(v, 12)
	var tv := _vbox(head, -2)
	_label(tv, "GÜNÜN KARARI", 12, accent, true)
	_label(tv, ev.title, 26, C_TEXT, true)
	if portrait:
		var bubble := _panel(v, Color(accent.r, accent.g, accent.b, 0.14), Color(accent.r, accent.g, accent.b, 0.4), 14, 8, 12)
		bubble_text = _label(bubble, "", 16, C_TEXT, true)
		bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bubble_text.custom_minimum_size.x = 500
	_text(v, ev.text, 540, 16, C_MUTED)
	var choices := _vbox(v, 10)
	# parasi yetmeyen secenek kilitli (kasa eksiye dusmesin); hepsi yetmiyorsa en ucuzu acik kalir
	var costs := []
	for c in ev.choices:
		costs.append(maxi(0, -int(c.effects.get("money", 0))))
	var money: int = game.money if game else 0
	var cheapest := costs.find(costs.min())
	for i in ev.choices.size():
		_choice_card(choices, ev.choices[i], i, costs[i] > money and i != cheapest)
	_pop_in(card, dim)
	if portrait:
		portrait.figure.gesture("wave" if rel >= 0 else "angry")
		dialog.say(portrait, Characters.greet(who, rel), bubble_text)
	var result: int = await _modal_done
	# secilmeyenler kaybolur, secilen kalir; altinda sonuc listesi (yesil ++ / kirmizi --)
	choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in choices.get_children():
		if c.get_index() != result:
			var tw := c.create_tween()
			tw.tween_property(c, "modulate:a", 0.0, 0.2)
			tw.tween_callback(c.hide)
	var delta: int = sp[1][result] if sp.size() > 1 and result < sp[1].size() else 0
	await get_tree().create_timer(0.25).timeout
	_result_list(v, ev.choices[result].effects, who, delta)
	# karakterin tepkisi
	if portrait and delta != 0:
		var reaction := Characters.react(who, delta, rel)
		portrait.figure.set_mood(reaction.get("mood", "happy" if delta > 0 else "angry"))
		portrait.figure.gesture("jump" if delta > 0 else "angry")
		_pop_hearts(hearts, delta)
		await dialog.say(portrait, reaction, bubble_text, 55.0)
	# oyuncu sonuclari okusun: Devam'a basinca kart kapanir
	var ok := _button(v, "Devam  ›", accent.darkened(0.15), 17)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.custom_minimum_size = Vector2(160, 44)
	await ok.pressed
	_sfx("click")
	dim.queue_free()
	return result


## Secimin sonuclari: iyiler yesil "++", kotuler kirmizi "--", notr / ileride cikacaklar gri.
## Karar kartinda secimden ONCE gosterilmez (oyuncu ne olacagini bilmeden karar verir).
func _result_list(parent: Node, fx: Dictionary, who: String, rel_delta: int) -> void:
	var box := _panel(parent, Color(1, 1, 1, 0.55), C_LINE, 14, 12, 10)
	var col := _vbox(box, 4)
	_label(col, "SONUÇ", 12, C_MUTED, true)
	var lines := effect_lines(fx)
	if who != "" and rel_delta != 0:
		lines.append(["%s seni %s" % [Characters.info(who).get("short", who), "sevdi" if rel_delta > 0 else "hiç sevmedi"],
			1 if rel_delta > 0 else -1])
	for i in lines.size():
		var kind: int = lines[i][1]
		var color: Color = C_GOOD if kind > 0 else (C_BAD if kind < 0 else C_MUTED)
		var mark: String = "++" if kind > 0 else ("--" if kind < 0 else "•")
		var l := _label(col, "%s  %s" % [mark, lines[i][0]], 17, color, true)
		l.modulate.a = 0.0
		l.create_tween().tween_property(l, "modulate:a", 1.0, 0.25).set_delay(0.12 * i)
	box.modulate.a = 0.0
	box.create_tween().tween_property(box, "modulate:a", 1.0, 0.2)
	_sfx("popup")


## Etki sozlugu -> [yazi, tur] (tur: 1 iyi, -1 kotu, 0 notr).
static func effect_lines(fx: Dictionary) -> Array:
	var out := []
	for k in fx:
		var v = fx[k]
		match k:
			"money":
				out.append(["Kasa %s%s" % ["+" if int(v) > 0 else "", GameManager.fmt_money(int(v))], 1 if int(v) > 0 else -1])
			"awareness":
				out.append(["Farkındalık %+d" % int(v), 1 if float(v) > 0 else -1])
			"pop":
				out.append(["Nüfus %+d kişi" % int(v), 1 if int(v) > 0 else -1])
			"risk_fire", "risk_forest", "risk_flood", "risk_quake":
				pass  # afet riski oyuncuya soylenmez: belirsizlik kalsin
			"kacak":
				out.append(["%d binaya kaçak kat çıktı" % int(v), -1])
			"river_site":
				out.append(["Dere yatağına %d bina yapıldı" % int(v), -1])
			"reinforce":
				out.append(["%d bina güçlendirildi" % int(v), 1])
			"upgrade":
				out.append(["%d gecekondu yenilendi" % int(v), 1])
			"upgrade_service":
				out.append(["%s gelişti (+1 araç)" % GameData.UNIT_NAMES.get(v, "Birim"), 1])
			"kits":
				out.append(["Deprem çantaları dağıtıldı", 1])
			"drills":
				out.append(["Tatbikat yapıldı", 1])
			"assembly":
				out.append(["Toplanma alanı %+d" % int(v), 1 if int(v) > 0 else -1])
			"build":
				out.append(["Haritada yeni yapı: " + str(v.get("label", "yapı")), 0])
			"later":
				out.append(["Bu kararın sonucu birkaç gün sonra ortaya çıkabilir...", 0])
	if out.is_empty():
		out.append(["Hiçbir şey değişmedi", 0])
	return out


## Iliski gostergesi: 5 kalp (-3..+3 araligini 0..5 dolu kalbe cevirir).
func _relation_hearts(rel: int) -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 3)
	h.custom_minimum_size.x = 190
	h.set_meta("rel", rel)
	_fill_hearts(h, rel)
	return h


func _fill_hearts(h: Control, rel: int) -> void:
	for c in h.get_children():
		c.queue_free()
	var full := clampi(rel + 3, 0, 6)  # 0..6 -> yarim kalpler
	for i in 3:
		var ic := UIIcon.new()
		ic.kind = "heart"
		var amount := clampi(full - i * 2, 0, 2)
		ic.color = [Color(0.47, 0.4, 0.34, 0.22), Color(1.0, 0.55, 0.6, 0.7), Color(0.9, 0.3, 0.38)][amount]
		ic.custom_minimum_size = Vector2(18, 18)
		h.add_child(ic)


func _pop_hearts(h: Control, delta: int) -> void:
	var rel: int = clampi(int(h.get_meta("rel", 0)) + delta, -3, 3)
	h.set_meta("rel", rel)
	_fill_hearts(h, rel)
	h.pivot_offset = h.size / 2.0
	var tw := h.create_tween()
	tw.tween_property(h, "scale", Vector2(1.3, 1.3), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(h, "scale", Vector2.ONE, 0.2)


func _choice_card(parent: Node, choice: Dictionary, index: int, locked := false) -> void:
	var normal := sb(C_TINT, 14, 1, C_LINE, 14, 10)
	var hover := sb(Color(0.17, 0.54, 0.78, 0.14), 14, 2, C_BLUE, 14, 10)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", normal)
	parent.add_child(p)
	var v := _vbox(p, 6)
	var h := _hbox(v, 10)
	var num := _panel(h, C_TINT, Color.TRANSPARENT, 8, 1, 8)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label(num, str(index + 1), 14, C_MUTED, true)
	var t := _label(h, choice.text, 17, C_TEXT, true)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	v.add_child(flow)
	# sonuclar secimden once gizli; sadece maliyeti belli olan secenekte fiyat yazar
	var cost := -int(choice.effects.get("money", 0))
	if cost > 0:
		_chip(flow, "coin", "Maliyet: " + GameManager.fmt_money(cost), C_GOLD, 13, Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.12))
	for c in p.find_children("*", "Control", true, false):
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		_chip(flow, "lock", "Bütçe yetersiz", C_BAD, 13, Color(C_BAD.r, C_BAD.g, C_BAD.b, 0.12))
		p.modulate = Color(1, 1, 1, 0.55)
		p.tooltip_text = "Kasada bu seçenek için yeterli para yok"
		return
	_clickable(p, func():
		_sfx("click")
		_modal_done.emit(index))
	p.mouse_entered.connect(func():
		p.add_theme_stylebox_override("panel", hover)
		_sfx("hover"))
	p.mouse_exited.connect(func(): p.add_theme_stylebox_override("panel", normal))


## Oyun sonu. failed = true ise nufus %25'in altina dustugu icin erken bitti (sadece baslik degisir).
func show_end(g: Node, failed := false) -> void:
	_game_over = true  # normal bitiste nufus kontrolu artik tetiklenmesin
	var gr: Array = g.grade()
	var col: Color = {"A": C_GOOD, "B": Color(0.6, 0.9, 0.4), "C": C_GOLD, "D": C_ACCENT, "F": C_BAD}[gr[0]]
	var title := "Şehir Boşaldı" if failed else "20 Gün Tamamlandı"
	var choice: int = await _modal(title, "warning" if failed else "star", C_BAD if failed else col, 640,
		_fill_end.bind(g, gr, col, failed), ["Yeniden Oyna", "Ana Menü"])
	get_tree().paused = false
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
		# ayarlar acik: kontroller sayfasindaysa ayarlara don, degilse kapat
		var panel := _pause.find_children("*", "SettingsPanel", true, false)
		if not panel.is_empty() and panel[0]._controls and panel[0]._controls.visible:
			panel[0]._show_controls(false)
		else:
			_sfx("click")
			_close_pause()
	elif shop_open():
		close_shop()
	elif _modal_root.get_child_count() == 0:
		open_settings()  # ESC = ayarlar (ayri duraklatma menusu yok)


func _close_pause() -> void:
	if _pause:
		_pause.queue_free()
		_pause = null
	get_tree().paused = false


## Oyun ici ayarlar (disli butonu ya da ESC): oyun durur; "Tamam" ya da ESC ile devam.
func open_settings() -> void:
	if _pause or get_tree().paused:
		return
	_sfx("click")
	get_tree().paused = true
	var holder := ColorRect.new()
	_pause = holder
	holder.color = Color(0.1, 0.06, 0.03, 0.45)
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(holder)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(center)
	var panel := SettingsPanel.new()
	panel.in_game = true  # oyun icinde: "Ana Menüye Dön" butonu da olsun
	center.add_child(panel)
	panel.to_menu.connect(_to_menu)
	panel.closed.connect(_close_pause)


## Ogretici: "Meteoroloji uyarisi" anlatilirken ornek bir uyari karti gosterilir (butonlar pasif).
var _demo_forecast := false


func demo_forecast(on: bool) -> void:
	if on and not _forecast.visible:
		_demo_forecast = true
		show_forecast("flood", "Meteoroloji Uyarısı · örnek", "Dağlarda yoğun yağış bekleniyor. 2 gün içinde dere taşabilir!",
			[{"id": "evacuate_river", "name": "Kıyıyı Tahliye Et", "cost": 2500}, {"id": "sandbag", "name": "Kum Torbası Diz", "cost": 2000}])
		for b in _forecast.find_children("*", "Button", true, false):
			b.disabled = true
	elif not on and _demo_forecast:
		_demo_forecast = false
		hide_forecast()


func _to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MENU_SCENE)


func _fill_end(v: VBoxContainer, w: int, g: Node, gr: Array, col: Color, failed := false) -> void:
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
	if failed:
		_text(v, "[color=#ff7359]Nüfus %%%d sınırının altına düştü, halk şehri terk etti.[/color]" % int(MIN_POP_RATIO), w, 16)
	# --- basari yuzdesi = nufus orani x farkindalik orani / 100 ---
	var pop := city_pop(g)
	var aw: float = g.awareness
	_label(v, "Başarı yüzdesi", 16, C_TEXT, true)
	_percent_bar(v, "Nüfus (%d / %d)" % [pop, MAX_POP], pop_ratio(pop), C_POP, w)
	_percent_bar(v, "Farkındalık", aw, C_GOOD, w)
	_percent_bar(v, "BAŞARI", success_rate(pop, aw), C_GOLD, w)
	# --- can karsilastirmasi ---
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
	var bg := _panel(h, C_TINT, Color.TRANSPARENT, 0, 0, 8)
	bg.custom_minimum_size = Vector2(width - 280, 22)
	var fill := ColorRect.new()
	fill.color = color
	fill.custom_minimum_size = Vector2(0, 22)
	fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bg.add_child(fill)
	var target := (width - 280) * clampf(float(value) / maxf(1.0, float(max_value)), 0.0, 1.0)
	fill.create_tween().tween_property(fill, "custom_minimum_size:x", maxf(4.0, target), 1.2).set_delay(0.4).set_trans(Tween.TRANS_QUAD)
	_label(h, "%d can" % value, 16, color, true)


## Yuzde bari (0-100): oyun sonundaki nufus / farkindalik / basari satirlari.
func _percent_bar(parent: Node, caption: String, percent: float, color: Color, width: int) -> void:
	var h := _hbox(parent, 10)
	var l := _label(h, caption, 14, C_MUTED)
	l.custom_minimum_size.x = 190
	var bg := _panel(h, C_TINT, Color.TRANSPARENT, 0, 0, 8)
	bg.custom_minimum_size = Vector2(width - 280, 22)
	var fill := ColorRect.new()
	fill.color = color
	fill.custom_minimum_size = Vector2(0, 22)
	fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bg.add_child(fill)
	var target := (width - 280) * clampf(percent / 100.0, 0.0, 1.0)
	fill.create_tween().tween_property(fill, "custom_minimum_size:x", maxf(4.0, target), 1.2) \
		.set_delay(0.4).set_trans(Tween.TRANS_QUAD)
	_label(h, "%%%d" % int(round(percent)), 16, color, true)
