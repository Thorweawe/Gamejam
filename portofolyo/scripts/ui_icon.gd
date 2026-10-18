@tool
class_name UIIcon
extends Control
## Kodla cizilen basit vektor ikonlar (dosya gerekmez). kind: asagidaki _draw eslesmeleri.

@export var kind := "coin":
	set(v):
		kind = v
		queue_redraw()
@export var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(22, 22)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	var r := s * 0.42
	var w := maxf(1.5, s * 0.09)
	var dark := Color(0, 0, 0, 0.35)
	match kind:
		"coin":
			draw_circle(c, r, Color(1.0, 0.78, 0.2))
			draw_circle(c, r * 0.78, Color(1.0, 0.86, 0.35))
			draw_line(c + Vector2(0, -r * 0.45), c + Vector2(0, r * 0.45), Color(0.75, 0.5, 0.05), w)
			draw_line(c + Vector2(-r * 0.3, -r * 0.1), c + Vector2(r * 0.3, -r * 0.25), Color(0.75, 0.5, 0.05), w * 0.8)
			draw_line(c + Vector2(-r * 0.3, r * 0.15), c + Vector2(r * 0.3, 0.0), Color(0.75, 0.5, 0.05), w * 0.8)
		"people":
			for dx in [-0.42, 0.42]:
				draw_circle(c + Vector2(dx * r, -r * 0.35), r * 0.24, color.darkened(0.2))
				draw_circle(c + Vector2(dx * r, r * 0.45), r * 0.38, color.darkened(0.2))
			draw_circle(c + Vector2(0, -r * 0.4), r * 0.3, color)
			draw_circle(c + Vector2(0, r * 0.55), r * 0.5, color)
		"shield":
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.85, -r * 0.6), c + Vector2(r * 0.7, r * 0.35),
				c + Vector2(0, r), c + Vector2(-r * 0.7, r * 0.35), c + Vector2(-r * 0.85, -r * 0.6)])
			draw_colored_polygon(pts, color)
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.35, 0), c + Vector2(-r * 0.05, r * 0.3), c + Vector2(r * 0.4, -r * 0.3)]), Color.WHITE, w)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2 + i * PI / 5
				pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
			draw_colored_polygon(pts, color)
		"shop":
			draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.2), Vector2(r * 1.5, r * 1.1)), color)
			draw_arc(c + Vector2(0, -r * 0.2), r * 0.45, PI, TAU, 16, color, w)
			draw_circle(c + Vector2(-r * 0.35, r * 0.2), w * 0.6, dark)
			draw_circle(c + Vector2(r * 0.35, r * 0.2), w * 0.6, dark)
		"map":
			var pts := PackedVector2Array([c + Vector2(-r, -r * 0.7), c + Vector2(-r * 0.33, -r), c + Vector2(r * 0.33, -r * 0.7),
				c + Vector2(r, -r), c + Vector2(r, r * 0.7), c + Vector2(r * 0.33, r), c + Vector2(-r * 0.33, r * 0.7), c + Vector2(-r, r)])
			draw_colored_polygon(pts, color)
			draw_line(c + Vector2(-r * 0.33, -r), c + Vector2(-r * 0.33, r * 0.7), dark, w * 0.7)
			draw_line(c + Vector2(r * 0.33, -r * 0.7), c + Vector2(r * 0.33, r), dark, w * 0.7)
			draw_circle(c + Vector2(r * 0.6, -r * 0.2), r * 0.18, Color(1, 0.3, 0.25))
		"fire":
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.55, -r * 0.1), c + Vector2(r * 0.65, r * 0.45),
				c + Vector2(0, r), c + Vector2(-r * 0.65, r * 0.45), c + Vector2(-r * 0.45, -r * 0.15), c + Vector2(-r * 0.15, r * 0.05)])
			draw_colored_polygon(pts, color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.1), c + Vector2(r * 0.3, r * 0.45), c + Vector2(0, r * 0.8),
				c + Vector2(-r * 0.3, r * 0.45)]), Color(1, 0.9, 0.4))
		"rubble":
			for i in 3:
				draw_rect(Rect2(c + Vector2(-r + i * r * 0.7, r * 0.1), Vector2(r * 0.6, r * 0.5)), color.darkened(i * 0.1))
			draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.45), Vector2(r * 0.6, r * 0.5)), color.lightened(0.15))
			draw_rect(Rect2(c + Vector2(r * 0.1, -r * 0.4), Vector2(r * 0.55, r * 0.45)), color)
			draw_line(c + Vector2(-r * 0.2, -r), c + Vector2(r * 0.2, -r * 0.55), Color.WHITE, w * 0.7)
		"medic", "cross":
			draw_rect(Rect2(c + Vector2(-r * 0.28, -r * 0.85), Vector2(r * 0.56, r * 1.7)), color)
			draw_rect(Rect2(c + Vector2(-r * 0.85, -r * 0.28), Vector2(r * 1.7, r * 0.56)), color)
		"rescue":
			draw_arc(c + Vector2(0, r * 0.15), r * 0.75, PI, TAU, 20, color, w * 2.2)
			draw_rect(Rect2(c + Vector2(-r, r * 0.1), Vector2(r * 2, w * 1.4)), color)
			draw_rect(Rect2(c + Vector2(-r * 0.12, -r * 0.6), Vector2(r * 0.24, r * 0.5)), Color.WHITE)
		"stranded", "wave":
			for k in 3:
				var y := c.y - r * 0.5 + k * r * 0.55
				var pts := PackedVector2Array()
				for i in 9:
					var x := c.x - r + i * r / 4.0
					pts.append(Vector2(x, y + sin(i * 1.6) * r * 0.15))
				draw_polyline(pts, color, w)
		"news":
			draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.8), Vector2(r * 1.6, r * 1.6)), color)
			for k in 3:
				draw_line(c + Vector2(-r * 0.55, -r * 0.4 + k * r * 0.4), c + Vector2(r * 0.55, -r * 0.4 + k * r * 0.4), dark, w * 0.8)
		"drill":
			draw_circle(c + Vector2(r * 0.15, -r * 0.65), r * 0.25, color)
			draw_line(c + Vector2(r * 0.05, -r * 0.35), c + Vector2(-r * 0.15, r * 0.25), color, w * 1.6)
			draw_line(c + Vector2(-r * 0.15, r * 0.25), c + Vector2(-r * 0.6, r * 0.9), color, w * 1.4)
			draw_line(c + Vector2(-r * 0.15, r * 0.25), c + Vector2(r * 0.4, r * 0.85), color, w * 1.4)
			draw_line(c + Vector2(-r * 0.6, -r * 0.1), c + Vector2(r * 0.6, -r * 0.3), color, w * 1.2)
		"tv":
			draw_rect(Rect2(c + Vector2(-r * 0.9, -r * 0.55), Vector2(r * 1.8, r * 1.2)), color)
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.38), Vector2(r * 1.4, r * 0.85)), dark)
			draw_line(c + Vector2(-r * 0.3, -r * 0.95), c + Vector2(0, -r * 0.55), color, w)
			draw_line(c + Vector2(r * 0.3, -r * 0.95), c + Vector2(0, -r * 0.55), color, w)
		"kit":
			draw_rect(Rect2(c + Vector2(-r * 0.65, -r * 0.6), Vector2(r * 1.3, r * 1.5)), color)
			draw_arc(c + Vector2(0, -r * 0.6), r * 0.3, PI, TAU, 12, color, w)
			draw_rect(Rect2(c + Vector2(-r * 0.45, r * 0.05), Vector2(r * 0.9, r * 0.6)), color.darkened(0.2))
		"tree":
			draw_rect(Rect2(c + Vector2(-r * 0.12, r * 0.2), Vector2(r * 0.24, r * 0.8)), Color(0.55, 0.35, 0.2))
			draw_circle(c + Vector2(0, -r * 0.2), r * 0.65, color)
		"flag":
			draw_line(c + Vector2(-r * 0.6, -r), c + Vector2(-r * 0.6, r), color.lightened(0.3), w)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.55, -r), c + Vector2(r * 0.8, -r * 0.6), c + Vector2(-r * 0.55, -r * 0.15)]), color)
		"siren":
			draw_rect(Rect2(c + Vector2(-r * 0.8, r * 0.45), Vector2(r * 1.6, r * 0.4)), color.darkened(0.3))
			draw_circle(c + Vector2(0, r * 0.2), r * 0.6, color)
			for a in [-0.6, 0.0, 0.6]:
				var d := Vector2(sin(a), -cos(a))
				draw_line(c + d * r * 0.75, c + d * r * 1.0, color, w)
		"house":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r * 0.05), c + Vector2(0, -r * 0.9), c + Vector2(r, -r * 0.05)]), color.darkened(0.15))
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.05), Vector2(r * 1.4, r * 0.95)), color)
			draw_rect(Rect2(c + Vector2(-r * 0.15, r * 0.35), Vector2(r * 0.3, r * 0.55)), dark)
		"hall":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r * 0.45), c + Vector2(0, -r), c + Vector2(r, -r * 0.45)]), color)
			for i in 4:
				draw_rect(Rect2(c + Vector2(-r * 0.75 + i * r * 0.45, -r * 0.35), Vector2(r * 0.18, r * 1.0)), color)
			draw_rect(Rect2(c + Vector2(-r, r * 0.7), Vector2(r * 2, r * 0.25)), color)
		"warning":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r * 0.8), c + Vector2(-r, r * 0.8)]), color)
			draw_line(c + Vector2(0, -r * 0.4), c + Vector2(0, r * 0.25), Color(0.2, 0.1, 0.05), w * 1.3)
			draw_circle(c + Vector2(0, r * 0.52), w * 0.8, Color(0.2, 0.1, 0.05))
		"close":
			draw_line(c + Vector2(-r * 0.6, -r * 0.6), c + Vector2(r * 0.6, r * 0.6), color, w * 1.5)
			draw_line(c + Vector2(r * 0.6, -r * 0.6), c + Vector2(-r * 0.6, r * 0.6), color, w * 1.5)
		"lock":
			draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.1), Vector2(r * 1.2, r * 1.0)), color)
			draw_arc(c + Vector2(0, -r * 0.1), r * 0.42, PI, TAU, 14, color, w * 1.2)
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.5, -r * 0.8), c + Vector2(r * 0.85, 0), c + Vector2(-r * 0.5, r * 0.8)]), color)
		"pause":
			draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.75), Vector2(r * 0.42, r * 1.5)), color)
			draw_rect(Rect2(c + Vector2(r * 0.18, -r * 0.75), Vector2(r * 0.42, r * 1.5)), color)
		"gear":
			# 8 dis (yamuk) + kalin halka; ortasi bos (zemin gorunur)
			for i in 8:
				var a := i * TAU / 8.0
				var d := Vector2(cos(a), sin(a))
				var t := Vector2(-d.y, d.x)
				draw_colored_polygon(PackedVector2Array([c + d * r * 0.6 - t * r * 0.2, c + d * r * 0.98 - t * r * 0.13,
					c + d * r * 0.98 + t * r * 0.13, c + d * r * 0.6 + t * r * 0.2]), color)
			draw_arc(c, r * 0.52, 0, TAU, 32, color, r * 0.36, true)
		"exit":
			draw_rect(Rect2(c + Vector2(-r * 0.85, -r * 0.9), Vector2(r * 0.95, r * 1.8)), color.darkened(0.25))
			draw_line(c + Vector2(-r * 0.1, 0), c + Vector2(r * 0.9, 0), color, w * 1.5)
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.95, 0), c + Vector2(r * 0.45, -r * 0.45), c + Vector2(r * 0.45, r * 0.45)]), color)
		"home":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(0, -r * 0.9), c + Vector2(r, 0)]), color)
			draw_rect(Rect2(c + Vector2(-r * 0.65, 0), Vector2(r * 1.3, r * 0.85)), color)
		"heart":
			draw_circle(c + Vector2(-r * 0.42, -r * 0.2), r * 0.48, color)
			draw_circle(c + Vector2(r * 0.42, -r * 0.2), r * 0.48, color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.88, 0), c + Vector2(r * 0.88, 0), c + Vector2(0, r * 0.9)]), color)
		"keyboard":
			draw_rect(Rect2(c + Vector2(-r, -r * 0.6), Vector2(r * 2, r * 1.2)), color)
			for row in 2:
				for i in 5:
					draw_rect(Rect2(c + Vector2(-r * 0.82 + i * r * 0.34, -r * 0.42 + row * r * 0.32), Vector2(r * 0.24, r * 0.22)), Color(0, 0, 0, 0.3))
			draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.24), Vector2(r, r * 0.2)), Color(0, 0, 0, 0.3))
		"check":
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.6, 0), c + Vector2(-r * 0.15, r * 0.5), c + Vector2(r * 0.7, -r * 0.5)]), color, w * 1.6)
		_:
			draw_circle(c, r, color)
