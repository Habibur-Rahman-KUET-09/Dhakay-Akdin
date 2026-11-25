## Playing at the same time on several phones (phase 8): a room, opened by
## one player (the host) under a six-letter code that friends type in, up
## to three in all. Two kinds: a story from together.json, each player
## playing their own characters' turns on their own phone (the others wait
## and see how it went); or a live rickshaw race, everyone riding the same
## route at once with the others' rickshaws alongside. Each phone writes
## only its own part (rooms/<code>/moves/<uid>: a name, step scores, the
## ride so far) and reads the others' every second or two. Stars for a
## live race: one for finishing, more for winning, a few races a day.
## No network here: the rules of who plays what, and the race's places.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")

const KINDS := ["story", "race"]
## A together story's cast id to its place in the cast (who plays them).
const SEAT_OF := {"rahim": 0, "monir": 1, "babu": 2}
const CAST_IDS := ["rahim", "monir", "babu"]

## Set by the lobby just before the story or the race opens: {code, kind,
## host, players (uids, host first), me (my uid), names {uid: name},
## story, area, seed}. {} when not online.
static var room := {}


static func fresh() -> Dictionary:
	# Live races paid today.
	return {"date": "", "paid": 0, "won": 0}


static func of(data: Dictionary) -> Dictionary:
	var have = data.get("online", null)
	if typeof(have) != TYPE_DICTIONARY:
		have = {}
		data["online"] = have
	var base := fresh()
	for k in base:
		if not have.has(k):
			have[k] = base[k]
	return have


static func active() -> bool:
	return not room.is_empty()


static func is_host(r: Dictionary) -> bool:
	return str(r.get("host", "")) == str(r.get("me", "-"))


## Who plays a story character: with three players one each (the host is
## Rahim Chacha); with two the host also plays Babu; alone, all.
static func owner_of(players: Array, who: String) -> String:
	if players.is_empty():
		return ""
	return str(players[int(SEAT_OF.get(who, 0)) % players.size()])


## The characters each player plays: {uid: [cast ids]}.
static func roles(players: Array) -> Dictionary:
	var out := {}
	for p in players:
		out[str(p)] = []
	for who in CAST_IDS:
		var o := owner_of(players, who)
		if o != "":
			out[o].append(who)
	return out


## Step `i`'s score as its player wrote it, or -1 while not yet played.
static func score_of(moves: Dictionary, owner: String, i: int) -> float:
	var m = moves.get(owner, {})
	if typeof(m) != TYPE_DICTIONARY:
		return -1.0
	return float(m.get("s%d" % i, -1.0))


## Whoever is in the room now: the players who have written their part
## (a name), host first, in the room's order.
static func present(players: Array, moves: Dictionary) -> Array:
	return players.filter(func(p): return moves.has(str(p)))


## The race so far: [{uid, name, time, done}], the finished first by
## time, then the rest by how long they have ridden.
static func standings(players: Array, moves: Dictionary) -> Array:
	var out := []
	for p in players:
		var m = moves.get(str(p), null)
		if typeof(m) != TYPE_DICTIONARY:
			continue
		out.append({"uid": str(p), "name": str(m.get("name", "")), "time": float(m.get("time", m.get("t", 0.0))), "done": bool(m.get("done", false))})
	out.sort_custom(func(x, y):
		if x.done != y.done:
			return x.done
		return x.time < y.time if x.done else x.time > y.time)
	return out


## A live race finished in `place` (1 first) of `racers`: a star for
## finishing and more for winning against at least one other, for the
## first few races of the day. Returns the stars.
static func race_prize(data: Dictionary, b: Balance, date: String, place: int, racers: int) -> int:
	var o := of(data)
	if str(o.date) != date:
		o.date = date
		o.paid = 0
	if int(o.paid) >= int(b.n("online.paid_per_day")):
		return 0
	o.paid = int(o.paid) + 1
	var stars := int(b.n("online.finish_tara"))
	if place == 1 and racers >= 2:
		stars += int(b.n("online.win_tara"))
		o.won = int(o.won) + 1
	data.tara = int(data.get("tara", 0)) + stars
	return stars
