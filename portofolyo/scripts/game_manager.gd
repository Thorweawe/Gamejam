class_name GameManager
extends Node
## Oyunun kurallari ve akisi.
## Her gun: gelir/gider -> olay karti (karar) -> varsa afet -> yarinin hava uyarisi -> oyuncu eylemleri.
## Afet kurallari (her afetten sonra sayac sifirlanir): afetten sonraki 2 gun afet yok, sonra olasilik
## her gun artar, 5 gun dolmadan gelmediyse 5. gun kesin gelir. Oyunun basi da boyle (1-2 sakin, 5. gun kesin).
## Ornek: 5. gun afet oldu -> 6 ve 7 sakin -> 8-9 artan olasilik -> en gec 10. gun.
## 20. gun buyuk afet zinciri ve oyun sonu. Deprem asla onceden haber verilmez.
## Farkindalik mahalle bazlidir: insan kaynakli olaylari azaltir, tahliyeyi ve kurtarmayi iyilestirir.

signal stats_changed
signal notify(text: String, kind: String)  # kind: info, good, bad, disaster

var money := GameData.START_MONEY
var day := 1
var district_aw: Array[float] = []  # mahalle farkindaliklari (0-100)
var awareness := GameData.START_AWARENESS  # nufus agirlikli ortalama
var risk := {"fire": 1.0, "forest": 1.0, "flood": 1.0, "quake": 1.0}
var flood_protection := 0
var kits := 0
var drills := 0
var forest_measures := 0
var early_warning := false
var units_busy := {"fire": 0, "medic": 0, "rescue": 0}
var totals := {"casualties": 0, "saved": 0, "collapsed": 0, "damaged": 0, "burned": 0, "disasters": 0,
	"evacuated": 0, "baseline": 0.0, "prevented": 0}
var busy := false
var game_over := false
var place_mode := ""  # "", "sandbag", "news", "drill"
var forecast := {}  # aktif uyari: {type, day, chance}
var risk_view := false

var _had_disaster := false
var _last_disaster_day := 0
var _last_type := ""
var _planned := {}  # gun -> afet tipi
var _prevent := {}  # gun -> {type: onleme olasiligi}
var _used_events: Array[String] = []
var _later: Array[Dictionary] = []
var _selected: Building
var _district_labels: Array[Label3D] = []

@onready var city: Node3D = $"../CityMap"
@onready var day_cycle: DayCycle = $"../DayCycle"
@onready var hud: Node = $"../HUD"
@onready var disasters: Disasters = $"../Disasters"
@onready var audio: Node = $"../Audio"
@onready var map_info: MapInfo = city.get_node("MapInfo")


func _ready() -> void:
	disasters.game = self
	for i in map_info.district_names.size():
		district_aw.append(GameData.START_AWARENESS + (-6.0 if "Dağ" in map_info.district_names[i] else 0.0))
	day_cycle.day_started.connect(func(d): _start_day(d))
	day_cycle.day_ending.connect(func(_d):
		_select(null)
		audio.play("day"))
	hud.action_pressed.connect(do_action)
	hud.building_action.connect(do_building_action)
	hud.precaution_pressed.connect(do_precaution)
	hud.risk_toggled.connect(set_risk_view)
	disasters.response_changed.connect(func(on):
		hud.show_response(on, self)
		audio.set_music("tense" if on else "calm"))
	notify.connect(func(t, k):
		hud.show_message(t, k)
		if k == "bad":
			audio.play("error"))
	stats_changed.connect(func(): hud.update_stats(self))
	await get_tree().process_frame
	_update_awareness()
	hud.update_stats(self)
	_set_busy(true)
	audio.set_music("calm")
	await hud.show_intro()
	_start_day(1)


func _set_busy(v: bool) -> void:
	busy = v
	day_cycle.locked = v or game_over
	hud.set_actions_enabled(not v and not game_over)


# ------------------------------------------------------------------ hesaplar
func population() -> int:
	var total := 0
	for b in city.buildings():
		total += b.population()
	return total


func daily_income() -> int:
	return int(population() * 1.5 + awareness * 10.0)


## Gunluk sabit giderler: servis binalari, dere islahi, uyari sistemi.
func upkeep() -> int:
	var cost := 0
	for unit in GameData.SERVICES:
		cost += service_level(unit) * 250
	cost += flood_protection * 300 + (400 if early_warning else 0)
	return cost


func repair_cost_today() -> int:
	var cost := 0
	for b in city.buildings():
		if b.state != Building.State.NORMAL and b.repair_days > 0:
			cost += GameData.REPAIR_UPKEEP[b.state]
	return cost


func service_level(unit: String) -> int:
	var prefix: String = GameData.SERVICES[unit]
	for b in city.buildings():
		if b.model_name.begins_with(prefix):
			return 3 if b.model_name.ends_with("_lv3") else (2 if b.model_name.ends_with("_lv2") else 1)
	return 1


## Birim sayisi: servis binasi seviyesi + 1 (Sv1: 2 arac, Sv3: 4 arac).
func units_total(unit: String) -> int:
	return service_level(unit) + 1


func units_free(unit: String) -> int:
	return units_total(unit) - units_busy[unit]


func hall_level() -> int:
	for b in city.buildings():
		if b.model_name.begins_with("building_townhall"):
			return int(b.model_name.right(1))
	return 1


func district_awareness(p: Vector3) -> float:
	if p == Vector3.INF or district_aw.is_empty():
		return awareness
	return district_aw[map_info.district_of(p)]


## Insan kaynakli olay carpani: farkindalik %100 iken olaylar %65 azalir.
func human_factor() -> float:
	return 1.0 - clampf(awareness, 0.0, 100.0) / 100.0 * 0.65


## Tahliye basarisi (0-0.95): mahalle farkindaligi + canta + tatbikat + toplanma alani + erken uyari.
func evac_ratio(p: Vector3) -> float:
	var assembly_bonus: float = (map_info.assembly_points.size() - 4) * 0.03
	var aw := district_awareness(p)
	return clampf(0.2 + aw / 100.0 * 0.55 + mini(kits, 2) * 0.06 + mini(drills, 3) * 0.03 + assembly_bonus
		+ (0.12 if early_warning else 0.0), 0.05, 0.95)


func _update_awareness() -> void:
	var sum := 0.0
	var weight := 0.0
	var pops := []
	pops.resize(district_aw.size())
	pops.fill(1.0)
	for b in city.buildings():
		pops[map_info.district_of(b.position)] += b.population()
	for i in district_aw.size():
		sum += district_aw[i] * pops[i]
		weight += pops[i]
	awareness = sum / maxf(weight, 1.0)
	disasters.update_awareness_visuals(awareness)
	city.traffic.update_kits(func(p): return district_awareness(p))
	_update_district_labels()


func add_awareness(v: float, district := -1) -> void:
	for i in district_aw.size():
		if district < 0 or i == district:
			district_aw[i] = clampf(district_aw[i] + v, 0.0, 100.0)
	_update_awareness()
	stats_changed.emit()


# ------------------------------------------------------------------ gun akisi
func _start_day(d: int) -> void:
	day = d
	_set_busy(true)
	place_mode = ""
	if d > 1:
		var repairs := 0
		for b in city.buildings():
			repairs += b.tick_day()
		var income := daily_income()
		var cost := upkeep()
		money += income - cost - repairs
		for i in district_aw.size():
			district_aw[i] = maxf(0.0, district_aw[i] - 1.5)  # halk zamanla unutur
		var msg := "Gün %d: Vergi +%s, Gider -%s" % [d, fmt_money(income), fmt_money(cost)]
		if repairs > 0:
			msg += ", Onarım -%s" % fmt_money(repairs)
		notify.emit(msg, "info")
		city.traffic.end_evacuation()
		city.traffic.set_picnic(true, d)
	_update_awareness()
	_process_later(d)
	stats_changed.emit()
	hud.hide_forecast()
	var ev := _pick_event()
	if not ev.is_empty():
		audio.play("popup")
		var choice: int = await hud.show_event(ev)
		audio.play("click")
		apply_effects(ev.choices[choice].effects, ev.title)
	if d >= GameData.TOTAL_DAYS:
		await _finale()
		return
	var type: String = _planned.get(d, "")
	if type != "" and _prevent.has(d) and _prevent[d].has(type) and randf() < _prevent[d][type]:
		notify.emit("Aldığın önlemler sayesinde bugünkü %s önlendi!" % _type_name(type), "good")
		totals.prevented += 1
		_last_disaster_day = d  # onlenen afet de sayaci sifirlar
		totals.baseline += 6.0
		audio.play("success")
		type = ""
	if type != "":
		await get_tree().create_timer(0.8).timeout
		await run_disaster(type)
	_plan_ahead(d)
	_set_busy(false)


func _process_later(d: int) -> void:
	for item in _later.duplicate():
		if item.day <= d:
			_later.erase(item)
			notify.emit("%s: %s" % [item.title, item.text], "bad")
			apply_effects(item.effects, item.title)


func _pick_event() -> Dictionary:
	var pool := GameData.EVENTS.filter(func(e): return not _used_events.has(e.id))
	if pool.is_empty():
		return {}
	var ev: Dictionary = pool.pick_random()
	_used_events.append(ev.id)
	return ev


func apply_effects(fx: Dictionary, _source := "") -> void:
	for k in fx:
		var v = fx[k]
		match k:
			"money":
				money += int(v)
			"awareness":
				add_awareness(float(v))
			"risk_fire", "risk_forest", "risk_flood", "risk_quake":
				var key: String = k.trim_prefix("risk_")
				risk[key] = clampf(risk[key] * float(v), 0.3, 3.0)
			"kacak":
				_convert_houses(int(v), func(b): return b.model_name in ["house_lv1", "house_lv2"], func(m): return m + "_kacak")
			"river_site":
				_convert_houses(int(v), _is_riverside_house, func(_m): return "house_lv2_kacak")
			"reinforce":
				_convert_houses(int(v), func(b): return b.model_name in ["house_lv1", "house_lv2"], func(m): return m + "_reinforced")
			"upgrade":
				_convert_houses(int(v), func(b): return b.model_name == "house_lv0_gecekondu", func(_m): return "house_lv1")
			"upgrade_service":
				var prefix: String = GameData.SERVICES[v]
				for b in city.buildings():
					if b.model_name.begins_with(prefix) and GameData.UPGRADES.has(b.model_name):
						b.start_upgrade(GameData.UPGRADES[b.model_name][0], 1)
						break
			"kits":
				kits += int(v)
			"drills":
				drills += int(v)
			"assembly":
				if int(v) > 0:
					for i in int(v):
						disasters.add_assembly_point()
				else:
					disasters.remove_assembly_point()
			"later":
				_later.append({"day": day + int(v.days), "title": v.title, "text": v.text, "effects": v.effects})
	stats_changed.emit()


func _is_riverside_house(b: Building) -> bool:
	return b.is_house() and not b.model_name.begins_with("house_lv3") and disasters.is_flood_tile(Disasters.tile_key(b.position))


func _convert_houses(n: int, filter: Callable, to: Callable) -> void:
	var options: Array = city.buildings().filter(func(b): return b.state == Building.State.NORMAL and filter.call(b))
	options.shuffle()
	for b in options.slice(0, n):
		b.upgrade_to(to.call(b.model_name))


# ------------------------------------------------------------------ afet plani ve uyarilar
## Son afetten (ya da planlanmis afetten) bu yana gecen gun.
func _days_since_disaster(d: int) -> int:
	var last := _last_disaster_day
	for k in _planned:
		if k < d and k > last:
			last = k
	return d - last


func _roll_disaster(d: int) -> String:
	if d >= GameData.TOTAL_DAYS:
		return ""
	var since := _days_since_disaster(d)
	if since <= 2:
		return ""  # afetten sonraki 2 gun sakin
	var forced := since >= 5
	var p := clampf(0.3 + (since - 3) * 0.2 + day * 0.01, 0.0, 0.9)
	if not forced and randf() > p:
		return ""
	var hf := human_factor()
	var weights := {
		"quake": 1.0 * risk.quake,
		"house_fire": 1.2 * risk.fire * hf,
		"forest_fire": 1.0 * risk.forest * hf,
		"flood": 0.9 * risk.flood * (1.4 - flood_protection * 0.5),
	}
	if weights.has(_last_type):
		weights[_last_type] *= 0.35
	var total := 0.0
	for k in weights:
		total += weights[k]
	var roll := randf() * total
	for k in weights:
		roll -= weights[k]
		if roll <= 0.0:
			return k
	return "quake"


## Yarin (sel icin 2 gun sonra) icin afet zari at; deprem disindakiler icin uyari ver.
func _plan_ahead(d: int) -> void:
	forecast = {}
	if _planned.has(d + 1) or _planned.has(d + 2):
		if _planned.get(d + 1, "") == "flood":  # 2 gun once uyarilan sel yarin geliyor
			_show_forecast("flood", d + 1, 80)
		return
	var type := _roll_disaster(d + 1)
	if type == "":
		return
	var when := d + (2 if type == "flood" and d + 2 < GameData.TOTAL_DAYS else 1)
	_planned[when] = type
	if type == "quake":
		return  # depremi kimse onceden bilemez
	var chance := randi_range(55, 85)
	var forced := _days_since_disaster(when) >= 5
	if not forced and randf() * 100.0 > chance:
		_planned.erase(when)  # yanlis alarm: uyari verildi ama afet olmayacak
	_show_forecast(type, when, chance)


func _show_forecast(type: String, when: int, chance: int) -> void:
	forecast = {"type": type, "day": when, "chance": chance}
	var f: Dictionary = GameData.FORECASTS[type]
	hud.show_forecast(f.title, f.text % chance, f.actions, self)
	notify.emit(f.title + ": " + (f.text % chance), "bad")
	audio.play("alert_soft")


func do_precaution(id: String) -> void:
	if forecast.is_empty() or game_over:
		return
	var f: Dictionary = GameData.FORECASTS[forecast.type]
	var cost := 0
	for a in f.actions:
		if a.id == id:
			cost = a.cost
	if money < cost:
		notify.emit("Bütçe yetersiz! (%s gerekli)" % fmt_money(cost), "bad")
		return
	var when: int = forecast.day
	match id:
		"picnic_ban":
			money -= cost
			_add_prevent(when, "forest_fire", 0.7 + awareness * 0.002)
			city.traffic.set_picnic(false, when)
			notify.emit("Ormanda piknik ve mangal yasaklandı.", "good")
		"stove_check":
			money -= cost
			_add_prevent(when, "house_fire", 0.6 + awareness * 0.002)
			notify.emit("Ekipler evleri gezip soba ve ısıtıcıları denetledi.", "good")
		"evacuate_river":
			money -= cost
			disasters.river_evacuated = true
			add_awareness(3, map_info.district_names.find("Dere Mahallesi"))
			notify.emit("Dere kenarındaki halk yakınlarının evlerine taşındı.", "good")
		"sandbag":
			place_mode = "sandbag"
			hud.show_place_hint("Kum torbası için dere kenarındaki bir binaya / karoya tıkla (%s). Sağ tık: bitir" % fmt_money(cost))
			return
	audio.play("coins")
	stats_changed.emit()


func _add_prevent(when: int, type: String, chance: float) -> void:
	if not _prevent.has(when):
		_prevent[when] = {}
	_prevent[when][type] = clampf(chance, 0.0, 0.95)


func _type_name(type: String) -> String:
	return {"quake": "deprem", "house_fire": "yangın", "forest_fire": "orman yangını", "flood": "sel"}.get(type, type)


## Afeti calistir: uyari bandi -> animasyon + mudahale -> rapor.
func run_disaster(type: String) -> void:
	_select(null)
	_had_disaster = true
	_last_disaster_day = day
	_last_type = type
	var report := {}
	audio.play("alarm")
	audio.set_music("tense")
	match type:
		"quake":
			var mag := clampf(0.6 + day * 0.022 + randf() * 0.15, 0.6, 1.1)
			hud.show_alert("DEPREM!", disasters.earthquake_cause(mag) + "\nYardım işaretlerine tıklayıp ekip gönder!")
			audio.play("quake")
			report = await disasters.earthquake(mag)
			report.cause = disasters.earthquake_cause(mag)
		"house_fire":
			var b := disasters.pick_fire_building()
			var cause := disasters.house_fire_cause(b)
			city.camera_rig.focus(b.global_position, 26.0)
			hud.show_alert("YANGIN!", cause + "\nİşarete tıklayıp itfaiyeyi gönder!")
			report = await disasters.house_fire(b, false)
			report.cause = cause
		"forest_fire":
			var start := disasters.forest_fire_start()
			var cause: String = GameData.CAUSES.forest_fire.pick_random()
			city.camera_rig.focus(Vector3(start.x, 0, start.y + 3), 34.0)
			hud.show_alert("ORMAN YANGINI!", cause + "\nYayılmadan itfaiye gönder!")
			report = await disasters.forest_fire(start, false)
			report.cause = cause
		"flood":
			var cause := disasters.flood_cause()
			hud.show_alert("SEL!", cause + "\nMahsur kalanlara AFAD gönder!")
			report = await disasters.flood(clampf(0.8 + day * 0.02 + randf() * 0.2, 0.8, 1.3))
			report.cause = cause
	_record(report)
	audio.set_music("calm")
	hud.show_report(report, self)


func _record(r: Dictionary) -> void:
	totals.disasters += 1
	for k in ["casualties", "saved", "collapsed", "damaged", "burned", "evacuated"]:
		totals[k] += int(r.get(k, 0))
	totals.baseline += float(r.get("baseline", 0.0))
	add_awareness(2.0)  # afet sonrasi halk biraz bilinclenir
	audio.play("success" if r.saved >= r.casualties else "fail")


func _finale() -> void:
	game_over = true
	_set_busy(true)
	await hud.show_decision("SON GÜN", "Bilim insanları uyarıyor: büyük fay hattı harekete geçti, üstüne şiddetli yağış bekleniyor. Bugün şehir en büyük sınavını verecek!", ["Hazırız!"])
	audio.play("alarm")
	audio.set_music("tense")
	hud.show_alert("BÜYÜK DEPREM!", "Tüm birimler göreve! Yardım işaretlerine tıkla.")
	audio.play("quake")
	var report := await disasters.finale()
	report.cause = "Şiddetli deprem, ardından yangınlar ve sel."
	_record(report)
	audio.set_music("calm")
	await hud.show_report(report, self, true)
	city.traffic.end_evacuation()
	audio.play("end")
	await hud.show_end(self)


## Sehrin guvenlik notu (oyun sonu).
func grade() -> Array:
	var score := clampf(100.0 - totals.casualties * 0.35 - totals.collapsed * 0.4 + totals.saved * 0.1
		+ awareness * 0.25 + flood_protection * 3, 0.0, 100.0)
	var letter := "F"
	for g in [[85, "A"], [70, "B"], [55, "C"], [40, "D"]]:
		if score >= g[0]:
			letter = g[1]
			break
	return [letter, int(score)]


# ------------------------------------------------------------------ belediye eylemleri
func action_def(id: String) -> Dictionary:
	for a in GameData.ACTIONS:
		if a.id == id:
			return a
	return {}


func action_cost(id: String) -> int:
	return action_def(id).get("cost", 0)


## "" = yapilabilir, aksi halde neden yapilamadigi.
func action_block_reason(id: String) -> String:
	var a := action_def(id)
	if hall_level() < a.get("hall", 1):
		return "Belediye Sv %d gerekli" % a.hall
	match id:
		"river":
			if flood_protection >= 1:
				return "Yapıldı"
		"levee":
			if flood_protection >= 2:
				return "Yapıldı"
			if flood_protection < 1:
				return "Önce dere ıslahı"
		"forest":
			if forest_measures >= 2:
				return "Yapıldı"
		"warning":
			if early_warning:
				return "Yapıldı"
		"renewal":
			if not city.buildings().any(func(b): return b.model_name == "house_lv0_gecekondu"):
				return "Gecekondu kalmadı"
		"assembly":
			if not Array(map_info.park_tiles).any(func(p): return not map_info.assembly_points.has(p)):
				return "Uygun park yok"
	return ""


func do_action(id: String) -> void:
	if busy or game_over:
		return
	var reason := action_block_reason(id)
	if reason != "":
		notify.emit(reason, "bad")
		return
	var cost := action_cost(id)
	if money < cost:
		notify.emit("Bütçe yetersiz! (%s gerekli)" % fmt_money(cost), "bad")
		return
	if action_def(id).get("target", false):
		place_mode = id
		hud.show_place_hint("%s: haritada bir mahalleye tıkla. Sağ tık: iptal" % action_def(id).name)
		set_risk_view(true)  # mahalle farkindaliklari gorunsun
		return
	money -= cost
	audio.play("coins")
	match id:
		"tv":
			add_awareness(7)
			notify.emit("TV kampanyası tüm şehirde yayınlandı.", "good")
		"kits":
			kits += 1
			add_awareness(3)
			notify.emit("Deprem çantaları dağıtıldı. Sokaklarda çantalı insanlar göreceksin.", "good")
		"forest":
			forest_measures += 1
			risk.forest = maxf(0.3, risk.forest * 0.6)
			notify.emit("Ormana mangal yasağı tabelaları ve gözetleme kulesi kuruldu.", "good")
		"river":
			flood_protection = 1
			disasters.build_river_walls(1)
			notify.emit("Dere ıslahı tamamlandı!", "good")
		"levee":
			flood_protection = 2
			disasters.build_river_walls(2)
			notify.emit("Kıyılara kalıcı taşkın seti kuruldu!", "good")
		"warning":
			early_warning = true
			notify.emit("Erken uyarı ağı kuruldu: afette tahliye çok daha başarılı.", "good")
		"renewal":
			for b in city.buildings():
				if b.model_name == "house_lv0_gecekondu" and b.state == Building.State.NORMAL:
					b.start_upgrade("house_lv1", GameData.UPGRADE_DAYS)
			add_awareness(4, map_info.district_names.find("Dağ Eteği"))
			notify.emit("Kentsel dönüşüm başladı: gecekondular güvenli evlere dönüşüyor.", "good")
		"assembly":
			if disasters.add_assembly_point():
				notify.emit("Yeni afet toplanma alanı belirlendi.", "good")
	stats_changed.emit()


func _apply_targeted(id: String, p: Vector3) -> void:
	var cost := action_cost(id)
	if money < cost:
		notify.emit("Bütçe yetersiz!", "bad")
		return
	money -= cost
	audio.play("coins")
	var d := map_info.district_of(p)
	var dname := map_info.district_names[d]
	if id == "news":
		add_awareness(12, d)
		notify.emit("%s için gazete ilanı verildi. Farkındalık +12" % dname, "good")
	else:
		drills += 1
		add_awareness(15, d)
		city.traffic.drill(MapInfo.to3(map_info.district_centers[d]))
		notify.emit("%s: tatbikat! İnsanlar toplanma alanına yürüyor." % dname, "good")
	stats_changed.emit()


# ------------------------------------------------------------------ tiklama: bina / isaret / hedef
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT and place_mode != "":
			_end_place_mode()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if disasters.responding:
			var inc := disasters.incident_at(event.position)
			if inc:
				assign_unit(inc)
			return
		if busy or game_over:
			return
		var p: Vector3 = city.ground_point(event.position)
		if p == Vector3.INF:
			return
		match place_mode:
			"sandbag":
				var k := Disasters.tile_key(p)
				var cost := 500
				if money < cost:
					notify.emit("Bütçe yetersiz!", "bad")
				elif disasters.place_sandbag(k):
					money -= cost
					audio.play("build")
					stats_changed.emit()
				else:
					notify.emit("Kum torbası sadece dere kenarına konur.", "bad")
				return
			"news", "drill":
				_apply_targeted(place_mode, p)
				_end_place_mode()
				return
		_select(city.building_at(p))
		audio.play("click")
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			set_risk_view(not risk_view)
		elif event.keycode == KEY_ESCAPE and place_mode != "":
			_end_place_mode()
		elif not busy and not game_over:
			var debug := {KEY_F1: "quake", KEY_F2: "house_fire", KEY_F3: "forest_fire", KEY_F4: "flood"}
			if debug.has(event.keycode):
				_set_busy(true)
				await run_disaster(debug[event.keycode])
				_set_busy(false)


func _end_place_mode() -> void:
	place_mode = ""
	hud.hide_place_hint()
	set_risk_view(false)


## Birim gonder: arac istasyondan cikar, varinca kurtarma baslar.
func assign_unit(inc: Incident) -> void:
	var unit := inc.unit()
	if units_free(unit) <= 0:
		notify.emit("Boşta %s birimi yok! (Binasını geliştirerek artır)" % GameData.UNIT_NAMES[unit], "bad")
		return
	units_busy[unit] += 1
	inc.state = Incident.State.EN_ROUTE
	audio.play("dispatch")
	var v: Agent = city.traffic.dispatch(GameData.UNIT_VEHICLES[unit], GameData.UNIT_STATIONS[unit], inc.global_position)
	# zayif referans: isaret ya da arac once silinirse baglanti guvenle bos gecer
	var inc_ref: WeakRef = weakref(inc)
	var v_ref: WeakRef = weakref(v)
	v.arrived.connect(func():
		var i: Incident = inc_ref.get_ref()
		if i and i.state == Incident.State.EN_ROUTE:
			i.state = Incident.State.WORKING)
	inc.resolved.connect(func(_i, _s, _l):
		units_busy[unit] = maxi(0, units_busy[unit] - 1)
		var vehicle = v_ref.get_ref()
		if vehicle:
			city.traffic.release(vehicle)
		hud.show_response(true, self))
	hud.show_response(true, self)


func _select(b: Building) -> void:
	if _selected and is_instance_valid(_selected):
		_selected.set_selected(false)
	_selected = b
	if b == null:
		hud.hide_building()
		return
	b.set_selected(true)
	hud.show_building(b, building_options(b), self)


func building_options(b: Building) -> Array:
	var out := []
	var m := b.model_name
	if b.is_closed():
		return out
	if GameData.UPGRADES.has(m):
		var up: Array = GameData.UPGRADES[m]
		out.append({"id": "upgrade", "text": "Geliştir: " + GameData.info(up[0]).name, "cost": up[1],
			"locked": "" if hall_level() >= up[2] else "Belediye Sv %d gerekli" % up[2]})
	if GameData.REINFORCE.has(m):
		out.append({"id": "reinforce", "text": "Depreme karşı güçlendir", "cost": GameData.REINFORCE[m],
			"locked": "" if hall_level() >= GameData.REINFORCE_HALL else "Belediye Sv %d gerekli" % GameData.REINFORCE_HALL})
	if GameData.REMOVE_KACAK.has(m):
		out.append({"id": "remove_kacak", "text": "Kaçak katı yık", "cost": GameData.REMOVE_KACAK[m], "locked": ""})
	if GameData.ALLOW_KACAK.has(m):
		out.append({"id": "allow_kacak", "text": "Kaçak kata göz yum (+nüfus)", "cost": -GameData.ALLOW_KACAK[m], "locked": ""})
	return out


func do_building_action(id: String) -> void:
	var b := _selected
	if b == null or busy or b.is_busy():
		return
	var opt: Dictionary = {}
	for o in building_options(b):
		if o.id == id:
			opt = o
	if opt.is_empty():
		return
	if opt.locked != "":
		notify.emit(opt.locked, "bad")
		return
	if money < opt.cost:
		notify.emit("Bütçe yetersiz! (%s gerekli)" % fmt_money(opt.cost), "bad")
		return
	money -= opt.cost
	var base := b.model_name.replace("_kacak", "").replace("_reinforced", "")
	match id:
		"upgrade":
			var hall_before := hall_level()
			b.start_upgrade(GameData.UPGRADES[b.model_name][0], GameData.UPGRADE_DAYS if b.is_house() else 1)
			audio.play("build")
			if b.model_name.begins_with("building_townhall") and hall_level() > hall_before:
				notify.emit("Belediye seviye %d! Yeni eylemler ve geliştirmeler açıldı." % hall_level(), "good")
			else:
				notify.emit("%s inşaatı başladı." % b.display_name(), "good")
		"reinforce":
			b.start_upgrade(b.model_name + "_reinforced", 1)
			add_awareness(1, map_info.district_of(b.position))
			audio.play("build")
			notify.emit("Bina güçlendiriliyor (1 gün boş kalacak).", "good")
		"remove_kacak":
			b.upgrade_to(base)
			add_awareness(2, map_info.district_of(b.position))
			audio.play("build")
			notify.emit("Kaçak kat yıkıldı. Bina artık daha güvenli.", "good")
		"allow_kacak":
			b.upgrade_to(b.model_name + "_kacak")
			add_awareness(-2, map_info.district_of(b.position))
			audio.play("coins")
			notify.emit("Kaçak kata göz yumuldu: +%s ama bina artık çok riskli." % fmt_money(-opt.cost), "bad")
	stats_changed.emit()
	await get_tree().create_timer(0.8).timeout
	if _selected == b:
		_select(b)


# ------------------------------------------------------------------ risk haritasi
func set_risk_view(on: bool) -> void:
	risk_view = on
	for b in city.buildings():
		if not on:
			b.set_overlay(null)
			continue
		var c := Color(0.3, 0.9, 0.35, 0.5)
		var m: String = b.model_name
		if b.state == Building.State.COLLAPSED:
			c = Color(0.4, 0.4, 0.4, 0.5)
		elif "kacak" in m or "gecekondu" in m:
			c = Color(1.0, 0.2, 0.15, 0.55)
		elif m in ["house_lv1", "house_lv2"] or (m.begins_with("building_") and GameData.quake_risk(m) >= 0.35):
			c = Color(1.0, 0.8, 0.15, 0.5)
		b.set_overlay(c)
	for l in _district_labels:
		l.visible = on
	if on:
		_update_district_labels()
	hud.set_risk_button(on)


func _update_district_labels() -> void:
	if _district_labels.is_empty():
		for i in map_info.district_names.size():
			var l := Label3D.new()
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.fixed_size = true
			l.pixel_size = 0.00045
			l.font_size = 40
			l.outline_size = 14
			l.position = MapInfo.to3(map_info.district_centers[i], 3.2)
			l.visible = false
			city.add_child(l)
			_district_labels.append(l)
	for i in _district_labels.size():
		var aw := district_aw[i]
		_district_labels[i].text = "%s\nFarkındalık %%%d" % [map_info.district_names[i], int(aw)]
		_district_labels[i].modulate = Color(1, 0.45, 0.4).lerp(Color(0.5, 1, 0.55), aw / 100.0)


static func fmt_money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out + " TL"
