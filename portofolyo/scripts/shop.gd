extends Node2D

# Ürün satırı şablonunu önceden yüklüyoruz (preload).
# Bu sayede her ürün üretildiğinde sahne diskten tekrar okunmaz, bellekte hazır durur.
const PRODUCT_ROW_SCENE = preload("res://scenes/product_row.tscn")

# Sekme Renk Paleti (Hazırlık, Farkındalık, Kamu Binaları)
# Her sekmenin zemin ve aktif sekme rengi buradan kolayca özelleştirilebilir:
const TAB_COLORS: Array[Color] = [
	Color(0.55, 0.09, 0.13, 1.0),  # Hazırlık: Derin Bordo (Afet hazırlığı & aciliyet)
	Color(0.08, 0.38, 0.42, 1.0),  # Farkındalık: Derin Petrol Yeşili (İletişim & Eğitim)
	Color(0.18, 0.28, 0.45, 1.0),  # Kamu Binaları: Çelik Donanma Mavisi (Kamu yapıları & Güven)
]

# Oyuncunun mevcut parası
var money: int = 500

# Oyun istatistikleri ve afet direnç değerleri
var stats: Dictionary = {
	"x": 0,
	"y": 0
}

# UI Düğüm Referansları (ShopPopup mimarisine uygun)
@onready var shop_panel: Control = $UI/ShopPopup
@onready var tab_container: TabContainer = $UI/ShopPopup/ShopPanel/TabContainer
@onready var money_label: Label = find_child("MoneyLabel", true, false) as Label

# Dinamik sekme arka planı stilleri (duplicate ile kopyalanır)
var _tab_panel_style: StyleBoxFlat
var _tab_selected_style: StyleBoxFlat

# Kamu Binalarının Seviye Takibi (1. seviyeden başlar, 3'e kadar artabilir)
var levels: Dictionary = {
	"belediye": 1,
	"itfaiye": 1,
	"hastane": 1,
	"afad": 1
}
var building_levels: Dictionary = levels # Geriye dönük uyumluluk

# Bina kodlarının ekranda görünen Türkçe karşılıkları
const BUILDING_DISPLAY_NAMES: Dictionary = {
	"belediye": "Belediye",
	"itfaiye": "İtfaiye",
	"hastane": "Hastane",
	"afad": "AFAD"
}

# Üretilen tüm ürün satırlarının referans listesi (Kilit yenileme için)
var _all_product_rows: Array[Node] = []

# 4 Temel Kamu Binasının Seviye Tanımlamaları
# Seviye 1->2 yükseltme fiyatları korunmuştur (180, 200, 170, 160).
# Seviye 2->3 yükseltme fiyatları 1.5 katı olarak placeholder belirlenmiştir.
var public_building_definitions: Dictionary = {
	"belediye": {
		"base_name": "Belediye Binası",
		"upgrade": "belediye",
		"upgrade_prices": [180, 270], # Seviye 1->2 (180), Seviye 2->3 (270 placeholder: 1.5x)
		"icons": [
			"res://assets/textures/belediye_1_saat_kulesi.png",
			"res://assets/textures/belediye_2_kubbeli.png",
			"res://assets/textures/belediye_3_modern.png"
		],
		"level_desc": [
			"Müzeler, sosyal medya ve kamu spotu açılır.",
			"Eğitim parkı açılır, deprem çadırı (AFAD Sv.2 ile birlikte) açılır."
		],
		"stat": "x",
		"amount": 20
	},
	"hastane": {
		"base_name": "Devlet Hastanesi",
		"upgrade": "hastane",
		"upgrade_prices": [200, 300], # Seviye 1->2 (200), Seviye 2->3 (300 placeholder: 1.5x)
		"icons": [
			"res://assets/textures/hastane_1_h.png",
			"res://assets/textures/hastane_2_arti.png",
			"res://assets/textures/hastane_3_nabiz.png"
		],
		"level_desc": [
			"Sağlık birimi artar, can kaybı azalır.",
			"Sağlık birimi artar, can kaybı azalır."
		],
		"stat": "y",
		"amount": 20
	},
	"afad": {
		"base_name": "AFAD İl Merkezi",
		"upgrade": "afad",
		"upgrade_prices": [170, 255], # Seviye 1->2 (170), Seviye 2->3 (255 placeholder: 1.5x)
		"icons": [
			"res://assets/textures/afad_1_merkez.png",
			"res://assets/textures/afad_2_koordinasyon.png",
			"res://assets/textures/afad_3_lojistik_depo.png"
		],
		"level_desc": [
			"AFAD birimi artar, can kaybı azalır; deprem çadırı (Belediye Sv.3 ile birlikte) açılır.",
			"AFAD birimi artar, can kaybı azalır; gönüllü mahalle ekibi açılır."
		],
		"stat": "x",
		"amount": 25
	},
	"itfaiye": {
		"base_name": "Merkez İtfaiye İstasyonu",
		"upgrade": "itfaiye",
		"upgrade_prices": [160, 240], # Seviye 1->2 (160), Seviye 2->3 (240 placeholder: 1.5x)
		"icons": [
			"res://assets/textures/itfaiye_1_garaj.png",
			"res://assets/textures/itfaiye_2_kuleli.png",
			"res://assets/textures/itfaiye_3_aracli.png"
		],
		"level_desc": [
			"İtfaiye birimi artar, afetlerde can kaybı azalır; yangın tüpü dağıt ve yangın müzesi (Belediye Sv.2 ile birlikte) açılır.",
			"İtfaiye birimi artar, can kaybı azalır; yangın uçağı açılır."
		],
		"stat": "y",
		"amount": 25
	}
}

# Sekme 1: Hazırlık / Yükseltmeler Sekmesi Ürün Listesi (Grup başlıkları kullanılır)
var hazirlik_products: Array[Dictionary] = [
	# === DEPREM ===
	{
		"group": "Deprem",
		"name": "Esnek Altyapı Boruları",
		"desc": "Şebeke hatlarını esneterek deprem dalgalarında kırılmaları ve su kesintilerini önler.",
		"price": 120,
		"stat": "x",
		"amount": 20,
		"icon": "res://assets/textures/su_borusu_1_dirsek.png"
	},
	{
		"group": "Deprem",
		"name": "Otomatik Gaz Kesme Vanası",
		"desc": "Sarsıntıyı hissettiği anda ana vanayı kapatıp patlama ve ikincil yangınları engeller.",
		"price": 140,
		"stat": "y",
		"amount": 25,
		"icon": "res://assets/textures/gaz_borusu_1_vana.png"
	},
	{
		"group": "Deprem",
		"name": "Okul ve Sağlık Ocakları Gaz Emniyeti",
		"desc": "Kazan daireleri ve mutfaklar için sarsıntıda devreye giren otomatik kesici vanalar.",
		"price": 115,
		"stat": "x",
		"amount": 20,
		"icon": "res://assets/textures/gaz_borusu_2_dirsek.png"
	},
	{
		"group": "Deprem",
		"name": "Binalara Acil Çıkış Kapısı",
		"desc": "Deprem anında yığılmayı önleyen geniş ve dayanıklı acil çıkış kapıları inşası.",
		"price": 100,
		"stat": "y",
		"amount": 18,
		"icon": "res://assets/textures/acil_cikis_2_acik_kapi.png"
	},
	{
		"group": "Deprem",
		"name": "Deprem Toplanma Alanı",
		"desc": "Mahallelerde açık toplanma noktaları ve yönlendirme tabelaları oluşturulur.",
		"price": 85,
		"stat": "y",
		"amount": 15,
		"icon": "res://assets/textures/cadir_2_kubbe.png"
	},
	{
		"group": "Deprem",
		"name": "Şok Emici Dış İskelet",
		"desc": "Binalara bağlanan çelik kafes iskelet sarsıntı enerjisini emer ve çöküşü geciktirir.",
		"price": 230,
		"stat": "x",
		"amount": 35,
		"icon": "res://assets/textures/bina_2_normal_resmi.png"
	},
	{
		"group": "Deprem",
		"name": "Binalara Çelik Aks Tak",
		"desc": "Deprem yüklerini duvarlara dağıtan çelik çerçeve (aks) sisteminin mevcut binalara eklenmesi.",
		"price": 200,
		"stat": "x",
		"amount": 30,
		"icon": "res://assets/textures/bina_1_normal_ev.png"
	},
	{
		"group": "Deprem",
		"name": "Hafif Hasarlı Binaları Yenile",
		"desc": "Çatlak ve yüzeysel hasar görmüş yapıların güçlendirilerek onarılması.",
		"price": 160,
		"stat": "x",
		"amount": 25,
		"icon": "res://assets/textures/bina_3_hafif_hasarli_dukkan.png"
	},
	{
		"group": "Deprem",
		"name": "Orta Hasarlı Binaları Yenile",
		"desc": "Taşıyıcı sistemleri zarar görmüş binaların güçlendirme ve restore programı.",
		"price": 280,
		"stat": "x",
		"amount": 40,
		"icon": "res://assets/textures/bina_4_orta_hasarli_gokdelen.png"
	},
	{
		"group": "Deprem",
		"name": "Ağır Hasarlı Binaları Yenile",
		"desc": "Yıkılma riski taşıyan yapıların yıkılıp çağdaş deprem standartlarında yeniden inşası.",
		"price": 420,
		"stat": "x",
		"amount": 60,
		"icon": "res://assets/textures/bina_5_buyuk_hasarli_apartman.png"
	},
	{
		"group": "Deprem",
		"name": "Kabloları Yer Altına Al",
		"desc": "Havai elektrik hatlarını toprağa gömerek depremde kopan teller nedeniyle çıkan yangınları önler.",
		"price": 175,
		"stat": "y",
		"amount": 28,
		"icon": "res://assets/textures/elektrik_teli_2_kablo.png"
	},
	{
		"group": "Deprem",
		"name": "Erken Uyarı Sistemi",
		"desc": "Sismik sensör ağı; şiddetli dalgalar gelmeden saniyeler önce otomatik alarm verir.",
		"price": 320,
		"stat": "y",
		"amount": 45,
		"icon": "res://assets/textures/sms_1_balon.png"
	},
	{
		"group": "Deprem",
		"name": "Deprem Çadırı Hazırla",
		"desc": "Acil barınma ihtiyacı için depolarda bekletilen prefabrik çadır kitleri.",
		"price": 130,
		"stat": "y",
		"amount": 22,
		"icon": "res://assets/textures/cadir_1_ucgen.png",
		"requires": {"belediye": 3, "afad": 2}
	},
	{
		"group": "Deprem",
		"name": "Binalara Çelik Destek Ekle",
		"desc": "Kritik yapı köşelerine ve kirişlere çelik perde duvar takviyesi eklenir.",
		"price": 190,
		"stat": "x",
		"amount": 32,
		"icon": "res://assets/textures/bina_2_normal_resmi.png"
	},
	# === YANGИН ===
	{
		"group": "Yangın",
		"name": "Korumalı Elektrik Tesisatı",
		"desc": "Kısa devre ve aşırı yüklenmelerde yangın riskini sıfıra indiren yanmaz kablolama.",
		"price": 110,
		"stat": "x",
		"amount": 15,
		"icon": "res://assets/textures/elektrik_teli_2_kablo.png"
	},
	{
		"group": "Yangın",
		"name": "Fosforlu Acil Çıkış Levhaları",
		"desc": "Yoğun duman ve elektrik kesintisinde tahliye yollarını görünür kılar.",
		"price": 70,
		"stat": "y",
		"amount": 15,
		"icon": "res://assets/textures/acil_cikis_3_exit.png"
	},
	{
		"group": "Yangın",
		"name": "Kritik Kamu Tesisleri Yangın Çıkış Kapıları",
		"desc": "Bas-aç kilitli, 120 dakika alev geçirmez özel çelik tahliye kapıları.",
		"price": 150,
		"stat": "y",
		"amount": 25,
		"icon": "res://assets/textures/acil_cikis_4_cikis.png"
	},
	{
		"group": "Yangın",
		"name": "Hastaneler İçin Kesintisiz Şebeke ve Jeneratör",
		"desc": "Afet durumunda yoğun bakım ve acil servisleri besleyen izole güç hattı.",
		"price": 190,
		"stat": "y",
		"amount": 30,
		"icon": "res://assets/textures/elektrik_teli_1_fis.png"
	},
	{
		"group": "Yangın",
		"name": "Kamu Binaları Yangın Kaçış Koridorları",
		"desc": "Genişletilmiş ve duman tahliyeli acil kaçış rotaları inşası.",
		"price": 140,
		"stat": "x",
		"amount": 25,
		"icon": "res://assets/textures/acil_cikis_1_kosan_adam.png"
	},
	{
		"group": "Yangın",
		"name": "Sokaklara Yangın Musluğu Ekle",
		"desc": "İtfaiyenin su kaynağına hızla bağlanması için her 200 metrede bir yangın hidrantı.",
		"price": 160,
		"stat": "y",
		"amount": 28,
		"icon": "res://assets/textures/su_borusu_2_vana.png"
	},
	{
		"group": "Yangın",
		"name": "Binalara Otomatik Fışkiye Sistemi",
		"desc": "Isı sensörüyle devreye giren sprinkler sistemi yangını başlangıç aşamasında söndürür.",
		"price": 200,
		"stat": "x",
		"amount": 32,
		"icon": "res://assets/textures/su_borusu_1_dirsek.png"
	},
	{
		"group": "Yangın",
		"name": "Eski Elektrik Tesisatlarını Yenile",
		"desc": "30 yıl üzeri binalardaki eskimiş tesisatın yangına dayanıklı yeni kablolarla değiştirilmesi.",
		"price": 175,
		"stat": "x",
		"amount": 28,
		"icon": "res://assets/textures/elektrik_teli_1_fis.png"
	},
	{
		"group": "Yangın",
		"name": "Yanmaz Malzemeli Bina Yenileme",
		"desc": "Cephe kaplaması ve çatı malzemelerinin yangına dirençli kompozit ürünlerle değiştirilmesi.",
		"price": 240,
		"stat": "x",
		"amount": 38,
		"icon": "res://assets/textures/bina_1_normal_ev.png"
	},
	{
		"group": "Yangın",
		"name": "Ormana Termal Kamera Kur",
		"desc": "Isı imzasını takip eden termal kameralar orman yangınını başlamadan dakikalar içinde tespit eder.",
		"price": 310,
		"stat": "y",
		"amount": 45,
		"icon": "res://assets/textures/televizyon_2_modern.png"
	},
	{
		"group": "Yangın",
		"name": "Yangın Söndürme Uçağı Al",
		"desc": "Geniş alanlı orman ve kentsel yangınlara havadan müdahale eden amphibi yangın uçağı.",
		"price": 500,
		"stat": "y",
		"amount": 70,
		"icon": "res://assets/textures/gonullu_2_el_kaldiran.png",
		"requires": {"itfaiye": 3}
	},
	{
		"group": "Yangın",
		"name": "Evlere Ücretsiz Yangın Tüpü Dağıt",
		"desc": "Her haneye ücretsiz 6 kg kuru toz yangın söndürücü ve kullanım eğitimi.",
		"price": 120,
		"stat": "y",
		"amount": 20,
		"icon": "res://assets/textures/brosur_1_uclu.png",
		"requires": {"itfaiye": 2}
	},
	# === SEL ===
	{
		"group": "Sel",
		"name": "Geri Tepme Önleyici Su Vanaları",
		"desc": "Aşırı yağış anında atık ve taşkın suyun binalara geri basmasını önler.",
		"price": 95,
		"stat": "x",
		"amount": 15,
		"icon": "res://assets/textures/su_borusu_2_vana.png"
	},
	{
		"group": "Sel",
		"name": "Acil Toplanma ve Çadır Alanı Planı",
		"desc": "Afet sonrası vatandaşların barınma ve gıda dağıtımı için geçici çadır kent planlaması.",
		"price": 125,
		"stat": "x",
		"amount": 25,
		"icon": "res://assets/textures/cadir_3_afet.png"
	},
	{
		"group": "Sel",
		"name": "Dere Yataklarını Temizle",
		"desc": "Biriken çamur, moloz ve bitki örtüsünün dere yataklarından kaldırılarak su akışı kapasitesinin artırılması.",
		"price": 110,
		"stat": "x",
		"amount": 18,
		"icon": "res://assets/textures/su_borusu_1_dirsek.png"
	},
	{
		"group": "Sel",
		"name": "Yağmur Suyu Kanalları Kaz",
		"desc": "Yoğun yağışlarda yüzeysel suyu toplayıp güvenli noktalara ileten yeraltı drenaj kanalları.",
		"price": 150,
		"stat": "x",
		"amount": 22,
		"icon": "res://assets/textures/gaz_borusu_2_dirsek.png"
	},
	{
		"group": "Sel",
		"name": "Taşkın Koruma Duvarı Ör",
		"desc": "Risk altındaki mahalleleri taşkın sularından koruyan beton ve çelik set inşası.",
		"price": 280,
		"stat": "x",
		"amount": 42,
		"icon": "res://assets/textures/bina_2_normal_resmi.png"
	},
	{
		"group": "Sel",
		"name": "Yer Altı Su Depoları Yap",
		"desc": "Taşkın suyunu yüzeyde biriktirmek yerine yeraltı sarnıçlarına yönlendiren altyapı sistemi.",
		"price": 220,
		"stat": "y",
		"amount": 35,
		"icon": "res://assets/textures/gaz_borusu_1_vana.png"
	},
	{
		"group": "Sel",
		"name": "Binalara Su Bariyeri Dağıt",
		"desc": "Kapı ve pencere önüne yerleştirilen taşınabilir su torbası setleri suyu giriş noktalarından uzak tutar.",
		"price": 80,
		"stat": "y",
		"amount": 12,
		"icon": "res://assets/textures/brosur_2_uyari.png"
	},
	{
		"group": "Sel",
		"name": "Su Tahliye Motoru Al",
		"desc": "Sel sonrası bodrum ve zemin katlardaki suyu hızla tahliye eden yüksek debili pompa sistemleri.",
		"price": 170,
		"stat": "y",
		"amount": 28,
		"icon": "res://assets/textures/elektrik_teli_1_fis.png"
	}
]

# Sekme 2: Farkındalık Sekmesi Ürün Listesi (Eğitim ve Medya alt grupları)
var farkindalik_products: Array[Dictionary] = [
	# --- EĞİTİM grubu ---
	{
		"group": "Eğitim",
		"name": "Afet Bilgilendirme ve Koordinasyon Hattı",
		"desc": "Vatandaşların yakınlarına ulaşması ve bilgi alması için kesintisiz çağrı altyapısı.",
		"price": 100,
		"stat": "x",
		"amount": 15,
		"icon": "res://assets/textures/sms_2_telefon.png"
	},
	{
		"group": "Eğitim",
		"name": "Okul ve Topluluk Eğitim Kitapçığı",
		"desc": "Öğrencilere ve ailelere afet bilinci kazandıran resimli eğitim seti.",
		"price": 65,
		"stat": "y",
		"amount": 15,
		"icon": "res://assets/textures/kitap_5_yildizli.png"
	},
	{
		"group": "Eğitim",
		"name": "Uygulamalı Tahliye Tatbikatı",
		"desc": "Siren eşliğinde güvenli kaçış rotalarını deneyimleme tatbikatı.",
		"price": 90,
		"stat": "x",
		"amount": 20,
		"icon": "res://assets/textures/acil_cikis_1_kosan_adam.png"
	},
	{
		"group": "Eğitim",
		"name": "Mahalle Afet Gönüllüleri Ekibi",
		"desc": "İlk müdahalede yerel ekiplere destek olacak eğitimli gönüllü vatandaş ağı.",
		"price": 110,
		"stat": "y",
		"amount": 20,
		"icon": "res://assets/textures/gonullu_1_yelekli.png",
		"requires": {"afad": 3}
	},
	{
		"group": "Eğitim",
		"name": "Deprem Müzesi Kur",
		"desc": "Deprem bilincini eğlenceli simülasyonlarla aşılayan interaktif afet eğitim müzesi.",
		"price": 200,
		"stat": "y",
		"amount": 30,
		"icon": "res://assets/textures/kitap_4_raf.png",
		"requires": {"belediye": 2}
	},
	{
		"group": "Eğitim",
		"name": "Sel Müzesi Kur",
		"desc": "Taşkın tehlikelerini görsel ve interaktif modellerle anlatan kamuya açık eğitim merkezi.",
		"price": 200,
		"stat": "y",
		"amount": 30,
		"icon": "res://assets/textures/kitap_3_yigin.png",
		"requires": {"belediye": 2}
	},
	{
		"group": "Eğitim",
		"name": "Yangın Müzesi Kur",
		"desc": "Yangın güvenliği ve ilk müdahale tekniklerini gerçekçi senaryolarla öğreten müze.",
		"price": 200,
		"stat": "y",
		"amount": 30,
		"icon": "res://assets/textures/kitap_2_acik.png",
		"requires": {"belediye": 2, "itfaiye": 2}
	},
	{
		"group": "Eğitim",
		"name": "Eğitim Parkı Kur",
		"desc": "Çocuklara ve gençlere afet farkındalığı kazandıran açık hava eğitim alanı.",
		"price": 150,
		"stat": "y",
		"amount": 25,
		"icon": "res://assets/textures/topluluk_3_mahalle.png",
		"requires": {"belediye": 3}
	},
	{
		"group": "Eğitim",
		"name": "Sel Tatbikatı Düzenle",
		"desc": "Taşkın senaryosunda hızlı tahliye ve güvenli bölgeye ulaşma alıştırması.",
		"price": 85,
		"stat": "x",
		"amount": 18,
		"icon": "res://assets/textures/gonullu_2_el_kaldiran.png"
	},
	{
		"group": "Eğitim",
		"name": "Ormanda Ateş Yakılmasını Denetle",
		"desc": "Ormanlık alanlarda ateş yakma yasağı denetimleri ve ceza sistemi uygulaması.",
		"price": 70,
		"stat": "x",
		"amount": 15,
		"icon": "res://assets/textures/brosur_3_kitapcik.png"
	},
	{
		"group": "Eğitim",
		"name": "Yangın Tatbikatı Düzenle",
		"desc": "Binalarda panik yaratmadan hızlı tahliyeyi öğreten yangın tatbikat programı.",
		"price": 80,
		"stat": "x",
		"amount": 18,
		"icon": "res://assets/textures/gonullu_3_koli.png"
	},
	# --- MEDYA grubu ---
	{
		"group": "Medya",
		"name": "Acil Durum SMS Uyarı Sistemi",
		"desc": "Afet öncesinde ve anında tüm vatandaşlara anlık bilgilendirme mesajı gönderir.",
		"price": 80,
		"stat": "y",
		"amount": 20,
		"icon": "res://assets/textures/sms_1_balon.png"
	},
	{
		"group": "Medya",
		"name": "Televizyon Kamu Spotu Kampanyası",
		"desc": "Çök-Kapan-Tutun ve doğru tahliye adımlarını anlatan ulusal TV eğitim yayınları.",
		"price": 130,
		"stat": "y",
		"amount": 25,
		"icon": "res://assets/textures/televizyon_2_modern.png",
		"requires": {"belediye": 2}
	},
	# TODO: değerleri kendim belirleyeceğim
	{
		"group": "Medya",
		"name": "Sosyal Medya",
		"desc": "Afet bilinci ve acil durum hazırlığını dijital platformlarda yayan video ve bilgilendirme serisi.",
		"price": 120,
		"stat": "y",
		"amount": 20,
		"icon": "res://assets/textures/sms_1_balon.png",
		"requires": {"belediye": 2}
	},
	{
		"group": "Medya",
		"name": "Halk İçin Afet Rehberi Gazetesi",
		"desc": "İlk yardım adımlarını ve mahalle toplanma haritalarını içeren bilgilendirici gazete eki.",
		"price": 50,
		"stat": "x",
		"amount": 10,
		"icon": "res://assets/textures/gazete_1.png"
	}
]


func _ready() -> void:
	# Sekme stil ve dinamik renk sistemini kuruyoruz
	_setup_tab_styles()
	
	# Açılışta para göstergesini güncelliyoruz
	update_money_ui()
	
	# Sekmelerdeki ürünleri dinamik olarak oluşturuyoruz
	populate_shop()
	
	# Başlangıç kilit durumlarını ürün gereksinimlerine göre yeniliyoruz
	refresh_locks()


# Belirli bir kamu binasının bir sonraki seviye yükseltme durumunu üretir
func get_building_product_data(building_id: String) -> Dictionary:
	var current_lvl: int = int(levels.get(building_id, 1))
	var b_def: Dictionary = public_building_definitions[building_id]
	var is_max: bool = (current_lvl >= 3)
	
	var target_lvl: int = current_lvl + 1 if not is_max else 3
	var building_name: String = "%s (Seviye %d)" % [b_def["base_name"], target_lvl]
	
	var building_desc: String = ""
	var price_to_next: int = 0
	var icon_path: String = ""
	
	if is_max:
		building_desc = "Maksimum seviyeye ulaşıldı."
		price_to_next = 0
		icon_path = b_def["icons"][2]
	else:
		# current_lvl == 1 -> index 0 (Seviye 2 açıklaması ve fiyatı)
		# current_lvl == 2 -> index 1 (Seviye 3 açıklaması ve fiyatı)
		var idx: int = current_lvl - 1
		building_desc = b_def["level_desc"][idx]
		price_to_next = b_def["upgrade_prices"][idx]
		icon_path = b_def["icons"][target_lvl - 1]
	
	return {
		"building_id": building_id,
		"upgrade": building_id,
		"level": current_lvl,
		"name": building_name,
		"desc": building_desc,
		"price": price_to_next,
		"stat": b_def.get("stat", "x"),
		"amount": b_def.get("amount", 20),
		"icon": icon_path,
		"is_max": is_max,
		"button_text": "Maks" if is_max else "Yükselt"
	}


# Sekme başlıklarının ve zemin renginin her sekmede dinamik değişmesini sağlar
func _setup_tab_styles() -> void:
	# Paylaşılan stilleri bozmamak için duplicate() ile yerel kopya alıyoruz
	var base_panel = tab_container.get_theme_stylebox("panel")
	if base_panel is StyleBoxFlat:
		_tab_panel_style = base_panel.duplicate()
	else:
		_tab_panel_style = StyleBoxFlat.new()
	tab_container.add_theme_stylebox_override("panel", _tab_panel_style)
	
	var base_selected = tab_container.get_theme_stylebox("tab_selected")
	if base_selected is StyleBoxFlat:
		_tab_selected_style = base_selected.duplicate()
	else:
		_tab_selected_style = StyleBoxFlat.new()
	tab_container.add_theme_stylebox_override("tab_selected", _tab_selected_style)
	
	# Sekme değiştiğinde renkleri güncellemek için sinyali bağlıyoruz
	tab_container.tab_changed.connect(_on_tab_changed)
	
	# Başlangıçta aktif sekmenin rengini uyguluyoruz
	_update_tab_color(tab_container.current_tab)


# Sekme değiştiğinde çağrılır
func _on_tab_changed(tab_idx: int) -> void:
	_update_tab_color(tab_idx)


# Belirtilen sekme indeksine göre zemin ve seçili sekme rengini günceller
func _update_tab_color(tab_idx: int) -> void:
	if tab_idx >= 0 and tab_idx < TAB_COLORS.size():
		var chosen_color: Color = TAB_COLORS[tab_idx]
		if _tab_panel_style:
			_tab_panel_style.bg_color = chosen_color
		if _tab_selected_style:
			_tab_selected_style.bg_color = chosen_color


# Para etiketini güncelleyen fonksiyon
func update_money_ui() -> void:
	if money_label != null:
		money_label.text = "Para: %d" % money


# Her sekme için ilgili Content VBoxContainer'ını bulur ve ürünleri ekler
func populate_shop() -> void:
	_all_product_rows.clear()
	var tab_names: Array[String] = ["Hazırlık", "Farkındalık", "Kamu Binaları"]
	
	for tab_name in tab_names:
		var content_container: VBoxContainer = tab_container.get_node_or_null(tab_name + "/Content") as VBoxContainer
		if content_container == null:
			continue
		
		# Hazırlık ve Farkındalık sekmelerinde alt grup başlıkları gösterilir
		var allow_group_headers: bool = (tab_name == "Hazırlık" or tab_name == "Farkındalık")
		
		if tab_name == "Kamu Binaları":
			# Sadece 4 Kamu Binası listelenir (Belediye, Hastane, AFAD, İtfaiye)
			for b_id in ["belediye", "hastane", "afad", "itfaiye"]:
				var b_data: Dictionary = get_building_product_data(b_id)
				var row = PRODUCT_ROW_SCENE.instantiate()
				content_container.add_child(row)
				row.setup(b_data)
				row.bought.connect(buy.bind(row))
				_all_product_rows.append(row)
		else:
			var product_list: Array[Dictionary] = hazirlik_products if tab_name == "Hazırlık" else farkindalik_products
			var last_group: String = ""
			
			for product in product_list:
				var current_group: String = str(product.get("group", ""))
				
				# Grup başlığı sadece izin verilen sekmelerde ve grup değiştiğinde eklenir
				if allow_group_headers and current_group != "" and current_group != last_group:
					if last_group != "":
						var section_spacer = Control.new()
						section_spacer.custom_minimum_size = Vector2(0, 10)
						content_container.add_child(section_spacer)
					
					var group_box: VBoxContainer = VBoxContainer.new()
					group_box.add_theme_constant_override("separation", 6)
					
					var group_label: Label = Label.new()
					group_label.text = current_group
					group_label.add_theme_font_size_override("font_size", 26)
					group_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
					
					var separator: HSeparator = HSeparator.new()
					separator.modulate = Color(1, 1, 1, 0.35)
					
					group_box.add_child(group_label)
					group_box.add_child(separator)
					content_container.add_child(group_box)
					last_group = current_group
				
				var row = PRODUCT_ROW_SCENE.instantiate()
				content_container.add_child(row)
				row.setup(product)
				row.bought.connect(buy.bind(row))
				_all_product_rows.append(row)


# Bir ürünün kilidinin açık olup olmadığını kontrol eder
func is_unlocked(data: Dictionary) -> bool:
	if not data.has("requires") or data["requires"].is_empty():
		return true
	var reqs: Dictionary = data["requires"]
	for b_id in reqs:
		var req_lvl: int = int(reqs[b_id])
		var cur_lvl: int = int(levels.get(b_id, 1))
		if cur_lvl < req_lvl:
			return false
	return true


# Tüm ürün satırlarının kilit durumunu levels sözlüğüne göre yeniler
func refresh_locks() -> void:
	for row in _all_product_rows:
		if not is_instance_valid(row) or not row.has_method("set_locked"):
			continue
		var data: Dictionary = row.product_data
		if not data.has("requires") or data["requires"].is_empty():
			row.set_locked(false, "")
			continue
		
		var reqs: Dictionary = data["requires"]
		var all_met: bool = true
		var condition_texts: Array[String] = []
		
		for b_id in reqs:
			var req_lvl: int = int(reqs[b_id])
			var cur_lvl: int = int(levels.get(b_id, 1))
			var b_name: String = BUILDING_DISPLAY_NAMES.get(b_id, b_id.capitalize())
			condition_texts.append("%s Sv.%d" % [b_name, req_lvl])
			if cur_lvl < req_lvl:
				all_met = false
		
		if all_met:
			row.set_locked(false, "")
		else:
			var reason: String = "Gerekli: " + ", ".join(condition_texts)
			row.set_locked(true, reason)


# Satın alma ve seviye yükseltme mantığı
func buy(data: Dictionary, row: Node = null) -> void:
	# Savunma kontrolü: Eğer ürün kilitliyse satın almayı engelliyoruz
	if not is_unlocked(data):
		print("Bu ürün kilitli, satın alınamaz!")
		return
	
	var price: int = int(data.get("price", 0))
	var stat_name: String = str(data.get("stat", ""))
	var amount: int = int(data.get("amount", 0))
	
	if money >= price:
		money -= price
		if stats.has(stat_name):
			stats[stat_name] += amount
		else:
			stats[stat_name] = amount
		
		# Eğer bu bir kamu binasıysa seviyesini artırıyoruz ve satırını yeni seviyeyle güncelliyoruz
		if data.has("upgrade") or data.has("building_id"):
			var b_id: String = str(data.get("upgrade", data.get("building_id", "")))
			levels[b_id] = min(int(levels.get(b_id, 1)) + 1, 3)
			var new_data: Dictionary = get_building_product_data(b_id)
			if row and row.has_method("setup"):
				row.setup(new_data)
			# Bina seviye atlayınca tüm kilitleri yeniliyoruz
			refresh_locks()
			print("Kamu binası yükseltildi: ", new_data.get("name", ""), " | Seviye: ", levels[b_id], " | Kalan Para: ", money)
		else:
			print("Satın alındı: ", data.get("name", ""), " | Kalan Para: ", money, " | Stats: ", stats)
		
		update_money_ui()
	else:
		print("Yetersiz para!")


# "Yükseltmeler" butonuna basılınca dükkan penceresini açar
func _on_shop_button_pressed() -> void:
	shop_panel.visible = true


# "Kapat" (X) butonuna basılınca dükkan penceresini kapatır
func _on_close_button_pressed() -> void:
	shop_panel.visible = false
