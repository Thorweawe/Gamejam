extends Node3D
## Harita koku. Test kisayollari:
##   1: deprem (binalar dayanikliligina gore hasar gorur / yikilir)
##   2: tum binalari onar
##   3: rastgele bir konutu bir ust seviyeye gelistir

const HOUSE_CHAIN := ["house_lv0_gecekondu", "house_lv1", "house_lv2", "house_lv3"]

@onready var camera_rig := $CameraRig


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			earthquake()
		KEY_2:
			for b in buildings():
				b.repair()
		KEY_3:
			upgrade_random_house()


func buildings() -> Array[Node]:
	return get_tree().get_nodes_in_group("buildings")


## Deprem: her bina riskine gore hasar gorur ya da yikilir. magnitude 0..1.5
func earthquake(magnitude: float = 1.0) -> void:
	camera_rig.shake(2.0)
	if has_node("Traffic"):
		$Traffic.panic(3.0)
	for b in buildings():
		var risk := risk_of(b.model_name) * magnitude
		var roll := randf()
		var delay := randf_range(0.1, 1.4)
		if roll < risk * 0.55:
			get_tree().create_timer(delay).timeout.connect(b.collapse)
		elif roll < risk:
			get_tree().create_timer(delay).timeout.connect(b.damage)


## 0 = hic etkilenmez, 1 = kesin etkilenir. Oyun dengesine gore ayarlayin.
func risk_of(model_name: String) -> float:
	if "gecekondu" in model_name:
		return 0.9
	if "kacak" in model_name:
		return 0.85
	if "reinforced" in model_name:
		return 0.15
	if model_name.begins_with("house_lv3"):
		return 0.05
	if model_name.begins_with("house_lv1"):
		return 0.5
	if model_name.begins_with("house_lv2"):
		return 0.45
	if model_name.contains("hospital") or model_name.contains("afad") or model_name.contains("firestation"):
		return 0.15
	if model_name.contains("townhall") or model_name.contains("school"):
		return 0.25
	return 0.4


func upgrade_random_house() -> void:
	var candidates := buildings().filter(func(b):
		var i := HOUSE_CHAIN.find(b.model_name)
		return i >= 0 and i < HOUSE_CHAIN.size() - 1 and b.state == Building.State.NORMAL)
	if candidates.is_empty():
		return
	var b: Building = candidates.pick_random()
	b.upgrade_to(HOUSE_CHAIN[HOUSE_CHAIN.find(b.model_name) + 1])
