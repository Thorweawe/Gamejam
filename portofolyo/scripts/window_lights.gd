class_name WindowLights
extends RefCounted
## Gece pencereleri: bina dokusu (KayKit citybits atlasi) tek bir renk-gecis atlasi; pencere camlari
## atlasin acik mavi hucresini kullanir. Bina malzemelerine eklenen ikinci gecis (next_pass) gece
## bu hucreyi sicak sari yakar; pencerelerin bir kismi karanlik kalir (her pencere icin sabit rastgele).
## Parlama (glow) acikken hafifce isildar. Gunduz ikinci gecis kaldirilir (maliyet yok).
## Kurulum: building.gd model yuklerken apply(); day_cycle.gd gece degisince set_night().

const CELL := Vector4(0.0, 0.25, 0.125, 0.5)  ## pencere hucresi: UV (x0, y0, x1, y1)

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;
uniform float night = 0.0;
uniform vec4 cell = vec4(0.0, 0.25, 0.125, 0.5);
uniform vec3 warm : source_color = vec3(1.0, 0.74, 0.4);
uniform float strength = 1.7;
varying vec3 wpos;
void vertex() {
	VERTEX += NORMAL * 0.004;  // ayni yuzeyle derinlik cekismesi olmasin
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}
void fragment() {
	float inside = step(cell.x, UV.x) * step(UV.x, cell.z) * step(cell.y, UV.y) * step(UV.y, cell.w);
	// pencere basina sabit rastgele: ~%30'u karanlik, yananlarin tonu biraz farkli
	float h = hash(floor(wpos * vec3(2.6, 2.2, 2.6)));
	float on = step(0.3, h);
	vec3 col = mix(warm, vec3(1.0, 0.88, 0.62), fract(h * 7.0));
	ALBEDO = col * inside * on * night * strength;
}
"""

static var _mat: ShaderMaterial
static var _night := 0.0
static var _patched: Array[BaseMaterial3D] = []


static func material() -> ShaderMaterial:
	if _mat == null:
		var sh := Shader.new()
		sh.code = SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_mat.set_shader_parameter("cell", CELL)
		_mat.set_shader_parameter("night", _night)
	return _mat


## Modelin atlas malzemelerine pencere gecisini bagla (ayni malzeme bir kez).
static func apply(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh == null:
			continue
		for i in m3.mesh.get_surface_count():
			var m := m3.get_active_material(i) as BaseMaterial3D
			if m == null or m.albedo_texture == null or _patched.has(m):
				continue
			if not m.albedo_texture.resource_path.contains("citybits"):
				continue
			_patched.append(m)
			m.next_pass = material() if _night > 0.01 else null


static func night() -> float:
	return _night


## k: 0 gunduz .. 1 gece
static func set_night(k: float) -> void:
	_night = k
	material().set_shader_parameter("night", k)
	for m in _patched:
		if is_instance_valid(m):
			m.next_pass = _mat if k > 0.01 else null
