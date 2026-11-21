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
		"rickshaw": {"days": 0, "school": 0, "bestDay": 0, "trips": 0, "earned": 0, "upgrades": []},
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


func school_goal() -> int:
	return int(b.n("rickshaw.school_fee_goal"))


func fund_goal() -> int:
	return int(b.n("fund_projects.%s.cost" % data.fundProject)) if data.fundProject != "" else 0


# --- The end of a day ---------------------------------------------------------


## Takes a day's result ({earned, trips, stars, fines}) into the save and
## says what changed, for the end-of-day screen.
func apply_day(result: Dictionary) -> Dictionary:
	var earned: int = maxi(0, int(result.earned))
	var trips := int(result.trips)
	var stars := float(result.stars)
	var target := int(b.n("rickshaw.daily_target"))
	var out := {"earned": earned, "met": earned >= target}
	# A tenth to the mohalla's fund, the rest is Rahim Chacha's; whatever
	# is over the day's target is put by for his daughter's school fee.
	var fund_cut := int(roundf(earned * b.n("economy.fund_share")))
	var keep := earned - fund_cut
	var school := maxi(0, keep - target)
	school = mini(school, maxi(0, school_goal() - int(data.rickshaw.school)))
	data.fund = int(data.fund) + fund_cut
	data.taka = int(data.taka) + keep - school
	data.rickshaw.school = int(data.rickshaw.school) + school
	out.fund = fund_cut
	out.kept = keep - school
	out.school = school
	# A finished project.
	out.project = ""
	if data.fundProject != "" and int(data.fund) >= fund_goal():
		data.fund = int(data.fund) - fund_goal()
		data.mohalla.projectsDone.append(data.fundProject)
		out.project = data.fundProject
		var left := PROJECTS.filter(func(p): return not data.mohalla.projectsDone.has(p))
		data.fundProject = left[0] if not left.is_empty() else ""
	# XP: 50 + 20 per star of the day's rating (half when no trips).
	var gain := int(b.n("economy.xp_base") + roundf(stars) * b.n("economy.xp_per_rating_star"))
	if trips == 0:
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
	# The record.
	data.day = int(data.day) + 1
	data.rickshaw.days = int(data.rickshaw.days) + 1
	data.rickshaw.trips = int(data.rickshaw.trips) + trips
	data.rickshaw.earned = int(data.rickshaw.earned) + earned
	out.best = earned > int(data.rickshaw.bestDay) and earned > 0
	if out.best:
		data.rickshaw.bestDay = earned
	data.history.push_front({"day": data.day, "earned": earned, "trips": trips, "stars": snappedf(stars, 0.1), "met": out.met})
	while data.history.size() > HISTORY:
		data.history.pop_back()
	out.day = data.day
	return out
