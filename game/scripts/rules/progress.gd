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
const Goods = preload("res://scripts/rules/goods.gd")
const Friends = preload("res://scripts/rules/friends.gd")
const Leaderboard = preload("res://scripts/rules/leaderboard.gd")
const League = preload("res://scripts/rules/league.gd")
const Ranked = preload("res://scripts/rules/ranked.gd")

const SCHEMA := 1
const DEFAULT_PATH := "user://save.json"
const HISTORY := 10
const PROJECTS := ["street_lights", "drain_cleaning", "bus_shelter"]
const UPGRADES := ["new_rickshaw", "battery_rickshaw"]
## The stall grows in this order (§৪.৩); the move to a shop comes with the story.
const TEA_UPGRADES := ["bench", "second_kettle", "awning", "fridge"]
const BUS_UPGRADES := ["notebook", "change_bag", "loud_voice"]
## Julekha Khala's cart: a stool for waiting, an umbrella against the rain,
## a pot of doi for doi fuchka.
const FUCHKA_UPGRADES := ["stool", "umbrella", "doi"]
## Ratul's bicycle (phase 8): gears, an insulated food bag, a raincoat.
const DELIVERY_UPGRADES := ["gear_cycle", "hot_bag", "raincoat"]
## Kashem Bhai's basket (phase 8): a bigger one, masala peanuts, a cooler box
## for water.
const HAWKER_UPGRADES := ["big_basket", "masala", "cooler"]
## Haripada's boat (phase 8): new oars, a chhoi (roof), a bigger boat.
const BOAT_UPGRADES := ["new_oars", "chhoi", "big_boat"]
## Each character's upgrades, and where their prices are in the balance.
const UPGRADE_LISTS := {"rickshaw": ["rickshaw", UPGRADES], "tea": ["tea_stall", TEA_UPGRADES], "bus": ["bus", BUS_UPGRADES], "fuchka": ["fuchka", FUCHKA_UPGRADES], "delivery": ["delivery", DELIVERY_UPGRADES], "hawker": ["hawker", HAWKER_UPGRADES], "boat": ["boat", BOAT_UPGRADES]}

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
		"fuchka": {"days": 0, "bestDay": 0, "served": 0, "exact": 0, "earned": 0, "upgrades": []},
		"delivery": {"days": 0, "bestDay": 0, "orders": 0, "earned": 0, "upgrades": []},
		"hawker": {"days": 0, "bestDay": 0, "sold": 0, "earned": 0, "upgrades": []},
		"boat": {"days": 0, "bestDay": 0, "carried": 0, "earned": 0, "upgrades": []},
		"history": [],
		"tara": 0,
		"story": {"seen": []},
		"npcs": {},
		"log": [],
		"daily": {"date": "", "featured": false, "challenge": false},
		"streak": {"count": 0, "last": "", "best": 0},
		"early": [],
		"cosmetics": [],
		# Where Rahim Chacha rides: "mirpur", or "old_dhaka" once open.
		"area": "mirpur",
		# How each one's family feels about them, 0–10 (calls from home).
		"family": {"rickshaw": 5, "tea": 5, "bus": 5, "fuchka": 5, "delivery": 5, "hawker": 5, "boat": 5},
		# Looks worn (bought ones are in "cosmetics"), by slot; things for
		# Rahim Chacha's home; his own phone; the savings club.
		"looks": {"rickshaw": {}, "tea": {}, "bus": {}, "fuchka": {}, "delivery": {}, "hawker": {}, "boat": {}},
		"home": [],
		"phone": false,
		"samity": {"in": false, "paid": 0, "rounds": 0},
		# Playing with friends (friends.gd): the code, the list, gifts…
		"friends": Friends.fresh(),
		# The leaderboards' numbers (leaderboard.gd); boosts bought with
		# stars for the next day.
		"board": Leaderboard.fresh(),
		"boosts": {},
		# Monir Mama's credit book (tea_day.gd): who owes what.
		"ledger": [],
		# The weekly area league (league.gd).
		"league": League.fresh(),
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


# --- Looks, the home, the phone, the samity (goods.gd) -----------------------


func owns_look(id: String) -> bool:
	return (data.cosmetics as Array).has(id)


## Buys a look for `who` and wears it. False if already owned, unknown or
## not affordable.
func buy_look(who: String, id: String) -> bool:
	var l := Goods.look(who, id)
	if l.is_empty() or bool(l.get("prize", false)) or owns_look(id):
		return false
	# Some are bought with stars instead of money.
	if l.has("tara"):
		if int(data.tara) < int(l.tara):
			return false
		data.tara = int(data.tara) - int(l.tara)
	elif int(data.taka) < int(l.get("price", 0)):
		return false
	else:
		data.taka = int(data.taka) - int(l.price)
	data.cosmetics.append(id)
	wear_look(who, id)
	return true


## Wears an owned look in its slot (taking off what was there); wearing the
## one already worn takes it off.
func wear_look(who: String, id: String) -> bool:
	var l := Goods.look(who, id)
	if l.is_empty() or not owns_look(id):
		return false
	var on: Dictionary = data.looks.get(who, {})
	if on.get(l.slot, "") == id:
		on.erase(l.slot)
	else:
		on[l.slot] = id
	data.looks[who] = on
	return true


## The look worn in a slot, or {}.
func worn(who: String, slot: String) -> Dictionary:
	var id: String = (data.looks.get(who, {}) as Dictionary).get(slot, "")
	return Goods.look(who, id) if id != "" else {}


## A boost bought with stars for `who`'s next day (one waiting at a
## time). False if one is waiting already or the stars are short.
func buy_boost(id: String) -> bool:
	var x := Goods.boost(id)
	if x.is_empty() or has_boost(str(x.who)) or int(data.tara) < int(x.tara):
		return false
	data.tara = int(data.tara) - int(x.tara)
	if not data.has("boosts"):
		data["boosts"] = {}
	data.boosts[str(x.who)] = id
	return true


func has_boost(who: String) -> bool:
	return str((data.get("boosts", {}) as Dictionary).get(who, "")) != ""


## The boost waiting for `who`'s day, used up now ({} if none).
func take_boost(who: String) -> Dictionary:
	if not has_boost(who):
		return {}
	var x := Goods.boost(str(data.boosts[who]))
	data.boosts.erase(who)
	return x


func has_home(id: String) -> bool:
	return (data.home as Array).has(id)


## Buys a thing for the home: the family is glad.
func buy_home(id: String) -> bool:
	var h := Goods.home_item(id)
	if h.is_empty() or has_home(id) or int(data.taka) < int(h.price):
		return false
	data.taka = int(data.taka) - int(h.price)
	data.home.append(id)
	add_family("rickshaw", int(h.get("family", 0)))
	return true


## Extra energy at the start of Rahim Chacha's day from resting better.
func home_energy() -> float:
	var extra := 0.0
	for id in data.home:
		extra += float(Goods.home_item(id).get("energy", 0))
	return extra


func has_phone() -> bool:
	return bool(data.get("phone", false))


func buy_phone() -> bool:
	var cost := int(Goods.phone().get("price", 0))
	if has_phone() or int(data.taka) < cost:
		return false
	data.taka = int(data.taka) - cost
	data.phone = true
	return true


## Joins the samity (or leaves it, taking back what was paid in, without
## the bonus).
func set_samity(join: bool) -> void:
	var sm: Dictionary = data.samity
	if not join and bool(sm.get("in", false)):
		data.taka = int(data.taka) + int(sm.get("paid", 0))
		sm.paid = 0
	sm["in"] = join
	data.samity = sm


## At the end of a day: the day's deposit, if the savings allow; after the
## last deposit of a round, everything paid in comes back with the bonus.
## Fills out.samity_paid (deposited) and out.samity_payout (paid back).
func _samity_day(out: Dictionary) -> void:
	var sm: Dictionary = data.samity
	if not bool(sm.get("in", false)):
		return
	var rules := Goods.samity()
	var per_day := int(rules.get("daily", 30))
	if int(data.taka) < per_day:
		return
	data.taka = int(data.taka) - per_day
	sm.paid = int(sm.get("paid", 0)) + per_day
	out.samity_paid = per_day
	if int(sm.paid) >= per_day * int(rules.get("rounds", 10)):
		var back := int(sm.paid) + int(rules.get("bonus", 0))
		data.taka = int(data.taka) + back
		sm.paid = 0
		sm.rounds = int(sm.get("rounds", 0)) + 1
		out.samity_payout = back


## A family scene now due (story.json's scenes): once, when a family's
## feeling reaches 8 ("family_high_<who>") or falls to 2 ("family_low_<who>").
## "" if none.
func family_scene_due() -> String:
	var shown: Array = data.story.get("scenes", [])
	for who in open_characters():
		var f := family(who)
		var id: String = "family_high_" + who if f >= 8 else ("family_low_" + who if f <= 2 else "")
		if id != "" and not shown.has(id):
			return id
	return ""


func scene_shown(id: String) -> void:
	if not data.story.has("scenes"):
		data.story["scenes"] = []
	if not (data.story.scenes as Array).has(id):
		data.story.scenes.append(id)


## How `who`'s family feels, 0–10.
func family(who: String) -> int:
	return int((data.get("family", {}) as Dictionary).get(who, 5))


## Moves `who`'s family feeling by `delta`, kept within 0–10.
func add_family(who: String, delta: int) -> int:
	if not data.has("family"):
		data.family = {"rickshaw": 5, "tea": 5, "bus": 5, "fuchka": 5, "delivery": 5, "hawker": 5, "boat": 5}
	data.family[who] = clampi(family(who) + delta, 0, 10)
	return int(data.family[who])


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


## The characters that can be played: "rickshaw", "tea", "bus", "fuchka",
## "delivery", "hawker", "boat".
func open_characters() -> Array:
	var out := ["rickshaw"]
	if unlocked("tea_stall"):
		out.append("tea")
	if unlocked("bus"):
		out.append("bus")
	if unlocked("fuchka"):
		out.append("fuchka")
	if unlocked("delivery"):
		out.append("delivery")
	if unlocked("hawker"):
		out.append("hawker")
	if unlocked("boat"):
		out.append("boat")
	return out


## Opens a character before its level for 30 stars.
func unlock_early(what: String) -> bool:
	var cost := int(b.n("unlocks.early_unlock_tara"))
	if unlocked(what) or int(data.tara) < cost:
		return false
	data.tara = int(data.tara) - cost
	data.early.append(what)
	return true


## The rickshaw's areas: Mirpur always, Old Dhaka from its level.
const AREAS := ["mirpur", "old_dhaka"]


## Where today's ride is: the area chosen, if it is open.
func rickshaw_area() -> String:
	var a := str(data.area)
	if a == "old_dhaka" and not unlocked("old_dhaka"):
		return "mirpur"
	return a if AREAS.has(a) else "mirpur"


## Chooses where to ride; false if that area is not open yet.
func choose_area(a: String) -> bool:
	if not AREAS.has(a) or (a == "old_dhaka" and not unlocked("old_dhaka")):
		return false
	data.area = a
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
	# For the area league, and customers taken to friends' stalls.
	League.note(data, rickshaw_area(), trips, date())
	Friends.note_visits(data, result.get("visits", {}))
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
	# A friend's good noon on the rickshaw brought riders to the stop.
	out.relay_bonus = Friends.relay_bonus(data, b, "bus", earned, date())
	earned += int(out.relay_bonus)
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


## Takes a day at Julekha Khala's cart ({earned, served, happy, exact,
## lost, stars}) into the save: a tenth to the fund, the rest saved.
func apply_fuchka_day(result: Dictionary) -> Dictionary:
	var out := {}
	var earned := _featured("fuchka", maxi(0, int(result.earned)), out)
	var stars := float(result.stars)
	out.earned = earned
	var fund_cut := _to_fund(earned, out)
	data.taka = int(data.taka) + earned - fund_cut
	out.kept = earned - fund_cut
	_gain_xp(stars, int(result.served) > 0, out)
	data.day = int(data.day) + 1
	if not data.has("fuchka"):
		data["fuchka"] = {"days": 0, "bestDay": 0, "served": 0, "exact": 0, "earned": 0, "upgrades": []}
	var f: Dictionary = data.fuchka
	f.days = int(f.days) + 1
	f.served = int(f.served) + int(result.served)
	f.exact = int(f.get("exact", 0)) + int(result.get("exact", 0))
	f.earned = int(f.earned) + earned
	out.best = earned > int(f.bestDay) and earned > 0
	if out.best:
		f.bestDay = earned
	_day_done("fuchka", result, out)
	_remember({"day": data.day, "who": "fuchka", "earned": earned, "served": int(result.served), "stars": snappedf(stars, 0.1), "met": true})
	out.day = data.day
	return out


## Takes an evening of Ratul's deliveries ({earned, orders, stars, cold})
## into the save: a tenth to the fund, the rest saved.
func apply_delivery_day(result: Dictionary) -> Dictionary:
	var out := {}
	var earned := _featured("delivery", maxi(0, int(result.earned)), out)
	var stars := float(result.stars)
	out.earned = earned
	var fund_cut := _to_fund(earned, out)
	data.taka = int(data.taka) + earned - fund_cut
	out.kept = earned - fund_cut
	_gain_xp(stars, int(result.orders) > 0, out)
	data.day = int(data.day) + 1
	if typeof(data.get("delivery")) != TYPE_DICTIONARY:
		data["delivery"] = {"days": 0, "bestDay": 0, "orders": 0, "earned": 0, "upgrades": []}
	var r: Dictionary = data.delivery
	r.days = int(r.days) + 1
	r.orders = int(r.get("orders", 0)) + int(result.orders)
	r.earned = int(r.earned) + earned
	out.best = earned > int(r.bestDay) and earned > 0
	if out.best:
		r.bestDay = earned
	_day_done("delivery", result, out)
	_remember({"day": data.day, "who": "delivery", "earned": earned, "orders": int(result.orders), "stars": snappedf(stars, 0.1), "met": true})
	out.day = data.day
	return out


## Takes a day of Kashem Bhai's on the buses ({earned, sold, stars}) into
## the save: a tenth to the fund, the rest saved.
func apply_hawker_day(result: Dictionary) -> Dictionary:
	var out := {}
	var earned := _featured("hawker", maxi(0, int(result.earned)), out)
	var stars := float(result.stars)
	out.earned = earned
	var fund_cut := _to_fund(earned, out)
	data.taka = int(data.taka) + earned - fund_cut
	out.kept = earned - fund_cut
	_gain_xp(stars, int(result.sold) > 0, out)
	data.day = int(data.day) + 1
	if typeof(data.get("hawker")) != TYPE_DICTIONARY:
		data["hawker"] = {"days": 0, "bestDay": 0, "sold": 0, "earned": 0, "upgrades": []}
	var r: Dictionary = data.hawker
	r.days = int(r.days) + 1
	r.sold = int(r.get("sold", 0)) + int(result.sold)
	r.earned = int(r.earned) + earned
	out.best = earned > int(r.bestDay) and earned > 0
	if out.best:
		r.bestDay = earned
	_day_done("hawker", result, out)
	_remember({"day": data.day, "who": "hawker", "earned": earned, "sold": int(result.sold), "stars": snappedf(stars, 0.1), "met": true})
	out.day = data.day
	return out


## Takes a day of Haripada's crossings ({earned, carried, stars}) into the
## save: a tenth to the fund, the rest saved.
func apply_boat_day(result: Dictionary) -> Dictionary:
	var out := {}
	var earned := _featured("boat", maxi(0, int(result.earned)), out)
	var stars := float(result.stars)
	out.earned = earned
	var fund_cut := _to_fund(earned, out)
	data.taka = int(data.taka) + earned - fund_cut
	out.kept = earned - fund_cut
	_gain_xp(stars, int(result.carried) > 0, out)
	data.day = int(data.day) + 1
	if typeof(data.get("boat")) != TYPE_DICTIONARY:
		data["boat"] = {"days": 0, "bestDay": 0, "carried": 0, "earned": 0, "upgrades": []}
	var r: Dictionary = data.boat
	r.days = int(r.days) + 1
	r.carried = int(r.get("carried", 0)) + int(result.carried)
	r.earned = int(r.earned) + earned
	out.best = earned > int(r.bestDay) and earned > 0
	if out.best:
		r.bestDay = earned
	_day_done("boat", result, out)
	_remember({"day": data.day, "who": "boat", "earned": earned, "carried": int(result.carried), "stars": snappedf(stars, 0.1), "met": true})
	out.day = data.day
	return out


## A tenth of the day's money to the mohalla's fund; finishes the project
## when it is full. Returns the cut.
func _to_fund(earned: int, out: Dictionary) -> int:
	var fund_cut := int(roundf(earned * b.n("economy.fund_share")))
	data.fund = int(data.fund) + fund_cut
	Friends.note_given(data, fund_cut)
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
	_samity_day(out)
	_story_effect_day(who)
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
	# This week's earnings and today's relay leg, for friends to see.
	Friends.note_day(data, who, int(out.get("earned", 0)), float(result.get("stars", 0.0)), date())
	Leaderboard.note(data, who, int(out.get("earned", 0)), date())
	# The weekly tournament: the day's XP as points.
	var rk := Ranked.note(data, b, int(out.get("xp", 0)), date())
	out.rank_points = int(rk.gained)
	out.rank = int(rk.rank)
	out.rank_up = bool(rk.up)
	out.rank_id = Ranked.rank_id(b, int(rk.rank))
	out.relay_done = Friends.claim_relay(data, b, date())


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
		# A story cost never takes the savings below nothing.
		data.taka = maxi(0, int(data.taka) + int(effects.taka))
	if effects.has("npc"):
		apply_npcs([{"id": effects.npc[0], "delta": int(effects.npc[1]), "what": "story"}], "story")
	if effects.has("family"):
		add_family(str(effects.family[0]), int(effects.family[1]))
	if effects.has("after") and typeof(effects.after) == TYPE_DICTIONARY and str(effects.after.get("who", "")) != "":
		var a: Dictionary = (effects.after as Dictionary).duplicate()
		a["left"] = int(a.get("days", 1))
		if not data.has("after"):
			data["after"] = {}
		data.after[str(a.who)] = a
	return out


## What a chapter still changes in `who`'s days ({speed, day_share,
## target, arrivals, note, left}), or {}.
func story_effect(who: String) -> Dictionary:
	var a = (data.get("after", {}) as Dictionary).get(who, {})
	return a if typeof(a) == TYPE_DICTIONARY and int(a.get("left", 0)) > 0 else {}


func _story_effect_day(who: String) -> void:
	var a := story_effect(who)
	if a.is_empty():
		return
	a.left = int(a.left) - 1
	if int(a.left) <= 0:
		data.after.erase(who)


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
