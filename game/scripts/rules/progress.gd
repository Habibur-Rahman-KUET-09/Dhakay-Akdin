## What carries over from one day to the next (§৫, §৯.৪): Rahim Chacha's
## savings and his daughter's school fee, the mohalla's community fund and
## its projects, mohalla XP and level, upgrades bought, and a record of the
## last days; the stars (তারা) earned, the story read, how the named
## neighbours feel, today's character and challenge, and the run of days
## played (§৬, §৭). Saved to user://save.json after every day, written to a new
## file first and then moved over the old one, so a crash cannot spoil it.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")
const Daily = preload("res://scripts/rules/daily.gd")

const SCHEMA := 1
const DEFAULT_PATH := "user://save.json"
const HISTORY := 10
const PROJECTS := ["street_lights", "drain_cleaning", "bus_shelter"]
const UPGRADES := ["new_rickshaw", "battery_rickshaw"]
## The stall grows in this order (§৪.৩); the move to a shop comes with the story.
const TEA_UPGRADES := ["bench", "second_kettle", "awning", "fridge"]
const BUS_UPGRADES := ["notebook", "change_bag", "loud_voice"]
## Each character's upgrades, and where their prices are in the balance.
const UPGRADE_LISTS := {"rickshaw": ["rickshaw", UPGRADES], "tea": ["tea_stall", TEA_UPGRADES], "bus": ["bus", BUS_UPGRADES]}

var b: Balance
var path := DEFAULT_PATH
var data: Dictionary
## The date to count as today ("YYYY-MM-DD"); "" for the phone's date.
var today := ""


func _init(balance: Balance, save_path := DEFAULT_PATH) -> void:
	b = balance
	path = save_path
	data = fresh()
	load_save()


static func fresh() -> Dictionary:
	return {
		"schema": SCHEMA,
		"day": 0,
		"taka": 0,
		"fund": 0,
		"fundProject": PROJECTS[0],
		"mohalla": {"level": 1, "xp": 0, "projectsDone": []},
		"rickshaw": {"days": 0, "school": 0, "bestDay": 0, "trips": 0, "earned": 0, "teas": 0, "upgrades": []},
		"tea": {"days": 0, "bestDay": 0, "served": 0, "happy": 0, "earned": 0, "upgrades": []},
		"bus": {"days": 0, "bestDay": 0, "riders": 0, "earned": 0, "upgrades": []},
		"history": [],
		"tara": 0,
		"story": {"seen": []},
		"npcs": {},
		"log": [],
		"daily": {"date": "", "featured": false, "challenge": false},
		"streak": {"count": 0, "last": "", "best": 0},
		"early": [],
		"cosmetics": [],
	}


func load_save() -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema", 0)) != SCHEMA:
		push_error("save: unreadable or old, starting fresh")
		return
	# Keep any field a newer game added to fresh() but the file lacks.
	var base := fresh()
	for k in parsed:
		base[k] = parsed[k]
	data = base


func save() -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("save: cannot write %s" % tmp)
		return
	f.store_string(JSON.stringify(data, " "))
	f.close()
	DirAccess.rename_absolute(tmp, path)


# --- Levels ----------------------------------------------------------------


## XP needed to go from `level` to the next.
func to_next(level: int) -> int:
	return int(b.n("economy.xp_level_base") + b.n("economy.xp_level_step") * level)


func level() -> int:
	return int(data.mohalla.level)


func xp() -> int:
	return int(data.mohalla.xp)


## Unlocked at this mohalla level (tea stall 2, bus 4…), or early with stars?
func unlocked(what: String) -> bool:
	return level() >= int(b.n("unlocks." + what)) or (data.early as Array).has(what)


## The characters that can be played: "rickshaw", "tea", "bus".
func open_characters() -> Array:
	var out := ["rickshaw"]
	if unlocked("tea_stall"):
		out.append("tea")
	if unlocked("bus"):
		out.append("bus")
	return out


## Opens a character before its level for 30 stars.
func unlock_early(what: String) -> bool:
	var cost := int(b.n("unlocks.early_unlock_tara"))
	if unlocked(what) or int(data.tara) < cost:
		return false
	data.tara = int(data.tara) - cost
	data.early.append(what)
	return true


func date() -> String:
	return today if today != "" else Daily.today()


## Today's state, started afresh on a new date.
func daily() -> Dictionary:
	if data.daily.get("date", "") != date():
		data.daily = {"date": date(), "featured": false, "challenge": false}
	return data.daily


func featured() -> String:
	return Daily.featured(date(), open_characters())


func challenge() -> Dictionary:
	return Daily.challenge(date(), open_characters())


# --- Rahim Chacha's rickshaw ----------------------------------------------------


## Upgrades for Rahim Chacha's rickshaw ("rickshaw", the default), Monir
## Mama's stall ("tea") or Babu's bus ("bus"), bought from the shared
## savings.
func has_upgrade(id: String, who := "rickshaw") -> bool:
	return data[who].upgrades.has(id)


## The next upgrade on sale; "" when all are bought.
func next_upgrade(who := "rickshaw") -> String:
	for id in UPGRADE_LISTS[who][1]:
		if not has_upgrade(id, who):
			return id
	return ""


func price(id: String, who := "rickshaw") -> int:
	return int(b.n("%s.upgrades.%s.cost" % [UPGRADE_LISTS[who][0], id]))


func buy(id: String, who := "rickshaw") -> bool:
	if has_upgrade(id, who) or int(data.taka) < price(id, who):
		return false
	data.taka = int(data.taka) - price(id, who)
	data[who].upgrades.append(id)
	return true


## Speed factor from the upgrades bought (the best one counts).
func speed_factor() -> float:
	var best := 1.0
	for id in data.rickshaw.upgrades:
		best = maxf(best, b.n("rickshaw.upgrades.%s.speed" % id))
	return best


## Energy cost factor from the upgrades bought (the battery rickshaw: half).
func energy_factor() -> float:
	var best := 1.0
	for id in data.rickshaw.upgrades:
		var up: Dictionary = b.at("rickshaw.upgrades." + id)
		best = minf(best, float(up.get("energy", 1.0)))
	return best


func school_goal() -> int:
	return int(b.n("rickshaw.school_fee_goal"))


func fund_goal() -> int:
	return int(b.n("fund_projects.%s.cost" % data.fundProject)) if data.fundProject != "" else 0


# --- The end of a day ---------------------------------------------------------


## Takes a day's result ({earned, trips, stars, fines, teas}) into the save and
## says what changed, for the end-of-day screen.
func apply_day(result: Dictionary) -> Dictionary:
	var out := {}
	var earned := _featured("rickshaw", maxi(0, int(result.earned)), out)
	var trips := int(result.trips)
	var stars := float(result.stars)
	var target := int(b.n("rickshaw.daily_target"))
	out.earned = earned
	out.met = earned >= target
	# A tenth to the mohalla's fund, the rest is Rahim Chacha's; whatever
	# is over the day's target is put by for his daughter's school fee.
	var fund_cut := _to_fund(earned, out)
	var keep := earned - fund_cut
	var school := maxi(0, keep - target)
	school = mini(school, maxi(0, school_goal() - int(data.rickshaw.school)))
	data.taka = int(data.taka) + keep - school
	data.rickshaw.school = int(data.rickshaw.school) + school
	out.kept = keep - school
	out.school = school
	_gain_xp(stars, trips > 0, out)
	# The record.
	data.day = int(data.day) + 1
	data.rickshaw.days = int(data.rickshaw.days) + 1
	data.rickshaw.trips = int(data.rickshaw.trips) + trips
	data.rickshaw.earned = int(data.rickshaw.earned) + earned
	# Cups of tea at the stalls: Monir Mama's regulars (§৬), kept for later.
	data.rickshaw.teas = int(data.rickshaw.get("teas", 0)) + int(result.get("teas", 0))
	out.best = earned > int(data.rickshaw.bestDay) and earned > 0
	if out.best:
		data.rickshaw.bestDay = earned
	_day_done("rickshaw", result, out)
	_remember({"day": data.day, "who": "rickshaw", "earned": earned, "trips": trips, "stars": snappedf(stars, 0.1), "met": out.met})
	out.day = data.day
	return out


## Takes a day at Monir Mama's tea stall ({earned, served, happy, lost,
## stars}) into the save: a tenth to the fund, the rest to the savings.
func apply_tea_day(result: Dictionary) -> Dictionary:
	var out := {}
	var earned := _featured("tea", maxi(0, int(result.earned)), out)
	var stars := float(result.stars)
	out.earned = earned
	var fund_cut := _to_fund(earned, out)
	data.taka = int(data.taka) + earned - fund_cut
	out.kept = earned - fund_cut
	_gain_xp(stars, int(result.served) > 0, out)
	data.day = int(data.day) + 1
	var tea: Dictionary = data.tea
	tea.days = int(tea.days) + 1
	tea.served = int(tea.served) + int(result.served)
	tea.happy = int(tea.happy) + int(result.happy)
	tea.earned = int(tea.earned) + earned
	out.best = earned > int(tea.bestDay) and earned > 0
	if out.best:
		tea.bestDay = earned
	_day_done("tea", result, out)
	_remember({"day": data.day, "who": "tea", "earned": earned, "served": int(result.served), "stars": snappedf(stars, 0.1), "met": true})
	out.day = data.day
	return out


## Takes a day on Babu's bus ({earned, riders, stars}) into the save: a
## tenth to the fund, the rest to the savings.
func apply_bus_day(result: Dictionary) -> Dictionary:
	var out := {}
	var earned := _featured("bus", maxi(0, int(result.earned)), out)
	var stars := float(result.stars)
	out.earned = earned
	var fund_cut := _to_fund(earned, out)
	data.taka = int(data.taka) + earned - fund_cut
	out.kept = earned - fund_cut
	_gain_xp(stars, int(result.riders) > 0, out)
	data.day = int(data.day) + 1
	var bus: Dictionary = data.bus
	bus.days = int(bus.days) + 1
	bus.riders = int(bus.riders) + int(result.riders)
	bus.earned = int(bus.earned) + earned
	out.best = earned > int(bus.bestDay) and earned > 0
	if out.best:
		bus.bestDay = earned
	_day_done("bus", result, out)
	_remember({"day": data.day, "who": "bus", "earned": earned, "riders": int(result.riders), "stars": snappedf(stars, 0.1), "met": true})
	out.day = data.day
	return out


## A tenth of the day's money to the mohalla's fund; finishes the project
## when it is full. Returns the cut.
func _to_fund(earned: int, out: Dictionary) -> int:
	var fund_cut := int(roundf(earned * b.n("economy.fund_share")))
	data.fund = int(data.fund) + fund_cut
	out.fund = fund_cut
	out.project = ""
	if data.fundProject != "" and int(data.fund) >= fund_goal():
		data.fund = int(data.fund) - fund_goal()
		data.mohalla.projectsDone.append(data.fundProject)
		out.project = data.fundProject
		var left := PROJECTS.filter(func(p): return not data.mohalla.projectsDone.has(p))
		data.fundProject = left[0] if not left.is_empty() else ""
	return fund_cut


## XP: 50 + 20 per star of the day's rating (half when nothing was done).
func _gain_xp(stars: float, worked: bool, out: Dictionary) -> void:
	var gain := int(b.n("economy.xp_base") + roundf(stars) * b.n("economy.xp_per_rating_star"))
	if not worked:
		gain = int(b.n("economy.xp_base") / 2)
	out.xp = gain
	_add_xp(gain, out)


func _add_xp(gain: int, out: Dictionary) -> void:
	var lvl := level()
	var total := xp() + gain
	var max_level := int(b.n("economy.max_level"))
	while lvl < max_level and total >= to_next(lvl):
		total -= to_next(lvl)
		lvl += 1
	out.level_up = lvl > level()
	data.mohalla.level = lvl
	data.mohalla.xp = total


func _remember(entry: Dictionary) -> void:
	data.history.push_front(entry)
	while data.history.size() > HISTORY:
		data.history.pop_back()


# --- Today's character, the challenge, the run of days (§৭) -----------------


## Doubles the day's money on the first day played as today's character.
func _featured(who: String, earned: int, out: Dictionary) -> int:
	out.featured = false
	var today_state := daily()
	if not today_state.featured and featured() == who:
		today_state.featured = true
		out.featured = true
		return earned * int(b.n("economy.featured_multiplier"))
	return earned


## After any day: the run of days played (stars for it, a special hood on
## the seventh), the challenge (stars if met), the neighbours.
func _day_done(who: String, result: Dictionary, out: Dictionary) -> void:
	var today_state := daily()
	var streak: Dictionary = data.streak
	out.streak_stars = 0
	out.streak_gift = ""
	if streak.last != date():
		streak.count = int(streak.count) + 1 if streak.last == Daily.yesterday(date()) else 1
		streak.last = date()
		streak.best = maxi(int(streak.best), int(streak.count))
		var rewards: Array = b.at("tara.streak")
		var step := (int(streak.count) - 1) % (rewards.size() + 1)
		if step < rewards.size():
			out.streak_stars = int(rewards[step])
			data.tara = int(data.tara) + out.streak_stars
		elif not (data.cosmetics as Array).has("festive_hood"):
			# The seventh day: a festive hood for Rahim Chacha's rickshaw.
			data.cosmetics.append("festive_hood")
			out.streak_gift = "festive_hood"
		else:
			out.streak_stars = int(rewards.back())
			data.tara = int(data.tara) + out.streak_stars
	out.streak = int(streak.count)
	out.challenge = false
	var c := challenge()
	if not today_state.challenge and Daily.met(c, who, result.get("stats", {})):
		today_state.challenge = true
		data.tara = int(data.tara) + int(b.n("tara.daily_challenge"))
		out.challenge = true
	apply_npcs(result.get("npcs", []), who)


# --- The story (§৬.২) ---------------------------------------------------------


func seen(chapter_id: String) -> bool:
	return (data.story.seen as Array).has(chapter_id)


## A chapter read to the end: XP and stars, and what a choice in it did
## ({taka, npc: [id, change]}).
func finish_chapter(chapter_id: String, effects := {}) -> Dictionary:
	var out := {"xp": 0, "tara": 0}
	if seen(chapter_id):
		return out
	data.story.seen.append(chapter_id)
	out.xp = int(b.n("economy.xp_chapter_bonus"))
	_add_xp(out.xp, out)
	out.tara = int(b.n("tara.chapter"))
	data.tara = int(data.tara) + out.tara
	if effects.has("taka"):
		data.taka = int(data.taka) + int(effects.taka)
	if effects.has("npc"):
		apply_npcs([{"id": effects.npc[0], "delta": int(effects.npc[1]), "what": "story"}], "story")
	return out


# --- The neighbours (§৬.১) ----------------------------------------------------


## How someone feels about the mohalla, −5 to 5.
func relation(id: String) -> int:
	return int(data.npcs.get(id, 0))


## Takes what happened with neighbours today ([{id, delta, what}]) into
## their feelings and the mohalla's notebook (the last 30).
func apply_npcs(entries: Array, who: String) -> void:
	for e in entries:
		data.npcs[e.id] = clampi(relation(e.id) + int(e.delta), -5, 5)
		data.log.push_front({"day": int(data.day), "who": who, "id": e.id, "delta": int(e.delta), "what": e.what})
	while data.log.size() > 30:
		data.log.pop_back()
