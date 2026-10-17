extends Node2D
## Belediye magazasi. Arayuz ekip arkadaslarimizin tasarimi (shop.tscn + product_row.tscn).
## Oyunda: para, kilitler, fiyatlar ve satin alma GameManager uzerinden yapilir
##   (game_manager.gd: shop_name / shop_desc / shop_cost / shop_reason / do_action).
## Urun listesi tek yerde: GameData.SHOP_ITEMS. Hazirlik sekmesi Deprem / Sel / Yangin seciciyle uce ayrilir.
## shop.tscn tek basina calistirilirsa (F6) deneme parasiyla acilir, oyuna etkisi olmaz.

# Ürün satırı şablonu (her ürün için bir kopya üretilir)
const PRODUCT_ROW_SCENE = preload("res://scenes/product_row.tscn")

# Sekme renkleri (Hazırlık, Farkındalık, Kamu Binaları)
## Renkler Tailwind CSS paletinin koyu tonlarindan (yumusak, goz yormayan, yazi okunakli)
const TAB_COLORS: Array[Color] = [
	Color("#6b3a2e"),  # Hazırlık (seçilen afete göre aşağıdaki HAZARD_BG ile değişir)
	Color("#1f5a57"),  # Farkındalık: petrol yeşili
	Color("#2a466b"),  # Kamu Binaları: çelik mavisi
]
const HAZARD_BG := {"deprem": Color("#6e4424"), "sel": Color("#1d4a6e"), "yangin": Color("#712f2a")}

# Hazırlık sekmesindeki afet seçicisi: [kimlik, başlık, renk, ikon, kısa açıklama]
const HAZARDS := [
	["deprem", "Deprem", Color("#d97706"), "res://assets/ui_icons/hazard_deprem.svg",
		"Yıkımı ve can kaybını azaltan yatırımlar"],
	["sel", "Sel", Color("#0284c7"), "res://assets/ui_icons/hazard_sel.svg",
		"Dere taşmasına ve su baskınına karşı önlemler"],
	["yangin", "Yangın", Color("#dc2626"), "res://assets/ui_icons/hazard_yangin.svg",
		"Ev ve orman yangınlarını önleyen, söndürmeyi hızlandıran yatırımlar"],
]

# Kamu binaları: magazadaki anahtar -> seviye ikonları (1, 2, 3)
const BUILDING_ICONS := {
	"belediye": ["res://assets/textures/belediye_1_saat_kulesi.png", "res://assets/textures/belediye_2_kubbeli.png", "res://assets/textures/belediye_3_modern.png"],
	"hastane": ["res://assets/textures/hastane_1_h.png", "res://assets/textures/hastane_2_arti.png", "res://assets/textures/hastane_3_nabiz.png"],
	"afad": ["res://assets/textures/afad_1_merkez.png", "res://assets/textures/afad_2_koordinasyon.png", "res://assets/textures/afad_3_lojistik_depo.png"],
	"itfaiye": ["res://assets/textures/itfaiye_1_garaj.png", "res://assets/textures/itfaiye_2_kuleli.png", "res://assets/textures/itfaiye_3_aracli.png"],
}

var game: Node  # GameManager (oyunda); null ise deneme modu
var _demo_money := 15000
var _demo_bought := {}
var _hazard := "deprem"

@onready var ui_layer: CanvasLayer = $UI
@onready var shop_panel: Control = $UI/ShopPopup
@onready var tab_container: TabContainer = $UI/ShopPopup/ShopPanel/TabContainer
@onready var money_label: Label = find_child("MoneyLabel", true, false) as Label
@onready var hazard_bar: HBoxContainer = $"UI/ShopPopup/ShopPanel/TabContainer/Hazırlık/Selector"
@onready var hazard_hint: Label = $"UI/ShopPopup/ShopPanel/TabContainer/Hazırlık/Hint"

var _tab_panel_style: StyleBoxFlat
var _tab_selected_style: StyleBoxFlat
var _rows: Array[Node] = []
var _hazard_buttons := {}
var _bold: FontVariation
var _dim: ColorRect


func _ready() -> void:
	game = get_tree().get_first_node_in_group("game")
	ui_layer.layer = 11  # oyun arayuzunun (HUD) ustunde
	_bold = FontVariation.new()
	_bold.base_font = load("res://assets/fonts/Fredoka.ttf")
	_bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	_style_fonts()
	_setup_tab_styles()
	_build_hazard_selector()
	_build_dim()
	populate_shop()
	refresh()
	if game:
		$UI/ShopButton.visible = false  # oyunda magaza alttaki "Mağaza" butonuyla acilir
		shop_panel.visible = false


# ------------------------------------------------------------------ acma / kapama
func open() -> void:
	refresh()
	_dim.visible = true
	shop_panel.visible = true
	shop_panel.pivot_offset = shop_panel.size / 2.0
	shop_panel.scale = Vector2(0.94, 0.94)
	shop_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(shop_panel, "modulate:a", 1.0, 0.15)
	tw.tween_property(shop_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	shop_panel.visible = false
	_dim.visible = false


func is_open() -> bool:
	return shop_panel.visible


func _on_shop_button_pressed() -> void:
	open()


func _on_close_button_pressed() -> void:
	_sfx("click")
	close()


## Panelin arkasini karartan katman (disina tiklayinca kapanir).
func _build_dim() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.45)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.visible = false
	_dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close())
	ui_layer.add_child(_dim)
	ui_layer.move_child(_dim, shop_panel.get_index())


# ------------------------------------------------------------------ yazi tipleri ve renkler
func _style_fonts() -> void:
	tab_container.add_theme_font_override("font", _bold)
	tab_container.add_theme_font_size_override("font_size", 22)
	tab_container.add_theme_color_override("font_selected_color", Color.WHITE)
	tab_container.add_theme_color_override("font_unselected_color", Color(0.78, 0.8, 0.86))
	tab_container.add_theme_color_override("font_hovered_color", Color.WHITE)
	money_label.add_theme_font_override("font", _bold)
	money_label.add_theme_font_size_override("font_size", 19)
	var close_btn: Button = $UI/ShopPopup/CloseButton
	close_btn.add_theme_font_override("font", _bold)
	var sb: Button = $UI/ShopButton
	sb.add_theme_font_override("font", _bold)
	hazard_hint.add_theme_font_size_override("font_size", 15)
	hazard_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))


func _setup_tab_styles() -> void:
	var base_panel = tab_container.get_theme_stylebox("panel")
	_tab_panel_style = base_panel.duplicate() if base_panel is StyleBoxFlat else StyleBoxFlat.new()
	tab_container.add_theme_stylebox_override("panel", _tab_panel_style)
	var base_selected = tab_container.get_theme_stylebox("tab_selected")
	_tab_selected_style = base_selected.duplicate() if base_selected is StyleBoxFlat else StyleBoxFlat.new()
	tab_container.add_theme_stylebox_override("tab_selected", _tab_selected_style)
	tab_container.tab_changed.connect(_on_tab_changed)
	_update_tab_color(tab_container.current_tab)


func _on_tab_changed(tab_idx: int) -> void:
	_sfx("click")
	_update_tab_color(tab_idx)


func _update_tab_color(tab_idx: int) -> void:
	if tab_idx >= 0 and tab_idx < TAB_COLORS.size():
		var col: Color = HAZARD_BG[_hazard] if tab_idx == 0 else TAB_COLORS[tab_idx]
		_tab_panel_style.bg_color = col
		_tab_selected_style.bg_color = col


# ------------------------------------------------------------------ Hazirlik: Deprem / Sel / Yangin secici
func _build_hazard_selector() -> void:
	for h in HAZARDS:
		var id: String = h[0]
		var b := Button.new()
		b.text = h[1]
		b.icon = load(h[3])
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 36)
		b.add_theme_constant_override("h_separation", 10)
		b.custom_minimum_size = Vector2(0, 50)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", _bold)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_select_hazard.bind(id))
		hazard_bar.add_child(b)
		_hazard_buttons[id] = b
	_style_hazard_buttons()


func _select_hazard(id: String) -> void:
	if id == _hazard:
		return
	_sfx("click")
	_hazard = id
	_style_hazard_buttons()
	_update_tab_color(tab_container.current_tab)
	populate_shop()
	refresh()


func _style_hazard_buttons() -> void:
	for h in HAZARDS:
		var b: Button = _hazard_buttons[h[0]]
		var col: Color = h[2]
		var on: bool = h[0] == _hazard
		var normal := _box(col if on else Color(0, 0, 0, 0.22), 12, 2, Color(1, 1, 1, 0.9) if on else Color(col.r, col.g, col.b, 0.55))
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", _box(col.lightened(0.1) if on else Color(col.r, col.g, col.b, 0.35), 12, 2, Color.WHITE))
		b.add_theme_stylebox_override("pressed", normal)
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(k, Color.WHITE if on else Color(1, 1, 1, 0.8))
		if on:
			hazard_hint.text = h[4]


func _box(c: Color, radius: int, border := 0, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


# ------------------------------------------------------------------ urun satirlari
func populate_shop() -> void:
	_rows.clear()
	var lists := {
		"Hazırlık/Scroll/Content": _ids_for(_hazard),
		"Farkındalık/Content": _ids_for("farkindalik"),
		"Kamu Binaları/Content": ["up:belediye", "up:hastane", "up:afad", "up:itfaiye"],
	}
	for path in lists:
		var content: VBoxContainer = tab_container.get_node(path)
		for c in content.get_children():
			c.queue_free()
		for id in lists[path]:
			var row = PRODUCT_ROW_SCENE.instantiate()
			content.add_child(row)
			row.setup(_row_data(id))
			row.bought.connect(_on_bought.bind(row))
			_rows.append(row)


func _ids_for(cat: String) -> Array:
	var out := []
	for it in GameData.SHOP_ITEMS:
		if it.cat == cat:
			out.append(it.id)
	return out


## Bir satirin guncel verisi (ad, aciklama, fiyat, ikon) oyundan.
func _row_data(id: String) -> Dictionary:
	var d := {"id": id}
	if id.begins_with("up:"):
		var key := id.get_slice(":", 1)
		d.building_id = key
		if game:
			var off: Dictionary = game.building_offer(key)
			d.name = off.name
			d.desc = off.desc
			d.price = off.cost
			var lvl: int = off.level
			d.icon = BUILDING_ICONS[key][clampi(lvl - 1 if off.is_max else lvl, 0, 2)]  # bir sonraki seviyenin gorunusu
		else:
			d.name = {"belediye": "Belediye Binası", "hastane": "Devlet Hastanesi", "afad": "AFAD Merkezi", "itfaiye": "İtfaiye İstasyonu"}[key] + " (Seviye 2)"
			d.desc = "Deneme modu"
			d.price = 5000
			d.icon = BUILDING_ICONS[key][1]
		return d
	var it := GameData.shop_item(id)
	d.name = game.shop_name(id) if game else it.name
	d.desc = game.shop_desc(id) if game else it.desc
	d.price = game.shop_cost(id) if game else maxi(0, int(it.cost))
	d.icon = it.icon
	if it.get("target", false):
		d.button_text = "Mahalle seç"
	return d


## Fiyatlari, kilitleri ve parayi yenile (para degisince ya da satin alinca).
func refresh() -> void:
	var money: int = game.money if game else _demo_money
	if money_label:
		money_label.text = GameManager.fmt_money(money).trim_suffix(" TL")
	for row in _rows:
		if not is_instance_valid(row):
			continue
		var id: String = row.product_data.get("id", "")
		var data := _row_data(id)
		var reason: String = game.shop_reason(id) if game else ("Alındı" if _demo_bought.has(id) else "")
		data.is_max = reason in ["Alındı", "Maks"]
		data.max_text = reason if data.is_max else ""
		row.setup(data)
		if data.is_max:
			row.set_locked(false, "")
		else:
			row.set_locked(reason != "", reason)
		row.set_affordable(money >= int(data.price))


func _on_bought(data: Dictionary, row: Node) -> void:
	var id: String = data.get("id", "")
	if game == null:  # deneme modu
		if _demo_money >= int(data.price):
			_demo_money -= int(data.price)
			_demo_bought[id] = true
			_sfx("coins")
		refresh()
		return
	var target: bool = GameData.shop_item(id).get("target", false)
	if game.do_action(id):
		# magaza kapanir: oyuncu haritada ne oldugunu gorsun (kamera oraya kayar, etiket cikar)
		_flash(row)
		await get_tree().create_timer(0.25).timeout
		close()
		return
	else:
		_sfx("error")
		_shake(row)
	refresh()


func _shake(row: Node) -> void:
	if not is_instance_valid(row):
		return
	var x: float = row.position.x
	var tw := row.create_tween()
	for i in 3:
		tw.tween_property(row, "position:x", x + 6.0, 0.04)
		tw.tween_property(row, "position:x", x - 6.0, 0.04)
	tw.tween_property(row, "position:x", x, 0.04)


func _flash(row: Node) -> void:
	if not is_instance_valid(row):
		return
	var tw := row.create_tween()
	tw.tween_property(row, "modulate", Color(1.3, 1.25, 0.8), 0.1)
	tw.tween_property(row, "modulate", Color.WHITE, 0.35)


func _sfx(sound: String) -> void:
	var a := get_tree().get_first_node_in_group("audio")
	if a:
		a.play(sound)
