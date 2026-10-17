extends HBoxContainer

# Satın alma butonuna tıklandığında ürün verisini dışarı aktaran sinyal
signal bought(data: Dictionary)

# Para için altın 1 lira ikonu
const COIN_TEXTURE = preload("res://assets/textures/para_1lira_altin.png")

# Ürünün tüm bilgilerini saklayan sözlük (Dictionary)
var product_data: Dictionary = {}
var is_locked: bool = false
var lock_reason: String = ""

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
		buy_button.text = "Kilitli"
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
		buy_button.text = "Maks"
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
		buy_button.text = "%s  %d " % [action_text, price]
		buy_button.icon = COIN_TEXTURE


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
