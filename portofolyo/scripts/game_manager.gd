class_name GameManager
extends Node
## Oyunun kurallari ve akisi.
## Her gun: gelir/gider -> olay karti (karar) -> varsa afet -> yarinin hava uyarisi -> oyuncu eylemleri.
## Afet kurallari (her afetten sonra sayac sifirlanir): afetten sonraki 2 gun afet yok, sonra
## 3. gun %55, 4. gun %80, 5. gun kesin. Oyunun basi da boyle (1-2 sakin, en gec 5. gun).
## Ornek: 5. gun afet oldu -> 6 ve 7 sakin -> 8 (%55) -> 9 (%80) -> en gec 10. gun.
## Sakin olmayan gunlerde buyuk afet gelmezse kucuk olaylar (mutfak yangini) cikabilir; sayaci sifirlamaz.
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
var place_mode := ""  # "", "sandbag", "news", "drill", "reinforce_district"
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
var _today := {}
var _pending_summary := {}
var rel := {}  # karakter -> iliski puani (-3..+3); kart sunan karakterler bunu hatirlar
var bought := {}  # magaza urunu -> kac kez alindi
# magaza gelistirmelerinin oyundaki etkileri
var gas_valves := false  # deprem sonrasi yangin azalir
var flood_barriers := false  # sel basan evler daha az hasar gorur
var hydrants := false  # yangin daha hizli soner
var extinguishers := false  # ev yangini daha yavas buyur
var fire_plane := false  # orman yangini yari hizda yayilir
var museums := {}  # acilan muzeler (deprem / sel / yangin): halk ogrendigini daha yavas unutur
var volunteers := false  # enkaz kurtarma hizlanir
var _barked := {}  # bir kez soylenen replikler  # gunun ozeti icin: gun basindaki degerler ve yapilan yatirimlar
var bubbles: Bubbles  # tiklanabilir baloncuklar
var _seen_types := {}  # yasanan (ya da onlenen) afet turleri

@onready var city: Node3D = $"../CityMap"
@onready var day_cycle: DayCycle = $"../DayCycle"
@onready var hud: Node = $"../HUD"
@onready var disasters: Disasters = $"../Disasters"
@onready var audio: Node = $"../Audio"
@onready var map_info: MapInfo = city.get_node("MapInfo")


func _ready() -> void:
	add_to_group("game")  # magaza (shop.gd) oyunu bu grupla bulur
	disasters.game = self
	hud.game = self
	for i in map_info.district_names.size():
		district_aw.append(GameData.START_AWARENESS + (-6.0 if "Dağ" in map_info.district_names[i] else 0.0))
	day_cycle.day_started.connect(func(d): _start_day(d))
	day_cycle.day_ending.connect(func(_d):
		hud.hide_forecast()  # gun bitti: uyari karti ve Nermin'in uyari konusmasi kapanir
		hud.dialog.cut_bark()
		_select(null)
		_set_busy(true)
		audio.play("day"))
	day_cycle.midnight_reached.connect(_on_midnight)
	hud.action_pressed.connect(do_action)
	hud.building_action.connect(do_building_action)
	hud.precaution_pressed.connect(do_precaution)
	hud.risk_toggled.connect(set_risk_view)
	disasters.response_changed.connect(func(on):
		hud.show_response(on, self)
		audio.set_music("tense" if on else "calm"))
	notify.connect(func(t, k):
		hud.toast(t, k)
		if k == "bad":
			audio.play("error"))
	disasters.incident_spawned.connect(func(inc):
		hud.add_incident(inc)
		_watch_incident(inc))
	stats_changed.connect(func(): hud.update_stats(self))
	# tiklanabilir baloncuklar: muzeler + oyun sirasinda rastgele (bkz. bubbles.gd)
	bubbles = preload("res://scripts/bubbles.gd").new()
	bubbles.name = "Bubbles"
	bubbles.game = self
	bubbles.camera = city.camera_rig.camera
	city.add_child(bubbles)
	await get_tree().process_frame
	_update_awareness()
	hud.update_stats(self)
	_set_busy(true)
	audio.set_music("calm")
	# acilis: siyahtan acilir, kamera yakindan yavasca geri cekilir, sonra karsilama penceresi
	hud.fade_in(0.9)
	var rig: Node3D = city.camera_rig
	var z: float = rig._zoom
	rig._zoom = z * 0.4
	rig.create_tween().tween_property(rig, "_zoom", z, 2.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(1.1).timeout
	await hud.dialog.play_scene(Dialogs.INTRO)
	await hud.dialog.play_scene(Dialogs.TUTORIAL)
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
		+ (0.12 if early_warning else 0.0) + (0.05 if museums.has("deprem") else 0.0), 0.05, 0.95)


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


## Kasaya para ekle / cikar. Kasa eksiye dusmez: odenemeyen kisim (maas, bakim, borc) halkin
## belediyeye guvenini sarsar -> her 500 TL acik icin -1 farkindalik (en az 1). Doner: gercek degisim.
func change_money(v: int, reason := "") -> int:
	var before := money
	money = maxi(0, money + v)
	var unpaid := -(before + v) if before + v < 0 else 0
	if unpaid > 0:
		var hit := maxf(1.0, round(unpaid / 500.0))
		add_awareness(-hit)
		hud.stat_delta("aw", -hit)
		notify.emit("Kasa boş! %s ödenemedi (%s açık), halk tepkili: farkındalık -%d" % [
			reason if reason != "" else "Giderler", fmt_money(unpaid), int(hit)], "bad")
	return money - before


## Ekip zamaninda yetismeyen (suresi dolan) her yardim isareti o mahallede farkindaligi biraz dusurur.
## Orman karolari (hektar) daha az etkiler; bir yanginda cok karo yanabilir.
const MISSED_AW := 1.0
const MISSED_AW_FOREST := 0.5


func _watch_incident(inc: Incident) -> void:
	inc.resolved.connect(func(i: Incident, saved: int, lost: int):
		if saved > 0 or lost <= 0 or game_over:
			return
		var v := MISSED_AW_FOREST if i.tile != Vector2i.ZERO else MISSED_AW
		var at := i.global_position
		add_awareness(-v, map_info.district_of(at))
		hud.world_toast(at + Vector3.UP * 1.2, "Yetişilemedi · Farkındalık -%s" % ("%d" % v if v >= 1.0 else "%.1f" % v),
			Color(1.0, 0.45, 0.35), "warning", 0.2))


func add_awareness(v: float, district := -1) -> void:
	for i in district_aw.size():
		if district < 0 or i == district:
			district_aw[i] = clampf(district_aw[i] + v, 0.0, 100.0)
	_update_awareness()
	stats_changed.emit()


# ------------------------------------------------------------------ gun akisi
## Gece yarisi olunca zaman dongusu durur, gun sonu raporu cikar; "Devam" ile sabaha devam edilir.
func _on_midnight(_d: int) -> void:
	var summary := _day_summary()
	await hud.show_day_summary(summary)
	day_cycle.resume_to_morning()


func _start_day(d: int) -> void:
	day = d
	_set_busy(true)
	place_mode = ""
	if d > 1:
		var repairs := 0
		for b in city.buildings():
			repairs += b.tick_day()
		var delta := daily_income() - upkeep() - repairs
		hud.money_delta(change_money(delta, "Günlük giderler"), "Günlük bütçe")
		for i in district_aw.size():
			district_aw[i] = maxf(0.0, district_aw[i] - maxf(0.6, 1.5 - museums.size() * 0.3))  # halk zamanla unutur
		city.traffic.end_evacuation()
		city.traffic.set_picnic(true, d)
	_update_awareness()
	if money < 1500 and d - int(_barked.get("low_money", -10)) >= 5:
		_barked["low_money"] = d
		hud.dialog.bark("low_money")
	hud.hide_day_summary()
	hud.best_streak = 0
	_today = {"money": money, "aw": awareness, "pop": hud.city_pop(self), "saved": totals.saved, "lost": totals.casualties,
		"collapsed": totals.collapsed, "actions": []}
	await _process_later(d)
	stats_changed.emit()
	hud.hide_forecast()
	# ilk gun ogreticiden hemen sonra karar karti yok (oyuncu sehri tanisin); son gun de yok (sadece buyuk afet)
	var ev := _pick_event() if d > 1 and d < GameData.TOTAL_DAYS else {}
	if not ev.is_empty():
		audio.play("popup")
		var sp: Array = Characters.EVENT_SPEAKERS.get(ev.id, [])
		var who: String = sp[0] if not sp.is_empty() else ""
		var choice: int = await hud.show_event(ev, int(rel.get(who, 0)))
		audio.play("click")
		if who != "" and choice < sp[1].size():
			rel[who] = clampi(int(rel.get(who, 0)) + int(sp[1][choice]), -3, 3)
			if absi(rel[who]) == 3:
				bark_once(("love_" if rel[who] > 0 else "hate_") + who)
		await apply_effects(ev.choices[choice].effects, ev.title)
	if d >= GameData.TOTAL_DAYS:
		await _finale()
		return
	var type: String = _planned.get(d, "")
	if type != "" and _prevent.has(d) and _prevent[d].has(type) and randf() < _prevent[d][type]:
		totals.prevented += 1
		_seen_types[type] = true
		_last_disaster_day = d  # onlenen afet de sayaci sifirlar
		totals.baseline += 6.0
		await get_tree().create_timer(0.6).timeout
		await _build_tension(type)  # tehlike yine gelir (gokyuzu kararir, ruzgar)...
		var av: Dictionary = await disasters.averted(type)  # ...ama onlem sayesinde zarar vermez
		_calm_down()
		hud.show_alert("AFET ÖNLENDİ!", av.text, "shield", Color(0.25, 0.75, 0.4))
		audio.play("success")
		for i in mini(av.held.size(), 8):
			var b: Building = av.held[i]
			b.set_overlay(Color(0.3, 1.0, 0.45, 0.55))
			hud.world_toast(b.global_position + Vector3.UP * 1.3, "Korundu!", Color(0.35, 0.95, 0.5), "shield", 0.3 + i * 0.12)
		await get_tree().create_timer(3.0).timeout
		for b in av.held:
			if is_instance_valid(b):
				b.set_overlay(null)
		type = ""
	if type != "":
		await get_tree().create_timer(0.6).timeout
		await _build_tension(type)
		await run_disaster(type)
	elif d >= 3 and _days_since_disaster(d) >= 3 and randf() < 0.35 * human_factor():
		await get_tree().create_timer(0.8).timeout
		# kucuk olay: sayaci sifirlamaz. Ev yangini ya da piknikten cikan orman yangini
		var minor := "forest_fire" if randf() < 0.35 * risk.forest else "house_fire"
		await run_disaster(minor, true)
	_plan_ahead(d)
	_set_busy(false)


func _process_later(d: int) -> void:
	for item in _later.duplicate():
		if item.day <= d:
			_later.erase(item)
			hud.show_alert(item.title, item.text, "warning", Color(1.0, 0.7, 0.3))
			await apply_effects(item.effects, item.title)


func _pick_event() -> Dictionary:
	var pool := GameData.EVENTS.filter(func(e): return not _used_events.has(e.id))
	if pool.is_empty():
		return {}
	var ev: Dictionary = pool.pick_random()
	_used_events.append(ev.id)
	return ev


## Olay karti / gecikmeli etkiler. Her sonuc haritada gorunur: kamera hafifce oraya kayar,
## degisen binalarin ustunde etiket cikar, para ve farkindalik degisimi ust panelde ucar.
func apply_effects(fx: Dictionary, _source := "") -> void:
	var focus := Vector3.INF
	for k in fx:
		var v = fx[k]
		match k:
			"money":
				hud.money_delta(change_money(int(v), _source))
			"awareness":
				add_awareness(float(v))
				hud.stat_delta("aw", float(v))
			"pop":
				hud.add_residents(int(v))  # tasinan / giden aileler (nufus gostergesi)
			"risk_fire", "risk_forest", "risk_flood", "risk_quake":
				# karar kartinin risk etkisi yariya indirildi (ornek: x1.3 -> x1.15) ve oyuncuya gosterilmez
				var key: String = k.trim_prefix("risk_")
				var mult := 1.0 + (float(v) - 1.0) * 0.5
				risk[key] = clampf(risk[key] * mult, 0.3, 3.0)
			"kacak":
				focus = _mark(_convert_houses(int(v), func(b): return b.model_name in ["house_lv1", "house_lv2"], func(m): return m + "_kacak"),
					"Kaçak kat!", Color(1.0, 0.45, 0.35), "warning", focus)
			"river_site":
				focus = _mark(_convert_houses(int(v), _is_riverside_house, func(_m): return "house_lv2_kacak"),
					"Dere yatağına bina", Color(1.0, 0.45, 0.35), "warning", focus)
			"reinforce":
				focus = _mark(_convert_houses(int(v), func(b): return b.model_name in ["house_lv1", "house_lv2"], func(m): return m + "_reinforced"),
					"Güçlendirildi", Color(0.45, 0.95, 0.55), "shield", focus)
			"upgrade":
				focus = _mark(_convert_houses(int(v), func(b): return b.model_name == "house_lv0_gecekondu", func(_m): return "house_lv1"),
					"Yenilendi", Color(0.45, 0.95, 0.55), "house", focus)
			"upgrade_service":
				var prefix: String = GameData.SERVICES[v]
				for b in city.buildings():
					if b.model_name.begins_with(prefix) and GameData.UPGRADES.has(b.model_name):
						b.start_upgrade(GameData.UPGRADES[b.model_name][0], 1)
						focus = _mark([b], "Gelişiyor", Color(0.45, 0.95, 0.55), "star", focus)
						break
			"kits":
				kits += int(v)
				hud.world_toast(Vector3(0, 0, 4), "Deprem çantaları dağıtıldı", Color(0.45, 0.95, 0.55), "kit")
			"drills":
				drills += int(v)
				city.traffic.drill(Vector3(0, 0, 4), 14.0)
				hud.world_toast(Vector3(0, 0, 4), "Tatbikat!", Color(0.45, 0.95, 0.55), "drill")
			"assembly":
				if int(v) > 0:
					for i in int(v):
						disasters.add_assembly_point()
				else:
					disasters.remove_assembly_point()
			"build":
				var at: Vector3 = disasters.build_feature(v)
				if at != Vector3.INF:
					focus = at
					audio.play("build")
					hud.world_toast(at, v.get("label", "Yeni yapı"), Color(0.55, 0.8, 1.0), "map")
			"later":
				_later.append({"day": day + int(v.days), "title": v.title, "text": v.text, "effects": v.effects})
	stats_changed.emit()
	if focus != Vector3.INF:
		city.camera_rig.focus(focus, 30.0, 1.0)
		await get_tree().create_timer(2.2).timeout


const RISK_NAMES := {"fire": "Yangın", "forest": "Orman yangını", "flood": "Sel", "quake": "Deprem"}


func _risk_area(key: String) -> Vector3:
	match key:
		"forest":
			if not map_info.picnic_spots.is_empty():
				return MapInfo.to3(map_info.picnic_spots[0])
		"flood":
			if not map_info.river_tiles.is_empty():
				var p: Vector2 = map_info.river_tiles[map_info.river_tiles.size() / 2]
				return MapInfo.to3(p)
	return Vector3(0, 0, 4)


## Degisen binalarin ustune etiket koy; ilk binayi odak yap (onceden odak yoksa).
func _mark(list: Array, text: String, color: Color, icon: String, focus: Vector3) -> Vector3:
	for i in list.size():
		hud.world_toast(list[i].global_position + Vector3.UP * 1.2, text, color, icon, i * 0.25)
	if focus == Vector3.INF and not list.is_empty():
		return list[0].global_position
	return focus


func _is_riverside_house(b: Building) -> bool:
	return b.is_house() and not b.model_name.begins_with("house_lv3") and disasters.is_flood_tile(Disasters.tile_key(b.position))


func _convert_houses(n: int, filter: Callable, to: Callable) -> Array:
	var options: Array = city.buildings().filter(func(b): return b.state == Building.State.NORMAL and not b.is_busy() and filter.call(b))
	# kameraya yakin / sehir merkezindekiler once (oyuncu gorsun)
	options.sort_custom(func(a, b): return a.position.length() < b.position.length())
	var picked := options.slice(0, mini(options.size(), n * 3))
	picked.shuffle()
	picked = picked.slice(0, n)
	for b in picked:
		b.upgrade_to(to.call(b.model_name))
	return picked


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
	var p := clampf((0.55 if since == 3 else 0.8) + day * 0.01, 0.0, 0.95)
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
	# her afet turu oyunda en az bir kez gelsin: henuz yasanmamis turler (orman yangini...) one cikar
	if day >= 3:
		for k in weights:
			if not _seen_types.has(k):
				weights[k] *= 3.0
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
	hud.show_forecast(type, f.title, f.text, f.actions)  # yuzde yazilmaz: belirsizlik kalsin
	audio.play("alert_soft")
	bark_once("first_forecast")


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
	for a in f.actions:
		if a.id == id:
			_log_action(a.name)
	match id:
		"picnic_ban":
			money -= cost
			_add_prevent(when, "forest_fire", 0.7 + awareness * 0.002)
			city.traffic.set_picnic(false, when)
			hud.world_toast(_risk_area("forest"), "Piknik yasak", Color(0.45, 0.95, 0.55), "tree")
			city.camera_rig.focus(_risk_area("forest"), 30.0, 1.0)
		"stove_check":
			money -= cost
			_add_prevent(when, "house_fire", 0.6 + awareness * 0.002)
			hud.world_toast(Vector3(0, 0, 4), "Sobalar denetlendi", Color(0.45, 0.95, 0.55), "fire")
		"evacuate_river":
			money -= cost
			disasters.river_evacuated = true
			add_awareness(3, map_info.district_names.find("Dere Mahallesi"))
			hud.world_toast(_risk_area("flood"), "Kıyı boşaltıldı", Color(0.45, 0.95, 0.55), "people")
			city.camera_rig.focus(_risk_area("flood"), 30.0, 1.0)
		"sandbag":
			# dere kenarindaki evlerin onune otomatik kum torbasi dizilir (kamera izler)
			money -= cost
			var placed := disasters.place_sandbags_auto()
			city.camera_rig.focus(_risk_area("flood"), 32.0, 1.0)
			hud.world_toast(_risk_area("flood"), "%d noktaya kum torbası dizildi" % placed, Color(0.45, 0.95, 0.55), "shield", 0.8)
			audio.play("build")
	hud.money_delta(-cost)
	audio.play("coins")
	stats_changed.emit()


## Afet oncesi: gokyuzu kararir, ruzgar eser (deprem haric: o habersiz gelir).
func _build_tension(type: String) -> void:
	if type == "quake":
		return
	var tint: Color = {"flood": Color(0.28, 0.31, 0.38), "forest_fire": Color(0.6, 0.42, 0.3),
		"house_fire": Color(0.45, 0.42, 0.4)}.get(type, Color(0.32, 0.34, 0.4))
	day_cycle.set_gloom(0.95 if type == "flood" else 0.65, tint, 2.0)
	audio.set_wind(true)
	await get_tree().create_timer(2.4).timeout


func _calm_down() -> void:
	day_cycle.set_gloom(0.0, Color(), 3.0)
	audio.set_wind(false)


## Afetin ilk ani: yarim saniyelik agir cekim (gercek zamana gore).
func _slowmo(sec := 0.5, scale := 0.2) -> void:
	var prev := Engine.time_scale
	Engine.time_scale = prev * scale
	await get_tree().create_timer(sec, true, false, true).timeout
	Engine.time_scale = prev


func _add_prevent(when: int, type: String, chance: float) -> void:
	if not _prevent.has(when):
		_prevent[when] = {}
	_prevent[when][type] = clampf(chance, 0.0, 0.95)


func _type_name(type: String) -> String:
	return {"quake": "deprem", "house_fire": "yangın", "forest_fire": "orman yangını", "flood": "sel"}.get(type, type)


## Afeti calistir: uyari bandi -> animasyon + mudahale -> rapor.
## minor: kucuk olay (tek ev yangini); afet sayacini sifirlamaz.
func run_disaster(type: String, minor := false) -> void:
	_select(null)
	_seen_types[type] = true
	hud.flash({"quake": Color(1.0, 0.15, 0.1), "house_fire": Color(1.0, 0.45, 0.15), "forest_fire": Color(1.0, 0.5, 0.15),
		"flood": Color(0.25, 0.5, 1.0)}.get(type, Color.RED), 2 if type == "quake" else 1)
	if type == "quake":
		_slowmo(0.55)
	bark_once("first_" + type)
	if not minor:
		_had_disaster = true
		_last_disaster_day = day
		_last_type = type
	var report := {}
	var real0 := population()
	audio.play("alert_soft" if minor else "alarm")
	audio.set_music("tense")
	match type:
		"quake":
			var mag := clampf(0.6 + day * 0.022 + randf() * 0.15, 0.6, 1.1)
			hud.show_alert("DEPREM!", "Büyüklük %.1f · İşaretlere tıkla, ekip gönder" % (5.2 + mag * 1.6), "warning")
			audio.play("quake")
			report = await disasters.earthquake(mag)
			report.cause = disasters.earthquake_cause(mag)
		"house_fire":
			var b := disasters.pick_fire_building()
			var cause := disasters.house_fire_cause(b)
			city.camera_rig.focus(b.global_position, 26.0)
			hud.show_alert("KÜÇÜK YANGIN" if minor else "YANGIN!", "İşarete tıkla, itfaiye gönder", "fire")
			report = await disasters.house_fire(b, false)
			report.cause = cause
		"forest_fire":
			var start := disasters.forest_fire_start()
			var cause: String = GameData.CAUSES.forest_fire.pick_random()
			city.camera_rig.focus(Vector3(start.x, 0, start.y + 3), 34.0)
			hud.show_alert("ORMAN YANGINI!", "Yayılmadan itfaiye gönder", "tree")
			report = await disasters.forest_fire(start, false)
			report.cause = cause
		"flood":
			var cause := disasters.flood_cause()
			hud.show_alert("SEL!", "Mahsur kalanlara AFAD gönder", "wave", Color(0.35, 0.65, 1.0))
			report = await disasters.flood(clampf(0.8 + day * 0.02 + randf() * 0.2, 0.8, 1.3))
			report.cause = cause
	report.minor = minor
	await get_tree().create_timer(0.5).timeout  # son coken binanin animasyonu bitsin (nufus hesabi dogru olsun)
	_record(report, real0)
	audio.set_music("calm")
	_calm_down()
	if not minor:
		await _prep_moment(report)
	hud.show_report(report)


## real0: afetten onceki (olceklenmemis) nufus. Rapordaki can kaybi gercek kisi sayisidir; nufus
## gostergesi ise oyun olcegindedir (x _pop_scale). Raporda nufusun neden dustugu ayrica yazilir:
## evsiz kalanlar (yikilan / hasarli binalar, onarilinca doner) + sehri terk edenler (olenlerin yakinlari).
func _record(r: Dictionary, real0 := -1) -> void:
	if not r.get("minor", false):
		totals.disasters += 1
	for k in ["casualties", "saved", "collapsed", "damaged", "burned", "evacuated"]:
		totals[k] += int(r.get(k, 0))
	totals.baseline += float(r.get("baseline", 0.0))
	r.fled = hud.lose_residents(int(r.get("casualties", 0)))  # olenlerin yakinlari sehri terk eder (kalici)
	r.homeless = maxi(0, int(round((real0 - population()) * hud.pop_scale()))) if real0 >= 0 else 0
	add_awareness(2.0)  # afet sonrasi halk biraz bilinclenir
	audio.play("success" if r.saved >= r.casualties else "fail")


## "Hazirlik ise yaradi" ani: hazirlik sayesinde ayakta kalan binalar yesil parlar, kurtulan can sayisi gosterilir.
## Hic hazirlik yoksa oyuncuya neyin ise yarayacagi hatirlatilir.
func _prep_moment(r: Dictionary) -> void:
	var held: Array = []
	for b in r.get("held", []):
		if is_instance_valid(b) and b.state != Building.State.COLLAPSED and not held.has(b):
			held.append(b)
	var lives := maxi(0, int(round(float(r.get("baseline", 0.0)) - float(r.casualties))))
	r.prep_lives = lives
	r.held_count = held.size()
	if held.is_empty() and lives < 3:
		if r.casualties > 0:
			hud.show_alert("HAZIRLIKSIZ YAKALANDIK", "Güçlendirme, farkındalık ve ekipler can kaybını azaltır", "warning", Color(1.0, 0.55, 0.25))
			bark_once("prep_bad")
			await get_tree().create_timer(2.2).timeout
		return
	var parts := []
	if not held.is_empty():
		parts.append("%d bina ayakta kaldı" % held.size())
	if lives > 0:
		parts.append("~%d can kurtuldu" % lives)
	var green := Color(0.35, 0.95, 0.5)
	hud.show_alert("HAZIRLIK İŞE YARADI!", "  ·  ".join(parts), "shield", Color(0.25, 0.75, 0.4))
	if not held.is_empty():
		bark_once("prep_good")
	audio.play("success")
	if not held.is_empty():
		city.camera_rig.focus(held[0].global_position, 32.0, 0.9)
		for i in mini(held.size(), 8):
			var b: Building = held[i]
			b.set_overlay(Color(0.3, 1.0, 0.45, 0.55))
			hud.world_toast(b.global_position + Vector3.UP * 1.3, "Dayandı!", green, "shield", 0.4 + i * 0.15)
	await get_tree().create_timer(2.8).timeout
	for b in held:
		if is_instance_valid(b):
			b.set_overlay(null)
	if risk_view:
		set_risk_view(true)


## Gun sonu ozet karti icin veriler.
func _day_summary() -> Dictionary:
	var out := {"day": day, "money0": _today.get("money", money), "money1": money,
		"aw0": _today.get("aw", awareness), "aw1": awareness,
		"pop0": _today.get("pop", hud.city_pop(self)), "pop1": hud.city_pop(self),
		"saved": totals.saved - int(_today.get("saved", totals.saved)),
		"lost": totals.casualties - int(_today.get("lost", totals.casualties)),
		"collapsed": totals.collapsed - int(_today.get("collapsed", totals.collapsed)),
		"actions": _today.get("actions", []), "streak": hud.best_streak,
		"next": daily_income() - upkeep() - repair_cost_today(), "warning": ""}
	# gun ozeti afet riskini soylemez: belirsizlik kalsin (uyari sadece meteoroloji kartinda)
	return out


func _log_action(text: String) -> void:
	if _today.has("actions"):
		_today.actions.append(text)


## Bir replik oyun boyunca bir kez soylensin (ilk deprem, ilk uyari...).
func bark_once(key: String) -> void:
	if _barked.has(key) or not Dialogs.BARKS.has(key):
		return
	_barked[key] = true
	hud.dialog.bark(key)


## Servis sefleriyle iliski ekip hizini etkiler: memnun sef %18'e kadar hizli, kus sef yavas.
func chief_factor(unit: String) -> float:
	var who: String = {"fire": "murat", "medic": "zeynep", "rescue": "elif"}.get(unit, "")
	return 1.0 - int(rel.get(who, 0)) * 0.06


func _finale() -> void:
	game_over = true
	_set_busy(true)
	await hud.dialog.play_scene(Dialogs.FINALE)
	city.camera_rig.focus(Vector3(0, 0, 4), 40.0, 0.8)  # buyuk deprem sehrin her yerinde: isaretler ekranda gorunsun
	audio.play("alarm")
	audio.set_music("tense")
	hud.show_alert("BÜYÜK DEPREM!", "Tüm birimler göreve!", "warning")
	hud.flash(Color(1.0, 0.15, 0.1), 3)
	_slowmo(0.7)
	day_cycle.set_gloom(0.6, Color(0.35, 0.33, 0.36), 3.0)
	audio.play("quake")
	var real0 := population()
	var report := await disasters.finale()
	report.cause = "Şiddetli deprem, ardından yangınlar ve sel."
	await get_tree().create_timer(0.5).timeout
	_record(report, real0)
	audio.set_music("calm")
	_calm_down()
	await _prep_moment(report)
	await hud.show_report(report, true)
	city.traffic.end_evacuation()
	# nufus yuzunden kaybedildiyse ("Şehir Boşaldı" acik) kapanis konusmasi ve ikinci oyun sonu ekrani gelmez
	if hud.lost:
		return
	audio.play("end")
	await hud.dialog.play_scene(Dialogs.ENDING_GOOD if grade()[0] in ["A", "B", "C"] else Dialogs.ENDING_BAD)
	if hud.lost:
		return
	await hud.show_end(self)


## Sehrin guvenlik notu (oyun sonu).
func grade() -> Array:
	# nufus: baslangic %40; sehir buyuduyse puan artar, insanlar gittiyse duser
	var pop_ratio: float = hud.pop_ratio(hud.city_pop(self))
	var score := clampf(95.0 - totals.casualties * 0.5 - totals.collapsed * 0.5 + totals.saved * 0.08
		+ awareness * 0.2 + flood_protection * 3 + (pop_ratio - 40.0) * 0.6, 0.0, 100.0)
	var letter := "F"
	for g in [[85, "A"], [70, "B"], [55, "C"], [40, "D"]]:
		if score >= g[0]:
			letter = g[1]
			break
	return [letter, int(score)]


# ------------------------------------------------------------------ magaza (shop.tscn)
## Urunler GameData.SHOP_ITEMS'ta; Kamu Binalari sekmesi "up:<anahtar>" urunleridir.
const LEVEL_NAMES := {"belediye": "Belediye", "itfaiye": "İtfaiye", "hastane": "Hastane", "afad": "AFAD"}
const LEVEL_KEYS := {"belediye": "hall", "itfaiye": "fire", "hastane": "medic", "afad": "rescue"}


## Magaza kilitleri icin bina seviyeleri.
func building_levels() -> Dictionary:
	return {"belediye": hall_level(), "itfaiye": service_level("fire"), "hastane": service_level("medic"), "afad": service_level("rescue")}


func shop_name(id: String) -> String:
	if id.begins_with("up:"):
		return building_offer(id.get_slice(":", 1)).name
	if id == "river" and flood_protection >= 1:
		return "Taşkın Seti"
	return GameData.shop_item(id).get("name", id)


func shop_desc(id: String) -> String:
	if id == "river" and flood_protection >= 1:
		return "Kıyılara kalıcı set çekilir: sel neredeyse hiç zarar veremez."
	if id == "kacak_all":
		return "Şehirdeki %d kaçak kat yıkılır; depremde ilk çöken binalar güvenli hâle gelir." % _kacak_list().size()
	if id == "reinforce_district":
		return GameData.shop_item(id).get("desc", "") + " Fiyat mahalledeki ev sayısına göre değişir; seçerken her mahallenin fiyatı haritada yazar."
	return GameData.shop_item(id).get("desc", "")


func shop_cost(id: String) -> int:
	if id.begins_with("up:"):
		return building_offer(id.get_slice(":", 1)).cost
	match id:
		"reinforce_district":
			# fiyat mahalleye gore degisir: magazada en ucuz mahalle (alinabilir mi kontrolu buna gore),
			# satir "X - Y" araligini gosterir, secerken her mahallenin ustunde kendi fiyati yazar
			var costs := _district_costs()
			return 0 if costs.is_empty() else costs.min()
		"river":
			return 8000 if flood_protection == 0 else 7000
	return int(GameData.shop_item(id).get("cost", 0))


## "" = alinabilir; aksi halde neden alinamadigi ("Alındı", "Gerekli: Belediye Sv.2"...)
func shop_reason(id: String) -> String:
	if id.begins_with("up:"):
		return building_offer(id.get_slice(":", 1)).reason
	var it := GameData.shop_item(id)
	if it.is_empty():
		return "?"
	var req: Dictionary = it.get("req", {})
	if id == "river" and flood_protection >= 1:
		req = {"belediye": 3}
	var lv := building_levels()
	var miss := []
	for k in req:
		if int(lv[k]) < int(req[k]):
			miss.append("%s Sv.%d" % [LEVEL_NAMES[k], req[k]])
	if not miss.is_empty():
		return "Gerekli: " + ", ".join(miss)
	var n := int(bought.get(id, 0))
	if (it.get("once", false) and n >= 1) or (it.has("max") and n >= int(it.max)):
		return "Alındı"
	match id:
		"reinforce_district":
			if shop_cost(id) == 0:
				return "Bütün evler güçlü"
		"kacak_all":
			if _kacak_list().is_empty():
				return "Kaçak kat kalmadı"
		"renewal":
			if not city.buildings().any(func(b): return b.model_name == "house_lv0_gecekondu"):
				return "Gecekondu kalmadı"
		"assembly":
			if not Array(map_info.park_tiles).any(func(p): return not map_info.assembly_points.has(p)):
				return "Uygun park yok"
	return ""


## Kamu binasi gelistirmesi: {name, desc, cost, reason, level, is_max}
func building_offer(key: String) -> Dictionary:
	var unit: String = LEVEL_KEYS.get(key, key)
	var b := _service_building(unit)
	var lvl := hall_level() if unit == "hall" else service_level(unit)
	var names := {"hall": "Belediye Binası", "fire": "İtfaiye İstasyonu", "medic": "Devlet Hastanesi", "rescue": "AFAD Merkezi"}
	var desc := {"hall": "Yeni geliştirmelerin kilidi açılır.", "fire": "+1 itfaiye aracı, yangınlara daha hızlı müdahale.",
		"medic": "+1 ambulans, yaralılar daha hızlı tedavi edilir.", "rescue": "+1 AFAD ekibi, enkaz altından daha hızlı kurtarma."}
	var out := {"name": "%s (Seviye %d)" % [names[unit], mini(lvl + 1, 3)], "desc": desc[unit], "cost": 0, "reason": "",
		"level": lvl, "is_max": false}
	if b == null or not GameData.UPGRADES.has(b.model_name):
		out.name = "%s (Seviye %d)" % [names[unit], lvl]
		out.desc = "En üst seviyeye ulaşıldı."
		out.is_max = true
		out.reason = "Maks"
		return out
	var up: Array = GameData.UPGRADES[b.model_name]
	out.cost = up[1]
	if b.is_closed():
		out.reason = "İnşaatta, yarın hazır"
	elif hall_level() < up[2]:
		out.reason = "Gerekli: Belediye Sv.%d" % up[2]
	return out


func _service_building(key: String) -> Building:
	var prefix: String = "building_townhall" if key == "hall" else GameData.SERVICES[key]
	for b in city.buildings():
		if b.model_name.begins_with(prefix):
			return b
	return null


func _district_reinforce_list(d: int) -> Array:
	var out := []
	for b in city.buildings():
		if GameData.REINFORCE.has(b.model_name) and b.state == Building.State.NORMAL and not b.is_closed() \
				and map_info.district_of(b.position) == d:
			out.append(b)
	return out


## Guclendirilecek evi olan mahallelerin paket fiyatlari.
func _district_costs() -> Array:
	var costs := []
	for d in map_info.district_names.size():
		var c := _district_reinforce_cost(_district_reinforce_list(d))
		if c > 0:
			costs.append(c)
	return costs


## Magaza satirindaki fiyat yazisi (TL'siz); "" = normal fiyat (shop_cost).
func shop_price_text(id: String) -> String:
	if id == "reinforce_district":
		var costs := _district_costs()
		if costs.size() > 1 and costs.min() != costs.max():
			return "%s–%s" % [fmt_money(costs.min()).trim_suffix(" TL"), fmt_money(costs.max()).trim_suffix(" TL")]
	return ""


func _district_reinforce_cost(list: Array) -> int:
	var sum := 0
	for b in list:
		sum += GameData.REINFORCE[b.model_name]
	return int(sum * GameData.DISTRICT_DISCOUNT / 100.0) * 100


func _kacak_list() -> Array:
	return city.buildings().filter(func(b): return GameData.REMOVE_KACAK.has(b.model_name) and b.state == Building.State.NORMAL)


## Magazadan satin al (shop.gd cagirir). Doner: basarili mi.
func do_action(id: String) -> bool:
	if busy or game_over:
		notify.emit("Şu an yatırım yapılamaz", "bad")
		return false
	var reason := shop_reason(id)
	if reason != "":
		notify.emit(reason, "bad")
		return false
	var cost := shop_cost(id)
	if money < cost:
		notify.emit("Bütçe yetersiz: %s gerekli" % fmt_money(cost), "bad")
		return false
	if GameData.shop_item(id).get("target", false):
		place_mode = id
		hud.show_place_hint("%s: haritada bir mahalleye tıkla  ·  Sağ tık: iptal" % shop_name(id))
		set_risk_view(true)  # mahalle farkindaliklari ve riskli binalar gorunsun
		return true
	_log_action(shop_name(id))
	money -= cost
	hud.money_delta(-cost)
	audio.play("coins")
	bought[id] = int(bought.get(id, 0)) + 1
	var good := Color(0.45, 0.95, 0.55)
	var center := Vector3(0, 0, 4)
	if id == "kacak_all":
		var list := _kacak_list()
		for b in list:
			b.upgrade_to(b.model_name.replace("_kacak", ""))
			add_awareness(1, map_info.district_of(b.position))
		_mark(list, "Kaçak kat yıkıldı", good, "check", Vector3.INF)
		if not list.is_empty():
			city.camera_rig.focus(list[0].global_position, 34.0, 1.0)
		audio.play("build")
		bought.erase(id)  # yeni kacak kat cikarsa tekrar alinabilsin
	elif id.begins_with("up:"):
		var key := id.get_slice(":", 1)
		var b := _service_building(LEVEL_KEYS.get(key, key))
		var hall_before := hall_level()
		b.start_upgrade(GameData.UPGRADES[b.model_name][0], 1)
		city.camera_rig.focus(b.global_position, 26.0, 1.0)
		hud.world_toast(b.global_position + Vector3.UP * 1.5, "Yarın hazır" if key != "belediye" else "Belediye gelişiyor", good, "star")
		audio.play("build")
		if hall_level() > hall_before:
			notify.emit("Belediye Sv %d: yeni geliştirmeler açıldı" % hall_level(), "good")
	else:
		match id:
			"gas_valves":
				gas_valves = true
				risk.fire = maxf(0.3, risk.fire * 0.8)
				hud.world_toast(center, "Gaz vanaları takıldı", good, "fire")
			"assembly":
				disasters.add_assembly_point()
			"renewal":
				var list: Array = city.buildings().filter(func(b): return b.model_name == "house_lv0_gecekondu" and b.state == Building.State.NORMAL)
				for b in list:
					b.start_upgrade("house_lv1", GameData.UPGRADE_DAYS)
				add_awareness(4, map_info.district_names.find("Dağ Eteği"))
				_mark(list, "Dönüşüm", good, "house", Vector3.INF)
				if not list.is_empty():
					city.camera_rig.focus(list[0].global_position, 32.0, 1.0)
			"warning":
				early_warning = true
				hud.world_toast(center, "Erken uyarı ağı kuruldu", good, "siren")
			"drain_clean", "storm_drains":
				risk.flood = maxf(0.3, risk.flood * (0.8 if id == "drain_clean" else 0.75))
				city.camera_rig.focus(_risk_area("flood"), 32.0, 1.0)
				hud.world_toast(_risk_area("flood"), "Sel riski azaldı", good, "wave")
			"flood_barriers":
				flood_barriers = true
				hud.world_toast(_risk_area("flood"), "Kıyıya su bariyerleri", good, "shield")
			"river":
				flood_protection += 1
				disasters.build_river_walls(flood_protection)
				city.camera_rig.focus(_risk_area("flood"), 34.0, 1.0)
				hud.world_toast(_risk_area("flood"), "Dere ıslah edildi" if flood_protection == 1 else "Taşkın seti kuruldu", good, "wave")
			"forest":
				forest_measures += 1
				risk.forest = maxf(0.3, risk.forest * 0.6)
				var at := _risk_area("forest")
				city.camera_rig.focus(at, 30.0, 1.0)
				hud.world_toast(at, "Orman yangını riski azaldı", good, "tree")
			"wiring":
				risk.fire = maxf(0.3, risk.fire * 0.75)
				hud.world_toast(center, "Tesisatlar yenilendi", good, "fire")
			"hydrants":
				hydrants = true
				disasters.place_hydrants()
				hud.world_toast(center, "Yangın muslukları kuruldu", good, "fire")
			"extinguishers":
				extinguishers = true
				risk.fire = maxf(0.3, risk.fire * 0.9)
				hud.world_toast(center, "Evlere yangın tüpü dağıtıldı", good, "fire")
			"plane":
				fire_plane = true
				hud.world_toast(_risk_area("forest"), "Yangın uçağı hazır", good, "tree")
			"booklet":
				add_awareness(4)
				hud.stat_delta("aw", 4)
				hud.world_toast(center, "Kitapçıklar okullarda", good, "news")
			"kits":
				kits += 1
				add_awareness(3)
				hud.world_toast(center, "Deprem çantaları dağıtıldı", good, "kit")
			"tv":
				add_awareness(7)
				hud.stat_delta("aw", 7)
				hud.world_toast(center, "TV kampanyası yayında", good, "tv")
			"museum_deprem", "museum_sel", "museum_yangin":
				var kind := id.get_slice("_", 1)
				museums[kind] = true
				add_awareness(6)
				hud.stat_delta("aw", 6)
				if kind == "sel":
					risk.flood = maxf(0.3, risk.flood * 0.85)
				elif kind == "yangin":
					risk.fire = maxf(0.3, risk.fire * 0.85)
					risk.forest = maxf(0.3, risk.forest * 0.9)
				var at: Vector3 = disasters.build_museum(kind)
				if at != Vector3.INF:
					city.camera_rig.focus(at, 26.0, 1.0)
					bubbles.add_museum(at, kind)  # tiklaninca patlar: ek farkindalik
					hud.world_toast(at + Vector3.UP * 2.0, {"deprem": "Deprem Müzesi", "sel": "Sel Müzesi", "yangin": "Yangın Müzesi"}[kind] + " açıldı", good, "hall", 0.6)
				audio.play("build")
			"volunteers":
				volunteers = true
				drills += 1
				add_awareness(3)
				hud.world_toast(center, "Gönüllü ekipler hazır", good, "people")
	_show_purchase(id)
	stats_changed.emit()
	return true


## Satin alinan her gelistirme ekranda gorunsun: yesil bant (ne alindi + ne ise yarar).
## Haritada yeri olmayan (sehir geneli) gelistirmelerde kamera sehrin ortasina kayar.
const CITY_WIDE := ["gas_valves", "warning", "wiring", "hydrants", "extinguishers", "booklet", "kits", "tv", "volunteers"]


func _show_purchase(id: String) -> void:
	var text: String = shop_desc(id) if not id.begins_with("up:") else building_offer(id.get_slice(":", 1)).desc
	var title := shop_name(id)
	if id.begins_with("up:"):
		title = title.split(" (")[0] + " geliştiriliyor · yarın hazır"
	hud.show_alert(title, text, "check", Color(0.24, 0.7, 0.42))
	if id in CITY_WIDE:
		city.camera_rig.focus(Vector3(0, 0, 4), 42.0, 1.0)


## Haritada mahalleye tiklanan urunler: gazete, tatbikat, mahalle guclendirme.
func _apply_targeted(id: String, p: Vector3) -> void:
	var d := map_info.district_of(p)
	var at := MapInfo.to3(map_info.district_centers[d], 1.5)
	var good := Color(0.45, 0.95, 0.55)
	var cost := shop_cost(id)
	var list := []
	if id == "reinforce_district":
		list = _district_reinforce_list(d)
		cost = _district_reinforce_cost(list)
		if list.is_empty():
			notify.emit("%s: güçlendirilecek ev yok" % map_info.district_names[d], "bad")
			return
	if money < cost:
		notify.emit("Bütçe yetersiz: %s gerekli" % fmt_money(cost), "bad")
		return
	_log_action(shop_name(id))
	money -= cost
	hud.money_delta(-cost)
	audio.play("coins")
	bought[id] = int(bought.get(id, 0)) + 1
	match id:
		"news":
			add_awareness(12, d)
			hud.world_toast(at, "Farkındalık +12", good, "news")
		"drill":
			drills += 1
			add_awareness(15, d)
			city.traffic.drill(MapInfo.to3(map_info.district_centers[d]))
			hud.world_toast(at, "Tatbikat! Farkındalık +15", good, "drill")
		"reinforce_district":
			for b in list:
				b.start_upgrade(b.model_name + "_reinforced", 1)
			add_awareness(3, d)
			_mark(list, "Güçlendiriliyor", good, "shield", Vector3.INF)
			city.camera_rig.focus(MapInfo.to3(map_info.district_centers[d]), 32.0, 1.0)
			audio.play("build")
	hud.show_alert(shop_name(id), map_info.district_names[d] + " · " + shop_desc(id).trim_prefix("Bir mahalleye tıkla: "), "check", Color(0.24, 0.7, 0.42))
	stats_changed.emit()


# ------------------------------------------------------------------ tiklama: bina / isaret / hedef
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT and place_mode != "":
			_end_place_mode()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if bubbles and bubbles.try_pop(event.position):
			get_viewport().set_input_as_handled()
			return
		if disasters.responding:
			return  # isaretlere HUD'daki IncidentMarker uzerinden tiklanir
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
					notify.emit("Bütçe yetersiz", "bad")
				elif disasters.place_sandbag(k):
					money -= cost
					hud.money_delta(-cost)
					audio.play("build")
					stats_changed.emit()
				else:
					notify.emit("Kum torbası sadece dere kenarına", "bad")
				return
			"news", "drill", "reinforce_district":
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
			get_viewport().set_input_as_handled()  # ayni ESC duraklatma menusunu acmasin
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


## Birim gonder: arac istasyondan cikar, varinca kurtarma baslar. Doner: gonderildi mi.
func assign_unit(inc: Incident) -> bool:
	var unit := inc.unit()
	if units_free(unit) <= 0:
		notify.emit("Boşta %s yok · ekip dönünce gönder" % GameData.UNIT_NAMES[unit], "bad")
		return false
	units_busy[unit] += 1
	inc.state = Incident.State.EN_ROUTE
	audio.play("dispatch")
	# istasyona donmekte olan ayni turden arac varsa o gider; yoksa istasyondan yeni arac cikar
	var v: Agent = city.traffic.returning_vehicle(GameData.UNIT_VEHICLES[unit], inc.global_position)
	if v:
		city.traffic.redirect(v, inc.global_position)
	else:
		v = city.traffic.dispatch(GameData.UNIT_VEHICLES[unit], GameData.UNIT_STATIONS[unit], inc.global_position)
	inc.vehicle = weakref(v)
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
	return true


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
		out.append({"id": "reinforce", "text": "Güçlendir", "cost": GameData.REINFORCE[m],
			"locked": "" if hall_level() >= GameData.REINFORCE_HALL else "Belediye Sv %d gerekli" % GameData.REINFORCE_HALL})
	if GameData.REMOVE_KACAK.has(m):
		out.append({"id": "remove_kacak", "text": "Kaçak katı yık", "cost": GameData.REMOVE_KACAK[m], "locked": ""})
	if GameData.ALLOW_KACAK.has(m):
		out.append({"id": "allow_kacak", "text": "Kaçak kata göz yum", "cost": -GameData.ALLOW_KACAK[m], "locked": ""})
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
		notify.emit("Bütçe yetersiz: %s gerekli" % fmt_money(opt.cost), "bad")
		return
	money -= opt.cost
	_log_action(opt.text)
	hud.money_delta(-opt.cost)
	var good := Color(0.45, 0.95, 0.55)
	var top := b.global_position + Vector3.UP * 1.4
	var base := b.model_name.replace("_kacak", "").replace("_reinforced", "")
	match id:
		"upgrade":
			var hall_before := hall_level()
			b.start_upgrade(GameData.UPGRADES[b.model_name][0], GameData.UPGRADE_DAYS if b.is_house() else 1)
			audio.play("build")
			if b.model_name.begins_with("building_townhall") and hall_level() > hall_before:
				notify.emit("Belediye Sv %d: yeni yatırımlar açıldı" % hall_level(), "good")
			hud.world_toast(top, "İnşaat başladı", good, "house")
		"reinforce":
			b.start_upgrade(b.model_name + "_reinforced", 1)
			add_awareness(1, map_info.district_of(b.position))
			audio.play("build")
			hud.world_toast(top, "Güçlendiriliyor", good, "shield")
		"remove_kacak":
			b.upgrade_to(base)
			add_awareness(2, map_info.district_of(b.position))
			audio.play("build")
			hud.world_toast(top, "Kaçak kat yıkıldı", good, "check")
		"allow_kacak":
			b.upgrade_to(b.model_name + "_kacak")
			add_awareness(-2, map_info.district_of(b.position))
			audio.play("coins")
			hud.world_toast(top, "Riskli bina!", Color(1.0, 0.45, 0.35), "warning")
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
	if on:
		_update_district_labels()
	else:
		hud.district_tags([])
	hud.set_risk_button(on)


## Mahalle etiketleri (risk haritasi / mahalle secimi): HUD'da okunakli kartlar (ad, farkindalik cubugu,
## mahalle guclendirmede paket fiyati). Sadece risk haritasi acikken gorunur.
func _update_district_labels() -> void:
	if not risk_view:
		return
	var items := []
	for i in map_info.district_names.size():
		var item := {"pos": MapInfo.to3(map_info.district_centers[i], 1.0), "name": map_info.district_names[i],
			"aw": district_aw[i], "extra": "", "extra_ok": true}
		if place_mode == "reinforce_district":
			# hedef secerken mahallenin gercek paket fiyati (magazadaki aralikla ayni hesap)
			var cost := _district_reinforce_cost(_district_reinforce_list(i))
			if cost <= 0:
				item.extra = "Güçlendirilecek ev yok"
				item.extra_ok = false
			else:
				item.extra = "Güçlendirme: %s" % fmt_money(cost)
				item.extra_ok = money >= cost
		items.append(item)
	hud.district_tags(items)


static func fmt_money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out + " TL"
