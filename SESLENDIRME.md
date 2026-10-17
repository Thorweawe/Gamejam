# Seslendirme Senaryosu

Bu dosya `portofolyo/scripts/dialogs.gd` içindeki metinlerden üretildi (`tools/make_voice_md.py`). Metni değiştirirseniz önce orayı değiştirip betiği yeniden çalıştırın.

## Nasıl kaydedilir?

- Her satır ayrı bir dosya. Dosya adı tablodaki **Dosya** sütunu, örneğin `intro_01.ogg`.
- Biçim: `.ogg` (önerilen), `.wav` ya da `.mp3`. Mono, 44.1 kHz yeterli.
- Dosyaları `portofolyo/assets/voice/` klasörüne koyun. Oyun dosyayı bulursa sesi çalar ve karakterin ağzını sesin şiddetine göre oynatır. Bulamazsa yazı akar ve karakter mırıldanır; yani eksik dosya oyunu bozmaz, istediğiniz kadarını kaydedebilirsiniz.
- Satır başında ve sonunda en fazla 0,2 sn sessizlik bırakın (yoksa ağız boşta açık bekler).
- Toplam süre: açılış yaklaşık 70 sn, öğretici yaklaşık 90 sn.

## Karakterler

- **Başkan** (oyuncu): genç, iyi niyetli, biraz şaşkın ama kararlı. Doğal, samimi ton.
- **Nermin Hanım** (sekreter): 30 yıllık emektar, her şeyi bilen, çay tutkunu, dramatik. Hızlı ve enerjik konuşur, abartılı tepkiler verir. Komedi onda.

**Not** sütunu yüz ifadesini ve animasyonu yazar; o duyguyla okuyun.

## 1. Açılış hikayesi

Menüden sonra, oyunun başında oynar.

| Dosya | Kim | Replik | Not |
|---|---|---|---|
| `intro_01` | NERMİN HANIM | Başkanım, hoş geldiniz! Ben Nermin, sekreteriniz. Çayınız da hazır, tavşan kanı! Şekerini sormadım, üç attım. | neşeli, el sallar |
| `intro_02` | BAŞKAN | Sağ ol Nermin Hanım. İlk günden çay... Üç şeker ha? Bu belediyeyi şimdiden sevdim. | neşeli, çay yudumlar |
| `intro_03` | NERMİN HANIM | Otuz yıldır buradayım, tam yedi başkan gördüm. Hepsi aynı şeyi söyledi: "Bize bir şey olmaz!" | normal, parmağıyla gösterir |
| `intro_04` | BAŞKAN | Eee? Olmadı mı? | şaşkın |
| `intro_05` | NERMİN HANIM | Olmaz mı! Biri deprem olunca masanın altına gireceğine dolabın üstüne çıktı. Hâlâ indiremedik! Yemeğini sepetle yolluyoruz. | şaşkın, zıplar |
| `intro_06` | BAŞKAN | Tamam, tamam... Ben öyle olmayacağım. Dolaplardan uzak dururum. Söyle bakalım, durum ne? | endişeli, elini alnına vurur |
| `intro_07` | NERMİN HANIM | Şehrimiz fay hattının üstünde, yanı başında orman, ortasından dere geçiyor. Deprem, yangın, sel... Hepsi kapıda. Sıra numarası bile aldılar. | endişeli, omuz silker |
| `intro_08` | BAŞKAN | Bu kadar da şanssız olunmaz ki! Burayı kim seçmiş? | endişeli |
| `intro_09` | NERMİN HANIM | Şans değil başkanım, hazırlık! Afeti durduramayız ama zararını azaltabiliriz. Önümüzde yirmi gün var. | normal, parmağıyla gösterir |
| `intro_10` | BAŞKAN | Yirmi gün... Peki. Hadi Nermin Hanım, şehir bize emanet! | neşeli, başını sallar |
| `intro_11` | NERMİN HANIM | İşte bu! Yedinci başkan da aynen böyle demişti ama... neyse! O şimdi Bodrum'da balık tutuyor. Size her şeyi anlatayım. | neşeli, zıplar |

## 2. Öğretici

Açılıştan hemen sonra. Nermin anlattıkça ekranda ilgili arayüz parçası parlar.

| Dosya | Kim | Replik | Not |
|---|---|---|---|
| `tut_01` | NERMİN HANIM | Sol üstte kasamız. Vergiler her sabah gelir, binaların bakımı ve onarımı da her gün para yer. Para gelir, para gider, Nermin kalır. | normal, parmağıyla gösterir |
| `tut_02` | NERMİN HANIM | Bu yeşil kalkan halkın farkındalığı. Halk ne kadar bilinçliyse afette o kadar az can kaybederiz. | neşeli |
| `tut_03` | BAŞKAN | Farkındalığı nasıl artıracağız? | normal |
| `tut_04` | NERMİN HANIM | Mağazadan başkanım! Gazete ilanı, tatbikat, deprem çantası... Binaları da mahalle mahalle toplu güçlendirebilirsiniz. İndirim sormayın, yok. | neşeli, parmağıyla gösterir |
| `tut_05` | NERMİN HANIM | Bu da risk haritası. Kırmızı binalar depremde ilk yıkılacak olanlar. Kaçak katlara dikkat! | endişeli |
| `tut_06` | BAŞKAN | Kaçak kat mı? Bizim şehirde mi? | şaşkın |
| `tut_07` | NERMİN HANIM | Ah başkanım... Kimin evine baksanız bir kat fazla. Teyzemin evi bile bir buçuk kat fazla. | endişeli, omuz silker |
| `tut_08` | NERMİN HANIM | Her sabah kapıya biri gelir: müteahhit, muhtar, itfaiye şefi... Ne karar verirseniz unutmazlar. Kalplerine bakın! Şefler sizi severse ekipler uçar, küserlerse kaplumbağa gibi gelirler. | normal |
| `tut_09` | NERMİN HANIM | Meteoroloji uyarı verirse sağ üstte görürsünüz, hemen önlem alın. Ama deprem... deprem haber vermez. | normal, parmağıyla gösterir |
| `tut_10` | BAŞKAN | Peki afet olursa ne yapacağım? | endişeli |
| `tut_11` | NERMİN HANIM | Haritada yardım işaretleri çıkar. Tıklayın, ekip yola çıksın. Ekiplerimiz sol altta; binalarını geliştirirseniz çoğalırlar. | normal, parmağıyla gösterir |
| `tut_12` | NERMİN HANIM | İşiniz bitince Günü Bitir'e basın. Akşam size günün özetini getiririm. Çayla birlikte tabii. | neşeli, parmağıyla gösterir |
| `tut_13` | BAŞKAN | Nermin Hanım, sen olmasan ne yapardım? | neşeli |
| `tut_14` | NERMİN HANIM | Yedi başkan da aynısını söyledi başkanım. Hadi, iş başına! Çayınız soğumasın. | neşeli, el sallar |

## 3. Son gün (20. gün)

Büyük afet zinciri başlamadan önce.

| Dosya | Kim | Replik | Not |
|---|---|---|---|
| `final_01` | NERMİN HANIM | Başkanım! Bilim insanları aradı. Büyük fay hareketlendi, üstüne de sağanak geliyor! | şaşkın, zıplar |
| `final_02` | BAŞKAN | Bugün mü? Hepsi birden mi? Kampanya mı var? | endişeli |
| `final_03` | NERMİN HANIM | Bugün. Ama siz yirmi gündür buna hazırlanıyorsunuz. Hazır mıyız? | normal, parmağıyla gösterir |
| `final_04` | BAŞKAN | Hazırız Nermin Hanım. Herkes görev başına! | kararlı, başını sallar |

## 4. Oyun sonu: iyi (A-C notu)

| Dosya | Kim | Replik | Not |
|---|---|---|---|
| `end_good_01` | NERMİN HANIM | Başardık başkanım! Şehir ayakta, halk bilinçli. Sekizinci başkan efsane oldu! Dolaptaki başkan bile alkışlıyor! | neşeli, zıplar |
| `end_good_02` | BAŞKAN | Asıl kahraman halkımız, Nermin Hanım. Bir de senin çayların tabii. | neşeli, çay yudumlar |

## 5. Oyun sonu: kötü (D-F notu)

| Dosya | Kim | Replik | Not |
|---|---|---|---|
| `end_bad_01` | NERMİN HANIM | Zor günlerdi başkanım... Ama bu bir ders. Afetler değil, hazırlıksızlık yıkar. | endişeli |
| `end_bad_02` | BAŞKAN | Haklısın. Bir dahaki sefere ilk günden hazırlanacağız. Önce dolaptakini indirelim. | endişeli, başını sallar |

## 6. Oyun içi kısa replikler (Nermin Hanım)

Sol altta küçük kutuda çıkar, oyunu durdurmaz. Her biri oyunda bir kez söylenir.

| Dosya | Ne zaman | Replik | Not |
|---|---|---|---|
| `bark_forecast` | İlk hava uyarısında | Başkanım, meteorolojiden uyarı var! Önlem alırsak afeti tamamen önleyebiliriz. | endişeli |
| `bark_quake` | İlk depremde | Deprem! Çök, kapan, tutun! ... Geçti. Hemen işaretlere tıklayın, ekipleri gönderin! | şaşkın |
| `bark_fire` | İlk ev yangınında | Yangın var başkanım! İtfaiyeyi gönderin, yoksa yan binaya sıçrar! | şaşkın |
| `bark_forest` | İlk orman yangınında | Ormandan duman yükseliyor! Yine biri mangalı söndürmeden gitmiş! | kararlı |
| `bark_flood` | İlk selde | Dere taştı başkanım! Mahsur kalanlara AFAD'ı gönderin! Hüsnü Amca yine çatıda! | şaşkın |
| `bark_aftershock` | İlk artçı depremde | Artçı deprem! Hasarlı binalardan uzak durun! | şaşkın |
| `bark_prep_good` | Güçlendirilmiş binalar ilk kez ayakta kalınca | Gördünüz mü başkanım? Güçlendirdiğimiz binalar dimdik ayakta! | neşeli |
| `bark_prep_bad` | İlk kez hazırlıksız yakalanınca | Keşke binaları önceden güçlendirseydik başkanım... | endişeli |
| `bark_money` | Kasa 1.500 TL'nin altına düşünce | Başkanım, kasada para kalmadı. Bu gidişle çayı da kesecekler! | endişeli |
| `bark_streak` | İlk 3'lü kurtarma serisinde | Maşallah başkanım, ekipler uçuyor! | neşeli |
| `bark_love_selim` | Müteahhit Selim Bey tam kalbe ulaşınca | Selim Bey sizi çok sevmiş başkanım. Bu beni hiç rahatlatmadı. | endişeli |
| `bark_hate_selim` | Müteahhit Selim Bey tamamen küsünce | Selim Bey size küsmüş! Otuz yılda ilk defa iyi bir haber veriyorum. | neşeli |
| `bark_love_husnu` | Muhtar Hüsnü Amca tam kalbe ulaşınca | Hüsnü Amca kahvede sizi evladım diye anlatıyor. Kızına damat arıyormuş, dikkat! | neşeli |
| `bark_hate_husnu` | Muhtar Hüsnü Amca tamamen küsünce | Hüsnü Amca kahvede sizi çekiştiriyor başkanım. Okey masasında bile! | endişeli |
| `bark_love_murat` | İtfaiye Müdürü Murat Şef tam kalbe ulaşınca | Murat Şef sizin için siren çaldırdı başkanım. Yangın yok, sırf sevgiden! | neşeli |
| `bark_hate_murat` | İtfaiye Müdürü Murat Şef tamamen küsünce | Murat Şef küsmüş başkanım. İtfaiye bu hızla gelirse yangın kendi kendine söner! | endişeli |
| `bark_love_elif` | AFAD Koordinatörü Elif Hanım tam kalbe ulaşınca | Elif Hanım sizi fahri AFAD gönüllüsü yaptı! Yeleğiniz de geldi, turuncu. | neşeli |
| `bark_hate_elif` | AFAD Koordinatörü Elif Hanım tamamen küsünce | Elif Hanım size küs başkanım. Kurtarma ekibi biraz ağırdan alabilir... | endişeli |
| `bark_love_ayse` | Ayşe Öğretmen tam kalbe ulaşınca | Ayşe Öğretmen'in çocukları resminizi panoya asmış. Kulaklarınız biraz büyük çıkmış ama. | neşeli |
| `bark_hate_ayse` | Ayşe Öğretmen tamamen küsünce | Ayşe Öğretmen sizi velilere şikâyet etmiş başkanım. Kırmızı kalem yedik! | endişeli |
| `bark_love_tolga` | Gazeteci Tolga tam kalbe ulaşınca | Tolga sizi manşete koymuş başkanım! Fotoğraf da güzel, gözleriniz kapalı ama. | neşeli |
| `bark_hate_tolga` | Gazeteci Tolga tamamen küsünce | Tolga aleyhinize yazıyor başkanım. Başlık: Başkan nerede? Buradayım diyemedim. | endişeli |
| `bark_love_oguz` | Prof. Dr. Oğuz Taner tam kalbe ulaşınca | Profesör makalesinde sizden bahsetmiş! Dipnotta ama, bilim bu. | neşeli |
| `bark_hate_oguz` | Prof. Dr. Oğuz Taner tamamen küsünce | Profesör raporlarını artık bana yolluyor başkanım. Ben de hiçbir şey anlamıyorum. | endişeli |
| `bark_love_riza` | Esnaf Rıza Usta tam kalbe ulaşınca | Rıza Usta size özel çay bardağı ayırmış başkanım! Bu çarşıda en büyük onurdur. | neşeli |
| `bark_hate_riza` | Esnaf Rıza Usta tamamen küsünce | Esnaf size küs başkanım. Rıza Usta çayınıza şeker koymamış, durum vahim! | endişeli |
| `bark_love_zeynep` | Dr. Zeynep Aydın tam kalbe ulaşınca | Doktor Zeynep sizi hastanede herkese övüyor başkanım. Tansiyonunuzu da merak ediyormuş. | neşeli |
| `bark_hate_zeynep` | Dr. Zeynep Aydın tamamen küsünce | Doktor Zeynep size kızgın başkanım. Aşı sırası gelince iğneyi büyük seçecek! | endişeli |

## 7. Karar kartı karakterleri

Kartı sunan karakter ilişki puanına (-3..+3) göre selam verir, kararından sonra önceki ilişkiye göre tepki verir. Metinler `portofolyo/scripts/characters.gd` içinde.

### Müteahhit Selim Bey

| Dosya | Ne zaman | Replik |
|---|---|---|
| `selim_greet_love` | selam: hayran (+3) | Başkanım, canım başkanım! Size bir villa yapacağım. Depreme dayanıklı... büyük ihtimalle! |
| `selim_greet_like_1` | selam: sıcak (+1/+2) | Sizinle iş yapmak bir zevk başkanım! Yine harika bir fırsatla geldim! |
| `selim_greet_like_2` | selam: sıcak (+1/+2) | En sevdiğim başkanım! Sizin için çimentoyu bile kaliteli aldım. |
| `selim_greet_neutral_1` | selam: nötr (0) | Başkanım, kısa keseceğim, bir teklifim var. |
| `selim_greet_neutral_2` | selam: nötr (0) | Size kaçırılmayacak bir fırsat getirdim. Fırsat bu, kaçar! |
| `selim_greet_cold_1` | selam: soğuk (-1/-2) | Yine ben... Bu sefer belki aklınızı kullanırsınız. |
| `selim_greet_cold_2` | selam: soğuk (-1/-2) | Geçen sefer beni kapıdan kovdunuz ama ben inatçıyımdır. Pencereden girdim. |
| `selim_greet_hate` | selam: küs (-3) | Sizinle konuşmuyorum başkan. Nermin Hanım, söyleyin ona, bir teklifim var. |
| `selim_react_pleased` | tepki: dostu yine sevindi | Hah! İşte iş adamı başkan! Size bir kat bedava! |
| `selim_react_won` | tepki: gönlü alındı | Vay! Demek kalbiniz varmış başkanım! Ben de yok sanıyordum. |
| `selim_react_hurt` | tepki: kırıldı | Bu fırsatı kaçırdınız başkanım... Pişman olacaksınız! |
| `selim_react_fed_up` | tepki: zaten küstü, yine kızdı | Tabii ya. Sizden başka ne beklenirdi ki? Hıh! |

### Muhtar Hüsnü Amca

| Dosya | Ne zaman | Replik |
|---|---|---|
| `husnu_greet_love` | selam: hayran (+3) | Evladım, başkanım! Gel bir sarılayım! Mahallede bebeklere senin adını koyuyorlar! |
| `husnu_greet_like_1` | selam: sıcak (+1/+2) | Başkanım, mahalle sana dua ediyor! |
| `husnu_greet_like_2` | selam: sıcak (+1/+2) | Hoş geldin evladım, çayını koydurdum bile. |
| `husnu_greet_neutral_1` | selam: nötr (0) | Selamünaleyküm başkanım, iki dakikanızı alacağım. Belki beş. |
| `husnu_greet_neutral_2` | selam: nötr (0) | Başkanım, mahalleden bir derdimiz var. Aslında on tane, birini seçtim. |
| `husnu_greet_cold_1` | selam: soğuk (-1/-2) | Yine mi ben geldim, yine mi dinlemeyeceksin? |
| `husnu_greet_cold_2` | selam: soğuk (-1/-2) | Mahalle sana küs başkanım, haberin olsun. Bakkal bile selam vermiyor. |
| `husnu_greet_hate` | selam: küs (-3) | Bak evladım, ben yedi başkan eskittim. Sekizinciyi de eskitirim, hiç zor değil. |
| `husnu_react_pleased` | tepki: dostu yine sevindi | Allah razı olsun evladım! Mahalle bunu unutmaz! |
| `husnu_react_won` | tepki: gönlü alındı | Oh be! Barıştık! Gel, sana kahvede okey öğreteyim. |
| `husnu_react_hurt` | tepki: kırıldı | Ah başkanım ah... Mahalleye ne diyeceğim ben? |
| `husnu_react_fed_up` | tepki: zaten küstü, yine kızdı | Zaten belliydi. Ben gidiyorum, kapı kendi kapanır. |

### İtfaiye Müdürü Murat Şef

| Dosya | Ne zaman | Replik |
|---|---|---|
| `murat_greet_love` | selam: hayran (+3) | Başkanım! Ekipler size marş besteledi! Sirenle söylüyoruz! |
| `murat_greet_like` | selam: sıcak (+1/+2) | Başkanım! Ekiplerimiz sizinle gurur duyuyor! Hortumlar hep hazır! |
| `murat_greet_neutral` | selam: nötr (0) | Kısa ve net söyleyeceğim başkanım. Hortum var, bütçe yok! |
| `murat_greet_cold` | selam: soğuk (-1/-2) | Başkanım, ekiplerin morali bozuk. Kedi kurtarmaya bile isteksiz gidiyorlar. |
| `murat_greet_hate` | selam: küs (-3) | Başkan... Yangın çıksa önce size haber vermeyi düşünüyorum. En son. |
| `murat_react_pleased` | tepki: dostu yine sevindi | İşte bu! Ekipler hazır, hortumlar hazır, ben hazırım! |
| `murat_react_won` | tepki: gönlü alındı | Hah! Demek itfaiyeyi seviyormuşsunuz başkanım! Ekiplere söyleyeceğim! |
| `murat_react_hurt` | tepki: kırıldı | Peki başkanım... Ama yangın beklemez. |
| `murat_react_fed_up` | tepki: zaten küstü, yine kızdı | Bunu ekiplere ben söylemiyorum. Siz söyleyin, ben dışarıda beklerim. |

### AFAD Koordinatörü Elif Hanım

| Dosya | Ne zaman | Replik |
|---|---|---|
| `elif_greet_love` | selam: hayran (+3) | Başkanım! Size fahri AFAD yeleği getirdim! Turuncu çok yakıştı! |
| `elif_greet_like_1` | selam: sıcak (+1/+2) | Hazırlıklı başkan, rahat AFAD! |
| `elif_greet_like_2` | selam: sıcak (+1/+2) | Başkanım, deprem çantanız hazır mı? Biliyorum hazır, sadece sormak istedim! |
| `elif_greet_neutral_1` | selam: nötr (0) | Başkanım, AFAD'dan bir önerimiz var. |
| `elif_greet_neutral_2` | selam: nötr (0) | Hazırlık için önemli bir konu başkanım. Kısa sürecek, düdük gibi. |
| `elif_greet_cold_1` | selam: soğuk (-1/-2) | Başkanım... Geçen sefer önerimizi geri çevirdiniz. |
| `elif_greet_cold_2` | selam: soğuk (-1/-2) | Umarım bu sefer dinlersiniz. Çünkü deprem dinlemiyor. |
| `elif_greet_hate` | selam: küs (-3) | Başkanım, yeni bir tatbikat önerim var: Ben konuşurken siz sadece dinleyin. |
| `elif_react_pleased` | tepki: dostu yine sevindi | Harika! Hazırlık hayat kurtarır! Size bir düdük daha! |
| `elif_react_won` | tepki: gönlü alındı | Sonunda! Bunu deprem çantama not ediyorum başkanım! |
| `elif_react_hurt` | tepki: kırıldı | Anlaşıldı... Umarım pişman olmayız. |
| `elif_react_fed_up` | tepki: zaten küstü, yine kızdı | Hazırlıksızlık pahalıya patlar başkanım. Faturayı size yollarım. |

### Ayşe Öğretmen

| Dosya | Ne zaman | Replik |
|---|---|---|
| `ayse_greet_love` | selam: hayran (+3) | Başkanım! Çocuklar size resim çizdi! Biraz yamuk ama sevgiyle. |
| `ayse_greet_like` | selam: sıcak (+1/+2) | Okulumuzun en sevilen başkanı! Çocuklar, alkış! Üç, iki, bir! |
| `ayse_greet_neutral` | selam: nötr (0) | Merhaba başkanım, öğrencilerim adına geldim. Sırayla konuşacağız, el kaldırarak. |
| `ayse_greet_cold` | selam: soğuk (-1/-2) | Başkanım, çocukları yine hayal kırıklığına uğratmayın. Sınıfça surat astık. |
| `ayse_greet_hate` | selam: küs (-3) | Başkanım, sizi velilere şikâyet ettim. Karnenize de zayıf yazdım. |
| `ayse_react_pleased` | tepki: dostu yine sevindi | Çocuklar çok sevinecek! Size bir yıldız daha! |
| `ayse_react_won` | tepki: gönlü alındı | Aferin başkanım! Bakın, siz de yapabiliyormuşsunuz! |
| `ayse_react_hurt` | tepki: kırıldı | Çok üzüldüm başkanım... Öğrencilerime ne diyeceğim? |
| `ayse_react_fed_up` | tepki: zaten küstü, yine kızdı | Peki. Bunu da karnenize yazıyorum. |

### Gazeteci Tolga

| Dosya | Ne zaman | Replik |
|---|---|---|
| `tolga_greet_love` | selam: hayran (+3) | Başkanım! Manşet yine sizsiniz! Fotoğrafı da ben çektim, bu sefer gözleriniz açık! |
| `tolga_greet_like` | selam: sıcak (+1/+2) | Okurlar sizi seviyor başkanım! Yorumlarda kalp yağıyor! |
| `tolga_greet_neutral` | selam: nötr (0) | Başkanım, birkaç soru sorabilir miyim? Sadece üç tane. Belki on iki. |
| `tolga_greet_cold` | selam: soğuk (-1/-2) | Başkanım, bu sefer de yorum yok mu diyeceksiniz? |
| `tolga_greet_hate` | selam: küs (-3) | Yarınki manşet hazır başkanım: Başkan yine yok! Siz buradasınız ama haber haberdir. |
| `tolga_react_pleased` | tepki: dostu yine sevindi | Harika! Yarın manşet bu! Kalın harflerle! |
| `tolga_react_won` | tepki: gönlü alındı | Vay! Bu sürpriz oldu başkanım! Başlığı değiştiriyorum! |
| `tolga_react_hurt` | tepki: kırıldı | Not aldım başkanım... Not aldım. |
| `tolga_react_fed_up` | tepki: zaten küstü, yine kızdı | Bu da haber olur aslında. Hem de birinci sayfadan. |

### Prof. Dr. Oğuz Taner

| Dosya | Ne zaman | Replik |
|---|---|---|
| `oguz_greet_love` | selam: hayran (+3) | Sayın başkan! Yeni bulduğumuz fay çatlağına sizin adınızı vereceğim. Bu bir onurdur! |
| `oguz_greet_like` | selam: sıcak (+1/+2) | Verilerimizi ciddiye alan nadir yöneticilerdensiniz. Grafiklerim sizi seviyor. |
| `oguz_greet_neutral` | selam: nötr (0) | Sayın başkan, verilerimiz önemli bir şey söylüyor. Fay hattı sizi beklemez. |
| `oguz_greet_cold` | selam: soğuk (-1/-2) | Raporlarımı yine rafa mı kaldıracaksınız? Raf da artık çöktü. |
| `oguz_greet_hate` | selam: küs (-3) | Sayın başkan, bilimsel olarak kanıtladım: Sizinle konuşmanın verimi yüzde sıfır. |
| `oguz_react_pleased` | tepki: dostu yine sevindi | Bilim kazandı! Teşekkürler sayın başkan! |
| `oguz_react_won` | tepki: gönlü alındı | İlginç! Fikrinizi değiştirdiniz. Bunu bir makaleye konu edeceğim! |
| `oguz_react_hurt` | tepki: kırıldı | Veriler yalan söylemez başkan... Tarih bunu yazacak. |
| `oguz_react_fed_up` | tepki: zaten küstü, yine kızdı | Beklediğim gibi. Hipotezim doğrulandı, maalesef. |

### Esnaf Rıza Usta

| Dosya | Ne zaman | Replik |
|---|---|---|
| `riza_greet_love` | selam: hayran (+3) | Yaşa başkanım! Dükkânda sana özel bardak var, kimse ondan içemez! |
| `riza_greet_like` | selam: sıcak (+1/+2) | Hoş geldin başkanım, dükkân şenlendi! Çaylar benden, simit de benden! |
| `riza_greet_neutral` | selam: nötr (0) | Merhaba başkanım, kepenk açık, dertler çok. |
| `riza_greet_cold` | selam: soğuk (-1/-2) | Başkanım, esnaf sana kırgın... Çayına şeker koymadım, ona göre. |
| `riza_greet_hate` | selam: küs (-3) | Başkanım, kepenk kapattık! Sana özel, yarım kepenk. |
| `riza_react_pleased` | tepki: dostu yine sevindi | Yaşa başkanım! Çaylar benden, simitler benden, gönlüm senden! |
| `riza_react_won` | tepki: gönlü alındı | Hah, şimdi oldu! Gel başkanım, barışma çayı içelim! |
| `riza_react_hurt` | tepki: kırıldı | Esnafı kırdın başkanım... Bunu deftere yazıyorum. |
| `riza_react_fed_up` | tepki: zaten küstü, yine kızdı | Hıh! Kepenk kapatırız ha! Bu sefer gerçekten! |

### Dr. Zeynep Aydın

| Dosya | Ne zaman | Replik |
|---|---|---|
| `zeynep_greet_love` | selam: hayran (+3) | Başkanım! Hastane ekibi size minnettar! Tansiyonunuz da harika, uzaktan belli. |
| `zeynep_greet_like` | selam: sıcak (+1/+2) | Sizin sayenizde hastane hazır başkanım. Servisler hazır, ben hazırım, kahvem hazır. |
| `zeynep_greet_neutral` | selam: nötr (0) | Hızlı konuşacağım başkanım, servisim beni bekliyor. Gerçekten bekliyor, kapıda. |
| `zeynep_greet_cold` | selam: soğuk (-1/-2) | Başkanım, hastanenin sesini yine duymayacak mısınız? Steteskopu size mi takayım? |
| `zeynep_greet_hate` | selam: küs (-3) | Başkanım, teşhisim hazır: Kulak tıkanıklığı. Bizi hiç duymuyorsunuz. |
| `zeynep_react_pleased` | tepki: dostu yine sevindi | Hastalarım adına teşekkürler! Doğru karar başkanım. |
| `zeynep_react_won` | tepki: gönlü alındı | Bak sen! Tedaviye yanıt veriyorsunuz başkanım! |
| `zeynep_react_hurt` | tepki: kırıldı | Peki... Umarım ihtiyaç olmaz. Bu riskli başkanım. |
| `zeynep_react_fed_up` | tepki: zaten küstü, yine kızdı | Teşhis değişmedi başkanım: Kulak tıkanıklığı. |

