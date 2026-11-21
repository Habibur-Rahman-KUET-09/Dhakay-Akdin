## What carries over from one day to the next (§৫, §৯.৪): Rahim Chacha's
## savings and his daughter's school fee, the mohalla's community fund and
## its projects, mohalla XP and level, upgrades bought, and a record of the
## last days. Saved to user://save.json after every day, written to a new
## file first and then moved over the old one, so a crash cannot spoil it.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")

const SCHEMA := 1
const DEFAULT_PATH := "user://save.json"
const HISTORY := 10
const PROJECTS := ["street_lights", "drain_cleaning", "bus_shelter"]
const UPGRADES := ["new_rickshaw", "battery_rickshaw"]

var b: Balance
var path := DEFAULT_PATH
var data: Dictionary


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
		"history": [],
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


## Unlocked at this mohalla level? (tea stall 2, bus 4…)
func unlocked(what: String) -> bool:
	return level() >= int(b.n("unlocks." + what))


# --- Rahim Chacha's rickshaw ----------------------------------------------------


func has_upgrade(id: String) -> bool:
	return data.rickshaw.upgrades.has(id)


## The next upgrade on sale and its price; "" when all are bought.
func next_upgrade() -> String:
	for id in UPGRADES:
		if not has_upgrade(id):
			return id
	return ""


func price(id: String) -> int:
	return int(b.n("rickshaw.upgrades.%s.cost" % id))


func buy(id: String) -> bool:
	if has_upgrade(id) or int(data.taka) < price(id):
		return false
	data.taka = int(data.taka) - price(id)
	data.rickshaw.upgrades.append(id)
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
	var earned: int = maxi(0, int(result.earned))
	var trips := int(result.trips)
	var stars := float(result.stars)
	var target := int(b.n("rickshaw.daily_target"))
	var out := {"earned": earned, "met": earned >= target}
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
	_remember({"day": data.day, "who": "rickshaw", "earned": earned, "trips": trips, "stars": snappedf(stars, 0.1), "met": out.met})
	out.day = data.day
	return out


## Takes a day at Monir Mama's tea stall ({earned, served, happy, lost,
## stars}) into the save: a tenth to the fund, the rest to the savings.
func apply_tea_day(result: Dictionary) -> Dictionary:
	var earned: int = maxi(0, int(result.earned))
	var stars := float(result.stars)
	var out := {"earned": earned}
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
	_remember({"day": data.day, "who": "tea", "earned": earned, "served": int(result.served), "stars": snappedf(stars, 0.1), "met": true})
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
