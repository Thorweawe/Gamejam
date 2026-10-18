class_name Portrait
extends SubViewportContainer
## Arayuzde konusan karakter portresi: kendi kucuk 3B dunyasinda (sehirden bagimsiz),
## seffaf arka planla CharacterFigure cizer.
##   var p := Portrait.new(); p.setup("nermin", "happy"); parent.add_child(p)
##   p.figure.talk = 0..1, p.figure.set_mood("angry"), p.figure.gesture("wave")

var figure: CharacterFigure
var char_id := ""
var _viewport: SubViewport
var _camera: Camera3D


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.9)
	env.ambient_light_energy = 0.55
	# sehirle ayni ton: ACES + hafif kontrast; yaka / cene altinda yumusak temas golgesi (SSAO)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.12
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 0.25
	env.ssao_intensity = 1.1
	env.ssao_power = 1.3
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-30), deg_to_rad(28), 0)
	key.light_energy = 1.3
	key.light_color = Color(1.0, 0.95, 0.87)  # sehirdeki gunesle ayni sicak ton
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-15), deg_to_rad(160), 0)
	rim.light_energy = 0.85  # serin kenar isigi: karakter arka plandan ayrilir
	rim.light_color = Color(0.7, 0.8, 1.0)
	_viewport.add_child(rim)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_camera.position = Vector3(0, 1.32, 3.1)
	_camera.rotation.x = deg_to_rad(-2.0)
	_viewport.add_child(_camera)
	figure = CharacterFigure.new()
	_viewport.add_child(figure)


func setup(id: String, mood := "neutral") -> void:
	char_id = id
	figure.build(Characters.info(id).look)
	figure.set_mood(mood, true)
