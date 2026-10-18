# Porto Şehri Afete Hazırlık: Kaynaklar ve Yapay Zekâ Beyanı

Bu dosya oyunda kullanılan her varlığın (model, ses, görsel, yazı tipi, kod, metin) **nereden geldiğini**,
**oyunda nerede kullanıldığını** ve **yapay zekâ ile üretilip üretilmediğini** beyan eder.

Kullanılan yapay zekâ araçları:
- **Claude (Anthropic), Claude Code üzerinden:** kod, 3B model üreteci, ses/müzik üreteci, metinler, shader'lar.
- **ElevenLabs (metinden sese):** karakter seslendirmeleri.

---

## Özet

| Kategori | Kaynak | Yapay zekâ? | Lisans |
|---|---|---|---|
| Oyun motoru | Godot Engine 4.7 | Hayır | MIT |
| 3B modeller: şehir paketi (41 model) | KayKit City Builder Bits 1.0, Kay Lousberg | Hayır | CC0 |
| 3B modeller: doğa paketi (105 model) | KayKit Forest Nature Pack 1.0, Kay Lousberg | Hayır | CC0 |
| 3B modeller: özel (169 model) | Python ile kodla üretildi (`tools/asset_gen/`) | **Evet**, üreteç kodu Claude ile yazıldı | Ekibe ait |
| Konuşan karakterler (11 karakter) | Kodla kurulan low-poly figürler (`character_figure.gd`) | **Evet** (Claude) | Ekibe ait |
| Yazı tipi | Fredoka, The Fredoka Project Authors | Hayır (Türkçe harfler eklendi, aşağıya bakın) | SIL OFL 1.1 |
| Ses efektleri, ortam sesleri, müzik | Kodla sentezlendi (`tools/audio_gen.py`) | **Evet**, sentez kodu Claude ile yazıldı | Ekibe ait |
| Karakter seslendirmeleri (152 dosya) | ElevenLabs metinden sese | **Evet** (ElevenLabs) | ElevenLabs kullanım koşulları |
| Oyun içi ikonlar | Kodla çiziliyor (`scripts/ui_icon.gd`) | **Evet** (Claude) | Ekibe ait |
| Mağaza ikonları (SVG) | Kodla üretildi (`tools/ui_icons.py`) | **Evet** (Claude) | Ekibe ait |
| Mağaza / harita görselleri (`assets/textures/*.png`) | Görseller Claude ile üretildi; mağaza arayüzü ve tasarımı ekibimiz tarafından yapıldı | **Evet**, görseller (Claude) | Ekibe ait |
| Oyun kodu (GDScript) | Ekip + Claude | **Kısmen**, aşağıda dosya dosya | Ekibe ait |
| Metinler, olaylar, diyaloglar | Ekip + Claude | **Evet** (Claude, ekip yönlendirmesiyle) | Ekibe ait |

---

## 1. Hazır (üçüncü taraf) varlıklar

| Varlık | Nerede | Oyunda nerede kullanılıyor |
|---|---|---|
| **KayKit City Builder Bits 1.0** (CC0) | `assets/_kaynak/kaykit_city_builder_bits/` → `assets/models/` | Yollar, bazı binalar ve dükkânlar, sivil arabalar (sedan, taksi, polis…), sokak lambaları, bina dokusu (`citybits_texture.png`) |
| **KayKit Forest Nature Pack 1.0** (CC0) | `assets/_kaynak/kaykit_forest_nature/` → `assets/models/doga/` | Ağaçlar, çalılar, kayalar, yanmış (çıplak) ağaçlar |
| **Fredoka** yazı tipi (OFL 1.1) | `assets/fonts/Fredoka.ttf`, lisans: `assets/fonts/Fredoka_OFL.txt` | Tüm arayüz, menü ve diyalog yazıları |
| **Godot Engine 4.7** (MIT) | Motor | Oyunun tamamı |

**Fredoka üzerinde yapılan değişiklik:** Orijinal fontta **Ş ş Ğ ğ İ** harfleri yoktu ve Ç ç'nin çengeli çok
inceydi. `tools/font_add_turkish.py` ile bu harfler fontun kendi parçalarından (S + virgül, G + breve, I + nokta)
bileşik glif olarak eklendi; Ç ve ç'nin çengeli virgülle değiştirildi. Bu betik Claude ile yazıldı. OFL lisansı
değişikliğe izin veriyor; fontta "ayrılmış ad" (Reserved Font Name) olmadığı için ad aynen kalabilir. Lisans dosyası
fontun yanında duruyor.

Modellerin tek tek listesi ve kaynakları: [`portofolyo/assets/ASSETS.md`](portofolyo/assets/ASSETS.md)
(`tools/organize_assets.py` ile otomatik üretilir).

---

## 2. Yapay zekâ ile üretilenler

### 2.1 3B modeller (169 model)
- **Nasıl:** Modeller doğrudan bir görsel yapay zekâ ile değil, **Python koduyla** üretildi. Bu kod
  (`tools/asset_gen/`: `kitgen.py`, `buildings.py`, `vehicles.py`, `props.py`, `tiles.py`, `nature.py`,
  `people.py`, `damage.py`) Claude ile yazıldı. Modeller KayKit'in renk dokusunu kullanır, o yüzden aynı stilde görünür.
- **Ham çıktılar:** `assets/_kaynak/ai_uretim/` (sunumda gösterilebilir, Godot bu klasörü yüklemez)
- **Oyunda:** `assets/models/` altındaki "AI üretimi" işaretli modeller ([ASSETS.md](portofolyo/assets/ASSETS.md))
  - **Konutlar:** gecekondu → ev → apartman → site; kaçak katlı ve güçlendirilmiş hâlleri; hepsinin hasarlı ve yıkık modelleri
  - **Kamu binaları:** belediye, hastane, itfaiye, AFAD (3 seviye), okul, gazete/TV binası, müzeler ve müze arsası
  - **Araçlar:** itfaiye, ambulans, AFAD aracı, TV aracı, otobüs, kamyonlar, tekne
  - **Afet nesneleri:** alev, duman, enkaz, kum torbası, çadır, toplanma alanı tabelası, siren, bariyer, koni
  - **Harita:** dağlar, tepeler, köprü, dere ıslahı duvarı, iskele, deniz feneri, piknik eşyaları, çeşme
  - **Canlılar:** martı, kuş, geyik, köpek, dağ keçisi, yayalar

### 2.2 Konuşan karakterler
- `scripts/character_figure.gd` (figür, yüz ifadeleri, kıyafetler), `scripts/characters.gd` (11 karakterin görünüşü,
  isimleri, cümleleri), `scripts/portrait.gd` (portre ışığı). Hepsi Claude ile yazıldı; karakterler kodla kurulur,
  görsel dosyası yoktur.

### 2.3 Sesler ve müzik
- **Kodla sentezlendi:** `tools/audio_gen.py` (Claude ile yazıldı). Kayıt ya da hazır ses örneği kullanılmadı.
  - Efektler: tıklama, para, inşaat, alarm, deprem, yıkılma, siren, başarı/başarısızlık, gök gürültüsü (`thunder.wav`)
  - Ortam: dalga, kuş, yağmur, rüzgâr, yangın çıtırtısı
  - Müzik: sakin ve gergin tema, menüden oyuna geçiş sesi
  - Seslendirmesi olmayan karakterlerin "mırıldanma" heceleri
- **Seslendirmeler (yapay zekâ ses):** `assets/voice/*.mp3`, **ElevenLabs** metinden sese ile üretildi
  (`tools/elevenlabs_tts.py`, ses kimlikleri `tools/voices.json`, senaryo `SESLENDIRME.md`). Oyunda: hikâye,
  öğretici, final ve karakter repliklerinde (`scripts/dialog_player.gd` çalar).

### 2.4 Arayüz görselleri
- Oyun içi ikonlar: `scripts/ui_icon.gd`, kodla çizilen vektör ikonlar (Claude)
- Mağaza ikonları: `assets/ui_icons/*.svg`, `tools/ui_icons.py` ile üretildi (Claude). Renk paleti Tailwind CSS'ten alındı.
- Oyun ikonu: `portofolyo/icon.svg`, `icon.png`, `icon.ico` (Claude ile üretildi)
- Menü arka plan videoları: `videolar/menu_arkaplan_v1.mp4`, `v2.mp4`. Oyunun kendisinden kaydedildi
  (Godot Movie Maker); yani yapay zekâ ile üretilmiş görüntü değil, oyunun ekran kaydı.
- **Kullanılmayan deneme:** `assets/_kaynak/ai_ui_deneme/magaza_onizleme.png`. Oyunda **kullanılmıyor**, sadece
  deneme olarak kaynak klasöründe duruyor.

### 2.5 Görsel efektler ve shader'lar
| Dosya | Ne yapar | Kim |
|---|---|---|
| `assets/shaders/foliage.gdshader` | Ağaç ve çalılarda rüzgâr | Claude |
| `scripts/window_lights.gd` | Gece yanan bina pencereleri | Claude |
| `scripts/ground_marks.gd` | Deprem çatlakları, yangın sonrası is izleri (dokular kodla üretilir) | Claude |
| `assets/shaders/ground.gdshader`, `sea.gdshader` | Zemin, kıyı, deniz, dere | Ekibimiz tarafından yapıldı (Denixhan); Claude ile eklemeler: bulut gölgeleri, su parıltısı, yanık orman, sel kenarları |
| `assets/shaders/outline.gdshader` | Çizgi film konturu | Ekibimiz tarafından yapıldı (Denixhan) |
| `scripts/map_visuals.gd` | Işık / renk / sis / parlama ayarları, minyatür etkisi | Ekibimiz tarafından yapıldı (Denixhan); Claude ile eklemeler: ışık-renk ayarı, minyatür etkisi, rüzgâr, yanık maskesi |
| `scripts/fire_fx.gd`, `flood_fx.gd` | Yangın ve sel efektleri | Ekibimiz tarafından yapıldı (Denixhan); Claude ile sel kenarı düzeltmeleri |

### 2.6 Harita
- `tools/map_gen.py` → `scenes/city_map.tscn` + `assets/textures/terrain_mask.png`, `land_mask.png`, `sand_mask.png`:
  ada haritası, şehir planı, orman, nehir, patikalar, müze arsaları. Claude ile yazıldı.
- `scripts/islands.gd`: ekibimiz tarafından yapıldı (Denixhan).

### 2.7 Oyun kodu (`portofolyo/scripts/`)
**Claude ile yazılanlar** (ekibin istekleri ve yönlendirmesiyle):
`game_manager.gd` (kurallar, ekonomi, farkındalık, olaylar), `game_data.gd` (olay kartları, fiyatlar, metinler),
`disasters.gd` (deprem, yangın, orman yangını, sel, final), `incident.gd`, `incident_marker.gd` (yardım işaretleri),
`traffic.gd`, `agent.gd` (trafik, yayalar, tahliye, acil durum araçları), `wildlife.gd`, `building.gd`,
`hud.gd` (arayüz), `menu.gd`, `settings.gd`, `settings_panel.gd`, `day_cycle.gd` (gece-gündüz),
`camera_rig.gd`, `audio.gd`, `dialogs.gd`, `dialog_player.gd`, `characters.gd`, `character_figure.gd`,
`portrait.gd`, `map_info.gd`, `city_map.gd`, `sun_moon_dial.gd`, `ui_icon.gd`, `window_lights.gd`, `ground_marks.gd`.

**Ekibimiz tarafından yapılanlar:**
- Denixhan: `bubbles.gd` (baloncuklar), `city_life.gd`, `fire_fx.gd`, `flood_fx.gd`, `graphics_quality.gd`,
  `islands.gd`, `map_visuals.gd`, sahneler `city_map_1.tscn`, `main_menu_deneme.tscn`
- Tunahan: `shop.gd`, `product_row.gd`, sahneler `shop.tscn`, `product_row.tscn` (mağaza tasarımı). Mağaza
  sonradan Claude ile oyuna bağlandı ve Deprem / Sel / Yangın olarak bölündü; tasarım korundu.

### 2.8 Metinler ve senaryo
- Karar kartı olayları ve seçenekleri, afet nedeni cümleleri, "Biliyor muydunuz?" ipuçları (`game_data.gd`)
- Karakter isimleri ve cümleleri (`characters.gd`), açılış hikâyesi, öğretici, final ve oyun sonu konuşmaları
  (`dialogs.gd`), seslendirme senaryosu (`SESLENDIRME.md`)
- Claude ile yazıldı; ekibimiz tarafından yönlendirildi ve düzenlendi.

---

## 3. Mağaza ve harita görselleri (arayüzdeki resimler)

`portofolyo/assets/textures/` içindeki PNG/SVG görseller (mağaza ürün görselleri, müze görselleri, harita işaretleri:
`acil_cikis_*`, `afad_*`, `belediye_*`, `bina_*`, `brosur_*`, `cadir_*`, `*_muze_*`, `elektrik_teli_*`,
`gaz_borusu_*`, `gazete_*` …).

| Ne | Kim |
|---|---|
| Arayüzdeki resimler (mağaza ürünleri, müzeler, harita işaretleri) | **Claude ile üretildi (yapay zekâ)** |
| Mağaza arayüzü, ekran tasarımı, görsellerin seçimi ve yerleşimi | **Ekibimiz tarafından yapıldı** |

(`terrain_mask.png`, `land_mask.png`, `sand_mask.png` bu tabloya dahil değil; `map_gen.py` üretir, bkz. 2.6.)

---

## 4. Araçlar (`tools/`)

| Dosya | Ne yapar | Kim |
|---|---|---|
| `asset_gen/*.py` | 3B modelleri üretir | Claude |
| `organize_assets.py` | Modelleri klasörler, `ASSETS.md` yazar | Claude |
| `map_gen.py` | Haritayı üretir | Claude |
| `audio_gen.py` | Ses ve müziği sentezler | Claude |
| `ui_icons.py` | Mağaza SVG ikonları | Claude |
| `ui_icon_cut.py` | Deneme ikon sayfalarını 4 ikona bölen, arka planı şeffaf yapan yardımcı betik | Claude |
| `font_add_turkish.py` | Fredoka'ya Türkçe harfler | Claude |
| `elevenlabs_tts.py`, `make_voice_md.py`, `voices.json` | Seslendirmeleri ElevenLabs ile üretir | Ekibimiz tarafından yapıldı |
| `preview/` | Modelleri tarayıcıda önizleme sayfası | Claude |
