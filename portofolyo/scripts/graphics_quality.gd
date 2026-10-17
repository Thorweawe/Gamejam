extends Node
## Performans ayarlari (CityMap'in cocugu olarak eklenir, menude ve oyunda calisir).
##  1) Gorunumu degistirmeyen kazanclar: deniz (~97 bin ucgen) ve ~600 duz zemin / yol karosu
##     golge atmaz; gunes golge haritasi her karede bunlari 4 kez yeniden cizmez.
##  2) Uyarlanabilir kalite: oyun yavas calisiyorsa (zayif / dahili ekran karti) grafik
##     kalitesi kademeli olarak duser. Guclu makinede hicbir sey degismez.
##       1: SSAO kapali   2: 3B cozunurluk %75 (FSR) + parlama kapali
##       3: 3B cozunurluk %60, 2 parcali golge, daha agresif LOD   4: gunes golgesi kapali

## Bu FPS'in altinda kalinca dusurulur. Dusuk tutuldu: editor acikken oyunu calistirmak ya da arka plandaki
## baska bir program FPS'i 35-40'a indirebilir; bu durumda kalite dusurmek ise yaramaz, gorunumu bozar.
const TARGET_FPS := 30.0
const MAX_LEVEL := 4
const OUTLINE_OFF_LEVEL := 3  # cizgi film konturu (map_visuals.gd) bu seviyeden itibaren kapali
const WARMUP := 2.5  # sahne yuklenip shader'lar derlenirken olcme
const WINDOW := 1.5  # olcum penceresi (sn)
const FLAT_TILES := ["tile_grass", "tile_mountain", "tile_plaza", "tile_river_straight", "tile_sand", "road_"]

## Sahne degisse de (menu -> oyun) korunur. Ekran karti turu D3D12'de guvenilir
## raporlanmadigi icin (Intel UHD de "harici" gorunuyor) sadece olculen FPS'e bakilir.
static var level := 0

var _city: Node3D
var _env: Environment
var _sun: DirectionalLight3D
var _wait := WARMUP
var _time := 0.0
var _frames := 0
var _bad := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # duraklatma ekraninda da olc
	_city = get_parent()
	_env = (_city.get_node("WorldEnvironment") as WorldEnvironment).environment
	_sun = _city.get_node("Sun")
	_disable_flat_shadows()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_apply()


func _disable_flat_shadows() -> void:
	var sea := _city.get_node_or_null("Sea") as GeometryInstance3D
	if sea:
		sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for group in ["Ground", "Roads"]:
		var parent := _city.get_node_or_null(group)
		if parent == null:
			continue
		for tile in parent.get_children():
			if not _is_flat(tile):
				continue
			for g in tile.find_children("*", "GeometryInstance3D", true, false):
				(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _is_flat(tile: Node) -> bool:
	var file := tile.scene_file_path.get_file().get_basename()
	if file.contains("bridge") or file.begins_with("tile_grass_"):
		return false  # kopru ve cimen tumsekleri golge atsin
	for prefix in FLAT_TILES:
		if file == prefix or (prefix.ends_with("_") and file.begins_with(prefix)):
			return true
	return false


## Dusurmeden sonra FPS en az %12 artmadiysa (yavaslik baska yerden geliyor: editor ayni anda haritayi
## ciziyor, arka planda baska program, CPU) adim geri alinir ve sistem durur. GPU suresi tek basina
## yeterli degil: GPU'yu paylasan baska bir surec varken olculen sure de sisiyor.
static var locked := false
static var _base := {}  # ortamin ilk (tam kalite) degerleri; ortam kaynagi sahneler arasi paylasilir
var _gpu_ms := 0.0
var _before_fps := 0.0  # son dusurmeden onceki FPS (0 = bekleyen karar yok)
var _prev_level := 0


func _process(delta: float) -> void:
	if locked or (level >= MAX_LEVEL and _before_fps == 0.0):
		set_process(false)
		return
	if _wait > 0.0:
		_wait -= delta
		return
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
		_time = 0.0
		_frames = 0
		_gpu_ms = 0.0
		return
	_time += minf(delta, 0.25)  # tek seferlik yukleme takilmalari olcumu bozmasin
	_frames += 1
	_gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	if _time < WINDOW:
		return
	var fps := _frames / _time
	var gpu := _gpu_ms / _frames
	_time = 0.0
	_frames = 0
	_gpu_ms = 0.0
	if _before_fps > 0.0:
		# son dusurme ise yaradi mi?
		if fps < _before_fps * 1.12:
			print("Grafik kalitesi geri alindi: seviye %d -> %d (FPS %.0f -> %.0f, darbogaz baska yerde)" % [level, _prev_level, _before_fps, fps])
			level = _prev_level
			locked = true
			_apply()
			return
		_before_fps = 0.0
	var gpu_bound := gpu > 1000.0 / fps * 0.75
	_bad = _bad + 1 if fps < TARGET_FPS and gpu_bound else 0
	if level < MAX_LEVEL and (_bad >= 2 or (fps < TARGET_FPS * 0.6 and gpu_bound)):
		_prev_level = level
		_before_fps = fps
		level = mini(MAX_LEVEL, level + (2 if fps < TARGET_FPS * 0.4 else 1))
		_bad = 0
		_wait = 1.0
		_apply()
		print("Grafik kalitesi dusuruldu: seviye %d (%.0f FPS, GPU %.1f ms)" % [level, fps, gpu])


## Seviyeyi uygula (iki yonlu: geri alinca tam kaliteye de doner).
func _apply() -> void:
	var vp := get_viewport()
	if _base.is_empty():
		_base = {"ssao": _env.ssao_enabled, "glow": _env.glow_enabled}
	_env.ssao_enabled = _base.ssao and level < 1
	_env.glow_enabled = _base.glow and level < 2
	if level >= 2:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		vp.scaling_3d_scale = 0.75 if level == 2 else 0.6
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 1.0
	get_tree().call_group("outline_fx", "set_visible", level < OUTLINE_OFF_LEVEL)
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if level >= 3 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	vp.mesh_lod_threshold = 4.0 if level >= 3 else 1.0
	_sun.shadow_enabled = level < 4
