extends Node
## Ses yoneticisi: efektler, ortam sesleri (dalga, kus, yagmur, siren) ve muzik.
## Sesler tools/audio_gen.py ile uretilir: assets/audio/*.wav
## Kullanim: audio.play("coins"), audio.set_music("calm" / "tense"), audio.set_rain(true)

const DIR := "res://assets/audio/"
const VOLUMES := {"hover": -22.0, "click": -10.0, "quake": 0.0, "alarm": -4.0, "collapse": -3.0, "thunder": -2.0}

@export var music_db := -13.0
@export var sfx_db := -5.0
@export var ambience_db := -16.0

var _pool: Array[AudioStreamPlayer] = []
var _streams := {}
var _music: Array[AudioStreamPlayer] = []
var _music_mode := ""
var _rain: AudioStreamPlayer
var _siren: AudioStreamPlayer
var _wind: AudioStreamPlayer


func _ready() -> void:
	add_to_group("audio")
	Settings.apply()  # ses yollari (Music / SFX / Ambience) ve kayitli ses seviyeleri
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = -80.0
		m.bus = "Music"
		add_child(m)
		_music.append(m)
	# dalgalar arkadan yumusakca: sessizden baslayip yavasca duyulur hale gelir
	var waves := _ambient("waves_loop", -60.0)
	create_tween().tween_property(waves, "volume_db", ambience_db - 3.0, 6.0).set_trans(Tween.TRANS_SINE)
	_ambient("birds_loop", ambience_db - 6.0)
	_rain = _ambient("rain_loop", -80.0)
	_siren = _ambient("siren_loop", -80.0)
	_wind = _ambient("wind_loop", -80.0)


func _stream(sound: String, loop := false) -> AudioStream:
	if not _streams.has(sound):
		var s = load(DIR + sound + ".wav")
		if s == null:
			return null
		if loop and s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
		_streams[sound] = s
	return _streams[sound]


func _ambient(sound: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _stream(sound, true)
	p.volume_db = db
	p.bus = "Ambience"
	add_child(p)
	p.play()
	return p


## Tek seferlik efekt. pitch > 0 ise o perdeden calar (ornek: seri arttikca yukselen ses).
func play(sound: String, pitch := 0.0) -> void:
	var s := _stream(sound)
	if s == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.volume_db = sfx_db + VOLUMES.get(sound, 0.0)
			p.pitch_scale = randf_range(0.95, 1.05) if sound in ["click", "hover", "build", "collapse"] else 1.0
			if pitch > 0.0:
				p.pitch_scale = pitch
			p.play()
			return


## Muzik: "calm" (gunluk) / "tense" (afet). Yumusak gecis.
func set_music(mode: String) -> void:
	if mode == _music_mode:
		return
	_music_mode = mode
	var incoming := _music[0] if not _music[0].playing or _music[0].volume_db < -40.0 else _music[1]
	var outgoing := _music[1] if incoming == _music[0] else _music[0]
	incoming.stream = _stream("music_" + mode, true)
	incoming.volume_db = -40.0
	incoming.play()
	var tw := create_tween().set_parallel()
	tw.tween_property(incoming, "volume_db", music_db, 1.5)
	tw.tween_property(outgoing, "volume_db", -60.0, 1.5)
	tw.chain().tween_callback(outgoing.stop)
	_fade(_siren, ambience_db - 2.0 if mode == "tense" else -80.0)


## Afet oncesi ruzgar ugultusu.
func set_wind(on: bool) -> void:
	_fade(_wind, ambience_db + 6.0 if on else -80.0)


func set_rain(on: bool) -> void:
	_fade(_rain, ambience_db + 4.0 if on else -80.0)


func _fade(p: AudioStreamPlayer, db: float) -> void:
	if p == null:
		return
	create_tween().tween_property(p, "volume_db", db, 1.2)
