class_name Dialogs
extends RefCounted
## Konusma metinleri. Her satirin "id"si seslendirme dosyasinin adidir:
##   res://assets/voice/<id>.ogg  (.wav ya da .mp3 de olur)
## Dosya varsa calinir ve agiz hareketleri sesten okunur; yoksa yazi akar, karakter "mirildanir".
## Satir anahtarlari: who (karakter), text, mood (yuz), anim (jest), focus (ogreticide parlayan arayuz)
## Seslendirme listesi: proje kokundeki SESLENDIRME.md. Sesler: tools/elevenlabs_tts.py

const VOICE_DIR := "res://assets/voice/"

# ------------------------------------------------------------------ acilis hikayesi (~70 sn)
const INTRO := [
	{"id": "intro_01", "who": "nermin", "mood": "happy", "anim": "wave",
		"text": "Başkanım, hoş geldiniz! Ben Nermin, sekreteriniz. Çayınız da hazır, tavşan kanı! Şekerini sormadım, üç attım."},
	{"id": "intro_02", "who": "baskan", "mood": "happy", "anim": "tea",
		"text": "Sağ ol Nermin Hanım. İlk günden çay... Üç şeker ha? Bu belediyeyi şimdiden sevdim."},
	{"id": "intro_03", "who": "nermin", "mood": "neutral", "anim": "point",
		"text": "Otuz yıldır buradayım, tam yedi başkan gördüm. Hepsi aynı şeyi söyledi: \"Bize bir şey olmaz!\""},
	{"id": "intro_04", "who": "baskan", "mood": "surprised",
		"text": "Eee? Olmadı mı?"},
	{"id": "intro_05", "who": "nermin", "mood": "surprised", "anim": "jump",
		"text": "Olmaz mı! Biri deprem olunca masanın altına gireceğine dolabın üstüne çıktı. Hâlâ indiremedik! Yemeğini sepetle yolluyoruz."},
	{"id": "intro_06", "who": "baskan", "mood": "worried", "anim": "facepalm",
		"text": "Tamam, tamam... Ben öyle olmayacağım. Dolaplardan uzak dururum. Söyle bakalım, durum ne?"},
	{"id": "intro_07", "who": "nermin", "mood": "worried", "anim": "shrug",
		"text": "Şehrimiz fay hattının üstünde, yanı başında orman, ortasından dere geçiyor. Deprem, yangın, sel... Hepsi kapıda. Sıra numarası bile aldılar."},
	{"id": "intro_08", "who": "baskan", "mood": "worried",
		"text": "Bu kadar da şanssız olunmaz ki! Burayı kim seçmiş?"},
	{"id": "intro_09", "who": "nermin", "mood": "neutral", "anim": "point",
		"text": "Şans değil başkanım, hazırlık! Afeti durduramayız ama zararını azaltabiliriz. Önümüzde yirmi gün var."},
	{"id": "intro_10", "who": "baskan", "mood": "happy", "anim": "nod",
		"text": "Yirmi gün... Peki. Hadi Nermin Hanım, şehir bize emanet!"},
	{"id": "intro_11", "who": "nermin", "mood": "happy", "anim": "jump",
		"text": "İşte bu! Yedinci başkan da aynen böyle demişti ama... neyse! O şimdi Bodrum'da balık tutuyor. Size her şeyi anlatayım."},
]

# ------------------------------------------------------------------ ogretici (~90 sn)
const TUTORIAL := [
	{"id": "tut_01", "who": "nermin", "mood": "neutral", "anim": "point", "focus": "money",
		"text": "Sol üstte kasamız. Vergiler her sabah gelir, binaların bakımı ve onarımı da her gün para yer. Para gelir, para gider, Nermin kalır."},
	{"id": "tut_02", "who": "nermin", "mood": "happy", "focus": "aw",
		"text": "Bu yeşil kalkan halkın farkındalığı. Halk ne kadar bilinçliyse afette o kadar az can kaybederiz."},
	{"id": "tut_03", "who": "baskan", "mood": "neutral",
		"text": "Farkındalığı nasıl artıracağız?"},
	{"id": "tut_04", "who": "nermin", "mood": "happy", "anim": "point", "focus": "shop",
		"text": "Mağazadan başkanım! Gazete ilanı, tatbikat, deprem çantası... Binaları da mahalle mahalle toplu güçlendirebilirsiniz. İndirim sormayın, yok."},
	{"id": "tut_05", "who": "nermin", "mood": "worried", "focus": "risk",
		"text": "Bu da risk haritası. Kırmızı binalar depremde ilk yıkılacak olanlar. Kaçak katlara dikkat!"},
	{"id": "tut_06", "who": "baskan", "mood": "surprised",
		"text": "Kaçak kat mı? Bizim şehirde mi?"},
	{"id": "tut_07", "who": "nermin", "mood": "worried", "anim": "shrug",
		"text": "Ah başkanım... Kimin evine baksanız bir kat fazla. Teyzemin evi bile bir buçuk kat fazla."},
	{"id": "tut_08", "who": "nermin", "mood": "neutral",
		"text": "Her sabah kapıya biri gelir: müteahhit, muhtar, itfaiye şefi... Ne karar verirseniz unutmazlar. Kalplerine bakın! Şefler sizi severse ekipler uçar, küserlerse kaplumbağa gibi gelirler."},
	{"id": "tut_09", "who": "nermin", "mood": "neutral", "anim": "point", "focus": "forecast_area",
		"text": "Meteoroloji uyarı verirse sağ üstte görürsünüz, hemen önlem alın. Ama deprem... deprem haber vermez."},
	{"id": "tut_10", "who": "baskan", "mood": "worried",
		"text": "Peki afet olursa ne yapacağım?"},
	{"id": "tut_11", "who": "nermin", "mood": "neutral", "anim": "point", "focus": "units",
		"text": "Haritada yardım işaretleri çıkar. Tıklayın, ekip yola çıksın. Ekiplerimiz sol altta; binalarını geliştirirseniz çoğalırlar."},
	{"id": "tut_12", "who": "nermin", "mood": "happy", "anim": "point", "focus": "endday",
		"text": "İşiniz bitince Günü Bitir'e basın. Akşam size günün özetini getiririm. Çayla birlikte tabii."},
	{"id": "tut_13", "who": "baskan", "mood": "happy",
		"text": "Nermin Hanım, sen olmasan ne yapardım?"},
	{"id": "tut_14", "who": "nermin", "mood": "happy", "anim": "wave",
		"text": "Yedi başkan da aynısını söyledi başkanım. Hadi, iş başına! Çayınız soğumasın."},
]

# ------------------------------------------------------------------ 20. gun ve oyun sonu
const FINALE := [
	{"id": "final_01", "who": "nermin", "mood": "surprised", "anim": "jump",
		"text": "Başkanım! Bilim insanları aradı. Büyük fay hareketlendi, üstüne de sağanak geliyor!"},
	{"id": "final_02", "who": "baskan", "mood": "worried",
		"text": "Bugün mü? Hepsi birden mi? Kampanya mı var?"},
	{"id": "final_03", "who": "nermin", "mood": "neutral", "anim": "point",
		"text": "Bugün. Ama siz yirmi gündür buna hazırlanıyorsunuz. Hazır mıyız?"},
	{"id": "final_04", "who": "baskan", "mood": "angry", "anim": "nod",
		"text": "Hazırız Nermin Hanım. Herkes görev başına!"},
]

const ENDING_GOOD := [
	{"id": "end_good_01", "who": "nermin", "mood": "happy", "anim": "jump",
		"text": "Başardık başkanım! Şehir ayakta, halk bilinçli. Sekizinci başkan efsane oldu! Dolaptaki başkan bile alkışlıyor!"},
	{"id": "end_good_02", "who": "baskan", "mood": "happy", "anim": "tea",
		"text": "Asıl kahraman halkımız, Nermin Hanım. Bir de senin çayların tabii."},
]

const ENDING_BAD := [
	{"id": "end_bad_01", "who": "nermin", "mood": "worried",
		"text": "Zor günlerdi başkanım... Ama bu bir ders. Afetler değil, hazırlıksızlık yıkar."},
	{"id": "end_bad_02", "who": "baskan", "mood": "worried", "anim": "nod",
		"text": "Haklısın. Bir dahaki sefere ilk günden hazırlanacağız. Önce dolaptakini indirelim."},
]

# ------------------------------------------------------------------ oyun ici kisa replikler (oyunu durdurmaz)
const BARKS := {
	"first_forecast": {"id": "bark_forecast", "who": "nermin", "mood": "worried",
		"text": "Başkanım, meteorolojiden uyarı var! Önlem alırsak afeti tamamen önleyebiliriz."},
	"first_quake": {"id": "bark_quake", "who": "nermin", "mood": "surprised",
		"text": "Deprem! Çök, kapan, tutun! ... Geçti. Hemen işaretlere tıklayın, ekipleri gönderin!"},
	"first_house_fire": {"id": "bark_fire", "who": "nermin", "mood": "surprised",
		"text": "Yangın var başkanım! İtfaiyeyi gönderin, yoksa yan binaya sıçrar!"},
	"first_forest_fire": {"id": "bark_forest", "who": "nermin", "mood": "angry",
		"text": "Ormandan duman yükseliyor! Yine biri mangalı söndürmeden gitmiş!"},
	"first_flood": {"id": "bark_flood", "who": "nermin", "mood": "surprised",
		"text": "Dere taştı başkanım! Mahsur kalanlara AFAD'ı gönderin! Hüsnü Amca yine çatıda!"},
	"aftershock": {"id": "bark_aftershock", "who": "nermin", "mood": "surprised",
		"text": "Artçı deprem! Hasarlı binalardan uzak durun!"},
	"prep_good": {"id": "bark_prep_good", "who": "nermin", "mood": "happy",
		"text": "Gördünüz mü başkanım? Güçlendirdiğimiz binalar dimdik ayakta!"},
	"prep_bad": {"id": "bark_prep_bad", "who": "nermin", "mood": "worried",
		"text": "Keşke binaları önceden güçlendirseydik başkanım..."},
	"low_money": {"id": "bark_money", "who": "nermin", "mood": "worried",
		"text": "Başkanım, kasada para kalmadı. Bu gidişle çayı da kesecekler!"},
	"streak": {"id": "bark_streak", "who": "nermin", "mood": "happy",
		"text": "Maşallah başkanım, ekipler uçuyor!"},

	# iliski tam kalbe (+3) ya da tam kusluge (-3) ulasinca Nermin yorum yapar (bir kez)
	"love_selim": {"id": "bark_love_selim", "who": "nermin", "mood": "worried",
		"text": "Selim Bey sizi çok sevmiş başkanım. Bu beni hiç rahatlatmadı."},
	"hate_selim": {"id": "bark_hate_selim", "who": "nermin", "mood": "happy",
		"text": "Selim Bey size küsmüş! Otuz yılda ilk defa iyi bir haber veriyorum."},
	"love_husnu": {"id": "bark_love_husnu", "who": "nermin", "mood": "happy",
		"text": "Hüsnü Amca kahvede sizi evladım diye anlatıyor. Kızına damat arıyormuş, dikkat!"},
	"hate_husnu": {"id": "bark_hate_husnu", "who": "nermin", "mood": "worried",
		"text": "Hüsnü Amca kahvede sizi çekiştiriyor başkanım. Okey masasında bile!"},
	"love_murat": {"id": "bark_love_murat", "who": "nermin", "mood": "happy",
		"text": "Murat Şef sizin için siren çaldırdı başkanım. Yangın yok, sırf sevgiden!"},
	"hate_murat": {"id": "bark_hate_murat", "who": "nermin", "mood": "worried",
		"text": "Murat Şef küsmüş başkanım. İtfaiye bu hızla gelirse yangın kendi kendine söner!"},
	"love_elif": {"id": "bark_love_elif", "who": "nermin", "mood": "happy",
		"text": "Elif Hanım sizi fahri AFAD gönüllüsü yaptı! Yeleğiniz de geldi, turuncu."},
	"hate_elif": {"id": "bark_hate_elif", "who": "nermin", "mood": "worried",
		"text": "Elif Hanım size küs başkanım. Kurtarma ekibi biraz ağırdan alabilir..."},
	"love_ayse": {"id": "bark_love_ayse", "who": "nermin", "mood": "happy",
		"text": "Ayşe Öğretmen'in çocukları resminizi panoya asmış. Kulaklarınız biraz büyük çıkmış ama."},
	"hate_ayse": {"id": "bark_hate_ayse", "who": "nermin", "mood": "worried",
		"text": "Ayşe Öğretmen sizi velilere şikâyet etmiş başkanım. Kırmızı kalem yedik!"},
	"love_tolga": {"id": "bark_love_tolga", "who": "nermin", "mood": "happy",
		"text": "Tolga sizi manşete koymuş başkanım! Fotoğraf da güzel, gözleriniz kapalı ama."},
	"hate_tolga": {"id": "bark_hate_tolga", "who": "nermin", "mood": "worried",
		"text": "Tolga aleyhinize yazıyor başkanım. Başlık: Başkan nerede? Buradayım diyemedim."},
	"love_oguz": {"id": "bark_love_oguz", "who": "nermin", "mood": "happy",
		"text": "Profesör makalesinde sizden bahsetmiş! Dipnotta ama, bilim bu."},
	"hate_oguz": {"id": "bark_hate_oguz", "who": "nermin", "mood": "worried",
		"text": "Profesör raporlarını artık bana yolluyor başkanım. Ben de hiçbir şey anlamıyorum."},
	"love_riza": {"id": "bark_love_riza", "who": "nermin", "mood": "happy",
		"text": "Rıza Usta size özel çay bardağı ayırmış başkanım! Bu çarşıda en büyük onurdur."},
	"hate_riza": {"id": "bark_hate_riza", "who": "nermin", "mood": "worried",
		"text": "Esnaf size küs başkanım. Rıza Usta çayınıza şeker koymamış, durum vahim!"},
	"love_zeynep": {"id": "bark_love_zeynep", "who": "nermin", "mood": "happy",
		"text": "Doktor Zeynep sizi hastanede herkese övüyor başkanım. Tansiyonunuzu da merak ediyormuş."},
	"hate_zeynep": {"id": "bark_hate_zeynep", "who": "nermin", "mood": "worried",
		"text": "Doktor Zeynep size kızgın başkanım. Aşı sırası gelince iğneyi büyük seçecek!"},
}


static func voice_path(id: String) -> String:
	for ext in ["ogg", "wav", "mp3"]:
		var p := "%s%s.%s" % [VOICE_DIR, id, ext]
		if ResourceLoader.exists(p):
			return p
	return ""
