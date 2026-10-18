class_name Characters
extends RefCounted
## Oyundaki konusan karakterler: gorunus (CharacterFigure icin), ses perdesi, selam ve tepki cumleleri.
## Karar kartlarini bu karakterler sunar. Oyuncunun kararlari iliski puanini (-3..+3) degistirir;
## karakter sonraki gelisinde buna gore selamlar ve yuz ifadesiyle gelir.

## look anahtarlari: skin, hair, hair_color, outfit, outfit2, hat, glasses, mustache, beard, tie, extra
const CHARS := {
	"baskan": {"name": "Başkan", "short": "Başkan", "title": "Belediye Başkanı", "pitch": 0.9, "color": Color(0.4, 0.68, 1.0),
		"look": {"skin": Color(0.87, 0.67, 0.52), "hair": "short", "hair_color": Color(0.17, 0.12, 0.1),
			"outfit": Color(0.16, 0.22, 0.38), "outfit2": Color(0.95, 0.95, 0.97), "tie": Color(0.8, 0.15, 0.15), "beard": true, "style": "suit"}},
	"nermin": {"name": "Nermin Hanım", "short": "Nermin", "title": "Başkanlık Sekreteri", "pitch": 1.35, "color": Color(0.85, 0.45, 0.9),
		"look": {"skin": Color(0.95, 0.78, 0.66), "hair": "bun", "hair_color": Color(0.62, 0.28, 0.14),
			"outfit": Color(0.55, 0.32, 0.65), "outfit2": Color(0.98, 0.92, 0.85), "glasses": "round", "extra": "pearls", "blush": true, "style": "blouse"}},
	"selim": {"name": "Selim Karataş", "short": "Selim Bey", "title": "Müteahhit", "pitch": 0.95, "color": Color(1.0, 0.8, 0.3),
		"look": {"skin": Color(0.8, 0.6, 0.45), "hair": "slick", "hair_color": Color(0.32, 0.2, 0.12),
			"outfit": Color(0.93, 0.92, 0.88), "outfit2": Color(0.2, 0.2, 0.22), "glasses": "sun", "mustache": "thin", "extra": "chain", "style": "blazer"}},
	"husnu": {"name": "Hüsnü Amca", "short": "Muhtar Hüsnü", "title": "Dere Mahallesi Muhtarı", "pitch": 0.8, "color": Color(0.7, 0.55, 0.4),
		"look": {"skin": Color(0.85, 0.66, 0.5), "hair": "bald_sides", "hair_color": Color(0.82, 0.82, 0.8),
			"outfit": Color(0.45, 0.33, 0.22), "outfit2": Color(0.85, 0.85, 0.8), "hat": "cap", "mustache": "big", "style": "vest"}},
	"murat": {"name": "Murat Şef", "short": "Şef Murat", "title": "İtfaiye Müdürü", "pitch": 0.85, "color": Color(1.0, 0.45, 0.3),
		"look": {"skin": Color(0.82, 0.62, 0.48), "hair": "short", "hair_color": Color(0.2, 0.15, 0.1),
			"outfit": Color(0.18, 0.18, 0.22), "outfit2": Color(0.95, 0.8, 0.2), "hat": "fire_helmet", "mustache": "big", "extra": "stripes", "style": "fire"}},
	"elif": {"name": "Elif Koç", "short": "Elif Hanım", "title": "AFAD Koordinatörü", "pitch": 1.2, "color": Color(1.0, 0.6, 0.2),
		"look": {"skin": Color(0.9, 0.72, 0.58), "hair": "pony", "hair_color": Color(0.25, 0.16, 0.1),
			"outfit": Color(1.0, 0.5, 0.12), "outfit2": Color(0.15, 0.2, 0.35), "hat": "hardhat", "extra": "stripes", "style": "safety"}},
	"ayse": {"name": "Ayşe Öğretmen", "short": "Ayşe Öğretmen", "title": "İlkokul Müdürü", "pitch": 1.25, "color": Color(0.45, 0.85, 0.55),
		"look": {"skin": Color(0.92, 0.74, 0.6), "hair": "long", "hair_color": Color(0.12, 0.09, 0.08),
			"outfit": Color(0.3, 0.6, 0.4), "outfit2": Color(0.97, 0.97, 0.95), "style": "teacher"}},
	"tolga": {"name": "Tolga Er", "short": "Gazeteci Tolga", "title": "Yerel Gazete Muhabiri", "pitch": 1.05, "color": Color(0.4, 0.75, 1.0),
		"look": {"skin": Color(0.88, 0.7, 0.55), "hair": "messy", "hair_color": Color(0.35, 0.22, 0.12),
			"outfit": Color(0.25, 0.45, 0.75), "outfit2": Color(0.9, 0.9, 0.9), "beard": true, "extra": "badge", "style": "press"}},
	"oguz": {"name": "Prof. Dr. Oğuz Taner", "short": "Prof. Oğuz", "title": "Jeoloji Profesörü", "pitch": 0.88, "color": Color(0.75, 0.75, 0.95),
		"look": {"skin": Color(0.9, 0.73, 0.6), "hair": "wild", "hair_color": Color(0.92, 0.92, 0.92),
			"outfit": Color(0.96, 0.96, 0.96), "outfit2": Color(0.35, 0.45, 0.6), "glasses": "round", "tie": Color(0.3, 0.3, 0.6), "style": "labcoat"}},
	"riza": {"name": "Rıza Usta", "short": "Esnaf Rıza", "title": "Esnaf Odası Başkanı", "pitch": 0.92, "color": Color(0.95, 0.6, 0.35),
		"look": {"skin": Color(0.84, 0.62, 0.46), "hair": "bald_sides", "hair_color": Color(0.15, 0.12, 0.1),
			"outfit": Color(0.92, 0.9, 0.85), "outfit2": Color(0.7, 0.2, 0.2), "mustache": "big", "extra": "apron", "style": "apron"}},
	"zeynep": {"name": "Dr. Zeynep Aydın", "short": "Dr. Zeynep", "title": "Hastane Başhekimi", "pitch": 1.18, "color": Color(0.4, 0.8, 1.0),
		"look": {"skin": Color(0.93, 0.76, 0.63), "hair": "bob", "hair_color": Color(0.3, 0.18, 0.1),
			"outfit": Color(0.96, 0.97, 0.98), "outfit2": Color(0.3, 0.65, 0.75), "extra": "stethoscope", "style": "doctor"}},
}

## Olay karti -> sunan karakter ve her secenegin (GameData.EVENTS sirasiyla, 3 secenek) o karaktere
## etkisi (+1 sevinir, -1 kizar, 0 notr). Her karakter kendi cikarina bakar: muteahhit parali
## secenegi, sefler kendi birimine yatirimi, muhtar mahallesini sever; "dogru" secenek her zaman
## herkesi memnun etmez.
const EVENT_SPEAKERS := {
	"bribe_floor": ["selim", [1, 0, -1]], "river_site": ["selim", [1, 0, -1]], "mall_park": ["selim", [1, 0, -1]],
	"hotel_forest": ["selim", [1, 0, -1]], "cheap_concrete": ["selim", [1, 0, -1]], "coast_hotel": ["selim", [1, 0, -1]],
	"donation": ["selim", [1, 0, -1]], "election": ["selim", [1, -1, 0]],
	"muhtar_drill": ["husnu", [1, 0, -1]], "gecekondu_deed": ["husnu", [1, -1, 0]], "illegal_power": ["husnu", [-1, 0, 1]],
	"dam": ["husnu", [1, 1, -1]], "drains": ["husnu", [1, 1, -1]], "stubble": ["husnu", [1, 0, -1]],
	"fire_truck": ["murat", [1, 0, -1]], "smoke_detector": ["murat", [1, 0, -1]], "volunteer_fire": ["murat", [1, 1, -1]],
	"afad_volunteer": ["elif", [1, 1, -1]], "tsunami_sign": ["elif", [1, 0, -1]], "help_neighbor": ["elif", [1, 0, -1]],
	"grant": ["elif", [1, 1, -1]], "kits_campaign": ["elif", [1, 0, -1]], "insurance": ["elif", [1, 1, -1]],
	"drill_parents": ["ayse", [-1, 1, 1]], "curriculum": ["ayse", [1, 0, -1]], "old_school": ["ayse", [1, 0, -1]],
	"bottle_cleanup": ["ayse", [1, 1, -1]],
	"interview": ["tolga", [1, 0, -1]], "fake_quake": ["tolga", [1, 1, -1]], "influencer": ["tolga", [1, 0, -1]],
	"scientist": ["oguz", [1, 0, -1]],
	"bbq_festival": ["riza", [1, 0, -1]], "parking": ["riza", [1, 0, -1]], "camping": ["riza", [-1, 0, 1]],
	"generator": ["zeynep", [1, 0, -1]],
}

## Iliskiye gore selam. Kademe: love (+3), like (+1/+2), neutral (0), cold (-1/-2), hate (-3).
## Her satirin "id"si seslendirme dosyasidir (Dialogs.voice_path).
const GREET := {
	"selim": {
		"love": [{"id": "selim_greet_love", "who": "selim", "mood": "happy",
			"text": "Başkanım, canım başkanım! Size bir villa yapacağım. Depreme dayanıklı... büyük ihtimalle!"}],
		"like": [{"id": "selim_greet_like_1", "who": "selim", "mood": "happy",
			"text": "Sizinle iş yapmak bir zevk başkanım! Yine harika bir fırsatla geldim!"},
			{"id": "selim_greet_like_2", "who": "selim", "mood": "happy",
			"text": "En sevdiğim başkanım! Sizin için çimentoyu bile kaliteli aldım."}],
		"neutral": [{"id": "selim_greet_neutral_1", "who": "selim", "mood": "neutral",
			"text": "Başkanım, kısa keseceğim, bir teklifim var."},
			{"id": "selim_greet_neutral_2", "who": "selim", "mood": "neutral",
			"text": "Size kaçırılmayacak bir fırsat getirdim. Fırsat bu, kaçar!"}],
		"cold": [{"id": "selim_greet_cold_1", "who": "selim", "mood": "worried",
			"text": "Yine ben... Bu sefer belki aklınızı kullanırsınız."},
			{"id": "selim_greet_cold_2", "who": "selim", "mood": "worried",
			"text": "Geçen sefer beni kapıdan kovdunuz ama ben inatçıyımdır. Pencereden girdim."}],
		"hate": [{"id": "selim_greet_hate", "who": "selim", "mood": "angry",
			"text": "Sizinle konuşmuyorum başkan. Nermin Hanım, söyleyin ona, bir teklifim var."}],
	},
	"husnu": {
		"love": [{"id": "husnu_greet_love", "who": "husnu", "mood": "happy",
			"text": "Evladım, başkanım! Gel bir sarılayım! Mahallede bebeklere senin adını koyuyorlar!"}],
		"like": [{"id": "husnu_greet_like_1", "who": "husnu", "mood": "happy",
			"text": "Başkanım, mahalle sana dua ediyor!"},
			{"id": "husnu_greet_like_2", "who": "husnu", "mood": "happy",
			"text": "Hoş geldin evladım, çayını koydurdum bile."}],
		"neutral": [{"id": "husnu_greet_neutral_1", "who": "husnu", "mood": "neutral",
			"text": "Selamünaleyküm başkanım, iki dakikanızı alacağım. Belki beş."},
			{"id": "husnu_greet_neutral_2", "who": "husnu", "mood": "neutral",
			"text": "Başkanım, mahalleden bir derdimiz var. Aslında on tane, birini seçtim."}],
		"cold": [{"id": "husnu_greet_cold_1", "who": "husnu", "mood": "worried",
			"text": "Yine mi ben geldim, yine mi dinlemeyeceksin?"},
			{"id": "husnu_greet_cold_2", "who": "husnu", "mood": "worried",
			"text": "Mahalle sana küs başkanım, haberin olsun. Bakkal bile selam vermiyor."}],
		"hate": [{"id": "husnu_greet_hate", "who": "husnu", "mood": "angry",
			"text": "Bak evladım, ben yedi başkan eskittim. Sekizinciyi de eskitirim, hiç zor değil."}],
	},
	"murat": {
		"love": [{"id": "murat_greet_love", "who": "murat", "mood": "happy",
			"text": "Başkanım! Ekipler size marş besteledi! Sirenle söylüyoruz!"}],
		"like": [{"id": "murat_greet_like", "who": "murat", "mood": "happy",
			"text": "Başkanım! Ekiplerimiz sizinle gurur duyuyor! Hortumlar hep hazır!"}],
		"neutral": [{"id": "murat_greet_neutral", "who": "murat", "mood": "neutral",
			"text": "Kısa ve net söyleyeceğim başkanım. Hortum var, bütçe yok!"}],
		"cold": [{"id": "murat_greet_cold", "who": "murat", "mood": "worried",
			"text": "Başkanım, ekiplerin morali bozuk. Kedi kurtarmaya bile isteksiz gidiyorlar."}],
		"hate": [{"id": "murat_greet_hate", "who": "murat", "mood": "angry",
			"text": "Başkan... Yangın çıksa önce size haber vermeyi düşünüyorum. En son."}],
	},
	"elif": {
		"love": [{"id": "elif_greet_love", "who": "elif", "mood": "happy",
			"text": "Başkanım! Size fahri AFAD yeleği getirdim! Turuncu çok yakıştı!"}],
		"like": [{"id": "elif_greet_like_1", "who": "elif", "mood": "happy",
			"text": "Hazırlıklı başkan, rahat AFAD!"},
			{"id": "elif_greet_like_2", "who": "elif", "mood": "happy",
			"text": "Başkanım, deprem çantanız hazır mı? Biliyorum hazır, sadece sormak istedim!"}],
		"neutral": [{"id": "elif_greet_neutral_1", "who": "elif", "mood": "neutral",
			"text": "Başkanım, AFAD'dan bir önerimiz var."},
			{"id": "elif_greet_neutral_2", "who": "elif", "mood": "neutral",
			"text": "Hazırlık için önemli bir konu başkanım. Kısa sürecek, düdük gibi."}],
		"cold": [{"id": "elif_greet_cold_1", "who": "elif", "mood": "worried",
			"text": "Başkanım... Geçen sefer önerimizi geri çevirdiniz."},
			{"id": "elif_greet_cold_2", "who": "elif", "mood": "worried",
			"text": "Umarım bu sefer dinlersiniz. Çünkü deprem dinlemiyor."}],
		"hate": [{"id": "elif_greet_hate", "who": "elif", "mood": "angry",
			"text": "Başkanım, yeni bir tatbikat önerim var: Ben konuşurken siz sadece dinleyin."}],
	},
	"ayse": {
		"love": [{"id": "ayse_greet_love", "who": "ayse", "mood": "happy",
			"text": "Başkanım! Çocuklar size resim çizdi! Biraz yamuk ama sevgiyle."}],
		"like": [{"id": "ayse_greet_like", "who": "ayse", "mood": "happy",
			"text": "Okulumuzun en sevilen başkanı! Çocuklar, alkış! Üç, iki, bir!"}],
		"neutral": [{"id": "ayse_greet_neutral", "who": "ayse", "mood": "neutral",
			"text": "Merhaba başkanım, öğrencilerim adına geldim. Sırayla konuşacağız, el kaldırarak."}],
		"cold": [{"id": "ayse_greet_cold", "who": "ayse", "mood": "worried",
			"text": "Başkanım, çocukları yine hayal kırıklığına uğratmayın. Sınıfça surat astık."}],
		"hate": [{"id": "ayse_greet_hate", "who": "ayse", "mood": "angry",
			"text": "Başkanım, sizi velilere şikâyet ettim. Karnenize de zayıf yazdım."}],
	},
	"tolga": {
		"love": [{"id": "tolga_greet_love", "who": "tolga", "mood": "happy",
			"text": "Başkanım! Manşet yine sizsiniz! Fotoğrafı da ben çektim, bu sefer gözleriniz açık!"}],
		"like": [{"id": "tolga_greet_like", "who": "tolga", "mood": "happy",
			"text": "Okurlar sizi seviyor başkanım! Yorumlarda kalp yağıyor!"}],
		"neutral": [{"id": "tolga_greet_neutral", "who": "tolga", "mood": "neutral",
			"text": "Başkanım, birkaç soru sorabilir miyim? Sadece üç tane. Belki on iki."}],
		"cold": [{"id": "tolga_greet_cold", "who": "tolga", "mood": "worried",
			"text": "Başkanım, bu sefer de yorum yok mu diyeceksiniz?"}],
		"hate": [{"id": "tolga_greet_hate", "who": "tolga", "mood": "angry",
			"text": "Yarınki manşet hazır başkanım: Başkan yine yok! Siz buradasınız ama haber haberdir."}],
	},
	"oguz": {
		"love": [{"id": "oguz_greet_love", "who": "oguz", "mood": "happy",
			"text": "Sayın başkan! Yeni bulduğumuz fay çatlağına sizin adınızı vereceğim. Bu bir onurdur!"}],
		"like": [{"id": "oguz_greet_like", "who": "oguz", "mood": "happy",
			"text": "Verilerimizi ciddiye alan nadir yöneticilerdensiniz. Grafiklerim sizi seviyor."}],
		"neutral": [{"id": "oguz_greet_neutral", "who": "oguz", "mood": "neutral",
			"text": "Sayın başkan, verilerimiz önemli bir şey söylüyor. Fay hattı sizi beklemez."}],
		"cold": [{"id": "oguz_greet_cold", "who": "oguz", "mood": "worried",
			"text": "Raporlarımı yine rafa mı kaldıracaksınız? Raf da artık çöktü."}],
		"hate": [{"id": "oguz_greet_hate", "who": "oguz", "mood": "angry",
			"text": "Sayın başkan, bilimsel olarak kanıtladım: Sizinle konuşmanın verimi yüzde sıfır."}],
	},
	"riza": {
		"love": [{"id": "riza_greet_love", "who": "riza", "mood": "happy",
			"text": "Yaşa başkanım! Dükkânda sana özel bardak var, kimse ondan içemez!"}],
		"like": [{"id": "riza_greet_like", "who": "riza", "mood": "happy",
			"text": "Hoş geldin başkanım, dükkân şenlendi! Çaylar benden, simit de benden!"}],
		"neutral": [{"id": "riza_greet_neutral", "who": "riza", "mood": "neutral",
			"text": "Merhaba başkanım, kepenk açık, dertler çok."}],
		"cold": [{"id": "riza_greet_cold", "who": "riza", "mood": "worried",
			"text": "Başkanım, esnaf sana kırgın... Çayına şeker koymadım, ona göre."}],
		"hate": [{"id": "riza_greet_hate", "who": "riza", "mood": "angry",
			"text": "Başkanım, kepenk kapattık! Sana özel, yarım kepenk."}],
	},
	"zeynep": {
		"love": [{"id": "zeynep_greet_love", "who": "zeynep", "mood": "happy",
			"text": "Başkanım! Hastane ekibi size minnettar! Tansiyonunuz da harika, uzaktan belli."}],
		"like": [{"id": "zeynep_greet_like", "who": "zeynep", "mood": "happy",
			"text": "Sizin sayenizde hastane hazır başkanım. Servisler hazır, ben hazırım, kahvem hazır."}],
		"neutral": [{"id": "zeynep_greet_neutral", "who": "zeynep", "mood": "neutral",
			"text": "Hızlı konuşacağım başkanım, servisim beni bekliyor. Gerçekten bekliyor, kapıda."}],
		"cold": [{"id": "zeynep_greet_cold", "who": "zeynep", "mood": "worried",
			"text": "Başkanım, hastanenin sesini yine duymayacak mısınız? Steteskopu size mi takayım?"}],
		"hate": [{"id": "zeynep_greet_hate", "who": "zeynep", "mood": "angry",
			"text": "Başkanım, teşhisim hazır: Kulak tıkanıklığı. Bizi hiç duymuyorsunuz."}],
	},
}

## Karar sonrasi tepki; karakterin onceki iliskisine gore degisir:
##   pleased: sevdigi baskan yine sevindirdi   won:    kusken / notrken gonlu alindi
##   hurt:    dost ya da notrken kirildi        fed_up: zaten kusken bir daha kizdi
const REACT := {
	"selim": {
		"pleased": {"id": "selim_react_pleased", "who": "selim", "mood": "happy", "text": "Hah! İşte iş adamı başkan! Size bir kat bedava!"},
		"won": {"id": "selim_react_won", "who": "selim", "mood": "surprised", "text": "Vay! Demek kalbiniz varmış başkanım! Ben de yok sanıyordum."},
		"hurt": {"id": "selim_react_hurt", "who": "selim", "mood": "worried", "text": "Bu fırsatı kaçırdınız başkanım... Pişman olacaksınız!"},
		"fed_up": {"id": "selim_react_fed_up", "who": "selim", "mood": "angry", "text": "Tabii ya. Sizden başka ne beklenirdi ki? Hıh!"},
	},
	"husnu": {
		"pleased": {"id": "husnu_react_pleased", "who": "husnu", "mood": "happy", "text": "Allah razı olsun evladım! Mahalle bunu unutmaz!"},
		"won": {"id": "husnu_react_won", "who": "husnu", "mood": "surprised", "text": "Oh be! Barıştık! Gel, sana kahvede okey öğreteyim."},
		"hurt": {"id": "husnu_react_hurt", "who": "husnu", "mood": "worried", "text": "Ah başkanım ah... Mahalleye ne diyeceğim ben?"},
		"fed_up": {"id": "husnu_react_fed_up", "who": "husnu", "mood": "angry", "text": "Zaten belliydi. Ben gidiyorum, kapı kendi kapanır."},
	},
	"murat": {
		"pleased": {"id": "murat_react_pleased", "who": "murat", "mood": "happy", "text": "İşte bu! Ekipler hazır, hortumlar hazır, ben hazırım!"},
		"won": {"id": "murat_react_won", "who": "murat", "mood": "surprised", "text": "Hah! Demek itfaiyeyi seviyormuşsunuz başkanım! Ekiplere söyleyeceğim!"},
		"hurt": {"id": "murat_react_hurt", "who": "murat", "mood": "worried", "text": "Peki başkanım... Ama yangın beklemez."},
		"fed_up": {"id": "murat_react_fed_up", "who": "murat", "mood": "angry", "text": "Bunu ekiplere ben söylemiyorum. Siz söyleyin, ben dışarıda beklerim."},
	},
	"elif": {
		"pleased": {"id": "elif_react_pleased", "who": "elif", "mood": "happy", "text": "Harika! Hazırlık hayat kurtarır! Size bir düdük daha!"},
		"won": {"id": "elif_react_won", "who": "elif", "mood": "surprised", "text": "Sonunda! Bunu deprem çantama not ediyorum başkanım!"},
		"hurt": {"id": "elif_react_hurt", "who": "elif", "mood": "worried", "text": "Anlaşıldı... Umarım pişman olmayız."},
		"fed_up": {"id": "elif_react_fed_up", "who": "elif", "mood": "angry", "text": "Hazırlıksızlık pahalıya patlar başkanım. Faturayı size yollarım."},
	},
	"ayse": {
		"pleased": {"id": "ayse_react_pleased", "who": "ayse", "mood": "happy", "text": "Çocuklar çok sevinecek! Size bir yıldız daha!"},
		"won": {"id": "ayse_react_won", "who": "ayse", "mood": "surprised", "text": "Aferin başkanım! Bakın, siz de yapabiliyormuşsunuz!"},
		"hurt": {"id": "ayse_react_hurt", "who": "ayse", "mood": "worried", "text": "Çok üzüldüm başkanım... Öğrencilerime ne diyeceğim?"},
		"fed_up": {"id": "ayse_react_fed_up", "who": "ayse", "mood": "angry", "text": "Peki. Bunu da karnenize yazıyorum."},
	},
	"tolga": {
		"pleased": {"id": "tolga_react_pleased", "who": "tolga", "mood": "happy", "text": "Harika! Yarın manşet bu! Kalın harflerle!"},
		"won": {"id": "tolga_react_won", "who": "tolga", "mood": "surprised", "text": "Vay! Bu sürpriz oldu başkanım! Başlığı değiştiriyorum!"},
		"hurt": {"id": "tolga_react_hurt", "who": "tolga", "mood": "worried", "text": "Not aldım başkanım... Not aldım."},
		"fed_up": {"id": "tolga_react_fed_up", "who": "tolga", "mood": "angry", "text": "Bu da haber olur aslında. Hem de birinci sayfadan."},
	},
	"oguz": {
		"pleased": {"id": "oguz_react_pleased", "who": "oguz", "mood": "happy", "text": "Bilim kazandı! Teşekkürler sayın başkan!"},
		"won": {"id": "oguz_react_won", "who": "oguz", "mood": "surprised", "text": "İlginç! Fikrinizi değiştirdiniz. Bunu bir makaleye konu edeceğim!"},
		"hurt": {"id": "oguz_react_hurt", "who": "oguz", "mood": "worried", "text": "Veriler yalan söylemez başkan... Tarih bunu yazacak."},
		"fed_up": {"id": "oguz_react_fed_up", "who": "oguz", "mood": "angry", "text": "Beklediğim gibi. Hipotezim doğrulandı, maalesef."},
	},
	"riza": {
		"pleased": {"id": "riza_react_pleased", "who": "riza", "mood": "happy", "text": "Yaşa başkanım! Çaylar benden, simitler benden, gönlüm senden!"},
		"won": {"id": "riza_react_won", "who": "riza", "mood": "surprised", "text": "Hah, şimdi oldu! Gel başkanım, barışma çayı içelim!"},
		"hurt": {"id": "riza_react_hurt", "who": "riza", "mood": "worried", "text": "Esnafı kırdın başkanım... Bunu deftere yazıyorum."},
		"fed_up": {"id": "riza_react_fed_up", "who": "riza", "mood": "angry", "text": "Hıh! Kepenk kapatırız ha! Bu sefer gerçekten!"},
	},
	"zeynep": {
		"pleased": {"id": "zeynep_react_pleased", "who": "zeynep", "mood": "happy", "text": "Hastalarım adına teşekkürler! Doğru karar başkanım."},
		"won": {"id": "zeynep_react_won", "who": "zeynep", "mood": "surprised", "text": "Bak sen! Tedaviye yanıt veriyorsunuz başkanım!"},
		"hurt": {"id": "zeynep_react_hurt", "who": "zeynep", "mood": "worried", "text": "Peki... Umarım ihtiyaç olmaz. Bu riskli başkanım."},
		"fed_up": {"id": "zeynep_react_fed_up", "who": "zeynep", "mood": "angry", "text": "Teşhis değişmedi başkanım: Kulak tıkanıklığı."},
	},
}


static func info(id: String) -> Dictionary:
	return CHARS.get(id, CHARS["nermin"])


## Iliski puanini (-3..+3) selam kademesine cevirir.
static func rel_tier(rel: int) -> String:
	if rel >= 3:
		return "love"
	if rel >= 1:
		return "like"
	if rel <= -3:
		return "hate"
	if rel <= -1:
		return "cold"
	return "neutral"


## Iliski puanina gore varsayilan yuz ifadesi.
static func mood_for(rel: int) -> String:
	if rel >= 2:
		return "happy"
	if rel <= -2:
		return "angry"
	if rel == -1:
		return "worried"
	return "neutral"


## Selam satiri {id, who, mood, text}; iliski kademesine gore.
static func greet(id: String, rel: int) -> Dictionary:
	var tiers: Dictionary = GREET.get(id, {})
	var lines: Array = tiers.get(rel_tier(rel), [])
	if lines.is_empty():
		return {"who": id, "text": "Merhaba başkanım!"}
	return lines.pick_random()


## Tepki satiri; rel_before = karardan onceki iliski puani.
static func react(id: String, delta: int, rel_before := 0) -> Dictionary:
	var kind := ""
	if delta > 0:
		kind = "pleased" if rel_before >= 1 else "won"
	else:
		kind = "fed_up" if rel_before <= -1 else "hurt"
	var r: Dictionary = REACT.get(id, {})
	return r.get(kind, {"who": id, "text": "Teşekkürler başkanım!" if delta > 0 else "Peki başkanım..."})
