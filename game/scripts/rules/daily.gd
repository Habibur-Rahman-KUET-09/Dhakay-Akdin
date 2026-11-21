## The day's structure (§৭), worked out from the date alone so no server
## is needed: today's character (double money on the first day played as
## them), today's challenge (stars for meeting it), and the reward for
## playing day after day. Dates are "YYYY-MM-DD". No drawing here, so it
## can be tested.
extends RefCounted

## The characters in the order they open.
const ORDER := ["rickshaw", "tea", "bus"]

## Challenges: whose day, which number of the day's stats, the goal.
const CHALLENGES := [
	{"id": "r_good", "who": "rickshaw", "stat": "good_trips", "goal": 4},
	{"id": "r_clean", "who": "rickshaw", "stat": "clean", "goal": 1},
	{"id": "r_money", "who": "rickshaw", "stat": "earned", "goal": 800},
	{"id": "t_happy", "who": "tea", "stat": "happy", "goal": 12},
	{"id": "t_none_lost", "who": "tea", "stat": "none_lost", "goal": 1},
	{"id": "t_milk", "who": "tea", "stat": "milk_tea", "goal": 15},
	{"id": "b_no_slip", "who": "bus", "stat": "no_slip", "goal": 1},
	{"id": "b_on_time", "who": "bus", "stat": "on_time", "goal": 2},
	{"id": "b_riders", "who": "bus", "stat": "riders", "goal": 40},
]


## Days since 1 January 1970.
static func day_number(date: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(date + "T00:00:00") / 86400)


static func yesterday(date: String) -> String:
	return Time.get_date_string_from_unix_time((day_number(date) - 1) * 86400)


static func today() -> String:
	return Time.get_date_string_from_system()


## Today's character, among those open.
static func featured(date: String, open: Array) -> String:
	var list := ORDER.filter(func(w): return open.has(w))
	if list.is_empty():
		return "rickshaw"
	return list[day_number(date) % list.size()]


## Today's challenge, among those for open characters.
static func challenge(date: String, open: Array) -> Dictionary:
	var list := CHALLENGES.filter(func(c): return open.has(c.who))
	if list.is_empty():
		return {}
	return list[(day_number(date) * 7 + 3) % list.size()]


## Whether a day as `who`, with these stats, meets the challenge.
static func met(c: Dictionary, who: String, stats: Dictionary) -> bool:
	return not c.is_empty() and c.who == who and int(stats.get(c.stat, 0)) >= int(c.goal)
