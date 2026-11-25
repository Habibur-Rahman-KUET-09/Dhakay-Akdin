## Leaderboards for everyone playing online: today, this week, this month
## and all time, for each character's earnings and for all three together.
## Each player's public card (profiles/<account>, with the friends' card)
## carries their numbers as plain fields named for the period, such as
## lb_d20261125_rickshaw, lb_w2918_all, lb_m202611_tea, lb_ever_bus; a list
## is then just the cards ordered by one field. The last period's numbers
## stay on the card too, so the top three can be found after a day, week
## or month is over and given their stars (each player claims their own).
## No drawing, no network, so it can be tested.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")
const Daily = preload("res://scripts/rules/daily.gd")
const Friends = preload("res://scripts/rules/friends.gd")

const WHO := ["all", "rickshaw", "tea", "bus", "fuchka"]
const PERIODS := ["day", "week", "month", "ever"]
## The periods that end, and so have prizes.
const ENDING := ["day", "week", "month"]


static func fresh() -> Dictionary:
	return {
		# Each period's id now and its numbers by character ("all" too);
		# the period before and its numbers.
		"ids": {}, "now": {}, "before_ids": {}, "before": {},
		"ever": {},
		# Prizes looked at already (a period's field), won or not.
		"checked": [],
	}


## The save's leaderboard part, filled in place.
static func of(data: Dictionary) -> Dictionary:
	var have = data.get("board", null)
	if typeof(have) != TYPE_DICTIONARY:
		have = {}
		data["board"] = have
	var base := fresh()
	for k in base:
		if not have.has(k):
			have[k] = base[k]
	return have


# --- Periods ---------------------------------------------------------------------


static func period_id(period: String, date: String) -> String:
	match period:
		"day":
			return "d" + date.replace("-", "")
		"week":
			return Friends.week_of(date)
		"month":
			return "m" + date.substr(0, 7).replace("-", "")
	return "ever"


## The id of the period just before the one `date` is in.
static func before_id(period: String, date: String) -> String:
	match period:
		"day":
			return period_id("day", Daily.yesterday(date))
		"week":
			return Friends.last_week(date)
		"month":
			var y := int(date.substr(0, 4))
			var m := int(date.substr(5, 2)) - 1
			if m == 0:
				m = 12
				y -= 1
			return "m%04d%02d" % [y, m]
	return "ever"


## The card's field for a period's list ("lb_d20261125_rickshaw").
static func field(period: String, who: String, date: String) -> String:
	return "lb_%s_%s" % [period_id(period, date), who]


static func before_field(period: String, who: String, date: String) -> String:
	return "lb_%s_%s" % [before_id(period, date), who]


static func _roll(lb: Dictionary, date: String) -> void:
	for p in ENDING:
		var id := period_id(p, date)
		if str(lb.ids.get(p, "")) == id:
			continue
		# A new period: the one just over becomes "before" (if it is the
		# one right before; otherwise nothing was played in it).
		if str(lb.ids.get(p, "")) == before_id(p, date):
			lb.before_ids[p] = lb.ids[p]
			lb.before[p] = lb.now.get(p, {})
		else:
			lb.before_ids[p] = before_id(p, date)
			lb.before[p] = {}
		lb.ids[p] = id
		lb.now[p] = {}


## A day played: its money into today, this week, this month and all
## time, for the character and for all together.
static func note(data: Dictionary, who: String, earned: int, date: String) -> void:
	var lb := of(data)
	_roll(lb, date)
	var add := maxi(0, earned)
	for p in ENDING:
		var n: Dictionary = lb.now[p]
		for w in [who, "all"]:
			n[w] = int(n.get(w, 0)) + add
	for w in [who, "all"]:
		lb.ever[w] = int(lb.ever.get(w, 0)) + add


## The numbers for the card: this period's and the last one's, all time.
static func fields(data: Dictionary, date: String) -> Dictionary:
	var lb := of(data)
	_roll(lb, date)
	var out := {}
	for p in ENDING:
		for w in WHO:
			var now := int((lb.now.get(p, {}) as Dictionary).get(w, 0))
			if now > 0:
				out["lb_%s_%s" % [lb.ids[p], w]] = now
			var before := int((lb.before.get(p, {}) as Dictionary).get(w, 0))
			if before > 0:
				out["lb_%s_%s" % [lb.before_ids[p], w]] = before
	for w in WHO:
		if int(lb.ever.get(w, 0)) > 0:
			out["lb_ever_" + w] = int(lb.ever[w])
	return out


## The whole public card: the friends' part and these numbers.
static func card(data: Dictionary, date: String) -> Dictionary:
	var c := Friends.card(data, date)
	c.merge(fields(data, date))
	return c


## My own number in a list.
static func mine(data: Dictionary, period: String, who: String, date: String) -> int:
	if period == "ever":
		return int(of(data).ever.get(who, 0))
	return int(fields(data, date).get(field(period, who, date), 0))


# --- Prizes for the top three ----------------------------------------------------------


static func prize(b: Balance, period: String, rank: int) -> int:
	var list: Array = b.at("leaderboard.prizes." + period)
	return int(list[rank - 1]) if rank >= 1 and rank <= list.size() else 0


## The lists just over in which I had something, not yet looked at:
## [{period, who, field}].
static func to_check(data: Dictionary, date: String) -> Array:
	var lb := of(data)
	_roll(lb, date)
	var out := []
	for p in ENDING:
		for w in WHO:
			var f := "lb_%s_%s" % [lb.before_ids[p], w]
			if int((lb.before.get(p, {}) as Dictionary).get(w, 0)) > 0 and not (lb.checked as Array).has(f):
				out.append({"period": p, "who": w, "field": f})
	return out


## Looked at a finished list, where I came `rank` (0: not in the top
## three): stars for a place in the top three, once. Returns the stars.
static func settle(data: Dictionary, b: Balance, check: Dictionary, rank: int) -> int:
	var lb := of(data)
	if (lb.checked as Array).has(check.field):
		return 0
	lb.checked.append(check.field)
	while lb.checked.size() > 60:
		lb.checked.pop_front()
	var stars := prize(b, str(check.period), rank)
	data.tara = int(data.get("tara", 0)) + stars
	return stars


## The name shown in a list: what they chose, or "Player" and a few
## letters of their account.
static func shown_name(name: String, uid: String, anon: String) -> String:
	var n := Friends.clean_name(name)
	return n if n != "" else "%s %s" % [anon, uid.substr(0, 4).to_upper()]
