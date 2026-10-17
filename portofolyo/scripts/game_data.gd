class_name GameData
extends RefCounted
## Oyunun icerigi: olay kartlari, afet sebepleri, bilgi notlari, bina bilgileri, eylemler.
## Yeni olay eklemek icin EVENTS listesine bir sozluk ekleyin.
##
## Olay etkileri ("effects") anahtarlari:
##   money, awareness            : dogrudan eklenir
##   risk_fire, risk_forest,
##   risk_flood, risk_quake      : carpan (1.3 = %30 daha riskli, 0.7 = %30 daha az)
##   kacak: n                    : n binaya kacak kat eklenir
##   reinforce: n                : n bina guclendirilir
##   upgrade: n                  : n bina bir seviye gelisir
##   upgrade_service: "fire"     : servis binasini bir seviye gelistir
##   river_site: n               : dere yatagina n kacak site (hizli nufus, sel riski)
##   kits, drills: n             : deprem cantasi / tatbikat sayaci (tahliye basarisini artirir)
##   pop: n                      : sehre tasinan (+) / sehirden giden (-) kisi (nufus gostergesi)
##   assembly: n                 : n yeni toplanma alani
##   later: {days, title, text, effects} : birkac gun sonra ortaya cikan sonuc

const TOTAL_DAYS := 20
const START_MONEY := 15000
const START_AWARENESS := 15.0

# ------------------------------------------------------------------ binalar
const BUILDING_INFO := {
	"house_lv0_gecekondu": {"name": "Gecekondu", "pop": 6, "risk": "Çok yüksek"},
	"house_lv1": {"name": "Müstakil ev", "pop": 12, "risk": "Orta"},
	"house_lv1_kacak": {"name": "Kaçak katlı ev", "pop": 20, "risk": "Çok yüksek"},
	"house_lv1_reinforced": {"name": "Güçlendirilmiş ev", "pop": 12, "risk": "Düşük"},
	"house_lv2": {"name": "Apartman", "pop": 30, "risk": "Orta"},
	"house_lv2_kacak": {"name": "Kaçak katlı apartman", "pop": 45, "risk": "Çok yüksek"},
	"house_lv2_reinforced": {"name": "Güçlendirilmiş apartman", "pop": 30, "risk": "Düşük"},
	"house_lv3": {"name": "Depreme dayanıklı site", "pop": 55, "risk": "Çok düşük"},
	"building_townhall_lv1": {"name": "Belediye (Sv 1)", "pop": 0, "risk": "Düşük"},
	"building_townhall_lv2": {"name": "Belediye (Sv 2)", "pop": 0, "risk": "Düşük"},
	"building_townhall_lv3": {"name": "Belediye (Sv 3)", "pop": 0, "risk": "Düşük"},
	"building_hospital": {"name": "Hastane (Sv 1)", "pop": 0, "risk": "Düşük"},
	"building_hospital_lv2": {"name": "Hastane (Sv 2)", "pop": 0, "risk": "Düşük"},
	"building_hospital_lv3": {"name": "Hastane (Sv 3)", "pop": 0, "risk": "Çok düşük"},
	"building_firestation": {"name": "İtfaiye (Sv 1)", "pop": 0, "risk": "Düşük"},
	"building_firestation_lv2": {"name": "İtfaiye (Sv 2)", "pop": 0, "risk": "Düşük"},
	"building_firestation_lv3": {"name": "İtfaiye (Sv 3)", "pop": 0, "risk": "Çok düşük"},
	"building_school": {"name": "Okul", "pop": 0, "risk": "Orta"},
	"building_afad": {"name": "AFAD Merkezi (Sv 1)", "pop": 0, "risk": "Düşük"},
	"building_afad_lv2": {"name": "AFAD Merkezi (Sv 2)", "pop": 0, "risk": "Düşük"},
	"building_afad_lv3": {"name": "AFAD Merkezi (Sv 3)", "pop": 0, "risk": "Çok düşük"},
	"building_news": {"name": "Gazete / TV", "pop": 0, "risk": "Orta"},
	"building_museum_deprem": {"name": "Deprem Müzesi", "pop": 0, "risk": "Düşük"},
	"building_museum_sel": {"name": "Sel Müzesi", "pop": 0, "risk": "Düşük"},
	"building_museum_yangin": {"name": "Yangın Müzesi", "pop": 0, "risk": "Düşük"},
}
const SHOP_INFO := {"name": "İş yeri", "pop": 15, "risk": "Orta"}

## Gelistirme zinciri: model -> [yeni model, maliyet, gereken belediye seviyesi]
## Guvenli buyume yavas ve pahali: gelistirilen bina insaat suresince (UPGRADE_DAYS) bosalir.
const UPGRADES := {
	"house_lv0_gecekondu": ["house_lv1", 2500, 1],
	"house_lv1": ["house_lv2", 5000, 1],
	"house_lv2": ["house_lv3", 9000, 2],
	"building_townhall_lv1": ["building_townhall_lv2", 7000, 1],
	"building_townhall_lv2": ["building_townhall_lv3", 12000, 2],
	"building_firestation": ["building_firestation_lv2", 5000, 1],
	"building_firestation_lv2": ["building_firestation_lv3", 8000, 2],
	"building_hospital": ["building_hospital_lv2", 5000, 1],
	"building_hospital_lv2": ["building_hospital_lv3", 8000, 2],
	"building_afad": ["building_afad_lv2", 5000, 1],
	"building_afad_lv2": ["building_afad_lv3", 8000, 2],
}
const UPGRADE_DAYS := 1  # gelistirme / guclendirme ertesi gun hazir
const REINFORCE := {"house_lv1": 1800, "house_lv2": 3000}
## Magazadaki mahalle paketi: mahalledeki tum uygun binalar %50 indirimle
const DISTRICT_DISCOUNT := 0.5
const REINFORCE_HALL := 1  # guclendirme bastan acik (mahalle paketleri magazada)
## Kacak kati yikmak, goz yumarak kazanilandan pahalidir (ac-kapa ile kar edilemez).
const REMOVE_KACAK := {"house_lv1_kacak": 3000, "house_lv2_kacak": 4500}
## Hizli ama riskli buyume: kacak kata goz yummak bir kerelik "harc" + kalici nufus getirir.
const ALLOW_KACAK := {"house_lv1": 1500, "house_lv2": 2500}
## Hasarli / yikik binalar kendiliginden onarilir (gun) ve her gun gider yazar.
const REPAIR_DAYS := {1: 2, 2: 3}  # Building.State.DAMAGED: 2 gun, COLLAPSED: 3 gun
const REPAIR_UPKEEP := {1: 40, 2: 100}
## Servis binalari: model adindaki seviye kadar arac / ekip verir.
const SERVICES := {"fire": "building_firestation", "medic": "building_hospital", "rescue": "building_afad"}
const UNIT_NAMES := {"fire": "İtfaiye", "medic": "Ambulans", "rescue": "AFAD"}
const UNIT_VEHICLES := {"fire": "car_firetruck", "medic": "car_ambulance", "rescue": "car_afad_rescue"}
const UNIT_STATIONS := {"fire": "firestation", "medic": "hospital", "rescue": "afad"}

## Depremde yikilma riski (0-1). Oyun dengesini buradan ayarlayin.
static func quake_risk(model: String) -> float:
	if "gecekondu" in model:
		return 0.9
	if "kacak" in model:
		return 0.85
	if "reinforced" in model:
		return 0.12
	if model.begins_with("house_lv3"):
		return 0.05
	if model.begins_with("house_lv1"):
		return 0.5
	if model.begins_with("house_lv2"):
		return 0.45
	if model.contains("hospital") or model.contains("afad") or model.contains("firestation") or model.contains("museum"):
		return 0.12
	if model.contains("townhall") or model.contains("school"):
		return 0.25
	return 0.4


static func info(model: String) -> Dictionary:
	return BUILDING_INFO.get(model, SHOP_INFO)


# ------------------------------------------------------------------ belediye eylemleri
## "target": true olan eylemler haritada bir mahalleye tiklanarak uygulanir.
## "hall": gereken belediye seviyesi (belediye binasini gelistirince acilir).
## Magaza (shop.tscn) urunleri. Hazirlik sekmesi Deprem / Sel / Yangin olarak uce ayrilir.
##   cat     : deprem | sel | yangin | farkindalik  (Kamu Binalari sekmesi binalardan uretilir)
##   req     : gereken bina seviyeleri {belediye, itfaiye, hastane, afad}
##   once    : bir kez alinir ("Alındı" olur);  max: en fazla kac kez alinir
##   target  : satin alinca haritada bir mahalleye tiklanir
##   cost    : TL (-1 = duruma gore hesaplanir: mahalle guclendirme, kacak kat operasyonu)
const SHOP_ITEMS := [
	# --- DEPREM ---
	{"id": "reinforce_district", "cat": "deprem", "name": "Mahalle Binalarını Güçlendir", "cost": -1, "target": true,
		"icon": "res://assets/ui_icons/reinforce_district.svg", "desc": "Bir mahalleye tıkla: oradaki tüm evler depreme karşı güçlendirilir. Tek tek yaptırmaktan %50 ucuz."},
	{"id": "kacak_all", "cat": "deprem", "name": "Kaçak Kat Operasyonu", "cost": -1,
		"icon": "res://assets/ui_icons/kacak_all.svg", "desc": "Şehirdeki bütün kaçak katlar yıkılır; depremde ilk çöken binalar güvenli hâle gelir."},
	{"id": "gas_valves", "cat": "deprem", "name": "Otomatik Gaz Kesme Vanası", "cost": 3000, "once": true,
		"icon": "res://assets/ui_icons/gas_valves.svg", "desc": "Sarsıntıda gazı otomatik keser. Deprem sonrası çıkan yangınlar ve yangın riski azalır."},
	{"id": "assembly", "cat": "deprem", "name": "Deprem Toplanma Alanı", "cost": 2500, "max": 3,
		"icon": "res://assets/ui_icons/assembly.svg", "desc": "Bir parkı toplanma alanı yapar. Afette daha çok insan güvenle tahliye olur."},
	{"id": "renewal", "cat": "deprem", "name": "Kentsel Dönüşüm", "cost": 12000, "once": true, "req": {"belediye": 3},
		"icon": "res://assets/ui_icons/renewal.svg", "desc": "Bütün gecekondular depreme dayanıklı evlere dönüşür (2 gün inşaat)."},
	{"id": "warning", "cat": "deprem", "name": "Erken Uyarı Sistemi", "cost": 7000, "once": true, "req": {"belediye": 3},
		"icon": "res://assets/ui_icons/warning.svg", "desc": "Sismik sensör, siren ve SMS ağı. Her afette tahliye çok daha başarılı olur."},
	# --- SEL ---
	{"id": "drain_clean", "cat": "sel", "name": "Dere Yatağını Temizle", "cost": 2000, "once": true,
		"icon": "res://assets/ui_icons/drain_clean.svg", "desc": "Moloz ve çamur temizlenir, dere daha çok su taşır. Sel riski azalır."},
	{"id": "storm_drains", "cat": "sel", "name": "Yağmur Suyu Kanalları", "cost": 3500, "once": true,
		"icon": "res://assets/ui_icons/storm_drains.svg", "desc": "Sokaklardaki suyu toplayan yer altı kanalları. Sel riski azalır."},
	{"id": "flood_barriers", "cat": "sel", "name": "Kıyıdaki Evlere Su Bariyeri", "cost": 2500, "once": true,
		"icon": "res://assets/ui_icons/flood_barriers.svg", "desc": "Kapı ve pencerelere taşınabilir bariyer. Sel basan evler daha az hasar görür."},
	{"id": "river", "cat": "sel", "name": "Dere Islahı", "cost": 8000, "max": 2, "req": {"belediye": 2},
		"icon": "res://assets/ui_icons/river.svg", "desc": "Kıyılara beton duvar örülür, sel hasarı büyük ölçüde azalır."},
	# --- YANGIN ---
	{"id": "forest", "cat": "yangin", "name": "Ormana Termal Kamera", "cost": 3000, "once": true,
		"icon": "res://assets/ui_icons/forest.svg", "desc": "Gözetleme kulesi ve termal kamera. Orman yangını riski %40 azalır."},
	{"id": "wiring", "cat": "yangin", "name": "Eski Elektrik Tesisatını Yenile", "cost": 3000, "once": true,
		"icon": "res://assets/ui_icons/wiring.svg", "desc": "Eskimiş kablolar yenilenir. Ev yangını riski azalır."},
	{"id": "hydrants", "cat": "yangin", "name": "Sokaklara Yangın Musluğu", "cost": 3500, "once": true,
		"icon": "res://assets/ui_icons/hydrants.svg", "desc": "İtfaiye suya hemen bağlanır: yangınlar %25 daha hızlı söner."},
	{"id": "extinguishers", "cat": "yangin", "name": "Evlere Yangın Tüpü Dağıt", "cost": 2500, "once": true, "req": {"itfaiye": 2},
		"icon": "res://assets/ui_icons/extinguishers.svg", "desc": "Halk küçük yangına ilk müdahaleyi yapar: yangın daha yavaş büyür, itfaiyeye zaman kalır."},
	{"id": "plane", "cat": "yangin", "name": "Yangın Söndürme Uçağı", "cost": 9000, "once": true, "req": {"itfaiye": 3},
		"icon": "res://assets/ui_icons/plane.svg", "desc": "Orman yangınına havadan müdahale: yangın yarı hızda yayılır, söndürme kolaylaşır."},
	# --- FARKINDALIK ---
	{"id": "news", "cat": "farkindalik", "name": "Afet Rehberi Gazetesi", "cost": 1200, "target": true,
		"icon": "res://assets/ui_icons/news.svg", "desc": "Bir mahalleye tıkla: o mahallede farkındalık +12."},
	{"id": "drill", "cat": "farkindalik", "name": "Tahliye Tatbikatı", "cost": 2000, "target": true,
		"icon": "res://assets/ui_icons/drill.svg", "desc": "Bir mahalleye tıkla: farkındalık +15, halk toplanma alanını öğrenir."},
	{"id": "booklet", "cat": "farkindalik", "name": "Okullara Eğitim Kitapçığı", "cost": 1500,
		"icon": "res://assets/ui_icons/booklet.svg", "desc": "Çocuklar öğrenir, ailelerine anlatır. Tüm şehirde farkındalık +4."},
	{"id": "kits", "cat": "farkindalik", "name": "Deprem Çantası Kampanyası", "cost": 3500, "max": 2, "req": {"belediye": 2},
		"icon": "res://assets/ui_icons/kits.svg", "desc": "Enkaz altındakiler daha uzun dayanır. Sokakta çantalı insanlar görürsün."},
	{"id": "tv", "cat": "farkindalik", "name": "TV Kamu Spotu", "cost": 4000, "req": {"belediye": 2},
		"icon": "res://assets/ui_icons/tv.svg", "desc": "Çök-Kapan-Tutun anlatılır. Tüm şehirde farkındalık +7."},
	{"id": "volunteers", "cat": "farkindalik", "name": "Mahalle Afet Gönüllüleri", "cost": 4000, "once": true, "req": {"afad": 2},
		"icon": "res://assets/ui_icons/volunteers.svg", "desc": "Eğitimli gönüllüler AFAD'a destek olur: enkaz kurtarma %20 hızlanır."},
	{"id": "museum_deprem", "cat": "farkindalik", "name": "Deprem Müzesi", "cost": 6000, "once": true, "req": {"belediye": 2},
		"icon": "res://assets/textures/deprem_muze_1_klasik.png", "desc": "Haritadaki arsaya müze kurulur. Farkındalık +6, halk depremde daha doğru davranır (tahliye artar)."},
	{"id": "museum_sel", "cat": "farkindalik", "name": "Sel Müzesi", "cost": 6000, "once": true, "req": {"belediye": 2},
		"icon": "res://assets/textures/sel_muze_1_klasik.png", "desc": "Haritadaki arsaya müze kurulur. Farkındalık +6, sel riski %15 azalır."},
	{"id": "museum_yangin", "cat": "farkindalik", "name": "Yangın Müzesi", "cost": 6000, "once": true, "req": {"belediye": 2, "itfaiye": 2},
		"icon": "res://assets/textures/yangin_muze_1_klasik.png", "desc": "Haritadaki arsaya müze kurulur. Farkındalık +6, ev ve orman yangını riski %15 azalır."},
]
const SHOP_CATS := {"deprem": "Deprem", "sel": "Sel", "yangin": "Yangın", "farkindalik": "Farkındalık"}


static func shop_item(id: String) -> Dictionary:
	for it in SHOP_ITEMS:
		if it.id == id:
			return it
	return {}


# ------------------------------------------------------------------ uyarilar (deprem asla haber verilmez!)
const FORECASTS := {
	"forest_fire": {"days": 1, "title": "Meteoroloji Uyarısı",
		"text": "Yarın çok sıcak ve rüzgarlı. Orman yangını riski %%%d!",
		"actions": [{"id": "picnic_ban", "name": "Piknik Yasağı", "cost": 1000}]},
	"flood": {"days": 2, "title": "Meteoroloji Uyarısı",
		"text": "Dağlarda yoğun yağış bekleniyor. 2 gün içinde sel riski %%%d!",
		"actions": [{"id": "evacuate_river", "name": "Kıyıyı Tahliye Et", "cost": 2500},
			{"id": "sandbag", "name": "Kum Torbası Diz", "cost": 2000}]},
	"house_fire": {"days": 1, "title": "İtfaiye Uyarısı",
		"text": "Soğuk hava nedeniyle soba ve ısıtıcı kullanımı artacak. Yangın riski %%%d!",
		"actions": [{"id": "stove_check", "name": "Soba Denetimi", "cost": 1500}]},
}

# ------------------------------------------------------------------ afet mesajlari
const CAUSES := {
	"house_fire": [
		"Ocak açık unutuldu! %s yanmaya başladı.",
		"Prize aşırı yüklenen elektrikli ısıtıcı kıvılcım çıkardı, %s alev aldı.",
		"Balkonda unutulan mangal kömürü rüzgarla tutuştu, %s yanıyor.",
		"Kaçak elektrik bağlantısı kısa devre yaptı, %s yangında!",
		"Mutfakta kızgın yağ tutuştu ve su döküldü, alevler %s binasını sardı.",
		"Söndürülmeden atılan sigara perdeyi tutuşturdu, %s yanıyor.",
	],
	"forest_fire": [
		"Ormanda mangal yapan bir grup ateşi söndürmeden ayrıldı. Orman yangını başladı!",
		"Ormana atılan bir cam şişe güneşte büyüteç gibi davrandı, kuru otlar tutuştu!",
		"Piknikçilerin attığı sigara izmariti kuru yaprakları tutuşturdu!",
		"Rüzgarlı havada yakılan piknik ateşinden sıçrayan kıvılcım ormanı sardı!",
		"Anız yakımı kontrolden çıktı ve ormana sıçradı!",
	],
	"flood": [
		"Belediye dere ıslahı yapmadığı için şiddetli yağışta nehir taştı!",
		"Dağlardan gelen sağanak sonrası nehir yatağına sığmadı, sel sokakları bastı!",
		"Tıkalı kanalizasyon ızgaraları suyu çekemedi, nehir kenarı sular altında!",
		"Dere yatağına yapılan evler suyun yolunu kapattı, sel kıyıyı yuttu!",
	],
	"flood_protected": [
		"Şiddetli yağışta nehir yükseldi ama dere ıslahı sayesinde taşkın sınırlı kaldı.",
	],
	"quake": [
		"Fay hattında %s büyüklüğünde deprem! Binalar sallanıyor!",
	],
}

const TIPS := {
	"quake": [
		"Depremde ÇÖK-KAPAN-TUTUN! Sarsıntı bitince toplanma alanına gidin.",
		"Deprem çantasında su, el feneri, düdük, ilk yardım malzemesi ve önemli belgeler olmalı.",
		"Kaçak kat ve izinsiz tadilat binanın taşıyıcı sistemini zayıflatır.",
		"Eski binalar güçlendirme ile çok daha dayanıklı hale gelir.",
	],
	"house_fire": [
		"Evden çıkarken ocak, ütü ve ısıtıcıların kapalı olduğunu kontrol edin.",
		"Yanan yağın üzerine asla su dökmeyin; kapağını kapatın.",
		"Evinizde yangın tüpü ve duman dedektörü bulundurun.",
	],
	"forest_fire": [
		"Ormanda mangal yakmayın, ateşi tamamen söndürmeden ayrılmayın.",
		"Cam şişe ve çöpleri ormanda bırakmayın; güneşte yangın başlatabilir.",
		"Orman yangınını gördüğünüzde 112'yi arayın.",
		"Nehirler ve yollar yangının yayılmasını durduran doğal şeritlerdir.",
	],
	"flood": [
		"Dere yataklarına yapı yapılmamalı; su eninde sonunda kendi yolunu bulur.",
		"Sel sırasında araçla veya yürüyerek sulara girmeyin.",
		"Dere ıslahı ve temiz kanalizasyon sel riskini büyük ölçüde azaltır.",
	],
}

# ------------------------------------------------------------------ olay kartlari
## Her kartta uc secenek; hicbiri bedava "dogru cevap" degildir: para, nufus, farkindalik, risk ve
## karakterle iliski arasinda takas. Sonuclar secimden once gosterilmez (sadece maliyet), secince
## karar kartinda yesil ++ / kirmizi -- olarak listelenir. "pop": karara bagli tasinan / giden kisi.
const EVENTS := [
	{"id": "bribe_floor", "title": "Müteahhitten Teklif",
		"text": "Bir müteahhit, mahalledeki iki apartmana ek kat çıkmak istiyor. Karşılığında belediyeye 'bağış' teklif ediyor.",
		"choices": [
			{"text": "Bağışı al, iki kata da izin ver", "effects": {"money": 6000, "kacak": 2, "pop": 90,
				"later": {"days": 3, "title": "Gazetede Skandal!", "text": "Kat izni karşılığı bağış basına sızdı. Halkın belediyeye güveni sarsıldı.", "effects": {"awareness": -5}}}},
			{"text": "Tek kata izin ver, projeyi denetlet", "effects": {"money": 2500, "kacak": 1, "pop": 40, "awareness": -1}},
			{"text": "Reddet, binaları denetime al", "effects": {"money": -800, "awareness": 3, "pop": -40}},
		]},
	{"id": "river_site", "title": "Dere Kenarına Konut Sitesi",
		"text": "Bir şirket nehir kıyısına büyük bir konut sitesi yapmak istiyor. Bölge eski dere yatağı ama şehrin konut ihtiyacı büyük.",
		"choices": [
			{"text": "Projeyi olduğu gibi onayla", "effects": {"money": 8000, "river_site": 2, "pop": 150, "risk_flood": 1.25}},
			{"text": "Kıyıdan geri çekilerek yapılsın", "effects": {"money": 3500, "pop": 80, "risk_flood": 1.05}},
			{"text": "Bu araziye yapı izni verme", "effects": {"awareness": 3, "pop": -60}},
		]},
	{"id": "bbq_festival", "title": "Mangal Festivali",
		"text": "Esnaf, ormandaki piknik alanında büyük bir mangal festivali düzenlemek istiyor. Hava sıcak ve rüzgarlı.",
		"choices": [
			{"text": "Ormanda yapılsın", "effects": {"money": 2500, "pop": 40, "risk_forest": 1.4, "build": {"where": "camp", "model": "festival", "label": "Mangal Festivali"}}},
			{"text": "Şehir meydanına taşı", "effects": {"money": 1200, "awareness": 1, "risk_fire": 1.05}},
			{"text": "Festivali sonbahara ertele", "effects": {"money": -300, "awareness": 2, "risk_forest": 0.85}},
		]},
	{"id": "drill_parents", "title": "Tatbikata Tepki",
		"text": "Bazı veliler okuldaki deprem tatbikatının çocukları korkuttuğunu söylüyor ve iptal istiyor.",
		"choices": [
			{"text": "Tatbikatı iptal et", "effects": {"money": 500, "awareness": -2}},
			{"text": "Velilere anlat, devam et", "effects": {"money": -600, "awareness": 3, "drills": 1}},
			{"text": "Oyunlaştırılmış kısa tatbikat yap", "effects": {"money": -1200, "awareness": 4, "drills": 1}},
		]},
	{"id": "fake_quake", "title": "Sahte Deprem Tahmini",
		"text": "Sosyal medyada 'yarın büyük deprem olacak' diye sahte bir tahmin yayılıyor. Halk paniğe kapılıyor.",
		"choices": [
			{"text": "Basın açıklaması yap", "effects": {"money": -800, "awareness": 4}},
			{"text": "Bilim insanlarıyla canlı yayın yap", "effects": {"money": -2000, "awareness": 7}},
			{"text": "Kendi kendine söner, karışma", "effects": {"awareness": -3, "pop": -50}},
		]},
	{"id": "grant", "title": "Güçlendirme Hibesi",
		"text": "Bakanlık eski binalar için güçlendirme hibesi veriyor ama başvuru dosyası masraflı ve uzun.",
		"choices": [
			{"text": "Danışmanla tam başvuru yap", "effects": {"money": -1500, "reinforce": 2, "awareness": 1}},
			{"text": "Dosyayı belediye ekibi hazırlasın", "effects": {"money": -400, "reinforce": 1}},
			{"text": "Bu dönem başvurma", "effects": {}},
		]},
	{"id": "fire_truck", "title": "İtfaiye Araç Talebi",
		"text": "İtfaiye müdürü araçların eskidiğini, dar sokaklara giremediklerini söylüyor.",
		"choices": [
			{"text": "Yeni araç al", "effects": {"money": -5000, "upgrade_service": "fire"}},
			{"text": "Eski aracı revizyona sok", "effects": {"money": -1800, "risk_fire": 0.9}},
			{"text": "Bütçe yok, ertele", "effects": {"risk_fire": 1.15}},
		]},
	{"id": "interview", "title": "Gazeteci Kapıda",
		"text": "Yerel gazete, belediyenin afet hazırlıkları hakkında uzun bir röportaj istiyor.",
		"choices": [
			{"text": "Her şeyi açıkça anlat", "effects": {"awareness": 3,
				"later": {"days": 2, "title": "Röportaj Gündemde", "text": "Röportajda eksikler de konuşuldu; meclis acil hazırlık bütçesi istedi.", "effects": {"money": -1000}}}},
			{"text": "Kısa yazılı açıklama gönder", "effects": {"awareness": 1}},
			{"text": "Röportajı reddet", "effects": {"awareness": -2}},
		]},
	{"id": "mall_park", "title": "Toplanma Alanına AVM",
		"text": "Bir yatırımcı, parktaki afet toplanma alanına AVM yapmak istiyor. Yüzlerce kişiye iş çıkacak.",
		"choices": [
			{"text": "Arsayı sat", "effects": {"money": 9000, "pop": 80, "awareness": -4, "build": {"where": "park", "model": "building_F", "label": "AVM"}}},
			{"text": "Yarısını sat, toplanma alanı kalsın", "effects": {"money": 4000, "pop": 30, "awareness": -1}},
			{"text": "Satma", "effects": {"awareness": 2, "pop": -30}},
		]},
	{"id": "illegal_power", "title": "Kaçak Elektrik",
		"text": "Gecekondu mahallesinde çok sayıda kaçak elektrik bağlantısı tespit edildi.",
		"choices": [
			{"text": "Denetle, güvenli hat çek", "effects": {"money": -2000, "risk_fire": 0.75}},
			{"text": "Uyar, kendileri düzeltsin", "effects": {"awareness": 1, "risk_fire": 0.95}},
			{"text": "Seçim yakın, dokunma", "effects": {"pop": 30, "risk_fire": 1.3}},
		]},
	{"id": "afad_volunteer", "title": "AFAD Gönüllü Eğitimi",
		"text": "AFAD, mahalle gönüllülerine arama-kurtarma eğitimi vermeyi teklif ediyor. Eğitim yeri ve malzeme belediyeden.",
		"choices": [
			{"text": "Tüm mahallelerle katıl", "effects": {"money": -2500, "awareness": 6, "drills": 1}},
			{"text": "Tek mahalleyle başla", "effects": {"money": -900, "awareness": 3}},
			{"text": "Şimdi değil", "effects": {}},
		]},
	{"id": "hotel_forest", "title": "Ormana AVM",
		"text": "Bir yatırımcı ormanın kıyısını açıp AVM yapmak istiyor. Ağaçlar toprağı tutar, yağmuru emer.",
		"choices": [
			{"text": "Onayla", "effects": {"money": 9000, "pop": 70, "risk_forest": 1.2, "risk_flood": 1.2, "awareness": -3,
				"build": {"where": "forest", "model": "building_G", "label": "AVM"}}},
			{"text": "Küçült, ağaçlandırma şartı koy", "effects": {"money": 4000, "pop": 30, "risk_flood": 1.08, "awareness": -1}},
			{"text": "Ormana dokunulmasın", "effects": {"awareness": 2}},
		]},
	{"id": "kits_campaign", "title": "Deprem Çantası Kampanyası",
		"text": "Bir dernek her eve deprem çantası hazırlanması için kampanya başlattı ve belediyeden destek istiyor.",
		"choices": [
			{"text": "Tüm evlere destekle", "effects": {"money": -2500, "awareness": 4, "kits": 1}},
			{"text": "Sadece yaşlı ve engelli hanelere", "effects": {"money": -1000, "awareness": 2}},
			{"text": "Destek verme", "effects": {"awareness": -1}},
		]},
	{"id": "drains", "title": "Tıkalı Izgaralar",
		"text": "Yağmur suyu ızgaralarının çoğu çöp ve yaprakla tıkalı. Temizlik ekibi ek bütçe istiyor.",
		"choices": [
			{"text": "Hemen temizlet", "effects": {"money": -2000, "risk_flood": 0.75}},
			{"text": "Gönüllü temizlik günü düzenle", "effects": {"money": -400, "awareness": 2, "risk_flood": 0.9}},
			{"text": "Sonra bakarız", "effects": {"risk_flood": 1.2}},
		]},
	{"id": "gecekondu_deed", "title": "Gecekondu Tapusu",
		"text": "Gecekondu sakinleri tapu istiyor. Alternatif olarak kentsel dönüşüm başlatılabilir.",
		"choices": [
			{"text": "Tapu ver", "effects": {"money": 3000, "pop": 60, "awareness": -1, "risk_quake": 1.05}},
			{"text": "Kentsel dönüşüm başlat", "effects": {"money": -6000, "upgrade": 3, "awareness": 2, "pop": -30}},
			{"text": "Güçlendirme kredisi ver", "effects": {"money": -2500, "upgrade": 1, "awareness": 1}},
		]},
	{"id": "camping", "title": "Kamp Sezonu",
		"text": "Turistler ormanda gelişigüzel kamp kurup ateş yakıyor. Esnaf turizmden memnun.",
		"choices": [
			{"text": "Kamp alanı düzenle, bekçi koy", "effects": {"money": -1500, "risk_forest": 0.7}},
			{"text": "Kamp ücreti al, ateş yasağı koy", "effects": {"money": 800, "risk_forest": 0.95}},
			{"text": "Turizm iyidir, serbest bırak", "effects": {"money": 1500, "pop": 30, "risk_forest": 1.3, "build": {"where": "camp", "model": "tents", "label": "Kamp"}}},
		]},
	{"id": "scientist", "title": "Fay Hattı Raporu",
		"text": "Bir jeoloji profesörü şehrin aktif bir fay hattına çok yakın olduğunu raporladı.",
		"choices": [
			{"text": "Raporu kamuoyuna açıkla", "effects": {"money": -500, "awareness": 5, "pop": -60}},
			{"text": "Önce muhtarlara anlat", "effects": {"money": -300, "awareness": 2}},
			{"text": "Panik yaratmasın, rafa kaldır", "effects": {"awareness": -1, "risk_quake": 1.1}},
		]},
	{"id": "cheap_concrete", "title": "Ucuz Beton",
		"text": "Bir tedarikçi yeni inşaatlar için piyasanın yarı fiyatına beton öneriyor. Laboratuvar raporu yok.",
		"choices": [
			{"text": "Al", "effects": {"money": 4000, "risk_quake": 1.2}},
			{"text": "Numune aldırıp test ettir", "effects": {"money": -600,
				"later": {"days": 2, "title": "Test Sonucu", "text": "Beton standart dışı çıktı; tedarikçi elendi. Basın titizliği övdü.", "effects": {"awareness": 3}}}},
			{"text": "Teklifi geri çevir", "effects": {"awareness": 1}},
		]},
	{"id": "help_neighbor", "title": "Komşu İlçede Sel",
		"text": "Komşu ilçe selden etkilendi ve yardım istiyor. Ekip göndermek bizim şehri birkaç gün zayıf bırakır.",
		"choices": [
			{"text": "Ekip ve malzeme gönder", "effects": {"money": -3000, "awareness": 4,
				"later": {"days": 4, "title": "Komşudan Teşekkür", "text": "Komşu ilçe, ekiplerini bizim mahallelere ortak tatbikata gönderdi.", "effects": {"drills": 1, "awareness": 2}}}},
			{"text": "Sadece malzeme gönder", "effects": {"money": -1200, "awareness": 2}},
			{"text": "Kendi işimize bakalım", "effects": {"awareness": -2}},
		]},
	{"id": "curriculum", "title": "Afet Eğitimi Dersi",
		"text": "Okullara haftalık afet bilinci dersi eklenmesi öneriliyor. Öğretmen eğitimi belediyeden.",
		"choices": [
			{"text": "Haftalık ders ekle", "effects": {"money": -2000, "awareness": 6}},
			{"text": "Ayda bir seminer yap", "effects": {"money": -700, "awareness": 2}},
			{"text": "Müfredat zaten yoğun", "effects": {}},
		]},
	{"id": "coast_hotel", "title": "Sahile Otel",
		"text": "Kumsal bölgesine büyük bir otel yapılmak isteniyor. Doğal drenaj alanı betonlanacak.",
		"choices": [
			{"text": "Onayla", "effects": {"money": 7000, "pop": 60, "risk_flood": 1.15, "build": {"where": "beach", "model": "building_H", "label": "Otel"}}},
			{"text": "Yüksek zeminli, drenajlı olsun", "effects": {"money": 3000, "pop": 30, "risk_flood": 1.03}},
			{"text": "Kumsal boş kalsın", "effects": {"awareness": 1}},
		]},
	{"id": "muhtar_drill", "title": "Muhtarın Teklifi",
		"text": "Mahalle muhtarı, pazar günü mahallece tahliye tatbikatı yapmak istiyor.",
		"choices": [
			{"text": "Belediye organize etsin", "effects": {"money": -1000, "awareness": 4, "drills": 1}},
			{"text": "Muhtar yapsın, afiş verelim", "effects": {"money": -200, "awareness": 1}},
			{"text": "Gerek yok", "effects": {"awareness": -1}},
		]},
	{"id": "volunteer_fire", "title": "Gönüllü İtfaiyeciler",
		"text": "Köylüler gönüllü orman yangını ekibi kurmak istiyor, ekipman lazım.",
		"choices": [
			{"text": "Ekipman al", "effects": {"money": -1500, "risk_forest": 0.8, "awareness": 2}},
			{"text": "İtfaiyeyle ortak eğitim ver", "effects": {"money": -600, "risk_forest": 0.9}},
			{"text": "Bu itfaiyenin işi", "effects": {}},
		]},
	{"id": "election", "title": "Seçim Yaklaşıyor",
		"text": "Danışmanlar 'Halk afet önlemini görmez, yolları asfaltlayalım' diyor. Bütçe ikisine birden yetmez.",
		"choices": [
			{"text": "Asfalt kampanyası", "effects": {"money": -3000, "pop": 120, "awareness": -2}},
			{"text": "Bütçeyi afet hazırlığına ayır", "effects": {"money": -3000, "awareness": 6}},
			{"text": "Yarı yarıya böl", "effects": {"money": -3000, "pop": 50, "awareness": 3}},
		]},
	{"id": "old_school", "title": "Okulda Çatlak",
		"text": "Okul binasının kolonlarında çatlaklar fark edildi.",
		"choices": [
			{"text": "Tahliye et ve güçlendir", "effects": {"money": -5000, "awareness": 3, "risk_quake": 0.88}},
			{"text": "Acil destek kolonu koy", "effects": {"money": -2000, "risk_quake": 0.95}},
			{"text": "Boya badana yeter", "effects": {"awareness": -3, "risk_quake": 1.1}},
		]},
	{"id": "influencer", "title": "Fenomen Videosu",
		"text": "Ünlü bir sosyal medya fenomeni afet farkındalığı videosu çekmek istiyor, sponsor arıyor.",
		"choices": [
			{"text": "Sponsor ol", "effects": {"money": -2000, "awareness": 6}},
			{"text": "Belediye hesabında ortak video", "effects": {"money": -500, "awareness": 2}},
			{"text": "İlgilenmiyoruz", "effects": {}},
		]},
	{"id": "stubble", "title": "Anız Yakma",
		"text": "Çiftçiler orman kenarındaki tarlalarda anız yakmak için izin istiyor. Yasak çiftçiye pahalıya patlıyor.",
		"choices": [
			{"text": "İzin ver", "effects": {"money": 600, "risk_forest": 1.35}},
			{"text": "Kontrollü yakım, itfaiye nöbette", "effects": {"money": -700, "risk_forest": 1.05}},
			{"text": "Yasakla, alternatif öner", "effects": {"money": -800, "awareness": 2, "risk_forest": 0.9}},
		]},
	{"id": "insurance", "title": "Zorunlu Deprem Sigortası",
		"text": "Konutlarda zorunlu deprem sigortası denetimi yapılması öneriliyor. Sigortasızlara ceza kesilebilir.",
		"choices": [
			{"text": "Sıkı denetim, ceza kes", "effects": {"money": 2000, "awareness": 3, "pop": -40}},
			{"text": "Bilgilendirme kampanyası yap", "effects": {"money": -800, "awareness": 2}},
			{"text": "Vatandaşı yormayalım", "effects": {}},
		]},
	{"id": "dam", "title": "Barajdan Su Bırakılacak",
		"text": "DSİ, dağdaki barajdan yarın kontrollü su bırakılacağını bildirdi.",
		"choices": [
			{"text": "Kıyıyı tahliye et", "effects": {"money": -1200, "awareness": 2, "risk_flood": 0.8}},
			{"text": "Kıyıdaki halkı uyar", "effects": {"awareness": 2, "risk_flood": 0.92}},
			{"text": "Sorun olmaz", "effects": {"risk_flood": 1.2}},
		]},
	{"id": "parking", "title": "Toplanma Alanına Otopark",
		"text": "Esnaf, meydandaki toplanma alanının otopark yapılmasını istiyor. Çarşıya müşteri gelmiyor.",
		"choices": [
			{"text": "Otopark yap", "effects": {"money": 5000, "pop": 40, "awareness": -3, "build": {"where": "plaza", "model": "parking", "label": "Otopark"}}},
			{"text": "Hafta içi otopark, afette boşaltılır", "effects": {"money": 2000, "awareness": -1}},
			{"text": "Açık alan kalmalı", "effects": {"awareness": 2}},
		]},
	{"id": "generator", "title": "Hastane Jeneratörü",
		"text": "Hastanenin jeneratörü eski; afette elektrik kesilirse yoğun bakım çalışmayabilir.",
		"choices": [
			{"text": "Yeni jeneratör ve ek ambulans", "effects": {"money": -4000, "upgrade_service": "medic"}},
			{"text": "Seyyar jeneratör kirala", "effects": {"money": -1200, "awareness": 1}},
			{"text": "Ertele", "effects": {
				"later": {"days": 3, "title": "Elektrik Kesintisi", "text": "Hastanede kesinti oldu, ameliyatlar ertelendi. Halk tepkili.", "effects": {"awareness": -4}}}},
		]},
	{"id": "donation", "title": "İş İnsanından Bağış",
		"text": "Tanınmış bir iş insanı büyük bağış yapmak istiyor; karşılığında dere kenarındaki arsasına imar izni istiyor.",
		"choices": [
			{"text": "Kabul et", "effects": {"money": 10000, "kacak": 1, "risk_flood": 1.2, "awareness": -3}},
			{"text": "Bağışı al, imarı meclise götür", "effects": {"money": 4000,
				"later": {"days": 3, "title": "Meclis Kararı", "text": "Meclis imarı reddetti; iş insanı bağışın yarısını geri istedi.", "effects": {"money": -2000}}}},
			{"text": "Şartlı bağış kabul edilmez", "effects": {"awareness": 2}},
		]},
	{"id": "smoke_detector", "title": "Duman Dedektörü",
		"text": "Bir firma toplu alımda duman dedektörlerini maliyetine vermeyi teklif ediyor.",
		"choices": [
			{"text": "Tüm evlere dağıt", "effects": {"money": -2500, "risk_fire": 0.7}},
			{"text": "Sadece gecekondulara", "effects": {"money": -900, "risk_fire": 0.88}},
			{"text": "Gerek yok", "effects": {}},
		]},
	{"id": "bottle_cleanup", "title": "Orman Temizliği",
		"text": "Gönüllüler ormandaki cam şişe ve çöpleri toplamak için kampanya önerdi.",
		"choices": [
			{"text": "Belediye araç ve ekip versin", "effects": {"money": -1000, "risk_forest": 0.8, "awareness": 2}},
			{"text": "Okullarla ortak temizlik günü", "effects": {"money": -300, "awareness": 2, "risk_forest": 0.92}},
			{"text": "Belediyenin işi değil", "effects": {"risk_forest": 1.1}},
		]},
	{"id": "tsunami_sign", "title": "Kıyı Uyarı Sistemi",
		"text": "Kıyı şeridine siren ve tahliye yönlendirme tabelaları önerildi.",
		"choices": [
			{"text": "Siren ve tabela kur", "effects": {"money": -3500, "awareness": 3, "drills": 1, "risk_flood": 0.92}},
			{"text": "Sadece tabela kur", "effects": {"money": -1000, "awareness": 2}},
			{"text": "Bize olmaz", "effects": {}},
		]},
]
