@tool
class_name SunMoonDial
extends Control
## Gun saatini gosteren gunes/ay kadrani. Sadece ust yarisi gorunur (ufkun ustu).
## Tekerlek saate gore doner: ogle vakti gunes tepede, gece yarisi ay tepede.
## Gunes soldan (dogu) dogar, saga (bati) batar.

@export_range(0.0, 24.0) var hour := 11.0:
	set(value):
		hour = value
		queue_redraw()

## Kadranin arka plani (DayCycle gokyuzu rengini verir).
@export var sky_color := Color(0.36, 0.6, 0.86):
	set(value):
		sky_color = value
		queue_redraw()

const STARS := [Vector2(0.22, 0.45), Vector2(0.36, 0.2), Vector2(0.55, 0.32), Vector2(0.7, 0.15),
	Vector2(0.8, 0.5), Vector2(0.15, 0.75), Vector2(0.62, 0.62)]


func _init() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(104, 54)


func _draw() -> void:
	var center := Vector2(size.x / 2.0, size.y)
	var r := minf(size.x / 2.0, size.y) - 1.0
	draw_circle(center, r, sky_color)

	# gece yildizlari
	var night := clampf(1.0 - sky_color.v * 2.2, 0.0, 1.0)
	if night > 0.0:
		for s in STARS:
			draw_circle(Vector2(s.x * size.x, s.y * size.y), 1.3, Color(1, 1, 0.9, night))

	var sun_angle := hour / 24.0 * TAU - PI * 1.5  # 12:00 -> tepe, 06:00 -> sol, 18:00 -> sag
	var orbit := r * 0.6
	var sun_pos := center + Vector2(cos(sun_angle), sin(sun_angle)) * orbit
	var moon_pos := center * 2.0 - sun_pos
	_draw_sun(sun_pos, r * 0.22)
	_draw_moon(moon_pos, r * 0.25)

	draw_line(Vector2(0, size.y - 1.0), Vector2(size.x, size.y - 1.0), Color(1, 1, 1, 0.9), 2.0)
	draw_arc(center, r, PI, TAU, 40, Color(1, 1, 1, 0.9), 2.0, true)


func _draw_sun(p: Vector2, r: float) -> void:
	var ray_color := Color(1.0, 0.82, 0.25)
	for i in 8:
		var a := TAU * i / 8.0 + hour * 0.3
		draw_line(p + Vector2(cos(a), sin(a)) * r * 1.3, p + Vector2(cos(a), sin(a)) * r * 1.8, ray_color, 2.0, true)
	draw_circle(p, r, Color(1.0, 0.86, 0.3))
	draw_circle(p - Vector2(r, r) * 0.25, r * 0.45, Color(1.0, 0.95, 0.6))


func _draw_moon(p: Vector2, r: float) -> void:
	draw_circle(p, r, Color(0.93, 0.94, 1.0))
	draw_circle(p + Vector2(r * 0.45, -r * 0.25), r * 0.78, sky_color)  # hilal
