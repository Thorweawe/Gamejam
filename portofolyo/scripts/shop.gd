extends Node2D

# Ürün satırı şablonunu önceden yüklüyoruz (preload).
# Bu sayede her ürün üretildiğinde sahne diskten tekrar okunmaz, bellekte hazır durur.
const PRODUCT_ROW_SCENE = preload("res://scenes/product_row.tscn")

# Oyuncunun mevcut parası
var money: int = 500

# Oyun istatistikleri ve afet direnç değerleri (ileride x ve y isimleri özelleştirilebilir)
var stats: Dictionary = {
	"x": 0,
	"y": 0
}

# UI Düğüm Referansları
@onready var shop_panel: PanelContainer = $UI/ShopPanel
@onready var tab_container: TabContainer = $UI/ShopPanel/VBoxContainer/TabContainer

# Sahnede MoneyLabel adında bir Label varsa otomatik bulur; yoksa hata vermez (null kalır)
# Böylece ileride panelin herhangi bir yerine MoneyLabel eklendiğinde doğrudan çalışır.
@onready var money_label: Label = find_child("MoneyLabel", true, false) as Label

# Sekme 1: Hazırlık Sekmesi Ürün Listesi
var hazirlik_products: Array[Dictionary] = [
	{
		"group": "Deprem",
		"name": "Esnek Alt Yapı Güçlendirmesi",
		"desc": "Şebeke hatlarını esneterek deprem anında kırılmaları ve altyapı hasarını önler.",
		"price": 100,
		"stat": "x",
		"amount": 15,
		"icon": "res://assets/textures/kitap.png" # Var olan doku örneği
	},
	{
		"group": "Deprem",
		"name": "Acil Durum Çantası Dağıtımı",
		"desc": "Halkın ilk 72 saatlik temel ihtiyaç ve gıda maddelerine ulaşmasını sağlar.",
		"price": 50,
		"stat": "y",
		"amount": 10,
		"icon": "" # Boş string olduğunda varsayılan ikon korunur
	},
	{
		"group": "Sel",
		"name": "Drenaj Tahliye Pompaları",
		"desc": "Kritik su kanallarına ve caddelere yüksek kapasiteli tahliye pompaları kurar.",
		"price": 150,
		"stat": "x",
		"amount": 25,
		"icon": ""
	}
]

# Sekme 2: Farkındalık Sekmesi Ürün Listesi
var farkindalik_products: Array[Dictionary] = [
	{
		"group": "Deprem",
		"name": "Mahalle Afet Tatbikatı",
		"desc": "Halkın toplanma alanlarına güvenli ve hızlı ulaşma bilincini artırır.",
		"price": 80,
		"stat": "y",
		"amount": 20,
		"icon": ""
	},
	{
		"group": "Yangın",
		"name": "Yangın Söndürme Eğitimi",
		"desc": "Gönüllü ekiplere ilk alev müdahalesi ve söndürme tüpü kullanımı öğretilir.",
		"price": 120,
		"stat": "x",
		"amount": 15,
		"icon": ""
	},
	{
		"group": "Yangın",
		"name": "Erken Uyarı Broşürleri",
		"desc": "Ev tipi duman dedektörleri ve acil durum tahliye rehberleri dağıtır.",
		"price": 40,
		"stat": "y",
		"amount": 5,
		"icon": ""
	}
]

# Sekme 3: Kamu Binaları Sekmesi Ürün Listesi
var kamu_binalari_products: Array[Dictionary] = [
	{
		"group": "Deprem",
		"name": "Hastane Sismik İzolatörleri",
		"desc": "Ana hastane binasının temeline izolatör ekleyerek operasyonların sürmesini sağlar.",
		"price": 250,
		"stat": "x",
		"amount": 40,
		"icon": ""
	},
	{
		"group": "Deprem",
		"name": "Okul Güçlendirme Projesi",
		"desc": "Devlet okullarının taşıyıcı kolonlarını karbon fiber kaplama ile güçlendirir.",
		"price": 180,
		"stat": "y",
		"amount": 30,
		"icon": ""
	},
	{
		"group": "Sel",
		"name": "Kamu Binası Su Bariyerleri",
		"desc": "Hizmet binalarının bodrum ve giriş kapılarına taşınabilir sel setleri yerleştirir.",
		"price": 130,
		"stat": "x",
		"amount": 20,
		"icon": ""
	}
]


func _ready() -> void:
	# Açılışta para göstergesini güncelliyoruz
	update_money_ui()
	
	# Sekmelerdeki ürünleri dinamik olarak oluşturuyoruz
	populate_shop()


# Para etiketini güncelleyen fonksiyon
func update_money_ui() -> void:
	if money_label != null:
		money_label.text = "Para: %d" % money


# Her sekme için ilgili Content VBoxContainer'ını bulur ve ürünleri ekler
func populate_shop() -> void:
	# Sekme adı ile ürün listesini eşleştiren sözlük
	var tabs_mapping: Dictionary = {
		"Hazırlık": hazirlik_products,
		"Farkındalık": farkindalik_products,
		"Kamu Binaları": kamu_binalari_products
	}
	
	for tab_name in tabs_mapping.keys():
		# Sekme içerisindeki "Content" isimli VBoxContainer'ı buluyoruz
		var content_container: VBoxContainer = tab_container.get_node_or_null(tab_name + "/Content") as VBoxContainer
		if content_container == null:
			continue
		
		# Grup başlıklarının gereksiz tekrarlanmasını engellemek için son eklenen grubu tutuyoruz
		var last_group: String = ""
		var product_list: Array[Dictionary] = tabs_mapping[tab_name]
		
		for product in product_list:
			var current_group: String = str(product.get("group", ""))
			
			# Eğer ürünün grubu bir öncekinden farklıysa grup başlığı Label'ı ekliyoruz
			if current_group != "" and current_group != last_group:
				var group_label: Label = Label.new()
				group_label.text = current_group
				group_label.add_theme_font_size_override("font_size", 30) # Büyük font
				content_container.add_child(group_label)
				last_group = current_group
			
			# product_row.tscn sahnesinden yeni bir satır türetiyoruz (instantiate)
			var row = PRODUCT_ROW_SCENE.instantiate()
			# Satırı Content konteynerine ekliyoruz
			content_container.add_child(row)
			# Satırın Label ve resimlerini ürün verisiyle dolduruyoruz
			row.setup(product)
			# Satırdaki butona basıldığında tetiklenen bought sinyalini buy fonksiyonumuza bağlıyoruz
			row.bought.connect(buy)


# Satın alma mantığı
func buy(data: Dictionary) -> void:
	var price: int = int(data.get("price", 0))
	var stat_name: String = str(data.get("stat", ""))
	var amount: int = int(data.get("amount", 0))
	
	# Paranın yetip yetmediğini kontrol ediyoruz
	if money >= price:
		# Parayı düşüyoruz
		money -= price
		
		# İlgili stat değerini artırıyoruz
		if stats.has(stat_name):
			stats[stat_name] += amount
		else:
			stats[stat_name] = amount
		
		# Para göstergesini güncelliyoruz
		update_money_ui()
		print("Satın alındı: ", data.get("name", ""), " | Kalan Para: ", money, " | Stats: ", stats)
	else:
		print("Yetersiz para!")


# "Yükseltmeler" butonuna basılınca dükkan penceresini açar
func _on_shop_button_pressed() -> void:
	shop_panel.visible = true


# "Kapat" butonuna basılınca dükkan penceresini kapatır
func _on_close_button_pressed() -> void:
	shop_panel.visible = false
