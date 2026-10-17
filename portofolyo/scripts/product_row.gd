extends HBoxContainer

# Satın alma butonuna tıklandığında ürün verisini dışarı aktaran sinyal
signal bought(data: Dictionary)

# Ürünün tüm bilgilerini saklayan sözlük (Dictionary)
var product_data: Dictionary = {}

# Sahne içindeki UI elemanlarının referansları
@onready var texture_rect: TextureRect = $PanelContainer/TextureRect
@onready var name_label: Label = $VBoxContainer/Name
@onready var desc_label: Label = $VBoxContainer/Description
@onready var price_label: Label = $Price
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
	
	# Başlık, açıklama ve fiyat etiketlerini güncelliyoruz
	name_label.text = str(data.get("name", ""))
	desc_label.text = str(data.get("desc", ""))
	price_label.text = str(data.get("price", 0))
	
	# Eğer veride geçerli bir ikon yolu ("icon") verilmişse resmi yüklüyoruz.
	# Boş bırakılmışsa veya dosya bulunamazsa varsayılan resim (kitap.png) kalır.
	var icon_path: String = str(data.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		texture_rect.texture = load(icon_path)


# Satın alma butonuna basıldığında çağrılır
func _on_buy_button_pressed() -> void:
	# Ürün verisini parametre olarak sinyal ile ana sisteme iletiyoruz
	bought.emit(product_data)
