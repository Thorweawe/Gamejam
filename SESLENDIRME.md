# Seslendirme Senaryosu

Bu dosya `portofolyo/scripts/dialogs.gd` içindeki metinlerden üretildi (`tools/make_voice_md.py`). Metni değiştirirseniz önce orayı değiştirip betiği yeniden çalıştırın.

## Nasıl kaydedilir?

- Her satır ayrı bir dosya. Dosya adı tablodaki **Dosya** sütunu, örneğin `intro_01.ogg`.
- Biçim: `.ogg` (önerilen), `.wav` ya da `.mp3`. Mono, 44.1 kHz yeterli.
- Dosyaları `portofolyo/assets/voice/` klasörüne koyun. Oyun dosyayı bulursa sesi çalar ve karakterin ağzını sesin şiddetine göre oynatır. Bulamazsa yazı akar ve karakter mırıldanır; yani eksik dosya oyunu bozmaz, istediğiniz kadarını kaydedebilirsiniz.
- Satır başında ve sonunda en fazla 0,2 sn sessizlik bırakın (yoksa ağız boşta açık bekler).
- Toplam süre: açılış yaklaşık 70 sn, öğretici yaklaşık 90 sn.

## Karakterler

- **Başkan Kerem Yıldız** (oyuncu): genç, iyi niyetli, biraz şaşkın ama kararlı. Doğal, samimi ton.
- **Nermin Hanım** (sekreter): 30 yıllık emektar, her şeyi bilen, çay tutkunu, dramatik. Hızlı ve enerjik konuşur, abartılı tepkiler verir. Komedi onda.

**Not** sütunu yüz ifadesini ve animasyonu yazar; o duyguyla okuyun.

## 1. Açılış hikayesi

Menüden sonra, oyunun başında oynar.

| Dosya | Kim | Replik | Not |
|---|---|---|---|
| `intro_01` | NERMİN HANIM | Başkanım, hoş geldiniz! Ben Nermin, sekreteriniz. Çayınız da hazır, tavşan kanı! | neşeli, el sallar |
| `intro_02` | BAŞKAN (Kerem) | Sağ ol Nermin Hanım. İlk günden çay... Bu belediyeyi şimdiden sevdim. | neşeli, çay yudumlar |
| `intro_03` | NERMİN HANIM | Otuz yıldır buradayım, tam yedi başkan gördüm. Hepsi aynı şeyi söyledi: "Bize bir şey olmaz!" | normal, parmağıyla gösterir |
| `intro_04` | BAŞKAN (Kerem) | Eee? Olmadı mı? | şaşkın |
| `intro_05` | NERMİN HANIM | Olmaz mı! Biri deprem olunca masanın altına gireceğine dolabın üstüne çıktı. Hâlâ indiremedik! | şaşkın, zıplar |
| `intro_06` | BAŞKAN (Kerem) | Tamam, tamam... Ben öyle olmayacağım. Söyle bakalım, durum ne? | endişeli, elini alnına vurur |
| `intro_07` | NERMİN HANIM | Şehrimiz fay hattının üstünde, yanı başında orman, ortasından dere geçiyor. Deprem, yangın, sel... Hepsi kapıda. | endişeli, omuz silker |
| `intro_08` | BAŞKAN (Kerem) | Bu kadar da şanssız olunmaz ki! | endişeli |
| `intro_09` | NERMİN HANIM | Şans değil başkanım, hazırlık! Afeti durduramayız ama zararını azaltabiliriz. Önümüzde yirmi gün var. | normal, parmağıyla gösterir |
| `intro_10` | BAŞKAN (Kerem) | Yirmi gün... Peki. Hadi Nermin Hanım, şehir bize emanet! | neşeli, başını sallar |
| `intro_11` | NERMİN HANIM | İşte bu! Yedinci başkan da aynen böyle demişti ama... neyse! Size her şeyi anlatayım. | neşeli, zıplar |

## 2. Öğretici

Açılıştan hemen sonra. Nermin anlattıkça ekranda ilgili arayüz parçası parlar.

| Dosya | Kim | Replik | Not |
|---|---|---|---|
| `tut_01` | NERMİN HANIM | Sol üstte kasamız. Vergiler her sabah gelir, binaların bakımı ve onarımı da her gün para yer. | normal, parmağıyla gösterir |
| `tut_02` | NERMİN HANIM | Bu yeşil kalkan halkın farkındalığı. Halk ne kadar bilinçliyse afette o kadar az can kaybederiz. | neşeli |
| `tut_03` | BAŞKAN (Kerem) | Farkındalığı nasıl artıracağız? | normal |
| `tut_04` | NERMİN HANIM | Mağazadan başkanım! Gazete ilanı, tatbikat, deprem çantası... Binaları da mahalle mahalle toplu güçlendirebilirsiniz. | neşeli, parmağıyla gösterir |
| `tut_05` | NERMİN HANIM | Bu da risk haritası. Kırmızı binalar depremde ilk yıkılacak olanlar. Kaçak katlara dikkat! | endişeli |
| `tut_06` | BAŞKAN (Kerem) | Kaçak kat mı? Bizim şehirde mi? | şaşkın |
| `tut_07` | NERMİN HANIM | Ah başkanım... Kimin evine baksanız bir kat fazla. | endişeli, omuz silker |
| `tut_08` | NERMİN HANIM | Her sabah kapıya biri gelir: müteahhit, muhtar, itfaiye şefi... Ne karar verirseniz unutmazlar. Küsen de olur, sevinen de! | normal |
| `tut_09` | NERMİN HANIM | Meteoroloji uyarı verirse sağ üstte görürsünüz, hemen önlem alın. Ama deprem... deprem haber vermez. | normal, parmağıyla gösterir |
| `tut_10` | BAŞKAN (Kerem) | Peki afet olursa ne yapacağım? | endişeli |
| `tut_11` | NERMİN HANIM | Haritada yardım işaretleri çıkar. Tıklayın, ekip yola çıksın. Ekiplerimiz sol altta; binalarını geliştirirseniz çoğalırlar. | normal, parmağıyla gösterir |
| `tut_12` | NERMİN HANIM | İşiniz bitince Günü Bitir'e basın. Akşam size günün özetini getiririm. Çayla birlikte tabii. | neşeli, parmağıyla gösterir |
| `tut_13` | BAŞKAN (Kerem) | Nermin Hanım, sen olmasan ne yapardım? | neşeli |
| `tut_14` | NERMİN HANIM | Yedi başkan da aynısını söyledi başkanım. Hadi, iş başına! | neşeli, el sallar |

## 3. Son gün (20. gün)

Büyük afet zinciri başlamadan önce.

| Dosya | Kim | Replik | Not |
|---|---|---|---|
| `final_01` | NERMİN HANIM | Başkanım! Bilim insanları aradı. Büyük fay hareketlendi, üstüne de sağanak geliyor! | şaşkın, zıplar |
| `final_02` | BAŞKAN (Kerem) | Bugün mü? Hepsi birden mi? | endişeli |
| `final_03` | NERMİN HANIM | Bugün. Ama siz yirmi gündür buna hazırlanıyorsunuz. Hazır mıyız? | normal, parmağıyla gösterir |
| `final_04` | BAŞKAN (Kerem) | Hazırız Nermin Hanım. Herkes görev başına! | kararlı, başını sallar |

## 4. Oyun sonu: iyi (A-C notu)

| Dosya | Kim | Replik | Not |
|---|---|---|---|
| `end_good_01` | NERMİN HANIM | Başardık başkanım! Şehir ayakta, halk bilinçli. Sekizinci başkan efsane oldu! | neşeli, zıplar |
| `end_good_02` | BAŞKAN (Kerem) | Asıl kahraman halkımız, Nermin Hanım. Bir de senin çayların tabii. | neşeli, çay yudumlar |

## 5. Oyun sonu: kötü (D-F notu)

| Dosya | Kim | Replik | Not |
|---|---|---|---|
| `end_bad_01` | NERMİN HANIM | Zor günlerdi başkanım... Ama bu bir ders. Afetler değil, hazırlıksızlık yıkar. | endişeli |
| `end_bad_02` | BAŞKAN (Kerem) | Haklısın. Bir dahaki sefere ilk günden hazırlanacağız. | endişeli, başını sallar |

## 6. Oyun içi kısa replikler (Nermin Hanım)

Sol altta küçük kutuda çıkar, oyunu durdurmaz. Her biri oyunda bir kez söylenir.

| Dosya | Ne zaman | Replik | Not |
|---|---|---|---|
| `bark_forecast` | İlk hava uyarısında | Başkanım, meteorolojiden uyarı var! Önlem alırsak afeti tamamen önleyebiliriz. | endişeli |
| `bark_quake` | İlk depremde | Deprem! Çök, kapan, tutun! ... Geçti. Hemen işaretlere tıklayın, ekipleri gönderin! | şaşkın |
| `bark_fire` | İlk ev yangınında | Yangın var başkanım! İtfaiyeyi gönderin, yoksa yan binaya sıçrar! | şaşkın |
| `bark_forest` | İlk orman yangınında | Ormandan duman yükseliyor! Yine biri mangalı söndürmeden gitmiş! | kararlı |
| `bark_flood` | İlk selde | Dere taştı başkanım! Mahsur kalanlara AFAD'ı gönderin! | şaşkın |
| `bark_aftershock` | İlk artçı depremde | Artçı deprem! Hasarlı binalardan uzak durun! | şaşkın |
| `bark_prep_good` | Güçlendirilmiş binalar ilk kez ayakta kalınca | Gördünüz mü başkanım? Güçlendirdiğimiz binalar dimdik ayakta! | neşeli |
| `bark_prep_bad` | İlk kez hazırlıksız yakalanınca | Keşke binaları önceden güçlendirseydik başkanım... | endişeli |
| `bark_money` | Kasa 1.500 TL'nin altına düşünce | Başkanım, kasada para kalmadı. Bu gidişle çayı da kesecekler! | endişeli |
| `bark_streak` | İlk 3'lü kurtarma serisinde | Maşallah başkanım, ekipler uçuyor! | neşeli |

## 7. Seslendirmesi olmayan karakterler

Karar kartlarını sunan diğer karakterler kendi ses perdelerinde mırıldanarak konuşur: Müteahhit Selim Bey, Muhtar Hüsnü Amca, İtfaiye Müdürü Murat Şef, AFAD Koordinatörü Elif Hanım, Ayşe Öğretmen, Gazeteci Tolga, Prof. Dr. Oğuz Taner, Esnaf Rıza Usta, Dr. Zeynep Aydın. Selam ve tepki cümleleri `portofolyo/scripts/characters.gd` içinde.
