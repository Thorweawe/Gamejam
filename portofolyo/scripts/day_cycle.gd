class_name DayCycle
extends Node3D
## Gece-gunduz dongusu.
## Gun icinde saat sabit durur (DAY_HOUR). "Gunu Gec" butonu (ya da N tusu) ile
## gun batimi -> gece -> gun dogumu animasyonu oynar, sonra yeni gun baslar.
## Oyun mantigi (gelir, olay karti, afet...) day_started sinyaline baglanmali.
## Gece isiklari: "night_lights" grubundaki isiklar karanlikta yanar; her isigin
## tam parlakligi "energy" meta degerindedir (bina pencereleri, lambalar, farlar).

signal day_started(day: int)
signal day_ending(day: int)  # animasyon basladiginda

const DAY_HOUR := 11.0  # gun boyunca sabit saat

## Animasyon asamalari (saniye)
@export var sunset_time := 2.0
@export var night_time := 2.0
@export var sunrise_time := 3.0
@export var city_path: NodePath = ^"../CityMap"
@export var ui_path: NodePath = ^"../UI"

var day := 1
var hour := DAY_HOUR
var transitioning := false
## true iken gun gecilemez (olay karti, afet, oyun sonu)
var locked := false:
	set(value):
		locked = value
		if is_node_ready():
			end_day_button.disabled = locked or transitioning
var _lights_k := -1.0

@onready var city: Node3D = get_node(city_path)
@onready var sun: DirectionalLight3D = city.get_node("Sun")
@onready var moon: DirectionalLight3D = $Moon
@onready var env: Environment = (city.get_node("WorldEnvironment") as WorldEnvironment).environment
@onready var sky: ProceduralSkyMaterial = env.sky.sky_material
@onready var ui: Node = get_node(ui_path)
@onready var day_label: Label = ui.get_node("ClockPanel/HBox/DayLabel")
@onready var dial: SunMoonDial = ui.get_node("ClockPanel/HBox/Dial")
@onready var traffic: Node = city.get_node_or_null("Traffic")
@onready var camera_rig: Node3D = city.get_node_or_null("CameraRig")
@onready var sea_material: ShaderMaterial = (city.get_node("Sea") as MeshInstance3D).mesh.material
@onready var end_day_button: Button = ui.get_node("EndDayButton")
@onready var banner: Label = ui.get_node("DayBanner")


func _ready() -> void:
	end_day_button.pressed.connect(skip_day)
	day_started.connect(_on_day_started)
	_add_street_lamp_lights()
	apply_time(hour)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_N and not end_day_button.disabled:
		skip_day()


## Gunu gec: ~7 sn'lik gece animasyonu, sonunda day_started yayilir.
func skip_day() -> void:
	if transitioning or locked or day >= GameData.TOTAL_DAYS:
		return
	transitioning = true
	end_day_button.disabled = true
	day_ending.emit(day)
	_zoom_out_and_back()

	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_method(set_hour, DAY_HOUR, 21.0, sunset_time).set_ease(Tween.EASE_IN)  # gun batimi
	tw.tween_method(set_hour, 21.0, 28.0, night_time)  # gece (21:00 -> 04:00)
	tw.tween_method(set_hour, 28.0, 24.0 + DAY_HOUR, sunrise_time).set_ease(Tween.EASE_OUT)  # sabah
	tw.tween_callback(func():
		day += 1
		hour = DAY_HOUR
		transitioning = false
		end_day_button.disabled = locked
		apply_time(hour)
		day_started.emit(day))


## Gece gecisinde kamera hafifce uzaklasir, sabah eski yerine doner.
func _zoom_out_and_back() -> void:
	if camera_rig == null:
		return
	var z0: float = camera_rig._zoom
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera_rig, "_zoom", minf(z0 * 1.2, camera_rig.zoom_max), sunset_time + night_time * 0.5)
	tw.tween_property(camera_rig, "_zoom", z0, night_time * 0.5 + sunrise_time)


func set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	apply_time(hour)


func is_night() -> bool:
	return hour > 19.5 or hour < 6.5


# ------------------------------------------------------------------ isik ve gokyuzu
func apply_time(h: float) -> void:
	var elev := sin((h / 24.0 - 0.25) * TAU)  # 06:00 = 0, 12:00 = 1, 18:00 = 0, gece < 0
	var day_k := smoothstep(-0.08, 0.3, elev)  # 0 gece, 1 gunduz
	var dusk_k := clampf(1.0 - absf(elev) / 0.35, 0.0, 1.0)  # gun dogumu/batimi kizilligi

	sun.rotation = Vector3(-deg_to_rad(maxf(elev * 65.0, 3.0)), deg_to_rad((h / 24.0 - 0.5) * 180.0 + 25.0), 0.0)
	sun.light_energy = 1.15 * day_k
	sun.light_color = Color(1.0, 0.55, 0.3).lerp(Color(1.0, 0.97, 0.92), smoothstep(0.0, 0.5, elev))
	moon.light_energy = 0.3 * (1.0 - day_k)
	moon.visible = day_k < 0.99

	var top := Color(0.02, 0.03, 0.09).lerp(Color(0.36, 0.6, 0.86), day_k).lerp(Color(0.32, 0.3, 0.55), dusk_k * 0.6)
	var horizon := Color(0.07, 0.09, 0.2).lerp(Color(0.72, 0.85, 0.95), day_k).lerp(Color(1.0, 0.55, 0.35), dusk_k * 0.7)
	sky.sky_top_color = top
	sky.sky_horizon_color = horizon
	sky.ground_horizon_color = horizon
	sky.ground_bottom_color = top.darkened(0.4)
	env.ambient_light_energy = lerpf(0.3, 0.9, day_k)
	sea_material.set_shader_parameter("light", lerpf(0.3, 1.0, day_k))
	if traffic:
		traffic.set_night(1.0 - day_k)  # gece sokaklar sakinlesir

	_set_night_lights(smoothstep(0.18, -0.02, elev))
	day_label.text = "Gün %d/%d" % [day, GameData.TOTAL_DAYS]
	dial.hour = h
	dial.sky_color = top


func _set_night_lights(k: float) -> void:
	if is_equal_approx(k, _lights_k):
		return
	_lights_k = k
	for l in get_tree().get_nodes_in_group("night_lights"):
		l.light_energy = float(l.get_meta("energy", 1.0)) * k
		l.visible = k > 0.01


func _add_street_lamp_lights() -> void:
	var props := city.get_node_or_null("Props")
	if props == null:
		return
	for p in props.get_children():
		if String(p.name).begins_with("lighthouse_"):
			var beam := OmniLight3D.new()
			beam.position = Vector3(0, 2.6, 0)
			beam.light_color = Color(1.0, 0.95, 0.7)
			beam.omni_range = 7.0
			beam.set_meta("energy", 5.0)
			beam.add_to_group("night_lights")
			p.add_child(beam)
		if String(p.name).begins_with("lamp_"):
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(-0.2, 0.85, 0.0)  # KayKit streetlight kolunun ucu
			lamp.light_color = Color(1.0, 0.85, 0.6)
			lamp.omni_range = 2.4
			lamp.set_meta("energy", 2.2)
			lamp.add_to_group("night_lights")
			p.add_child(lamp)


# ------------------------------------------------------------------ arayuz
func _on_day_started(d: int) -> void:
	banner.text = "GÜN %d" % d
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(banner, "modulate:a", 0.0, 0.6)
