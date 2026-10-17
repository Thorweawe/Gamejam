class_name Characters
extends RefCounted
## Oyundaki konusan karakterler: gorunus (CharacterFigure icin), ses perdesi, selam ve tepki cumleleri.
## Karar kartlarini bu karakterler sunar. Oyuncunun kararlari iliski puanini (-3..+3) degistirir;
## karakter sonraki gelisinde buna gore selamlar ve yuz ifadesiyle gelir.

## look anahtarlari: skin, hair, hair_color, outfit, outfit2, hat, glasses, mustache, beard, tie, extra
const CHARS := {
	"baskan": {"name": "Başkan Kerem Yıldız", "short": "Başkan", "title": "Belediye Başkanı", "pitch": 0.9, "color": Color(0.4, 0.68, 1.0),
		"look": {"skin": Color(0.87, 0.67, 0.52), "hair": "short", "hair_color": Color(0.17, 0.12, 0.1),
			"outfit": Color(0.16, 0.22, 0.38), "outfit2": Color(0.95, 0.95, 0.97), "tie": Color(0.8, 0.15, 0.15), "beard": true}},
	"nermin": {"name": "Nermin Hanım", "short": "Nermin", "title": "Başkanlık Sekreteri", "pitch": 1.35, "color": Color(0.85, 0.45, 0.9),
		"look": {"skin": Color(0.95, 0.78, 0.66), "hair": "bun", "hair_color": Color(0.62, 0.28, 0.14),
			"outfit": Color(0.55, 0.32, 0.65), "outfit2": Color(0.98, 0.92, 0.85), "glasses": "round", "extra": "pearls", "blush": true}},
	"selim": {"name": "Selim Karataş", "short": "Selim Bey", "title": "Müteahhit", "pitch": 0.95, "color": Color(1.0, 0.8, 0.3),
		"look": {"skin": Color(0.8, 0.6, 0.45), "hair": "slick", "hair_color": Color(0.32, 0.2, 0.12),
			"outfit": Color(0.93, 0.92, 0.88), "outfit2": Color(0.2, 0.2, 0.22), "glasses": "sun", "mustache": "thin", "extra": "chain"}},
	"husnu": {"name": "Hüsnü Amca", "short": "Muhtar Hüsnü", "title": "Dere Mahallesi Muhtarı", "pitch": 0.8, "color": Color(0.7, 0.55, 0.4),
		"look": {"skin": Color(0.85, 0.66, 0.5), "hair": "bald_sides", "hair_color": Color(0.82, 0.82, 0.8),
			"outfit": Color(0.45, 0.33, 0.22), "outfit2": Color(0.85, 0.85, 0.8), "hat": "cap", "mustache": "big"}},
	"murat": {"name": "Murat Şef", "short": "Şef Murat", "title": "İtfaiye Müdürü", "pitch": 0.85, "color": Color(1.0, 0.45, 0.3),
		"look": {"skin": Color(0.82, 0.62, 0.48), "hair": "short", "hair_color": Color(0.2, 0.15, 0.1),
			"outfit": Color(0.18, 0.18, 0.22), "outfit2": Color(0.95, 0.8, 0.2), "hat": "fire_helmet", "mustache": "big", "extra": "stripes"}},
	"elif": {"name": "Elif Koç", "short": "Elif Hanım", "title": "AFAD Koordinatörü", "pitch": 1.2, "color": Color(1.0, 0.6, 0.2),
		"look": {"skin": Color(0.9, 0.72, 0.58), "hair": "pony", "hair_color": Color(0.25, 0.16, 0.1),
			"outfit": Color(1.0, 0.5, 0.12), "outfit2": Color(0.15, 0.2, 0.35), "hat": "hardhat", "extra": "stripes"}},
	"ayse": {"name": "Ayşe Öğretmen", "short": "Ayşe Öğretmen", "title": "İlkokul Müdürü", "pitch": 1.25, "color": Color(0.45, 0.85, 0.55),
		"look": {"skin": Color(0.92, 0.74, 0.6), "hair": "long", "hair_color": Color(0.12, 0.09, 0.08),
			"outfit": Color(0.3, 0.6, 0.4), "outfit2": Color(0.97, 0.97, 0.95)}},
	"tolga": {"name": "Tolga Er", "short": "Gazeteci Tolga", "title": "Yerel Gazete Muhabiri", "pitch": 1.05, "color": Color(0.4, 0.75, 1.0),
		"look": {"skin": Color(0.88, 0.7, 0.55), "hair": "messy", "hair_color": Color(0.35, 0.22, 0.12),
			"outfit": Color(0.25, 0.45, 0.75), "outfit2": Color(0.9, 0.9, 0.9), "beard": true, "extra": "badge"}},
	"oguz": {"name": "Prof. Dr. Oğuz Taner", "short": "Prof. Oğuz", "title": "Jeoloji Profesörü", "pitch": 0.88, "color": Color(0.75, 0.75, 0.95),
		"look": {"skin": Color(0.9, 0.73, 0.6), "hair": "wild", "hair_color": Color(0.92, 0.92, 0.92),
			"outfit": Color(0.96, 0.96, 0.96), "outfit2": Color(0.35, 0.45, 0.6), "glasses": "round", "tie": Color(0.3, 0.3, 0.6)}},
	"riza": {"name": "Rıza Usta", "short": "Esnaf Rıza", "title": "Esnaf Odası Başkanı", "pitch": 0.92, "color": Color(0.95, 0.6, 0.35),
		"look": {"skin": Color(0.84, 0.62, 0.46), "hair": "bald_sides", "hair_color": Color(0.15, 0.12, 0.1),
			"outfit": Color(0.92, 0.9, 0.85), "outfit2": Color(0.7, 0.2, 0.2), "mustache": "big", "extra": "apron"}},
	"zeynep": {"name": "Dr. Zeynep Aydın", "short": "Dr. Zeynep", "title": "Hastane Başhekimi", "pitch": 1.18, "color": Color(0.4, 0.8, 1.0),
		"look": {"skin": Color(0.93, 0.76, 0.63), "hair": "bob", "hair_color": Color(0.3, 0.18, 0.1),
			"outfit": Color(0.96, 0.97, 0.98), "outfit2": Color(0.3, 0.65, 0.75), "extra": "stethoscope"}},
}

## Olay karti -> sunan karakter ve her secenegin o karaktere etkisi (+1 sevinir, -1 kizar, 0 notr)
const EVENT_SPEAKERS := {
	"bribe_floor": ["selim", [1, -1]], "river_site": ["selim", [1, -1]], "mall_park": ["selim", [1, -1]],
	"hotel_forest": ["selim", [1, -1]], "cheap_concrete": ["selim", [1, -1]], "coast_hotel": ["selim", [1, -1]],
	"donation": ["selim", [1, -1]], "election": ["selim", [1, -1]],
	"muhtar_drill": ["husnu", [1, -1]], "gecekondu_deed": ["husnu", [1, -1]], "illegal_power": ["husnu", [1, -1]],
	"dam": ["husnu", [1, -1]], "drains": ["husnu", [1, -1]], "stubble": ["husnu", [1, -1]],
	"fire_truck": ["murat", [1, -1]], "smoke_detector": ["murat", [1, -1]], "volunteer_fire": ["murat", [1, -1]],
	"afad_volunteer": ["elif", [1, -1]], "tsunami_sign": ["elif", [1, -1]], "help_neighbor": ["elif", [1, -1]],
	"grant": ["elif", [1, -1]], "kits_campaign": ["elif", [1, -1]], "insurance": ["elif", [1, -1]],
	"drill_parents": ["ayse", [-1, 1]], "curriculum": ["ayse", [1, -1]], "old_school": ["ayse", [1, -1]],
	"bottle_cleanup": ["ayse", [1, -1]],
	"interview": ["tolga", [1, -1]], "fake_quake": ["tolga", [1, -1]], "influencer": ["tolga", [1, -1]],
	"scientist": ["oguz", [1, -1]],
	"bbq_festival": ["riza", [1, -1]], "parking": ["riza", [1, -1]], "camping": ["riza", [-1, 1]],
	"generator": ["zeynep", [1, -1]],
}

## Iliskiye gore selam: [iyi (>=2), notr, kotu (<=-2)]
const GREET := {
	"selim": [["Başkanım, en sevdiğim başkanım! Yine harika bir fırsatla geldim!", "Sizinle iş yapmak bir zevk başkanım!"],
		["Başkanım, kısa keseceğim, bir teklifim var.", "Size kaçırılmayacak bir fırsat getirdim."],
		["Yine ben... Bu sefer belki aklınızı kullanırsınız.", "Geçen sefer beni kapıdan kovdunuz ama ben inatçıyımdır."]],
	"husnu": [["Evladım, başkanım! Mahalle sana dua ediyor!", "Gel buraya, bir sarılayım!"],
		["Başkanım, mahalleden bir derdimiz var.", "Selamünaleyküm başkanım, iki dakikanızı alacağım."],
		["Yine mi ben geldim, yine mi dinlemeyeceksin?", "Mahalle sana küs başkanım, haberin olsun."]],
	"murat": [["Başkanım! Ekiplerimiz sizinle gurur duyuyor!", "Sizin sayenizde hortumlar hep hazır!"],
		["Başkanım, itfaiyeden acil bir konu var.", "Kısa ve net söyleyeceğim başkanım."],
		["Başkanım, yine mi bütçe yok diyeceksiniz?", "Ekipler morali bozuk, haberiniz olsun."]],
	"elif": [["Başkanım, AFAD olarak sizinle çalışmak harika!", "Hazırlıklı başkan, rahat AFAD!"],
		["Başkanım, AFAD'dan bir önerimiz var.", "Hazırlık için önemli bir konu başkanım."],
		["Başkanım... Geçen sefer önerimizi geri çevirdiniz.", "Umarım bu sefer dinlersiniz."]],
	"ayse": [["Başkanım! Çocuklar size resim çizdi!", "Okulumuzun en sevilen başkanı!"],
		["Başkanım, okulumuzla ilgili bir konu var.", "Merhaba başkanım, öğrencilerim adına geldim."],
		["Başkanım, çocukları yine hayal kırıklığına uğratmayın.", "Velilere ne diyeceğimi bilemiyorum..."]],
	"tolga": [["Başkanım! Manşet yine sizsiniz, güzel haberle!", "Okurlar sizi seviyor başkanım!"],
		["Başkanım, gazete için bir konu var.", "Merhaba başkanım, birkaç soru sorabilir miyim?"],
		["Başkanım, bu sefer de 'yorum yok' mu diyeceksiniz?", "Gazete sizinle ilgili yazmaya hazır..."]],
	"oguz": [["Sayın başkan, bilime verdiğiniz değer için teşekkürler!", "Verilerimizi ciddiye alan nadir yöneticilerdensiniz."],
		["Sayın başkan, verilerimiz önemli bir şey söylüyor.", "Bilimsel bir uyarım var."],
		["Raporlarımı yine rafa mı kaldıracaksınız?", "Fay hattı sizi beklemez sayın başkan."]],
	"riza": [["Başkanım! Esnaf seni çok seviyor, çaylar benden!", "Hoş geldin başkanım, dükkânın şenlendi!"],
		["Başkanım, esnaf olarak bir ricamız var.", "Merhaba başkanım, kepenk açık, dertler çok."],
		["Başkanım, esnaf sana kırgın...", "Kepenk kapatacağız bu gidişle başkanım!"]],
	"zeynep": [["Başkanım, hastane ekibi size minnettar!", "Sizin sayenizde hastane hazır."],
		["Başkanım, hastaneden önemli bir talep var.", "Hızlı konuşacağım, servisim beni bekliyor."],
		["Başkanım, hastanenin sesini yine duymayacak mısınız?", "Hastalarım adına endişeliyim."]],
}

## Karar sonrasi tepki: [sevindi, kizdi]
const REACT := {
	"selim": [["Hah! İşte iş adamı başkan!", "Anlaştık! Elinize sağlık!"], ["Bu fırsatı kaçırdınız başkanım...", "Hıh! Pişman olacaksınız!"]],
	"husnu": [["Allah razı olsun evladım!", "Mahalle bunu unutmaz!"], ["Ah başkanım ah...", "Mahalleye ne diyeceğim ben?"]],
	"murat": [["Ekipler adına teşekkürler başkanım!", "İşte bu! Hazırız!"], ["Peki başkanım... Ama yangın beklemez.", "Ekipler bunu duyunca sevinmeyecek."]],
	"elif": [["Harika! Hazırlık hayat kurtarır!", "Doğru karar başkanım!"], ["Anlaşıldı... Umarım pişman olmayız.", "Hazırlıksızlık pahalıya patlar başkanım."]],
	"ayse": [["Çocuklar çok sevinecek!", "Teşekkürler başkanım!"], ["Çok üzüldüm başkanım...", "Öğrencilerime ne diyeceğim?"]],
	"tolga": [["Harika! Yarın manşet bu!", "Okurlar bayılacak!"], ["Not aldım başkanım... Not aldım.", "Bu da haber olur aslında."]],
	"oguz": [["Bilim kazandı!", "Teşekkürler sayın başkan!"], ["Veriler yalan söylemez başkan...", "Tarih bunu yazacak."]],
	"riza": [["Yaşa başkanım! Çaylar benden!", "Esnaf seninle!"], ["Esnafı kırdın başkanım...", "Hıh! Kepenk kapatırız ha!"]],
	"zeynep": [["Hastalarım adına teşekkürler!", "Doğru karar başkanım."], ["Peki... Umarım ihtiyaç olmaz.", "Bu riskli başkanım."]],
}


static func info(id: String) -> Dictionary:
	return CHARS.get(id, CHARS["nermin"])


## Iliski puanina gore varsayilan yuz ifadesi.
static func mood_for(rel: int) -> String:
	if rel >= 2:
		return "happy"
	if rel <= -2:
		return "angry"
	if rel == -1:
		return "worried"
	return "neutral"


static func greet(id: String, rel: int) -> String:
	var tier := 0 if rel >= 2 else (2 if rel <= -2 else 1)
	var lines: Array = GREET.get(id, [["Merhaba başkanım!"], ["Merhaba başkanım!"], ["Merhaba başkanım."]])[tier]
	return lines.pick_random()


static func react(id: String, delta: int) -> String:
	var r: Array = REACT.get(id, [["Teşekkürler başkanım!"], ["Peki başkanım..."]])
	return (r[0] if delta > 0 else r[1]).pick_random()
