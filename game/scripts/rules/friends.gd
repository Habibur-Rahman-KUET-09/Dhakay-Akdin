## Playing with friends, each at their own time (§৯, phase 5). Every player
## has a six-letter code; friends are added by it (no phone number or
## email). Online each one keeps a small public card (profiles/<account>):
## the name they chose, this week's earnings, what they gave to the mohalla
## fund, and the legs of today's relay day. From those cards:
##  - the week's list among friends (the first gets a golden paint for the rickshaw),
##  - gifts (a cup of tea: more energy for Rahim Chacha's next day; paan:
##    stars), at most a few a day, and preset stickers (no free chat),
##  - the joint fund: what everyone gave, together, builds big things,
##  - the relay day (পালার দিন): Monir Mama's morning, Rahim Chacha's noon
##    and Babu's evening, played by different friends; a good leg helps
##    the next one.
## Everything here works on the save's "friends" part and on cards as
## plain dictionaries. No drawing, no network, so it can be tested.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")
const Daily = preload("res://scripts/rules/daily.gd")
const RoadMap = preload("res://scripts/rules/road_map.gd")

## Letters that cannot be mistaken for one another (no I, O, 0, 1).
const LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 6
const NAME_LENGTH := 16
const GIFTS := ["tea", "paan"]
const STICKERS := ["josh", "rain", "thanks", "well_done", "see_you", "eid"]
## The relay's legs, in the day's order: each good leg helps the next.
const LEGS := ["tea", "rickshaw", "bus"]
## The prize for the week's first: a golden paint for the rickshaw.
const PRIZE := "paint_friends"


static func fresh() -> Dictionary:
	return {
		"name": "", "code": "",
		# Friends: [{uid, code, name}]; blocked accounts.
		"list": [], "blocked": [],
		# Their cards as last seen, by account.
		"cards": {},
		# Sent today (gifts, stickers), to keep within the day's limits.
		"sent": {"date": "", "gifts": 0, "stickers": 0},
		# Cups of tea received and not yet drunk.
		"tea": 0,
		# Received lately: [{name, kind, sticker, date}], newest first.
		"mail": [],
		# This week and last week's earnings; all ever given to the fund.
		"week": "", "week_taka": 0, "prev_week": "", "prev_taka": 0, "given": 0,
		# Today's relay legs played here: {who: stars}.
		"legs_date": "", "legs": {},
		# Weeks won, joint projects seen done, the day a relay paid stars.
		"won": [], "joint_done": [], "relay_paid": "",
		# Friends' tea stalls in my town (phase 7): customers my rickshaw
		# took to each friend's stall, all told (on my card, for them),
		# and those I have been paid for at mine, by friend.
		"visits_sent": {}, "visits_got": {},
	}


## The save's friends part, made whole if an older save lacks it or some of it.
## Filled in place, so every caller holds the same dictionary.
static func of(data: Dictionary) -> Dictionary:
	var have = data.get("friends", null)
	if typeof(have) != TYPE_DICTIONARY:
		have = {}
		data["friends"] = have
	var base := fresh()
	for k in base:
		if not have.has(k):
			have[k] = base[k]
	return have


# --- Codes and names -------------------------------------------------------------


static func make_code(rng: RandomNumberGenerator) -> String:
	var out := ""
	for i in CODE_LENGTH:
		out += LETTERS[rng.randi_range(0, LETTERS.length() - 1)]
	return out


## A code as typed, tidied: capitals, no spaces or dashes; O read as 0 is
## not a letter we use, so it stays (and the code is then not valid).
static func clean_code(text: String) -> String:
	return text.strip_edges().to_upper().replace(" ", "").replace("-", "")


static func valid_code(code: String) -> bool:
	if code.length() != CODE_LENGTH:
		return false
	for ch in code:
		if not LETTERS.contains(ch):
			return false
	return true


## A chosen name, tidied: letters (any script), digits, spaces and a few
## marks; spaces collapsed; at most 16 characters. "" if nothing is left.
static func clean_name(text: String) -> String:
	var out := ""
	var space := false
	for ch in text.strip_edges():
		var c := ch.unicode_at(0)
		var keep := ch == "." or ch == "-" or ch == "_" or (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c >= 0x0980
		if ch == " " or ch == "\t":
			space = out != ""
			continue
		if not keep or c < 32 or (c >= 0x2000 and c <= 0x206F and c != 0x200C and c != 0x200D):
			continue
		if space:
			out += " "
			space = false
		out += ch
		if out.length() >= NAME_LENGTH:
			break
	return out.strip_edges()


# --- Weeks --------------------------------------------------------------------


## The week a date falls in; weeks start on Saturday, as at work in Dhaka.
static func week_of(date: String) -> String:
	# 1 January 1970 was a Thursday; the 3rd, day 2, a Saturday.
	return "w%d" % floori((Daily.day_number(date) - 2) / 7.0)


static func last_week(date: String) -> String:
	return week_of(Time.get_date_string_from_unix_time((Daily.day_number(date) - 7) * 86400))


## A day just played: the week's earnings (moving this week to last week
## when a new one has begun) and today's relay leg.
static func note_day(data: Dictionary, who: String, earned: int, stars: float, date: String) -> void:
	var f := of(data)
	_roll_week(f, date)
	f.week_taka = int(f.week_taka) + maxi(0, earned)
	if f.legs_date != date:
		f.legs_date = date
		f.legs = {}
	f.legs[who] = maxf(float(f.legs.get(who, 0.0)), stars)


static func _roll_week(f: Dictionary, date: String) -> void:
	var w := week_of(date)
	if f.week == w:
		return
	if f.week == last_week(date):
		f.prev_week = f.week
		f.prev_taka = int(f.week_taka)
	else:
		f.prev_week = last_week(date)
		f.prev_taka = 0
	f.week = w
	f.week_taka = 0


## Money to the mohalla fund, counted for the joint fund too.
static func note_given(data: Dictionary, taka: int) -> void:
	var f := of(data)
	f.given = int(f.given) + maxi(0, taka)


# --- The card others see ------------------------------------------------------------


## This player's public card: nothing but the chosen name and the game.
static func card(data: Dictionary, date: String) -> Dictionary:
	var f := of(data)
	_roll_week(f, date)
	var legs: Dictionary = f.legs if f.legs_date == date else {}
	var art := str((data.get("looks", {}).get("rickshaw", {}) as Dictionary).get("art", ""))
	return {
		"name": str(f.name), "code": str(f.code), "level": int(data.get("mohalla", {}).get("level", 1)),
		"week": str(f.week), "week_taka": int(f.week_taka), "prev_week": str(f.prev_week), "prev_taka": int(f.prev_taka),
		"given": int(f.given), "legs_date": date if not legs.is_empty() else "", "legs": legs.duplicate(), "art": art,
		"visits": (f.visits_sent as Dictionary).duplicate(),
	}


## What a card says about a week's earnings: this week, or last week, or 0.
static func taka_in(c: Dictionary, week: String) -> int:
	if str(c.get("week", "")) == week:
		return int(c.get("week_taka", 0))
	if str(c.get("prev_week", "")) == week:
		return int(c.get("prev_taka", 0))
	return 0


# --- Friends ------------------------------------------------------------------


static func is_friend(data: Dictionary, uid: String) -> bool:
	for p in of(data).list:
		if p.uid == uid:
			return true
	return false


## Adds a friend found by code. Fails ("self", "already", "full",
## "blocked") with a reason, else "".
static func add(data: Dictionary, b: Balance, uid: String, code: String, name: String, my_uid: String) -> String:
	var f := of(data)
	if uid == my_uid or code == f.code:
		return "self"
	if is_friend(data, uid):
		return "already"
	if (f.blocked as Array).has(uid):
		return "blocked"
	if f.list.size() >= int(b.n("friends.max_friends")):
		return "full"
	f.list.append({"uid": uid, "code": code, "name": clean_name(name)})
	return ""


static func remove(data: Dictionary, uid: String) -> void:
	var f := of(data)
	f.list = (f.list as Array).filter(func(p): return p.uid != uid)
	(f.cards as Dictionary).erase(uid)


## Removes and blocks: their gifts and stickers are thrown away unread.
static func block(data: Dictionary, uid: String) -> void:
	remove(data, uid)
	var f := of(data)
	if not (f.blocked as Array).has(uid):
		f.blocked.append(uid)


## Keeps the cards fetched for friends (and their names, as they set them now).
static func take_cards(data: Dictionary, cards: Dictionary) -> void:
	var f := of(data)
	for p in f.list:
		if cards.has(p.uid):
			f.cards[p.uid] = cards[p.uid]
			var n := clean_name(str(cards[p.uid].get("name", "")))
			if n != "":
				p.name = n


## The week's list: me and my friends by this week's earnings, highest
## first; [{uid, name, taka, me}].
static func board(data: Dictionary, my_uid: String, date: String) -> Array:
	var f := of(data)
	var w := week_of(date)
	var rows := [{"uid": my_uid, "name": str(f.name), "taka": taka_in(card(data, date), w), "me": true}]
	for p in f.list:
		rows.append({"uid": p.uid, "name": p.name, "taka": taka_in(f.cards.get(p.uid, {}), w), "me": false})
	rows.sort_custom(func(x, y): return x.taka > y.taka if x.taka != y.taka else (x.me and not y.me))
	return rows


## At the start of a new week: did I come first last week among friends
## (with earnings, and at least one friend playing)? Gives the prize look
## once, or stars when it is already owned. Returns "" or what was given
## ("prize" or "tara").
static func claim_week(data: Dictionary, b: Balance, date: String) -> String:
	var f := of(data)
	var lw := last_week(date)
	if (f.won as Array).has(lw):
		return ""
	var me := taka_in(card(data, date), lw)
	if me <= 0:
		return ""
	var others := 0
	for p in f.list:
		var t := taka_in(f.cards.get(p.uid, {}), lw)
		if t >= me:
			return ""
		if t > 0:
			others += 1
	if others == 0:
		return ""
	f.won.append(lw)
	var owned: Array = data.get("cosmetics", [])
	if not owned.has(PRIZE):
		owned.append(PRIZE)
		data.cosmetics = owned
		return "prize"
	data.tara = int(data.get("tara", 0)) + int(b.n("friends.week_tara"))
	return "tara"


# --- Gifts and stickers -----------------------------------------------------------


static func _sent_today(f: Dictionary, date: String) -> Dictionary:
	if f.sent.get("date", "") != date:
		f.sent = {"date": date, "gifts": 0, "stickers": 0}
	return f.sent


## How many more gifts (kind "gift") or stickers ("sticker") may go today.
static func left_today(data: Dictionary, b: Balance, kind: String, date: String) -> int:
	var sent := _sent_today(of(data), date)
	if kind == "sticker":
		return maxi(0, int(b.n("friends.stickers_per_day")) - int(sent.stickers))
	return maxi(0, int(b.n("friends.gifts_per_day")) - int(sent.gifts))


## The item to send to a friend ({from, name, kind, sticker, date}), or {}
## when today's limit is reached or it is not something that can be sent.
## Counts it as sent.
static func send(data: Dictionary, b: Balance, my_uid: String, kind: String, sticker: String, date: String) -> Dictionary:
	var f := of(data)
	var is_sticker := kind == "sticker"
	if is_sticker and not STICKERS.has(sticker):
		return {}
	if not is_sticker and not GIFTS.has(kind):
		return {}
	if left_today(data, b, "sticker" if is_sticker else "gift", date) <= 0:
		return {}
	var sent := _sent_today(f, date)
	if is_sticker:
		sent.stickers = int(sent.stickers) + 1
	else:
		sent.gifts = int(sent.gifts) + 1
	return {"from": my_uid, "name": str(f.name), "kind": kind, "sticker": sticker if is_sticker else "", "date": date}


## Takes back a count when sending failed.
static func unsend(data: Dictionary, kind: String, date: String) -> void:
	var sent := _sent_today(of(data), date)
	var key := "stickers" if kind == "sticker" else "gifts"
	sent[key] = maxi(0, int(sent[key]) - 1)


## Items that came in: tea is kept for Rahim Chacha's next day, paan gives
## stars, stickers are shown. From blocked accounts or broken: dropped.
## Returns how many were taken.
static func receive(data: Dictionary, b: Balance, items: Array) -> int:
	var f := of(data)
	var taken := 0
	for it in items:
		if typeof(it) != TYPE_DICTIONARY or (f.blocked as Array).has(str(it.get("from", ""))):
			continue
		var kind := str(it.get("kind", ""))
		if kind == "tea":
			f.tea = int(f.tea) + 1
		elif kind == "paan":
			data.tara = int(data.get("tara", 0)) + int(b.n("friends.paan_tara"))
		elif kind != "sticker" or not STICKERS.has(str(it.get("sticker", ""))):
			continue
		taken += 1
		f.mail.push_front({"name": clean_name(str(it.get("name", ""))), "kind": kind, "sticker": str(it.get("sticker", "")), "date": str(it.get("date", ""))})
	while f.mail.size() > 12:
		f.mail.pop_back()
	return taken


## Energy from the cups of tea friends sent (a few count), drunk now.
static func drink_tea(data: Dictionary, b: Balance) -> float:
	var f := of(data)
	var cups := mini(int(f.tea), int(b.n("friends.tea_cap")))
	f.tea = 0
	return cups * b.n("friends.tea_energy")


# --- The joint fund --------------------------------------------------------------


## All that I and my friends gave to the mohalla funds.
static func joint_total(data: Dictionary) -> int:
	var f := of(data)
	var total := int(f.given)
	for p in f.list:
		total += int((f.cards.get(p.uid, {}) as Dictionary).get("given", 0))
	return total


## The joint projects with where they stand: [{id, cost, got, done}], in
## order; each one's money counts after the ones before it.
static func joint(data: Dictionary, b: Balance) -> Array:
	var left := joint_total(data)
	var out := []
	for p in b.at("friends.joint"):
		var cost := int(p.cost)
		var got := clampi(left, 0, cost)
		left -= got
		out.append({"id": str(p.id), "cost": cost, "got": got, "done": got >= cost})
	return out


## Joint projects newly done (with at least one friend): XP and stars for
## each, once. Returns their ids.
static func claim_joint(data: Dictionary, b: Balance) -> Array:
	var f := of(data)
	var out := []
	if f.list.is_empty():
		return out
	for p in joint(data, b):
		if p.done and not (f.joint_done as Array).has(p.id):
			f.joint_done.append(p.id)
			data.tara = int(data.get("tara", 0)) + int(b.n("friends.joint_tara"))
			out.append(p.id)
	return out


# --- The relay day (পালার দিন) ------------------------------------------------------


## Who played each leg today, among friends (not me): {leg: {name, stars}},
## the best of each.
static func relay(data: Dictionary, date: String) -> Dictionary:
	var f := of(data)
	var out := {}
	for p in f.list:
		var c: Dictionary = f.cards.get(p.uid, {})
		if str(c.get("legs_date", "")) != date:
			continue
		var legs = c.get("legs", {})
		if typeof(legs) != TYPE_DICTIONARY:
			continue
		for leg in LEGS:
			if legs.has(leg) and float(legs[leg]) > float(out.get(leg, {}).get("stars", -1.0)):
				out[leg] = {"name": p.name, "stars": float(legs[leg])}
	return out


## The friend whose good leg before `who`'s helps today ({name, stars}),
## or {}.
static func helped_by(data: Dictionary, b: Balance, who: String, date: String) -> Dictionary:
	var i := LEGS.find(who)
	if i <= 0:
		return {}
	var before: Dictionary = relay(data, date).get(LEGS[i - 1], {})
	if before.is_empty() or float(before.stars) < b.n("friends.relay_good_stars"):
		return {}
	return before


## Rahim Chacha's extra energy from a friend's good morning at the stall.
static func relay_energy(data: Dictionary, b: Balance, date: String) -> float:
	return b.n("friends.relay_energy") if not helped_by(data, b, "rickshaw", date).is_empty() else 0.0


## Babu's extra money from a friend's good noon on the rickshaw (Rahim
## Chacha brings riders to the stop).
static func relay_bonus(data: Dictionary, b: Balance, who: String, earned: int, date: String) -> int:
	if who != "bus" or helped_by(data, b, "bus", date).is_empty():
		return 0
	return int(roundf(maxi(0, earned) * b.n("friends.relay_bonus")))


## All three legs played today, by me and friends together, with at least
## one friend: stars once a day. True when given now.
static func claim_relay(data: Dictionary, b: Balance, date: String) -> bool:
	var f := of(data)
	if f.relay_paid == date:
		return false
	var theirs := relay(data, date)
	if theirs.is_empty():
		return false
	var mine: Dictionary = f.legs if f.legs_date == date else {}
	for leg in LEGS:
		if not theirs.has(leg) and not mine.has(leg):
			return false
	f.relay_paid = date
	data.tara = int(data.get("tara", 0)) + int(b.n("friends.relay_tara"))
	return true


# --- A friend's stall in my town (phase 7) ------------------------------------------


## Where friends' tea stalls stand in a town: one each for up to `most`
## friends, on an ordinary road by the kerb, picked from the friend's
## account so it is the same spot every day, and clear of the real
## places and of each other. Places like the map's ({id, names, at}),
## with `friend` (their account) and `name`; `names` from `formats`
## ({bn, en} with {name} in them).
static func shop_places(data: Dictionary, map: RoadMap, formats: Dictionary, most := 3) -> Array:
	var out := []
	var spots := []
	for p in map.roads():
		if map.kind_at(p) != RoadMap.Kind.ROAD:
			continue
		if map.places.any(func(pl): return absi(pl.at.x - p.x) + absi(pl.at.y - p.y) < 3):
			continue
		if absi(map.home.x - p.x) + absi(map.home.y - p.y) < 4:
			continue
		spots.append(p)
	if spots.is_empty():
		return out
	for friend in of(data).list:
		if out.size() >= most:
			break
		var name := clean_name(str(friend.get("name", "")))
		if name == "":
			continue
		var i := absi(hash(str(friend.uid) + str(map.id))) % spots.size()
		for k in spots.size():
			var at: Vector2i = spots[(i + k * 7) % spots.size()]
			if out.any(func(o): return absi(o.at.x - at.x) + absi(o.at.y - at.y) < 4):
				continue
			var names := {}
			for lang in formats:
				names[lang] = str(formats[lang]).replace("{name}", name)
			out.append({"id": "friend_" + str(friend.uid), "names": names, "at": at, "friend": str(friend.uid), "name": name})
			break
	return out


## Customers my rickshaw took to friends' stalls today: {friend: n}.
static func note_visits(data: Dictionary, visits: Dictionary) -> void:
	var f := of(data)
	for uid in visits:
		f.visits_sent[uid] = int(f.visits_sent.get(uid, 0)) + int(visits[uid])


## Customers friends' rickshaws brought to my stall since I last looked
## (their cards count them all told): paid into my savings.
## Returns [{name, n, taka}].
static func claim_visits(data: Dictionary, b: Balance, my_uid: String) -> Array:
	var f := of(data)
	var out := []
	for p in f.list:
		var c: Dictionary = f.cards.get(p.uid, {})
		var sent = c.get("visits", {})
		if typeof(sent) != TYPE_DICTIONARY:
			continue
		var total := int(sent.get(my_uid, 0))
		var got := int(f.visits_got.get(p.uid, 0))
		if total <= got:
			continue
		var n := total - got
		f.visits_got[p.uid] = total
		var taka := n * int(b.n("friends.shop_visit_taka"))
		data.taka = int(data.get("taka", 0)) + taka
		out.append({"name": str(p.name), "n": n, "taka": taka})
	return out
