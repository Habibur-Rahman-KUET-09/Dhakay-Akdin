## The free season pass: a season is a calendar month. Every day played
## adds its XP as points; every per_tier points opens the next of 20
## tiers, whose prize the player claims: stars, a new card for the album,
## a photo frame for the photo mode, or a look (given, not sold). A new
## month starts again from nothing. No drawing: testable.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")
const Cards = preload("res://scripts/rules/cards.gd")
const Goods = preload("res://scripts/rules/goods.gd")
const PATH := "res://content/season.json"

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data


static func tiers() -> Array:
	return data().tiers


static func per_tier() -> int:
	return int(data().per_tier)


## The season of a date: "2026-11".
static func id_of(date: String) -> String:
	return date.substr(0, 7)


## The save's part for the pass, started again in a new month.
static func of(save: Dictionary, date: String) -> Dictionary:
	var have = save.get("season", null)
	if typeof(have) != TYPE_DICTIONARY or str(have.get("id", "")) != id_of(date):
		have = {"id": id_of(date), "points": 0, "claimed": []}
		save["season"] = have
	return have


static func points(save: Dictionary, date: String) -> int:
	return int(of(save, date).points)


## Tiers open so far (0..20).
static func open_tiers(save: Dictionary, date: String) -> int:
	return mini(tiers().size(), points(save, date) / per_tier())


## A day played: its XP as points. Returns {gained, tier, new_tiers}.
static func note(save: Dictionary, xp: int, date: String) -> Dictionary:
	var before := open_tiers(save, date)
	var s := of(save, date)
	s.points = int(s.points) + maxi(0, xp)
	var now := open_tiers(save, date)
	return {"gained": maxi(0, xp), "tier": now, "new_tiers": now - before}


static func claimed(save: Dictionary, date: String, tier: int) -> bool:
	return (of(save, date).claimed as Array).has(tier)


## Tiers open and not yet claimed.
static func waiting(save: Dictionary, date: String) -> int:
	var n := 0
	for t in range(1, open_tiers(save, date) + 1):
		if not claimed(save, date, t):
			n += 1
	return n


## Claims tier t (1-based): gives its prize. Returns what was given
## ({tara, card, frame, look}) or {} if it cannot be claimed.
static func claim(save: Dictionary, b: Balance, date: String, t: int, rng: RandomNumberGenerator) -> Dictionary:
	if t < 1 or t > open_tiers(save, date) or claimed(save, date, t):
		return {}
	var prize: Dictionary = tiers()[t - 1]
	var out := {}
	if prize.has("tara"):
		save["tara"] = int(save.get("tara", 0)) + int(prize.tara)
		out["tara"] = int(prize.tara)
	if prize.has("card"):
		# A card not held yet (or a star if the album is full).
		var missing := []
		for s in Cards.sets():
			for c in s.cards:
				if not Cards.owned(save, str(c.id)):
					missing.append(str(c.id))
		if missing.is_empty():
			save["tara"] = int(save.get("tara", 0)) + 1
		else:
			var id: String = missing[rng.randi() % missing.size()]
			out["card"] = Cards.give(save, b, id)
	if prize.has("frame"):
		if not save.has("frames"):
			save["frames"] = []
		if not (save.frames as Array).has(str(prize.frame)):
			save.frames.append(str(prize.frame))
		out["frame"] = str(prize.frame)
	if prize.has("look"):
		var who := str(prize.look[0])
		var id := str(prize.look[1])
		if not save.has("cosmetics"):
			save["cosmetics"] = []
		if not Goods.look(who, id).is_empty() and not (save.cosmetics as Array).has(id):
			save.cosmetics.append(id)
		out["look"] = [who, id]
	of(save, date).claimed.append(t)
	return out
