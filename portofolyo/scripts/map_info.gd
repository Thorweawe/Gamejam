class_name MapInfo
extends Node
## Harita uretici (tools/map_gen.py) tarafindan doldurulur. Tum konumlar dunya
## koordinatinda (x, z) karo merkezleridir; karo 2x2 birimdir.

@export var forest_tiles: PackedVector2Array  ## orman + piknik karolari (orman yangini yayilir)
@export var picnic_spots: PackedVector2Array  ## mangal alanlari
@export var assembly_points: PackedVector2Array  ## toplanma alanlari
@export var park_tiles: PackedVector2Array  ## parklar (yeni toplanma alani acilabilir)
@export var plaza_tiles: PackedVector2Array
@export var flood_tiles: PackedVector2Array  ## nehir tasinca su basan karolar (dere yatagi)
@export var river_tiles: PackedVector2Array
@export var beach_tiles: PackedVector2Array
@export var mountain_tiles: PackedVector2Array
@export var sea_points: PackedVector2Array

const TILE := 2.0


static func key(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x), roundi(p.z))


static func to3(p: Vector2, y := 0.1) -> Vector3:
	return Vector3(p.x, y, p.y)


func nearest(points: PackedVector2Array, from: Vector3) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for p in points:
		var d := Vector2(from.x, from.z).distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = p
	return best


@export var district_names: PackedStringArray  ## mahalle adlari
@export var district_centers: PackedVector2Array  ## mahalle merkezleri


## Bir noktanin ait oldugu mahalle (en yakin merkez).
func district_of(p: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in district_centers.size():
		var d := Vector2(p.x, p.z).distance_squared_to(district_centers[i])
		if d < best_d:
			best_d = d
			best = i
	return best
