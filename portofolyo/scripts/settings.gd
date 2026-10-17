class_name Settings
extends RefCounted
## Oyuncu ayarlari (user://settings.cfg). Menu ve oyun ici duraklatma ekrani kullanir.
## Ses: Master / Music / SFX / Ambience veri yollari (yoksa olusturulur).

const PATH := "user://settings.cfg"
const BUSES := ["Music", "SFX", "Ambience"]
const DEFAULTS := {"master": 0.8, "music": 0.7, "sfx": 0.8, "ambience": 0.6, "fullscreen": false, "shake": true}

static var values := {}


static func ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")


static func load_settings() -> void:
	values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in DEFAULTS:
			values[k] = cfg.get_value("ayarlar", k, DEFAULTS[k])


static func get_value(key: String) -> Variant:
	if values.is_empty():
		load_settings()
	return values.get(key, DEFAULTS.get(key))


static func set_value(key: String, v: Variant) -> void:
	if values.is_empty():
		load_settings()
	values[key] = v
	apply()
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("ayarlar", k, values[k])
	cfg.save(PATH)


static func apply() -> void:
	if values.is_empty():
		load_settings()
	ensure_buses()
	for pair in [["Master", "master"], ["Music", "music"], ["SFX", "sfx"], ["Ambience", "ambience"]]:
		var i := AudioServer.get_bus_index(pair[0])
		var v: float = float(values[pair[1]])
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.01)
	var fs: bool = values.fullscreen
	var mode := DisplayServer.window_get_mode()
	if fs and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fs and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
