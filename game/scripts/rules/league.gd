## The weekly area league (phase 7): Mirpur against Old Dhaka. Every
## rickshaw trip counts for the area it was ridden in. Each player's
## public card carries their trips this week and last, per area
## (lg_<week>_<area>); the area whose players made more trips on average
## wins the week (an average, so the smaller area is not outnumbered).
## The winners' streets are decked out the next week, and everyone who
## rode there that week gets stars. No drawing, no network: testable.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")
const Friends = preload("res://scripts/rules/friends.gd")

const AREAS := ["mirpur", "old_dhaka"]


static func fresh() -> Dictionary:
	return {
		# This week's trips by area, and last week's.
		"week": "", "trips": {}, "prev_week": "", "prev": {},
		# The weeks whose prize was looked at; the last winner known:
		# {week, area}.
		"claimed": [], "winner": {},
	}


## The save's league part, filled in place.
static func of(data: Dictionary) -> Dictionary:
	var have = data.get("league", null)
	if typeof(have) != TYPE_DICTIONARY:
		have = {}
		data["league"] = have
	var base := fresh()
	for k in base:
		if not have.has(k):
			have[k] = base[k]
	return have


static func field(area: String, week: String) -> String:
	return "lg_%s_%s" % [week, area]


static func _roll(l: Dictionary, date: String) -> void:
	var w := Friends.week_of(date)
	if str(l.week) == w:
		return
	if str(l.week) == Friends.last_week(date):
		l.prev_week = l.week
		l.prev = l.trips
	else:
		l.prev_week = Friends.last_week(date)
		l.prev = {}
	l.week = w
	l.trips = {}


## A rickshaw day's trips, for the area ridden in.
static func note(data: Dictionary, area: String, trips: int, date: String) -> void:
	if not AREAS.has(area) or trips <= 0:
		return
	var l := of(data)
	_roll(l, date)
	l.trips[area] = int(l.trips.get(area, 0)) + trips


## The numbers for the public card: this week's and last week's.
static func fields(data: Dictionary, date: String) -> Dictionary:
	var l := of(data)
	_roll(l, date)
	var out := {}
	for a in AREAS:
		if int(l.trips.get(a, 0)) > 0:
			out[field(a, str(l.week))] = int(l.trips[a])
		if int(l.prev.get(a, 0)) > 0:
			out[field(a, str(l.prev_week))] = int(l.prev[a])
	return out


static func mine(data: Dictionary, area: String, date: String) -> int:
	var l := of(data)
	_roll(l, date)
	return int(l.trips.get(area, 0))


## The average trips of a side ({count, sum} from the server).
static func average(stats: Dictionary) -> float:
	var n := int(stats.get("count", 0))
	return float(stats.get("sum", 0)) / n if n > 0 else 0.0


## Who won, from each area's {count, sum}: the higher average, if each
## side had enough players (else nobody: "").
static func winner(b: Balance, by_area: Dictionary) -> String:
	var best := ""
	var best_avg := -1.0
	var tie := false
	for a in AREAS:
		var st: Dictionary = by_area.get(a, {})
		if int(st.get("count", 0)) < int(b.n("league.min_players")):
			return ""
		var avg := average(st)
		if avg > best_avg:
			best = a
			best_avg = avg
			tie = false
		elif is_equal_approx(avg, best_avg):
			tie = true
	return "" if tie else best


## Last week's result seen: remembered for the decorations, and stars if
## I rode in the winning area that week (once a week). Returns the stars.
static func settle(data: Dictionary, b: Balance, date: String, area: String) -> int:
	var l := of(data)
	_roll(l, date)
	var week := Friends.last_week(date)
	if area != "":
		l.winner = {"week": week, "area": area}
	if (l.claimed as Array).has(week):
		return 0
	l.claimed.append(week)
	while l.claimed.size() > 12:
		l.claimed.pop_front()
	if area == "" or str(l.prev_week) != week or int(l.prev.get(area, 0)) <= 0:
		return 0
	var stars := int(b.n("league.win_tara"))
	data.tara = int(data.get("tara", 0)) + stars
	return stars


## Whether an area's streets are decked out this week (it won last week).
static func decked(data: Dictionary, area: String, date: String) -> bool:
	var w: Dictionary = of(data).winner
	return str(w.get("week", "")) == Friends.last_week(date) and str(w.get("area", "")) == area
