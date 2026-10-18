"""Oyunun tum ses efektlerini ve muziklerini sentezler -> portofolyo/assets/audio/*.wav

  python tools/audio_gen.py

Hepsi kodla uretilir (lisans sorunu yok). 22050 Hz, mono, 16 bit.
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "portofolyo", "assets", "audio")
rng = np.random.default_rng(1)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack=0.005, release=0.1, sustain=1.0):
    e = np.ones(n) * sustain
    a = max(1, int(SR * attack))
    r = max(1, int(SR * release))
    e[:a] = np.linspace(0, sustain, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def decay(n, rate):
    return np.exp(-np.arange(n) / SR * rate)


def tone(freq, sec, kind="sine", harmonics=(1.0,)):
    x = t(sec)
    phase = 2 * np.pi * np.cumsum(np.broadcast_to(freq, x.shape)) / SR
    if kind == "square":
        return np.sign(np.sin(phase)) * 0.6
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(phase))
    return sum(a * np.sin(phase * (i + 1)) for i, a in enumerate(harmonics))


def noise(sec, color="white"):
    n = rng.normal(size=int(SR * sec))
    if color == "brown":
        n = np.cumsum(n)
        n -= np.convolve(n, np.ones(2000) / 2000, mode="same")
        n /= np.max(np.abs(n)) + 1e-9
    elif color == "pink":
        n = lowpass(n, 2500) + 0.3 * n
    return n


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def lowpass_fast(x, cutoff):
    # birinci dereceden suzgec, vektorel (scipy olmadan): ust uste ortalama
    k = max(1, int(SR / cutoff / 2))
    return np.convolve(x, np.ones(k) / k, mode="same")


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def place(buf, x, start):
    i = int(start * SR)
    end = min(len(buf), i + len(x))
    buf[i:end] += x[:end - i]


def loopable(x, fade=0.3):
    """Basi ve sonu capraz karistirilarak kesintisiz dongu."""
    f = int(SR * fade)
    head = x[:f].copy()
    x = x[f:].copy()
    x[-f:] = x[-f:] * np.linspace(1, 0, f) + head * np.linspace(0, 1, f)
    return x


def save(name, x, gain=0.8):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) + 1e-9
    x = x / peak * gain
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(name, f"{len(x) / SR:.1f}s")


NOTE = {n: 440 * 2 ** ((i - 9) / 12) for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def hz(name, octave=4):
    return NOTE[name] * 2 ** (octave - 4)


def pluck(freq, sec=0.6, bright=1.0):
    n = int(SR * sec)
    return tone(freq, sec, harmonics=(1.0, 0.35 * bright, 0.15 * bright, 0.05)) * decay(n, 7) * env(n, 0.003, 0.05)


def marimba(freq, sec=0.7):
    n = int(SR * sec)
    return (np.sin(2 * np.pi * freq * t(sec)) + 0.25 * np.sin(2 * np.pi * freq * 4 * t(sec)) * decay(n, 30)) * decay(n, 6) * env(n, 0.002, 0.05)


def pad(freqs, sec):
    n = int(SR * sec)
    x = np.zeros(n)
    for f in freqs:
        for det in (-0.6, 0.6):
            x += np.sin(2 * np.pi * (f + det) * t(sec)) * 0.5
    return x * env(n, 0.4, 0.6)


# ------------------------------------------------------------------ efektler
def sfx():
    n = int(SR * 0.08)
    save("click", tone(950, 0.08, harmonics=(1, 0.3)) * decay(n, 60), 0.5)
    n = int(SR * 0.04)
    save("hover", tone(1700, 0.04) * decay(n, 120), 0.18)
    save("coins", mix(marimba(1318, 0.35), np.pad(marimba(1760, 0.45), (int(SR * 0.07), 0))), 0.6)
    b = np.zeros(int(SR * 0.9))
    for i, s in enumerate((0.0, 0.28, 0.56)):
        hit = noise(0.12) * decay(int(SR * 0.12), 45) * 0.6 + tone(140 - i * 10, 0.12) * decay(int(SR * 0.12), 30)
        place(b, hit, s)
    save("build", b, 0.7)
    p = np.zeros(int(SR * 0.6))
    for i, nn in enumerate(("C", "E", "G")):
        place(p, marimba(hz(nn, 5), 0.4), i * 0.08)
    save("popup", p, 0.55)
    e = mix(tone(220, 0.15, "tri") * env(int(SR * 0.15), 0.005, 0.05),
            np.pad(tone(175, 0.22, "tri") * env(int(SR * 0.22), 0.005, 0.08), (int(SR * 0.14), 0)))
    save("error", e, 0.5)
    # acil durum alarmi: yukselen-alcalan siren
    x = t(2.2)
    f = 650 + 380 * (0.5 - 0.5 * np.cos(2 * np.pi * x / 1.1))
    save("alarm", tone(f, 2.2, harmonics=(1, 0.4, 0.2)) * env(len(x), 0.05, 0.3), 0.55)
    save("alert_soft", mix(marimba(880, 0.5), np.pad(marimba(660, 0.6), (int(SR * 0.22), 0))), 0.55)
    # deprem ugultusu
    sec = 4.5
    n = int(SR * sec)
    rumble = noise(sec, "brown") * 0.9 + np.sin(2 * np.pi * 38 * t(sec)) * 0.5 + np.sin(2 * np.pi * 52 * t(sec)) * 0.3
    shake = 0.6 + 0.4 * np.sin(2 * np.pi * 7 * t(sec)) * np.sin(2 * np.pi * 0.9 * t(sec))
    save("quake", rumble * shake * env(n, 0.6, 1.8), 0.9)
    # cokus: gurultu patlamasi + dusuk gumburtu + dokulen parcalar
    c = np.zeros(int(SR * 2.0))
    place(c, noise(1.2) * decay(int(SR * 1.2), 4) * 0.7, 0)
    place(c, np.sin(2 * np.pi * np.linspace(90, 35, int(SR * 0.6)) * t(0.6)) * decay(int(SR * 0.6), 5), 0)
    for i in range(14):
        place(c, noise(0.05) * decay(int(SR * 0.05), 80) * rng.uniform(0.2, 0.5), rng.uniform(0.2, 1.7))
    save("collapse", lowpass_fast(c, 3000), 0.8)
    # gorev: kisa siren "vuu-vuu"
    x = t(1.0)
    f = np.where((x * 4).astype(int) % 2 == 0, 760, 980)
    save("dispatch", tone(f, 1.0, harmonics=(1, 0.3)) * env(len(x), 0.01, 0.15), 0.45)
    s = np.zeros(int(SR * 0.9))
    for i, nn in enumerate(("C", "E", "G")):
        place(s, marimba(hz(nn, 5), 0.5), i * 0.1)
    place(s, marimba(hz("C", 6), 0.6), 0.3)
    save("success", s, 0.6)
    f2 = np.zeros(int(SR * 1.0))
    for i, nn in enumerate(("A", "F", "D")):
        place(f2, pluck(hz(nn, 3), 0.6, 0.6), i * 0.18)
    save("fail", f2, 0.55)
    d = np.zeros(int(SR * 2.0))
    for i, nn in enumerate(("G", "C", "E")):
        place(d, marimba(hz(nn, 5), 1.2) * 0.8, i * 0.25)
    save("day", d, 0.5)
    en = np.zeros(int(SR * 2.4))
    for i, (nn, o) in enumerate((("C", 5), ("E", 5), ("G", 5), ("C", 6))):
        place(en, pluck(hz(nn, o), 1.2), i * 0.15)
    place(en, pad([hz("C", 4), hz("E", 4), hz("G", 4)], 1.8) * 0.3, 0.6)
    save("end", en, 0.7)


# ------------------------------------------------------------------ gok gurultusu (saganak)
def thunder():
    """Simsek sesi: keskin catirti (yakin yildirim) + yuvarlanan, dalga dalga sonen derin gurleme."""
    sec = 5.5
    n = int(SR * sec)
    out = np.zeros(n)
    # catirti: yuksek frekansli kirik kirik patlama (birkac ust uste carpma)
    for st, amp in ((0.0, 0.28), (0.05, 0.2), (0.13, 0.15), (0.24, 0.1)):
        k = lowpass_fast(noise(0.35), 3500)
        hi = k - lowpass_fast(k, 900)
        place(out, hi * decay(len(hi), 16) * amp, st)
    # derin gurleme: kahverengi gurultu, birkac kabarma ile yuvarlanir ve uzun kuyrukla soner
    rum = lowpass_fast(lowpass_fast(noise(sec, "brown"), 220), 220) * 2.6 + lowpass_fast(lowpass_fast(noise(sec), 90), 90) * 1.4
    x = t(sec)
    swell = np.zeros(n)
    for c, w, a in ((0.25, 0.5, 1.0), (0.95, 0.7, 0.8), (1.8, 0.9, 0.65), (2.9, 1.2, 0.45)):
        swell += a * np.exp(-((x - c) / w) ** 2)
    swell = np.maximum(swell, decay(n, 0.9) * 0.35)
    out += rum * swell
    # en dipte gumburtu
    boom = np.sin(2 * np.pi * np.cumsum(np.linspace(62, 28, int(SR * 1.6))) / SR) * decay(int(SR * 1.6), 2.2)
    place(out, boom * 0.6, 0.05)
    save("thunder", out * env(n, 0.002, 1.2), 0.9)


# ------------------------------------------------------------------ ortam donguleri
def ambience():
    save("rain_loop", loopable(lowpass_fast(noise(6.3), 4000) * 0.8 + noise(6.3) * 0.15), 0.5)
    waves()
    b = np.zeros(int(SR * 10.3))
    for i in range(16):
        s = rng.uniform(0.2, 9.5)
        f0 = rng.uniform(2600, 4200)
        for k in range(rng.integers(2, 5)):
            d = rng.uniform(0.05, 0.12)
            sweep = np.linspace(f0, f0 * rng.uniform(0.7, 1.3), int(SR * d))
            place(b, np.sin(2 * np.pi * np.cumsum(sweep) / SR) * env(int(SR * d), 0.01, 0.03) * 0.3, s + k * 0.13)
    save("birds_loop", loopable(b), 0.35)
    f = lowpass_fast(noise(5.3, "brown"), 400) * 0.6
    for i in range(140):
        place(f, noise(0.01) * rng.uniform(0.2, 1.0), rng.uniform(0, 5.2))
    save("fire_loop", loopable(f), 0.5)
    x = t(4.3)
    f = np.where((x * 2).astype(int) % 2 == 0, 700, 940)
    save("siren_loop", loopable(tone(f, 4.3, harmonics=(1, 0.3)) * 0.8), 0.35)


def waves():
    """Uzaktan gelen yumusak dalgalar: derin, yavas kabaran su + kiyida hafif kopuk hisirtisi.
    Iki dalga ritmi (8.25 sn ve 5.5 sn) 16.5 sn'de tam dongu yapar -> tekrar hissi az."""
    sec = 16.5
    x = t(sec)
    w1 = (0.5 - 0.5 * np.cos(2 * np.pi * x / 8.25)) ** 2
    w2 = (0.5 - 0.5 * np.cos(2 * np.pi * (x + 2.0) / 5.5)) ** 2
    body = lowpass_fast(lowpass_fast(noise(sec, "brown"), 300), 300) * (0.25 + 0.55 * w1 + 0.2 * w2)
    crest1 = (0.5 - 0.5 * np.cos(2 * np.pi * (x - 1.4) / 8.25)) ** 6
    crest2 = (0.5 - 0.5 * np.cos(2 * np.pi * (x + 0.6) / 5.5)) ** 6
    foam = lowpass_fast(lowpass_fast(noise(sec), 1800), 1800) * (crest1 + 0.45 * crest2) * 0.35
    save("waves_loop", loopable(body + foam, 1.0), 0.32)


def start_game():
    """Menuden oyuna gecis: yukselen ruzgar 'vinn'i + yukari cikan marimba arpeji + yumusak akor."""
    sec = 2.6
    n = int(SR * sec)
    x = t(sec)
    # vinn: suzgeci acilan gurultu, ortada tepe yapar
    whoosh = np.zeros(n)
    sweep = noise(sec)
    for i, cut in enumerate([300, 700, 1500, 3000]):
        whoosh += lowpass_fast(sweep, cut) * np.exp(-((x - 0.45 - i * 0.12) / 0.35) ** 2) * 0.35
    out = whoosh * 0.6
    notes = [hz("C", 4), hz("E", 4), hz("G", 4), hz("C", 5), hz("E", 5)]
    for i, f in enumerate(notes):
        place(out, marimba(f, 0.9) * (0.5 + i * 0.08), 0.25 + i * 0.11)
    chord = pad([hz("C", 4), hz("G", 4), hz("E", 5)], 1.8) * 0.35
    place(out, chord * env(len(chord), 0.15, 0.9), 0.8)
    save("start_game", out * env(n, 0.01, 0.4), 0.7)


def babble():
    """Seslendirmesi olmayan karakterler icin kisa hece sesleri (a, e, o, i). Oyunda karakterin
    ses perdesiyle (pitch) calinir: komik 'mirildanma' konusmasi."""
    formants = {"a": (800, 1200), "e": (500, 1850), "o": (480, 880), "i": (320, 2300)}
    f0 = 210.0
    sec = 0.085
    x = t(sec)
    n = len(x)
    for v, (f1, f2) in formants.items():
        y = np.zeros(n)
        for k in range(1, 18):
            f = f0 * k
            w = np.exp(-((f - f1) / 160.0) ** 2) + 0.6 * np.exp(-((f - f2) / 220.0) ** 2) + 0.15 / k
            y += w * np.sin(2 * np.pi * f * x * (1.0 + 0.04 * x / sec))
        save("blip_" + v, y * env(n, 0.006, 0.035), 0.55)


def wind():
    """Afet oncesi ruzgar: alcak ugultu + yavas esintiler + hafif islik."""
    sec = 8.3
    x = t(sec)
    gust = 0.45 + 0.55 * (0.5 - 0.5 * np.cos(2 * np.pi * x / 4.15)) ** 1.5
    low = lowpass_fast(noise(sec, "brown"), 500) * 0.9
    hiss = lowpass_fast(noise(sec, "pink"), 2200) * 0.35
    whistle = np.sin(2 * np.pi * np.cumsum(620 + 140 * np.sin(2 * np.pi * x / 2.6)) / SR) * 0.04
    save("wind_loop", loopable((low + hiss * gust + whistle * gust) * gust), 0.5)


# ------------------------------------------------------------------ muzik
def music_calm():
    bpm = 88
    beat = 60 / bpm
    bars = 16
    sec = bars * 4 * beat
    out = np.zeros(int(SR * (sec + 2)))
    prog = [("C", "E", "G"), ("G", "B", "D"), ("A", "C", "E"), ("F", "A", "C")]
    melody = ["E", "G", "A", "G", "E", "D", "C", "D", "E", "G", "C", "B", "A", "G", "E", "D"]
    for bar in range(bars):
        ch = prog[bar % 4]
        start = bar * 4 * beat
        place(out, pad([hz(n, 3) for n in ch], 4 * beat + 0.4) * 0.12, start)
        place(out, pluck(hz(ch[0], 2), 1.5, 0.4) * 0.5, start)
        place(out, pluck(hz(ch[0], 2), 1.0, 0.4) * 0.35, start + 2 * beat)
        for k in range(8):  # arpej
            n = ch[[0, 1, 2, 1][k % 4]]
            place(out, marimba(hz(n, 4), 0.5) * 0.18, start + k * beat / 2)
        if bar % 2 == 1 or bar >= 8:  # melodi
            for k in range(4):
                n = melody[(bar * 4 + k) % len(melody)]
                place(out, marimba(hz(n, 5), 0.8) * 0.28, start + k * beat)
    out = out[:int(SR * sec)]
    save("music_calm", loopable(out, 0.5), 0.6)


def music_tense():
    bpm = 118
    beat = 60 / bpm
    bars = 8
    sec = bars * 4 * beat
    out = np.zeros(int(SR * (sec + 2)))
    prog = [("A", "C", "E"), ("A", "C", "E"), ("F", "A", "C"), ("E", "G#", "B")]
    for bar in range(bars):
        ch = prog[bar % 4]
        start = bar * 4 * beat
        place(out, pad([hz(n, 3) for n in ch], 4 * beat + 0.3) * 0.15, start)
        for k in range(16):  # ostinato 16'lik
            n = ch[0] if k % 4 == 0 else ch[(k // 2) % 3]
            place(out, pluck(hz(n, 3 if k % 4 == 0 else 4), 0.25, 0.8) * (0.28 if k % 4 == 0 else 0.16), start + k * beat / 4)
        for k in range(4):  # davul: kick
            kick_n = int(SR * 0.35)
            kick = np.sin(2 * np.pi * np.cumsum(np.linspace(110, 40, kick_n)) / SR) * decay(kick_n, 9)
            place(out, kick * 0.7, start + k * beat)
            place(out, noise(0.08) * decay(int(SR * 0.08), 40) * 0.12, start + k * beat + beat / 2)
    out = out[:int(SR * sec)]
    save("music_tense", loopable(out, 0.3), 0.65)


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:  # sadece istenenler: python audio_gen.py wind
        for name in sys.argv[1:]:
            globals()[name]()
        sys.exit(0)
    sfx()
    thunder()
    start_game()
    babble()
    wind()
    ambience()
    music_calm()
    music_tense()
