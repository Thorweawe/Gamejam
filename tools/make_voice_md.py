import re

import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "portofolyo", "scripts", "dialogs.gd"), encoding='utf-8').read()
names = {"baskan": "BAŞKAN", "nermin": "NERMİN HANIM"}
mood_tr = {"happy": "neşeli", "neutral": "normal", "worried": "endişeli", "surprised": "şaşkın", "angry": "kararlı"}
anim_tr = {"wave": "el sallar", "tea": "çay yudumlar", "point": "parmağıyla gösterir", "jump": "zıplar",
           "facepalm": "elini alnına vurur", "shrug": "omuz silker", "nod": "başını sallar",
           "shake": "başını iki yana sallar", "angry": "sinirlenir"}
LINE = re.compile(r'\{"id": "([^"]+)", "who": "([^"]+)"(.*?)"text": "((?:[^"\\]|\\.)*)"\}', re.S)


def section(const):
    body = re.search(r'const %s := \[(.*?)\n\]' % const, src, re.S).group(1)
    rows = []
    for m in LINE.finditer(body):
        id_, who, mid, text = m.groups()
        mood = re.search(r'"mood": "([^"]+)"', mid)
        anim = re.search(r'"anim": "([^"]+)"', mid)
        note = ", ".join(x for x in [mood_tr.get(mood.group(1), "") if mood else "",
                                     anim_tr.get(anim.group(1), "") if anim else ""] if x)
        rows.append((id_, who, text.replace('\\"', '"'), note))
    return rows


def barks():
    body = re.search(r'const BARKS := \{(.*?)\n\}', src, re.S).group(1)
    rows = []
    for m in re.finditer(r'"([a-z_]+)": \{"id": "([^"]+)", "who": "([^"]+)", "mood": "([^"]+)",\s*"text": "((?:[^"\\]|\\.)*)"\}', body, re.S):
        key, id_, who, mood, text = m.groups()
        rows.append((id_, key, text, mood_tr.get(mood, "")))
    return rows


when = {"first_forecast": "İlk hava uyarısında", "first_quake": "İlk depremde", "first_house_fire": "İlk ev yangınında",
        "first_forest_fire": "İlk orman yangınında", "first_flood": "İlk selde", "aftershock": "İlk artçı depremde",
        "prep_good": "Güçlendirilmiş binalar ilk kez ayakta kalınca", "prep_bad": "İlk kez hazırlıksız yakalanınca",
        "low_money": "Kasa 1.500 TL'nin altına düşünce", "streak": "İlk 3'lü kurtarma serisinde"}
char_names = {"selim": "Müteahhit Selim Bey", "husnu": "Muhtar Hüsnü Amca", "murat": "İtfaiye Müdürü Murat Şef",
              "elif": "AFAD Koordinatörü Elif Hanım", "ayse": "Ayşe Öğretmen", "tolga": "Gazeteci Tolga",
              "oguz": "Prof. Dr. Oğuz Taner", "riza": "Esnaf Rıza Usta", "zeynep": "Dr. Zeynep Aydın"}
for c, n in char_names.items():
    when["love_" + c] = n + " tam kalbe ulaşınca"
    when["hate_" + c] = n + " tamamen küsünce"
tier_tr = {"love": "selam: hayran (+3)", "like": "selam: sıcak (+1/+2)", "neutral": "selam: nötr (0)",
           "cold": "selam: soğuk (-1/-2)", "hate": "selam: küs (-3)", "pleased": "tepki: dostu yine sevindi",
           "won": "tepki: gönlü alındı", "hurt": "tepki: kırıldı", "fed_up": "tepki: zaten küstü, yine kızdı"}
chars_src = open(os.path.join(ROOT, "portofolyo", "scripts", "characters.gd"), encoding='utf-8').read()
out = ["# Seslendirme Senaryosu", "",
       "Bu dosya `portofolyo/scripts/dialogs.gd` içindeki metinlerden üretildi (`tools/make_voice_md.py`). Metni değiştirirseniz önce orayı değiştirip betiği yeniden çalıştırın.", "",
       "## Nasıl kaydedilir?", "",
       "- Her satır ayrı bir dosya. Dosya adı tablodaki **Dosya** sütunu, örneğin `intro_01.ogg`.",
       "- Biçim: `.ogg` (önerilen), `.wav` ya da `.mp3`. Mono, 44.1 kHz yeterli.",
       "- Dosyaları `portofolyo/assets/voice/` klasörüne koyun. Oyun dosyayı bulursa sesi çalar ve karakterin ağzını sesin şiddetine göre oynatır. Bulamazsa yazı akar ve karakter mırıldanır; yani eksik dosya oyunu bozmaz, istediğiniz kadarını kaydedebilirsiniz.",
       "- Satır başında ve sonunda en fazla 0,2 sn sessizlik bırakın (yoksa ağız boşta açık bekler).",
       "- Toplam süre: açılış yaklaşık 70 sn, öğretici yaklaşık 90 sn.", "",
       "## Karakterler", "",
       "- **Başkan** (oyuncu): genç, iyi niyetli, biraz şaşkın ama kararlı. Doğal, samimi ton.",
       "- **Nermin Hanım** (sekreter): 30 yıllık emektar, her şeyi bilen, çay tutkunu, dramatik. Hızlı ve enerjik konuşur, abartılı tepkiler verir. Komedi onda.", "",
       "**Not** sütunu yüz ifadesini ve animasyonu yazar; o duyguyla okuyun."]
for title, const, desc in [("1. Açılış hikayesi", "INTRO", "Menüden sonra, oyunun başında oynar."),
                           ("2. Öğretici", "TUTORIAL", "Açılıştan hemen sonra. Nermin anlattıkça ekranda ilgili arayüz parçası parlar."),
                           ("3. Son gün (20. gün)", "FINALE", "Büyük afet zinciri başlamadan önce."),
                           ("4. Oyun sonu: iyi (A-C notu)", "ENDING_GOOD", ""),
                           ("5. Oyun sonu: kötü (D-F notu)", "ENDING_BAD", "")]:
    out += ["", "## " + title, ""]
    if desc:
        out += [desc, ""]
    out += ["| Dosya | Kim | Replik | Not |", "|---|---|---|---|"]
    for id_, who, text, note in section(const):
        out.append("| `%s` | %s | %s | %s |" % (id_, names.get(who, who), text, note))
out += ["", "## 6. Oyun içi kısa replikler (Nermin Hanım)", "",
        "Sol altta küçük kutuda çıkar, oyunu durdurmaz. Her biri oyunda bir kez söylenir.", "",
        "| Dosya | Ne zaman | Replik | Not |", "|---|---|---|---|"]
for id_, key, text, mood in barks():
    out.append("| `%s` | %s | %s | %s |" % (id_, when.get(key, key), text, mood))
out += ["", "## 7. Karar kartı karakterleri", "",
        "Kartı sunan karakter ilişki puanına (-3..+3) göre selam verir, kararından sonra önceki ilişkiye göre tepki verir. "
        "Metinler `portofolyo/scripts/characters.gd` içinde.", ""]
for c, n in char_names.items():
    out += ["### " + n, "", "| Dosya | Ne zaman | Replik |", "|---|---|---|"]
    for m in LINE.finditer(chars_src):
        id_, who, mid, text = m.groups()
        if who == c:
            kind = id_.split("_")[2] if "_greet_" in id_ else id_.split("_react_")[1]
            out.append("| `%s` | %s | %s |" % (id_, tier_tr.get(kind, kind), text.replace('\\"', '"')))
    out.append("")
open(os.path.join(ROOT, "SESLENDIRME.md"), 'w', encoding='utf-8').write("\n".join(out) + "\n")
print("satir:", sum(1 for l in out if l.startswith("| `")))
