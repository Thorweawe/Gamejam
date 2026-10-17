class_name IncidentMarker
extends Control
## Bir Incident'in ekrandaki isareti: ikon, sure halkasi, kisi sayisi, durum yazisi.
## Tiklaninca uygun birim gonderilir; gonderilen araca kesikli cizgi cekilir.
## Isaret ekran disindaysa kenara yapisir (ok gibi).

signal clicked(inc: Incident)

const R := 21.0
const UNIT_ICONS := {"fire": "fire", "medic": "medic", "rescue": "rescue"}
const KIND_ICONS := {"rubble": "rubble", "fire": "fire", "injured": "medic", "stranded": "stranded"}

var inc: Incident
var camera: Camera3D
var font: Font

var _icon: UIIcon
var _hover := false
var _t := 0.0
var _shake := 0.0
var _vehicle_pos := Vector2.INF
var _offscreen := false


func setup(i: Incident, cam: Camera3D, f: Font) -> void:
	inc = i
	camera = cam
	font = f
	custom_minimum_size = Vector2(R * 2 + 8, R * 2 + 8)
	size = custom_minimum_size
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_icon = UIIcon.new()
	_icon.kind = KIND_ICONS.get(inc.kind, "warning")
	_icon.color = Color.WHITE
	_icon.size = Vector2(24, 24)
	_icon.position = size / 2.0 - _icon.size / 2.0
	add_child(_icon)
	mouse_entered.connect(func(): _hover = true)
	mouse_exited.connect(func(): _hover = false)
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Bos birim yokken tiklanirsa salla.
func deny() -> void:
	_shake = 0.4


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if is_instance_valid(inc) and inc.state == Incident.State.WAITING:
			clicked.emit(inc)


func _process(delta: float) -> void:
	if not is_instance_valid(inc) or not is_instance_valid(camera):
		return
	_t += delta
	var world := inc.global_position + Vector3.UP * 1.0
	var vp := get_viewport_rect().size
	var sp := camera.unproject_position(world)
	var behind := camera.is_position_behind(world)
	var margin := 40.0
	_offscreen = behind or sp.x < margin or sp.y < 130 or sp.x > vp.x - margin or sp.y > vp.y - 100
	if behind:
		sp = vp - sp
	sp = sp.clamp(Vector2(margin, 130), vp - Vector2(margin, 100))  # ust/alt panellerin altinda kalmasin
	if _shake > 0.0:
		_shake -= delta
		sp.x += sin(_t * 60.0) * 6.0 * _shake / 0.4
	position = sp - size / 2.0 - Vector2(0, R + 6)
	if inc.kind == "injured" and not _offscreen:
		position.x += R * 1.6  # ayni binadaki yangin / enkaz isaretiyle ust uste binmesin
	var target_scale := 1.15 if _hover and inc.state == Incident.State.WAITING else 1.0
	if inc.state == Incident.State.WAITING and inc.time_left < 8.0:
		target_scale += sin(_t * 9.0) * 0.08
	if scale.x > 0.3:
		scale = scale.lerp(Vector2.ONE * target_scale, minf(1.0, delta * 12.0))
	_vehicle_pos = Vector2.INF
	if inc.state == Incident.State.EN_ROUTE and inc.vehicle:
		var v = inc.vehicle.get_ref()
		if v and is_instance_valid(v):
			var vw: Vector3 = v.global_position + Vector3.UP * 0.4
			if not camera.is_position_behind(vw):
				_vehicle_pos = camera.unproject_position(vw)
	_icon.color = Color.WHITE if inc.state != Incident.State.WORKING else Color(0.75, 1.0, 0.8)
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(inc):
		return
	var c := size / 2.0
	var col := inc.color()
	var p := inc.progress()
	var urgent := inc.state == Incident.State.WAITING and inc.time_left < 8.0
	var ring := col
	if inc.state == Incident.State.WORKING:
		ring = Color(0.4, 1.0, 0.55)
	elif urgent:
		ring = Color(1.0, 0.3, 0.25).lerp(Color.WHITE, 0.5 + sin(_t * 9.0) * 0.5)
	# araca kesikli cizgi
	if _vehicle_pos != Vector2.INF:
		var local := _vehicle_pos - position
		draw_dashed_line(c + Vector2(0, R + 6), local, Color(1, 1, 1, 0.7), 2.0, 8.0)
		draw_circle(local, 5.0, Color(1, 1, 1, 0.9))
		draw_circle(local, 3.0, col)
	# isaretin altindaki igne
	if not _offscreen:
		draw_colored_polygon(PackedVector2Array([c + Vector2(-7, R - 3), c + Vector2(7, R - 3), c + Vector2(0, R + 9)]), Color(0.08, 0.1, 0.16, 0.92))
	# govde + halka
	draw_circle(c + Vector2(0, 2), R + 2, Color(0, 0, 0, 0.3))
	draw_circle(c, R, Color(0.08, 0.1, 0.16, 0.92))
	draw_circle(c, R - 5, col.darkened(0.25) if inc.state != Incident.State.WORKING else Color(0.15, 0.5, 0.3))
	draw_arc(c, R - 2, 0, TAU, 40, Color(1, 1, 1, 0.12), 4.0, true)
	if p > 0.0:
		draw_arc(c, R - 2, -PI / 2, -PI / 2 + TAU * clampf(p, 0.0, 1.0), 40, ring, 4.0, true)
	# kisi sayisi rozeti
	var badge := c + Vector2(R * 0.78, -R * 0.78)
	draw_circle(badge, 10, Color.WHITE)
	var txt := str(inc.people) if inc.tile == Vector2i.ZERO else "!"
	var fs := 13
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, badge + Vector2(-tw / 2.0, 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.1, 0.1, 0.15))
	# durum yazisi
	var label := ""
	match inc.state:
		Incident.State.WAITING:
			label = GameData.UNIT_NAMES[inc.unit()] + " gönder" if _hover else "%ds" % ceili(inc.time_left)
		Incident.State.EN_ROUTE:
			label = "Yolda · %ds" % ceili(inc.time_left)
		Incident.State.WORKING:
			label = {"fire": "Söndürülüyor", "medic": "Tedavi", "rescue": "Kurtarılıyor"}[inc.unit()]
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var lp := c + Vector2(-lw / 2.0, -R - 8)
	draw_rect(Rect2(lp + Vector2(-6, -13), Vector2(lw + 12, 18)), Color(0.08, 0.1, 0.16, 0.85))
	draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ring if inc.state != Incident.State.WAITING or urgent else Color.WHITE)
