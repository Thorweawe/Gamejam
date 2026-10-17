"""ElevenLabs ile Nermin ve Baskan repliklerini seslendirir.

Replikler portofolyo/scripts/dialogs.gd ve characters.gd'den okunur (id, who, mood, text).
Cikti: portofolyo/assets/voice/<id>.mp3 (dialog_player.gd burada bulursa calar).

API anahtari: ELEVENLABS_API_KEY ortam degiskeni ya da tools/.elevenlabs_key dosyasi
(.gitignore'da, repoya girmez). Ses kimlikleri: tools/voices.json

  py tools/elevenlabs_tts.py --find-voices              # Turkce ses kutuphanesinde aday ara
  py tools/elevenlabs_tts.py --add-voice OWNER VOICE AD  # paylasilan sesi hesaba ekle
  py tools/elevenlabs_tts.py                            # eksik dosyalari uret
  py tools/elevenlabs_tts.py --force intro_01 tut_03    # secili replikleri yeniden uret
  py tools/elevenlabs_tts.py --force nermin             # bir karakterin tum repliklerini yeniden uret
  py tools/elevenlabs_tts.py --force                    # hepsini yeniden uret
"""

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIALOGS = ROOT / "portofolyo" / "scripts" / "dialogs.gd"
CHARACTERS = ROOT / "portofolyo" / "scripts" / "characters.gd"  # kart karakterlerinin selam / tepkileri
OUT_DIR = ROOT / "portofolyo" / "assets" / "voice"
TOOLS = Path(__file__).resolve().parent
VOICES_FILE = TOOLS / "voices.json"
KEY_FILE = TOOLS / ".elevenlabs_key"
API = "https://api.elevenlabs.io/v1"

LINE_RE = re.compile(r'\{"id":\s*"(?P<id>[^"]+)",\s*"who":\s*"(?P<who>[^"]+)"(?P<rest>.*?)"text":\s*"(?P<text>(?:[^"\\]|\\.)*)"\}', re.S)
MOOD_RE = re.compile(r'"mood":\s*"([^"]+)"')

# Duyguya gore ufak ayar: daha dusuk stability = daha hareketli okuma.
MOOD_TWEAKS = {
    "surprised": {"stability": -0.12, "style": 0.15},
    "angry": {"stability": -0.08, "style": 0.15},
    "happy": {"stability": -0.05, "style": 0.08},
    "worried": {"stability": 0.0, "style": 0.05},
}


# eleven_v3 duygu etiketleri (metnin basina eklenir, okunmaz).
V3_TAGS = {
    "surprised": "[excited]",
    "angry": "[frustrated]",
    "happy": "[cheerfully]",
    "worried": "[worried]",
}


def api_key() -> str:
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not key and KEY_FILE.exists():
        key = KEY_FILE.read_text(encoding="utf-8").strip()
    if not key:
        sys.exit("API anahtari yok: ELEVENLABS_API_KEY ayarla ya da tools/.elevenlabs_key dosyasina yaz.")
    return key


def request(method: str, path: str, body=None, accept="application/json") -> bytes:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method)
    req.add_header("xi-api-key", api_key())
    req.add_header("Accept", accept)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return resp.read()
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code} {path}: {e.read().decode('utf-8', 'replace')}")


def load_lines() -> list[dict]:
    src = DIALOGS.read_text(encoding="utf-8") + "\n" + CHARACTERS.read_text(encoding="utf-8")
    lines = []
    for m in LINE_RE.finditer(src):
        mood = MOOD_RE.search(m["rest"])
        text = m["text"].replace('\\"', '"')
        lines.append({"id": m["id"], "who": m["who"], "mood": mood[1] if mood else "neutral", "text": text})
    return lines


def find_voices() -> None:
    for gender, age in (("female", "middle_aged"), ("female", "old"), ("male", "middle_aged"), ("male", "old")):
        q = urllib.parse.urlencode({"language": "tr", "gender": gender, "age": age, "page_size": 8})
        res = json.loads(request("GET", f"/shared-voices?{q}"))
        print(f"\n=== {gender} / {age} ===")
        for v in res.get("voices", []):
            print(f"- {v['name']} | voice_id={v['voice_id']} owner={v['public_owner_id']}")
            print(f"    {(v.get('description') or '').strip()[:160]}")
            print(f"    preview: {v.get('preview_url')}")


DESIGNS = {
    "nermin": {
        "description": "A native Turkish woman in her early fifties with a natural Istanbul accent. A chatty, warm and "
                       "dramatic municipal secretary: fast, energetic, expressive, a little theatrical and funny. "
                       "Slightly husky mature voice, clear studio recording.",
        "text": "Başkanım, hoş geldiniz! Ben Nermin, sekreteriniz. Çayınız da hazır, tavşan kanı! Otuz yıldır "
                "buradayım, tam yedi başkan gördüm. Hepsi aynı şeyi söyledi: Bize bir şey olmaz! Olmaz mı! Biri "
                "deprem olunca dolabın üstüne çıktı.",
    },
    "baskan": {
        "description": "A native Turkish man in his forties with a deep, full, resonant voice and a natural Istanbul "
                       "accent. A newly elected mayor: confident, warm, sincere, slightly bewildered but determined. "
                       "Calm conversational pace, clear studio recording.",
        "text": "Sağ ol Nermin Hanım. İlk günden çay... Bu belediyeyi şimdiden sevdim. Tamam, tamam, ben öyle "
                "olmayacağım. Söyle bakalım, durum ne? Hazırız Nermin Hanım. Herkes görev başına!",
    },
}


def design_voices(out_dir: Path, who_list: list[str]) -> None:
    import base64
    out_dir.mkdir(parents=True, exist_ok=True)
    for who in who_list or list(DESIGNS):
        d = DESIGNS[who]
        res = json.loads(request("POST", "/text-to-voice/design", {
            "voice_description": d["description"], "text": d["text"], "model_id": "eleven_ttv_v3"}))
        for n, p in enumerate(res["previews"], 1):
            f = out_dir / f"{who}_{n}.mp3"
            f.write_bytes(base64.b64decode(p["audio_base_64"]))
            print(f"{f.name}  generated_voice_id={p['generated_voice_id']}")


def save_design(generated_id: str, who: str, name: str) -> None:
    res = json.loads(request("POST", "/text-to-voice", {
        "voice_name": name, "voice_description": DESIGNS[who]["description"], "generated_voice_id": generated_id}))
    print("voice_id =", res["voice_id"])


def add_voice(owner: str, voice_id: str, name: str) -> None:
    print(request("POST", f"/voices/add/{owner}/{voice_id}", {"new_name": name}).decode())


def synthesize(only: list[str], force: bool, out_dir: Path | None = None, model: str | None = None,
               voice_overrides: dict | None = None) -> None:
    voices = json.loads(VOICES_FILE.read_text(encoding="utf-8"))
    model = model or voices["model_id"]
    for who, vid in (voice_overrides or {}).items():
        voices[who] = dict(voices[who], voice_id=vid)
    out_dir = out_dir or OUT_DIR
    v3 = model.startswith("eleven_v3")
    lines = load_lines()
    out_dir.mkdir(parents=True, exist_ok=True)
    done = 0
    for i, line in enumerate(lines):
        if only and line["id"] not in only and line["who"] not in only:
            continue
        out = out_dir / f"{line['id']}.mp3"
        if out.exists() and not force:
            continue
        cfg = voices[line["who"]]
        settings = dict(cfg["settings"])
        text = line["text"]
        if v3:
            # v3: stability sadece 0.0 (yaratici) / 0.5 (dogal) / 1.0 (sabit); duygu etiketle verilir.
            # Karakter basina "v3_stability" (1.0 = ses tinisi her satirda ayni kalir) ve "tags" (false = etiketsiz).
            settings = {"stability": cfg.get("v3_stability", voices.get("v3_stability", 0.5))}
            tags = cfg.get("tags", V3_TAGS)
            tag = tags.get(line["mood"]) if tags else None
            if tag:
                text = f"{tag} {text}"
        else:
            for k, d in MOOD_TWEAKS.get(line["mood"], {}).items():
                settings[k] = round(min(1.0, max(0.0, settings.get(k, 0.0) + d)), 2)
        body = {"text": text, "model_id": model, "voice_settings": settings}
        if v3:
            body["language_code"] = "tr"
        if "seed" in cfg:
            body["seed"] = cfg["seed"]  # ayni tohum = satirlar arasi daha tutarli ses
        # Ayni sahnedeki komsu replikler tonlamayi tutarli yapar (bark'lar tek basina; v3 desteklemiyor).
        scene = line["id"].rsplit("_", 1)[0]
        if not scene.startswith("bark") and not v3:
            if i > 0 and lines[i - 1]["id"].rsplit("_", 1)[0] == scene:
                body["previous_text"] = lines[i - 1]["text"]
            if i + 1 < len(lines) and lines[i + 1]["id"].rsplit("_", 1)[0] == scene:
                body["next_text"] = lines[i + 1]["text"]
        audio = request("POST", f"/text-to-speech/{cfg['voice_id']}?output_format=mp3_44100_128", body, accept="audio/mpeg")
        out.write_bytes(audio)
        done += 1
        print(f"ok  {line['id']:<16} {line['who']:<7} {line['mood']:<9} {len(audio) // 1024} KB")
    print(f"{done} dosya uretildi -> {out_dir}")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--find-voices", action="store_true")
    p.add_argument("--design", action="store_true", help="Voice Design ile Turkce ses adaylari uret (nermin/baskan)")
    p.add_argument("--save-design", nargs=3, metavar=("GENERATED_ID", "KIM", "AD"), help="tasarlanan sesi hesaba kaydet")
    p.add_argument("--add-voice", nargs=3, metavar=("OWNER_ID", "VOICE_ID", "NAME"))
    p.add_argument("--list", action="store_true", help="dialogs.gd'den okunan replikleri goster")
    p.add_argument("--force", action="store_true", help="mevcut dosyalarin uzerine yaz")
    p.add_argument("--model", help="voices.json'daki model yerine (orn. eleven_v3)")
    p.add_argument("--out", type=Path, help="cikti klasoru (deneme icin)")
    p.add_argument("--voice", action="append", default=[], metavar="KIM=VOICE_ID", help="orn. nermin=XrExE9yKIg1WjnnlVkGX")
    p.add_argument("ids", nargs="*")
    a = p.parse_args()
    if a.design:
        design_voices(a.out or ROOT / "ses_deneme" / "tasarim", a.ids)
    elif a.save_design:
        save_design(*a.save_design)
    elif a.find_voices:
        find_voices()
    elif a.add_voice:
        add_voice(*a.add_voice)
    elif a.list:
        for l in load_lines():
            print(f"{l['id']:<16} {l['who']:<7} {l['mood']:<9} {l['text']}")
    else:
        synthesize(a.ids, a.force, a.out, a.model, dict(v.split("=", 1) for v in a.voice))


if __name__ == "__main__":
    main()
