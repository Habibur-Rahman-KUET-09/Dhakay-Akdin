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
## Who plays a character nobody in the room plays, or one whose player
## has gone: the game itself.
const BOT := "bot"

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


## Who plays a story character: one each in the room's order (the host is
## Rahim Chacha, the next Monir Mama, the third Babu); a seat with nobody
## in it is the bot's. Alone, all of them.
static func owner_of(players: Array, who: String) -> String:
	if players.is_empty():
		return ""
	if players.size() == 1:
		return str(players[0])
	var seat := int(SEAT_OF.get(who, 0))
	return str(players[seat]) if seat < players.size() else BOT


## A turn the bot plays (or plays for someone who has gone): a fair score,
## the same on every phone (it comes from the room's code and the step),
## so every phone still reaches the same ending.
static func bot_score(code: String, step: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%d" % [code, step])
	return snappedf(rng.randf_range(0.55, 0.9), 0.01)


## A turn some phone gave to the bot (its player had gone): the score it
## wrote, or -1. Every phone then takes that, even the player coming back.
static func bot_mark(moves: Dictionary, i: int) -> float:
	for uid in moves:
		var m = moves[uid]
		if typeof(m) == TYPE_DICTIONARY and m.has("g%d" % i):
			return float(m["g%d" % i])
	return -1.0


## Whether a player has gone: their phone stopped writing its heartbeat
## (`key`: a count that goes up every few seconds, or the race clock).
## `seen` is {uid: [last value, seconds since it changed]}, kept by the
## caller; `moves` the latest read. Updates `seen` and returns whether
## `uid` has been silent `limit` seconds.
static func gone(seen: Dictionary, moves: Dictionary, uid: String, dt: float, limit: float, key := "beat") -> bool:
	var m = moves.get(uid, null)
	var beat := str(m.get(key, "")) if typeof(m) == TYPE_DICTIONARY else ""
	var had: Array = seen.get(uid, [beat, 0.0])
	if beat != str(had[0]):
		had = [beat, 0.0]
	else:
		had = [beat, float(had[1]) + dt]
	seen[uid] = had
	return float(had[1]) >= limit


## The characters each player plays: {uid: [cast ids]}.
static func roles(players: Array) -> Dictionary:
	var out := {}
	for p in players:
		out[str(p)] = []
	for who in CAST_IDS:
		var o := owner_of(players, who)
		if o != "":
			if not out.has(o):
				out[o] = []
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
