## The weekly tournament: a ladder of ranks that every day played climbs,
## whatever the character. A day's XP is its points; the week's points
## give the rank (নতুন, পাকা খেলোয়াড়, ওস্তাদ, রাজা, কিংবদন্তি, from
## balance "ranked.ranks"). Each week starts again from নতুন; when a new
## week begins, last week's rank pays its stars, once. It sits beside the
## area league (league.gd), which is Mirpur against Old Dhaka. On the
## phone only, no drawing: testable.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")
const Friends = preload("res://scripts/rules/friends.gd")
const Daily = preload("res://scripts/rules/daily.gd")


static func fresh() -> Dictionary:
	return {"week": "", "points": 0, "prev_week": "", "prev_points": 0, "paid": [], "best": 0}


## The save's tournament part, filled in place.
static func of(data: Dictionary) -> Dictionary:
	var have = data.get("ranked", null)
	if typeof(have) != TYPE_DICTIONARY:
		have = {}
		data["ranked"] = have
	var base := fresh()
	for k in base:
		if not have.has(k):
			have[k] = base[k]
	return have


static func _roll(r: Dictionary, date: String) -> void:
	var w := Friends.week_of(date)
	if str(r.week) == w:
		return
	if str(r.week) == Friends.last_week(date):
		r.prev_week = r.week
		r.prev_points = r.points
	else:
		r.prev_week = Friends.last_week(date)
		r.prev_points = 0
	r.week = w
	r.points = 0


static func ranks(b: Balance) -> Array:
	return b.at("ranked.ranks")


## The rank (an index into ranks) that `points` reach.
static func rank_of(b: Balance, points: int) -> int:
	var all := ranks(b)
	var at := 0
	for i in all.size():
		if points >= int(all[i].points):
			at = i
	return at


static func rank_id(b: Balance, i: int) -> String:
	return str(ranks(b)[clampi(i, 0, ranks(b).size() - 1)].id)


## Points still wanted for the next rank, or -1 at the top.
static func to_next(b: Balance, points: int) -> int:
	var i := rank_of(b, points)
	if i + 1 >= ranks(b).size():
		return -1
	return int(ranks(b)[i + 1].points) - points


## This week's points.
static func points(data: Dictionary, date: String) -> int:
	var r := of(data)
	_roll(r, date)
	return int(r.points)


## A day played: its XP as points. Returns {gained, points, rank, up}.
static func note(data: Dictionary, b: Balance, xp: int, date: String) -> Dictionary:
	var r := of(data)
	_roll(r, date)
	var before := rank_of(b, int(r.points))
	r.points = int(r.points) + maxi(0, xp)
	var now := rank_of(b, int(r.points))
	r.best = maxi(int(r.best), now)
	return {"gained": maxi(0, xp), "points": int(r.points), "rank": now, "up": now > before}


## Last week's prize, once a new week has begun: {week, rank, tara}, or
## {} if there is none (or it was paid already).
static func claim(data: Dictionary, b: Balance, date: String) -> Dictionary:
	var r := of(data)
	_roll(r, date)
	var week := str(r.prev_week)
	if week == "" or int(r.prev_points) <= 0 or (r.paid as Array).has(week):
		return {}
	r.paid.append(week)
	while r.paid.size() > 12:
		r.paid.pop_front()
	var i := rank_of(b, int(r.prev_points))
	var stars := int(ranks(b)[i].tara)
	data.tara = int(data.get("tara", 0)) + stars
	return {"week": week, "rank": i, "tara": stars}


## Days left in this week, today counted (7 on the first day, 1 on the last).
static func days_left(date: String) -> int:
	return 7 - posmod(Daily.day_number(date) - 2, 7)
