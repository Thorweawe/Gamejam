class_name Incident
extends Node3D
## Afet aninda yardim bekleyen olay: enkaz, yangin, yarali, mahsur.
## Oyuncu isarete tiklar -> GameManager uygun birimi gonderir -> arac varinca calisma baslar.
## Sure dolmadan calisma biterse insanlar kurtulur; dolarsa kaybedilir.

signal resolved(inc: Incident, saved: int, lost: int)

enum State { WAITING, EN_ROUTE, WORKING, DONE }

## lethality: sure dolarsa bekleyenlerin ne kadari hayatini kaybeder (gerisi yarali kurtulur)
const KINDS := {
	"rubble": {"title": "ENKAZ", "unit": "rescue", "color": Color(1.0, 0.55, 0.15), "lethality": 0.7},
	"fire": {"title": "YANGIN", "unit": "fire", "color": Color(1.0, 0.25, 0.2), "lethality": 0.6},
	"injured": {"title": "YARALI", "unit": "medic", "color": Color(0.3, 0.75, 1.0), "lethality": 0.35},
	"stranded": {"title": "MAHSUR", "unit": "rescue", "color": Color(0.35, 0.9, 0.95), "lethality": 0.5},
}

var kind := "rubble"
var people := 3
var time_left := 20.0
var time_total := 20.0
var work_left := 4.0
var state := State.WAITING
var building: Node3D  # ilgili bina (varsa)
var tile := Vector2i.ZERO  # orman yangini karosu (varsa)
var subject := "kişi"  # orman yanginda "hektar"

var _label: Label3D
var _beam: MeshInstance3D
var _ring: MeshInstance3D
var _t := 0.0


func setup(k: String, count: int, seconds: float, work: float) -> void:
	kind = k
	people = count
	time_left = seconds
	time_total = seconds
	work_left = work


func unit() -> String:
	return KINDS[kind].unit


func _ready() -> void:
	add_to_group("incidents")
	var col: Color = KINDS[kind].color
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(col.r, col.g, col.b, 0.45)
	mat.no_depth_test = true
	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.12
	cyl.height = 2.6
	_beam.mesh = cyl
	_beam.material_override = mat
	_beam.position.y = 1.4
	add_child(_beam)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.6
	_ring.mesh = torus
	_ring.material_override = mat
	_ring.position.y = 0.15
	_ring.scale = Vector3(1, 0.25, 1)
	add_child(_ring)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0004
	_label.font_size = 40
	_label.outline_size = 14
	_label.position.y = 2.9
	add_child(_label)


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
			work_left -= delta
			if work_left <= 0.0:
				_finish(people, 0)
				return
	var pulse := 1.0 + sin(_t * (9.0 if time_left < 6.0 else 4.0)) * 0.15
	_ring.scale = Vector3(pulse, 0.25, pulse)
	var col: Color = KINDS[kind].color
	var status := "%d sn" % ceili(maxf(time_left, 0.0))
	match state:
		State.EN_ROUTE:
			status += "  >> %s yolda" % GameData.UNIT_NAMES[unit()]
		State.WORKING:
			status = "Kurtarılıyor..."
			col = Color(0.4, 1.0, 0.5)
	_label.text = "%s %d %s\n%s" % [KINDS[kind].title, people, subject, status]
	_label.modulate = Color(1, 0.3, 0.25) if time_left < 6.0 and state != State.WORKING else col
	_label.outline_modulate = Color(0, 0, 0, 0.9)


func _finish(saved: int, lost: int) -> void:
	state = State.DONE
	remove_from_group("incidents")
	resolved.emit(self, saved, lost)
	if subject == "hektar":
		_label.text = "Söndürüldü!" if saved > 0 else "Orman yandı"
	else:
		_label.text = ("%d kişi kurtarıldı!" % saved) if saved > 0 else ("%d kişi kaybedildi" % lost)
	_label.modulate = Color(0.4, 1.0, 0.5) if saved > 0 else Color(1.0, 0.35, 0.3)
	_beam.visible = false
	_ring.visible = false
	var tw := create_tween()
	tw.tween_property(_label, "position:y", 3.6, 1.6)
	tw.parallel().tween_property(_label, "modulate:a", 0.0, 1.6)
	tw.tween_callback(queue_free)
