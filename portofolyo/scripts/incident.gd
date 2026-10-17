class_name Incident
extends Node3D
## Afet aninda yardim bekleyen olay: enkaz, yangin, yarali, mahsur.
## Dunyada renkli isik sutunu + halka; ekrandaki ikon / sure halkasi HUD'daki IncidentMarker'da.
## Oyuncu isarete tiklar -> GameManager uygun birimi gonderir -> arac varinca calisma baslar.
## Sure dolmadan calisma biterse insanlar kurtulur; dolarsa kaybedilir.

signal resolved(inc: Incident, saved: int, lost: int)

enum State { WAITING, EN_ROUTE, WORKING, DONE }

## lethality: sure dolarsa bekleyenlerin ne kadari hayatini kaybeder (gerisi yarali kurtulur)
const KINDS := {
	"rubble": {"title": "Enkaz", "unit": "rescue", "color": Color(1.0, 0.55, 0.15), "lethality": 0.7},
	"fire": {"title": "Yangın", "unit": "fire", "color": Color(1.0, 0.27, 0.2), "lethality": 0.6},
	"injured": {"title": "Yaralı", "unit": "medic", "color": Color(0.3, 0.72, 1.0), "lethality": 0.35},
	"stranded": {"title": "Mahsur", "unit": "rescue", "color": Color(0.3, 0.9, 0.9), "lethality": 0.5},
}

var kind := "rubble"
var people := 3
var time_left := 20.0
var time_total := 20.0
var work_left := 4.0
var work_total := 4.0
var state := State.WAITING
var building: Node3D  # ilgili bina (varsa)
var tile := Vector2i.ZERO  # orman yangini karosu (varsa)
var subject := "kişi"  # orman yanginda "hektar"
var vehicle: WeakRef  # gonderilen arac

var _beam: MeshInstance3D
var _ring: MeshInstance3D
var _mat: StandardMaterial3D
var _t := 0.0
var _fx: GPUParticles3D


func setup(k: String, count: int, seconds: float, work: float) -> void:
	kind = k
	people = count
	time_left = seconds
	time_total = seconds
	work_left = work
	work_total = work


func unit() -> String:
	return KINDS[kind].unit


func color() -> Color:
	return KINDS[kind].color


## 0..1: kalan sure (bekleme) ya da calisma ilerlemesi.
func progress() -> float:
	if state == State.WORKING:
		return 1.0 - work_left / maxf(work_total, 0.01)
	return time_left / maxf(time_total, 0.01)


func _ready() -> void:
	add_to_group("incidents")
	var col := color()
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(col.r, col.g, col.b, 0.4)
	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.09
	cyl.height = 2.4
	_beam.mesh = cyl
	_beam.material_override = _mat
	_beam.position.y = 1.3
	add_child(_beam)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.62
	_ring.mesh = torus
	_ring.material_override = _mat
	_ring.position.y = 0.15
	_ring.scale = Vector3(1, 0.2, 1)
	add_child(_ring)


func _process(delta: float) -> void:
	if state == State.DONE:
		return
	_t += delta
	match state:
		State.WAITING, State.EN_ROUTE:
			time_left -= delta
			if time_left <= 0.0:
				_finish(0, people)
				return
		State.WORKING:
			if _fx == null:
				_start_work_fx()
			work_left -= delta
			if work_left <= 0.0:
				_finish(people, 0)
				return
	var urgent := time_left < 6.0 and state != State.WORKING
	var pulse := 1.0 + sin(_t * (10.0 if urgent else 4.0)) * 0.18
	_ring.scale = Vector3(pulse, 0.2, pulse)
	var col := Color(0.4, 1.0, 0.5) if state == State.WORKING else color()
	_mat.albedo_color = Color(col.r, col.g, col.b, 0.45)


## Ekip calisirken gorunen efekt: itfaiye su sikar, AFAD toz kaldirir, ambulans isiltisi, mahsurda su sicramasi.
func _start_work_fx() -> void:
	var cfg: Array = {
		"fire": [Color(0.7, 0.88, 1.0, 0.9), Vector3(0, 1, 0), 30.0, 3.2, -7.0, 0.06, 0.9],
		"rubble": [Color(0.72, 0.66, 0.58, 0.7), Vector3(0, 1, 0), 60.0, 0.8, 0.4, 0.12, 1.4],
		"injured": [Color(0.5, 1.0, 0.6, 0.9), Vector3(0, 1, 0), 40.0, 0.9, 0.5, 0.05, 1.0],
		"stranded": [Color(0.85, 0.95, 1.0, 0.9), Vector3(0, 1, 0), 50.0, 2.0, -5.0, 0.05, 0.7],
	}[kind]
	_fx = GPUParticles3D.new()
	var m := ParticleProcessMaterial.new()
	m.direction = cfg[1]
	m.spread = cfg[2]
	m.initial_velocity_min = cfg[3] * 0.7
	m.initial_velocity_max = cfg[3]
	m.gravity = Vector3(0, cfg[4], 0)
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.35
	m.scale_min = 0.6
	m.scale_max = 1.2
	_fx.process_material = m
	var mesh := SphereMesh.new()
	mesh.radius = cfg[5]
	mesh.height = cfg[5] * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = cfg[0]
	mesh.material = mat
	_fx.draw_pass_1 = mesh
	_fx.amount = 40
	_fx.lifetime = cfg[6]
	_fx.position = Vector3(0, 0.3, 0)
	add_child(_fx)


func _finish(saved: int, lost: int) -> void:
	state = State.DONE
	if _fx:
		_fx.emitting = false
	remove_from_group("incidents")
	resolved.emit(self, saved, lost)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.6, 0.01, 1.6), 0.5)
	tw.tween_callback(queue_free)
