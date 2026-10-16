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
}
const SHOP_INFO := {"name": "İş yeri", "pop": 15, "risk": "Orta"}

## Gelistirme zinciri: model -> [yeni model, maliyet, gereken belediye seviyesi]
## Guvenli buyume yavas ve pahali: gelistirilen bina insaat suresince (UPGRADE_DAYS) bosalir.
const UPGRADES := {
	"house_lv0_gecekondu": ["house_lv1", 3500, 1],
	"house_lv1": ["house_lv2", 7000, 1],
	"house_lv2": ["house_lv3", 12000, 2],
	"building_townhall_lv1": ["building_townhall_lv2", 9000, 1],
	"building_townhall_lv2": ["building_townhall_lv3", 15000, 2],
	"building_firestation": ["building_firestation_lv2", 6000, 1],
	"building_firestation_lv2": ["building_firestation_lv3", 10000, 2],
	"building_hospital": ["building_hospital_lv2", 7000, 1],
	"building_hospital_lv2": ["building_hospital_lv3", 11000, 2],
	"building_afad": ["building_afad_lv2", 6000, 1],
	"building_afad_lv2": ["building_afad_lv3", 10000, 2],
}
const UPGRADE_DAYS := 2
const REINFORCE := {"house_lv1": 4000, "house_lv2": 7000}
const REINFORCE_HALL := 2  # guclendirme belediye Sv 2 ile acilir
const REMOVE_KACAK := {"house_lv1_kacak": 2500, "house_lv2_kacak": 4000}
## Hizli ama riskli buyume: kacak kata goz yummak para ve nufus getirir.
const ALLOW_KACAK := {"house_lv1": 3000, "house_lv2": 5000}
## Hasarli / yikik binalar kendiliginden onarilir (gun) ve her gun gider yazar.
const REPAIR_DAYS := {1: 2, 2: 3}  # Building.State.DAMAGED: 2 gun, COLLAPSED: 3 gun
const REPAIR_UPKEEP := {1: 80, 2: 200}
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
	if model.contains("hospital") or model.contains("afad") or model.contains("firestation"):
		return 0.12
	if model.contains("townhall") or model.contains("school"):
		return 0.25
	return 0.4


static func info(model: String) -> Dictionary:
	return BUILDING_INFO.get(model, SHOP_INFO)


# ------------------------------------------------------------------ belediye eylemleri
## "target": true olan eylemler haritada bir mahalleye tiklanarak uygulanir.
## "hall": gereken belediye seviyesi (belediye binasini gelistirince acilir).
const ACTIONS := [
	{"id": "news", "name": "Gazete İlanı", "cost": 1500, "hall": 1, "target": true, "desc": "Seçtiğin mahalleye gazete ilanı.\nO mahallede farkındalık +12"},
	{"id": "drill", "name": "Tatbikat", "cost": 2500, "hall": 1, "target": true, "desc": "Seçtiğin mahallede tahliye tatbikatı.\nO mahallede farkındalık +15"},
	{"id": "forest", "name": "Orman Önlemleri", "cost": 3500, "hall": 1, "desc": "Mangal yasağı tabelaları, yangın gözetleme.\nOrman yangını riski -%40"},
	{"id": "assembly", "name": "Toplanma Alanı", "cost": 3000, "hall": 1, "desc": "Bir parkı afet toplanma alanı yap.\nTahliye kapasitesi artar"},
	{"id": "tv", "name": "TV Kampanyası", "cost": 4500, "hall": 2, "desc": "Tüm şehirde kamu spotu.\nHer mahallede farkındalık +7"},
	{"id": "kits", "name": "Deprem Çantası", "cost": 4000, "hall": 2, "desc": "Evlere deprem çantası dağıt.\nEnkaz altındakiler daha uzun dayanır"},
	{"id": "river", "name": "Dere Islahı", "cost": 9000, "hall": 2, "desc": "Nehir kıyılarına beton duvar.\nSel hasarı büyük ölçüde azalır"},
	{"id": "warning", "name": "Erken Uyarı", "cost": 8000, "hall": 3, "desc": "Şehre siren ve SMS uyarı ağı.\nAfet anında tahliye çok daha başarılı"},
	{"id": "renewal", "name": "Kentsel Dönüşüm", "cost": 15000, "hall": 3, "desc": "Tüm gecekonduları güvenli eve dönüştür.\nİnşaat süresince boşalırlar"},
	{"id": "levee", "name": "Taşkın Seti", "cost": 7000, "hall": 3, "desc": "Dere ıslahının üstüne kalıcı set.\nSel neredeyse hiç zarar veremez"},
]

# ------------------------------------------------------------------ uyarilar (deprem asla haber verilmez!)
const FORECASTS := {
	"forest_fire": {"days": 1, "title": "Meteoroloji Uyarısı",
		"text": "Yarın çok sıcak ve rüzgarlı. Orman yangını riski %%%d!",
		"actions": [{"id": "picnic_ban", "name": "Piknik Yasağı", "cost": 1000}]},
	"flood": {"days": 2, "title": "Meteoroloji Uyarısı",
		"text": "Dağlarda yoğun yağış bekleniyor. 2 gün içinde sel riski %%%d!",
		"actions": [{"id": "evacuate_river", "name": "Kıyıyı Tahliye Et", "cost": 2500},
			{"id": "sandbag", "name": "Kum Torbası Diz", "cost": 500}]},
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
const EVENTS := [
	{"id": "bribe_floor", "title": "Müteahhitten Teklif",
		"text": "Bir müteahhit, mahalledeki iki apartmana kaçak kat çıkmak istiyor. Karşılığında belediyeye 'bağış' teklif ediyor.",
		"choices": [
			{"text": "Kabul et (+6.000 TL)", "effects": {"money": 6000, "kacak": 2, "awareness": -3,
				"later": {"days": 3, "title": "Gazetede Skandal!", "text": "Kaçak kat rüşveti basına sızdı. Halkın belediyeye güveni sarsıldı.", "effects": {"awareness": -6}}}},
			{"text": "Reddet ve denetim başlat", "effects": {"awareness": 3}},
		]},
	{"id": "river_site", "title": "Dere Kenarına Lüks Site",
		"text": "Bir şirket nehir kıyısına lüks konut sitesi yapmak istiyor. Bölge eski dere yatağı.",
		"choices": [
			{"text": "Onayla (+8.000 TL, +nüfus)", "effects": {"money": 8000, "river_site": 2, "risk_flood": 1.2, "awareness": -2}},
			{"text": "Reddet: dere yatağına yapı olmaz", "effects": {"awareness": 4}},
		]},
	{"id": "bbq_festival", "title": "Mangal Festivali",
		"text": "Esnaf, ormandaki piknik alanında büyük bir mangal festivali düzenlemek istiyor. Hava çok sıcak ve rüzgarlı.",
		"choices": [
			{"text": "İzin ver (+2.500 TL turizm)", "effects": {"money": 2500, "risk_forest": 1.5}},
			{"text": "Ertele, uyarı tabelaları koy (-500 TL)", "effects": {"money": -500, "risk_forest": 0.8, "awareness": 3}},
		]},
	{"id": "drill_parents", "title": "Tatbikata Tepki",
		"text": "Bazı veliler okuldaki deprem tatbikatının çocukları korkuttuğunu söylüyor ve iptal istiyor.",
		"choices": [
			{"text": "Tatbikatı iptal et", "effects": {"awareness": -3}},
			{"text": "Velilere anlat, devam et", "effects": {"awareness": 4, "drills": 1}},
		]},
	{"id": "fake_quake", "title": "Sahte Deprem Tahmini",
		"text": "Sosyal medyada 'yarın büyük deprem olacak' diye sahte bir tahmin yayılıyor. Halk paniğe kapılıyor.",
		"choices": [
			{"text": "Basın açıklaması yap (-800 TL)", "effects": {"money": -800, "awareness": 5}},
			{"text": "Görmezden gel", "effects": {"awareness": -4}},
		]},
	{"id": "grant", "title": "Güçlendirme Hibesi",
		"text": "Bakanlık eski binalar için güçlendirme hibesi veriyor ama başvuru masrafı var.",
		"choices": [
			{"text": "Başvur (-1.500 TL, 2 bina güçlenir)", "effects": {"money": -1500, "reinforce": 2, "awareness": 2}},
			{"text": "Uğraşmaya değmez", "effects": {}},
		]},
	{"id": "fire_truck", "title": "İtfaiye Araç Talebi",
		"text": "İtfaiye müdürü araçların eskidiğini, dar sokaklara giremediklerini söylüyor.",
		"choices": [
			{"text": "Yeni araç al (-5.000 TL)", "effects": {"money": -5000, "upgrade_service": "fire"}},
			{"text": "Bütçe yok, ertele", "effects": {"risk_fire": 1.1}},
		]},
	{"id": "interview", "title": "Gazeteci Kapıda",
		"text": "Yerel gazete, belediyenin afet hazırlıkları hakkında röportaj istiyor.",
		"choices": [
			{"text": "Röportaj ver, planı anlat", "effects": {"awareness": 4}},
			{"text": "Yorum yok", "effects": {"awareness": -2}},
		]},
	{"id": "mall_park", "title": "Toplanma Alanına AVM",
		"text": "Bir yatırımcı, parktaki afet toplanma alanına AVM yapmak istiyor.",
		"choices": [
			{"text": "Sat (+9.000 TL)", "effects": {"money": 9000, "awareness": -6, "assembly": -1}},
			{"text": "Toplanma alanı satılmaz", "effects": {"awareness": 4}},
		]},
	{"id": "illegal_power", "title": "Kaçak Elektrik",
		"text": "Gecekondu mahallesinde çok sayıda kaçak elektrik bağlantısı tespit edildi.",
		"choices": [
			{"text": "Denetle ve güvenli hat çek (-2.000 TL)", "effects": {"money": -2000, "risk_fire": 0.75}},
			{"text": "Seçim yakın, dokunma", "effects": {"risk_fire": 1.3}},
		]},
	{"id": "afad_volunteer", "title": "AFAD Gönüllü Eğitimi",
		"text": "AFAD, mahalle gönüllülerine arama-kurtarma eğitimi vermeyi teklif ediyor.",
		"choices": [
			{"text": "Katıl (-1.500 TL)", "effects": {"money": -1500, "awareness": 6, "drills": 1}},
			{"text": "Şimdi değil", "effects": {}},
		]},
	{"id": "hotel_forest", "title": "Ormanda Otel Projesi",
		"text": "Ormanın bir kısmı kesilip otel yapılması öneriliyor. Ağaçlar toprağı tutuyor ve yağmur suyunu emiyor.",
		"choices": [
			{"text": "Onayla (+9.000 TL)", "effects": {"money": 9000, "risk_forest": 1.2, "risk_flood": 1.25, "awareness": -3}},
			{"text": "Orman korunmalı", "effects": {"awareness": 3}},
		]},
	{"id": "kits_campaign", "title": "Deprem Çantası Kampanyası",
		"text": "Bir dernek her eve deprem çantası hazırlanması için kampanya başlattı ve belediyeden destek istiyor.",
		"choices": [
			{"text": "Destekle (-2.500 TL)", "effects": {"money": -2500, "awareness": 5, "kits": 1}},
			{"text": "Destek verme", "effects": {"awareness": -1}},
		]},
	{"id": "drains", "title": "Tıkalı Izgaralar",
		"text": "Yağmur suyu ızgaralarının çoğu çöp ve yaprakla tıkalı. Temizlik ekibi ek bütçe istiyor.",
		"choices": [
			{"text": "Temizlet (-2.000 TL)", "effects": {"money": -2000, "risk_flood": 0.75}},
			{"text": "Sonra bakarız", "effects": {"risk_flood": 1.2}},
		]},
	{"id": "gecekondu_deed", "title": "Gecekondu Tapusu",
		"text": "Gecekondu sakinleri tapu istiyor. Alternatif olarak kentsel dönüşüm başlatılabilir.",
		"choices": [
			{"text": "Tapu ver (+3.000 TL harç)", "effects": {"money": 3000, "awareness": -2}},
			{"text": "Kentsel dönüşüm (-6.000 TL, 3 ev yenilenir)", "effects": {"money": -6000, "upgrade": 3, "awareness": 3}},
		]},
	{"id": "camping", "title": "Kamp Sezonu",
		"text": "Turistler ormanda gelişigüzel kamp kurup ateş yakıyor.",
		"choices": [
			{"text": "Kamp alanı düzenle, bekçi koy (-1.500 TL)", "effects": {"money": -1500, "risk_forest": 0.7}},
			{"text": "Turizm iyidir, serbest bırak (+1.500 TL)", "effects": {"money": 1500, "risk_forest": 1.3}},
		]},
	{"id": "scientist", "title": "Fay Hattı Raporu",
		"text": "Bir jeoloji profesörü şehrin aktif bir fay hattına çok yakın olduğunu raporladı.",
		"choices": [
			{"text": "Raporu yayınla (-500 TL)", "effects": {"money": -500, "awareness": 6}},
			{"text": "Panik yaratmasın, rafa kaldır", "effects": {"awareness": -3, "risk_quake": 1.1}},
		]},
	{"id": "cheap_concrete", "title": "Ucuz Beton",
		"text": "Bir tedarikçi yeni inşaatlar için piyasanın yarı fiyatına beton öneriyor. Laboratuvar raporu yok.",
		"choices": [
			{"text": "Al (+4.000 TL tasarruf)", "effects": {"money": 4000, "risk_quake": 1.25, "awareness": -2}},
			{"text": "Standart dışı malzeme kullanılmaz", "effects": {"awareness": 2}},
		]},
	{"id": "help_neighbor", "title": "Komşu İlçede Sel",
		"text": "Komşu ilçe selden etkilendi ve yardım istiyor.",
		"choices": [
			{"text": "Ekip ve malzeme gönder (-3.000 TL)", "effects": {"money": -3000, "awareness": 5}},
			{"text": "Kendi işimize bakalım", "effects": {"awareness": -2}},
		]},
	{"id": "curriculum", "title": "Afet Eğitimi Dersi",
		"text": "Okullara haftalık afet bilinci dersi eklenmesi öneriliyor.",
		"choices": [
			{"text": "Ekle (-2.000 TL)", "effects": {"money": -2000, "awareness": 7}},
			{"text": "Müfredat zaten yoğun", "effects": {}},
		]},
	{"id": "coast_hotel", "title": "Sahile Otel",
		"text": "Kumsal bölgesine büyük bir otel yapılmak isteniyor. Doğal drenaj alanı betonlanacak.",
		"choices": [
			{"text": "Onayla (+7.000 TL)", "effects": {"money": 7000, "risk_flood": 1.15}},
			{"text": "Reddet", "effects": {"awareness": 2}},
		]},
	{"id": "muhtar_drill", "title": "Muhtarın Teklifi",
		"text": "Mahalle muhtarı, pazar günü mahallece tahliye tatbikatı yapmak istiyor.",
		"choices": [
			{"text": "Organize et (-1.000 TL)", "effects": {"money": -1000, "awareness": 4, "drills": 1}},
			{"text": "Gerek yok", "effects": {"awareness": -1}},
		]},
	{"id": "volunteer_fire", "title": "Gönüllü İtfaiyeciler",
		"text": "Köylüler gönüllü orman yangını ekibi kurmak istiyor, ekipman lazım.",
		"choices": [
			{"text": "Ekipman al (-1.500 TL)", "effects": {"money": -1500, "risk_forest": 0.8, "awareness": 2}},
			{"text": "Bu itfaiyenin işi", "effects": {}},
		]},
	{"id": "election", "title": "Seçim Yaklaşıyor",
		"text": "Danışmanlar 'Halk afet önlemini görmez, yolları asfaltlayalım' diyor.",
		"choices": [
			{"text": "Asfalt kampanyası (-3.000 TL)", "effects": {"money": -3000, "awareness": -3}},
			{"text": "Bütçeyi afet hazırlığına ayır (-3.000 TL)", "effects": {"money": -3000, "awareness": 6}},
		]},
	{"id": "old_school", "title": "Okulda Çatlak",
		"text": "Okul binasının kolonlarında çatlaklar fark edildi.",
		"choices": [
			{"text": "Tahliye et ve güçlendir (-5.000 TL)", "effects": {"money": -5000, "awareness": 3, "risk_quake": 0.9}},
			{"text": "Boya badana yeter", "effects": {"awareness": -4, "risk_quake": 1.1}},
		]},
	{"id": "influencer", "title": "Fenomen Videosu",
		"text": "Ünlü bir sosyal medya fenomeni afet farkındalığı videosu çekmek istiyor, sponsor arıyor.",
		"choices": [
			{"text": "Sponsor ol (-2.000 TL)", "effects": {"money": -2000, "awareness": 8}},
			{"text": "Hayır", "effects": {}},
		]},
	{"id": "stubble", "title": "Anız Yakma",
		"text": "Çiftçiler orman kenarındaki tarlalarda anız yakmak için izin istiyor.",
		"choices": [
			{"text": "İzin ver", "effects": {"risk_forest": 1.4}},
			{"text": "Yasakla, alternatif öner (-800 TL)", "effects": {"money": -800, "awareness": 3, "risk_forest": 0.9}},
		]},
	{"id": "insurance", "title": "Zorunlu Deprem Sigortası",
		"text": "Konutlarda zorunlu deprem sigortası denetimi yapılması öneriliyor.",
		"choices": [
			{"text": "Denetim başlat (+2.000 TL ceza geliri)", "effects": {"money": 2000, "awareness": 4}},
			{"text": "Vatandaşı yormayalım", "effects": {}},
		]},
	{"id": "dam", "title": "Barajdan Su Bırakılacak",
		"text": "DSİ, dağdaki barajdan yarın kontrollü su bırakılacağını bildirdi.",
		"choices": [
			{"text": "Kıyıdaki halkı uyar", "effects": {"awareness": 3, "risk_flood": 0.9}},
			{"text": "Sorun olmaz", "effects": {"risk_flood": 1.2}},
		]},
	{"id": "parking", "title": "Toplanma Alanına Otopark",
		"text": "Esnaf, meydandaki toplanma alanının otopark yapılmasını istiyor.",
		"choices": [
			{"text": "Otopark yap (+5.000 TL)", "effects": {"money": 5000, "awareness": -5}},
			{"text": "Hayır, açık alan kalmalı", "effects": {"awareness": 3}},
		]},
	{"id": "generator", "title": "Hastane Jeneratörü",
		"text": "Hastanenin jeneratörü eski; afette elektrik kesilirse yoğun bakım çalışmayabilir.",
		"choices": [
			{"text": "Yenile (-3.000 TL)", "effects": {"money": -3000, "awareness": 2}},
			{"text": "Ertele", "effects": {"awareness": -2}},
		]},
	{"id": "donation", "title": "İş İnsanından Bağış",
		"text": "Tanınmış bir iş insanı büyük bağış yapmak istiyor; karşılığında dere kenarındaki arsasına imar izni istiyor.",
		"choices": [
			{"text": "Kabul et (+10.000 TL)", "effects": {"money": 10000, "kacak": 1, "risk_flood": 1.2, "awareness": -4}},
			{"text": "Şartlı bağış kabul edilmez", "effects": {"awareness": 3}},
		]},
	{"id": "smoke_detector", "title": "Duman Dedektörü",
		"text": "Bir firma toplu alımda duman dedektörlerini maliyetine vermeyi teklif ediyor.",
		"choices": [
			{"text": "Evlere dağıt (-2.500 TL)", "effects": {"money": -2500, "risk_fire": 0.7, "awareness": 3}},
			{"text": "Gerek yok", "effects": {}},
		]},
	{"id": "bottle_cleanup", "title": "Orman Temizliği",
		"text": "Gönüllüler ormandaki cam şişe ve çöpleri toplamak için kampanya önerdi.",
		"choices": [
			{"text": "Destek ver (-1.000 TL)", "effects": {"money": -1000, "risk_forest": 0.8, "awareness": 3}},
			{"text": "Belediyenin işi değil", "effects": {"risk_forest": 1.1}},
		]},
	{"id": "tsunami_sign", "title": "Kıyı Uyarı Sistemi",
		"text": "Kıyı şeridine siren ve tahliye yönlendirme tabelaları önerildi.",
		"choices": [
			{"text": "Kur (-3.500 TL)", "effects": {"money": -3500, "awareness": 4, "drills": 1}},
			{"text": "Bize olmaz", "effects": {}},
		]},
]
