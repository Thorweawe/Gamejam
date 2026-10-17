extends HBoxContainer

# Satın alma butonuna tıklandığında ürün verisini dışarı aktaran sinyal
signal bought(data: Dictionary)

# Para için altın 1 lira ikonu
const COIN_TEXTURE = preload("res://assets/textures/para_1lira_altin.png")

# Ürünün tüm bilgilerini saklayan sözlük (Dictionary)
var product_data: Dictionary = {}
var is_locked: bool = false
var lock_reason: String = ""
var is_affordable: bool = true

# Okunakli yazi: Fredoka kalin (basliklar ve buton)
static var _bold: FontVariation

# Sahne içindeki UI elemanlarının referansları
@onready var texture_rect: TextureRect = $PanelContainer/TextureRect
@onready var name_label: Label = $VBoxContainer/Name
@onready var desc_label: Label = $VBoxContainer/Description
@onready var lock_label: Label = $VBoxContainer/LockLabel
@onready var price_label: Label = get_node_or_null("Price") as Label
@onready var buy_button: Button = $BuyButton


func _ready() -> void:
	# "Satın al" butonuna basıldığında kendi iç metodumuzu tetikliyoruz
	buy_button.pressed.connect(_on_buy_button_pressed)
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = load("res://assets/fonts/Fredoka.ttf")
		_bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	name_label.add_theme_font_override("font", _bold)
	name_label.add_theme_font_size_override("font_size", 20)
	desc_label.add_theme_font_size_override("font_size", 15)
	desc_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97, 0.88))
	# ikon cercevesi: krem zemin, yumusak altin kenar
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#fdf6e3")
	frame.set_corner_radius_all(16)
	frame.set_border_width_all(3)
	frame.border_color = Color("#f2c46b")
	frame.set_content_margin_all(5)
	frame.shadow_color = Color(0, 0, 0, 0.25)
	frame.shadow_size = 4
	frame.shadow_offset = Vector2(0, 2)
	$PanelContainer.add_theme_stylebox_override("panel", frame)
	desc_label.add_theme_constant_override("line_spacing", 2)
	lock_label.add_theme_font_override("font", _bold)
	lock_label.add_theme_font_size_override("font_size", 14)
	buy_button.add_theme_font_override("font", _bold)
	buy_button.add_theme_font_size_override("font_size", 17)
	buy_button.custom_minimum_size.x = 200


# Dışarıdan gelen ürün verisiyle satırın görsel ve metin içeriğini doldurur
func setup(data: Dictionary) -> void:
	# Veriyi daha sonra sinyalle gönderebilmek için kaydediyoruz
	product_data = data
	
	# Node'lar henüz hazır değilse ready olmasını bekliyoruz (güvenlik önlemi)
	if not is_node_ready():
		await ready
	
	# Başlık ve açıklama etiketlerini güncelliyoruz
	name_label.text = str(data.get("name", ""))
	desc_label.text = str(data.get("desc", ""))
	
	# Ayrık fiyat etiketi varsa gizliyoruz (fiyat artık buton içine entegre)
	if price_label != null:
		price_label.visible = false
	
	# Eğer veride geçerli bir ikon yolu ("icon") verilmişse resmi yüklüyoruz.
	# Boş bırakılmışsa veya dosya bulunamazsa varsayılan resim kalır.
	var icon_path: String = str(data.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		texture_rect.texture = load(icon_path)
	
	_update_ui_state()


# Buton ve satır görünümünü kilit ve seviye durumuna göre günceller
func _update_ui_state() -> void:
	if is_locked:
		buy_button.disabled = true
		buy_button.text = "Yarın hazır" if lock_reason.begins_with("İnşaatta") else "Kilitli"
		buy_button.icon = null
		modulate = Color(1.0, 1.0, 1.0, 0.5)
		if lock_label != null:
			lock_label.text = lock_reason
			lock_label.visible = true
		return
	
	# Kilitli değilse normal görünüme döndür
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	if lock_label != null:
		lock_label.text = ""
		lock_label.visible = false
	
	# Maksimum seviyeye ulaşıldı mı kontrolü (Örn: Seviye 3 kamu binaları)
	var is_max: bool = product_data.get("is_max", false)
	if is_max:
		buy_button.disabled = true
		var done := str(product_data.get("max_text", "Maks"))
		buy_button.text = ("✓ " + done) if done == "Alındı" else done
		buy_button.icon = null
	else:
		var price: int = int(product_data.get("price", 0))
		buy_button.disabled = false
		var action_text: String = "Satın al"
		if product_data.has("building_id") or product_data.has("upgrade"):
			action_text = "Yükselt"
		elif product_data.has("button_text"):
			action_text = str(product_data["button_text"])
		
		# Buton içine eylem adı, fiyat ve altın 1 lira ikonu yerleştiriyoruz
		var price_str: String = str(product_data.get("price_text", GameManager.fmt_money(price).trim_suffix(" TL")))
		buy_button.text = "%s  %s " % [action_text, price_str]
		buy_button.icon = COIN_TEXTURE
		# para yetmiyorsa fiyat kirmizi
		var col := Color(0.23, 0.04, 0.04) if is_affordable else Color(0.62, 0.08, 0.06)
		buy_button.add_theme_color_override("font_color", col)
		buy_button.add_theme_color_override("font_hover_color", col)
		buy_button.tooltip_text = "" if is_affordable else "Bütçe yetersiz"


# Para yetiyor mu (yetmiyorsa fiyat kirmizi gorunur)
func set_affordable(ok: bool) -> void:
	is_affordable = ok
	if is_node_ready():
		_update_ui_state()


# Kilit durumunu günceller ve satır görünümünü ayarlar
func set_locked(locked: bool, reason: String = "") -> void:
	is_locked = locked
	lock_reason = reason
	if is_node_ready():
		_update_ui_state()


# Satın alma butonuna basıldığında çağrılır
func _on_buy_button_pressed() -> void:
	# Kilitli veya maksimum seviyedeki ürünler satın alınamaz
	if is_locked or product_data.get("is_max", false):
		return
	
	# Ürün verisini parametre olarak sinyal ile ana sisteme iletiyoruz
	bought.emit(product_data)
