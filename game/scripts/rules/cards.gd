## The Dhaka card album: 24 cards in four sets (places, food, rides,
## festivals), each with a little fact. One card after every day played,
## drawn from the set that suits the character (rickshaw and delivery:
## places; tea and fuchka: food; bus, hawker and boat: rides); a festival
## day gives that festival's card instead. A card already held turns into
## stars; a whole set pays its stars once. No drawing: testable.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")
const PATH := "res://content/cards.json"

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data


static func sets() -> Array:
	return data().sets


static func card(id: String) -> Dictionary:
	for s in sets():
		for c in s.cards:
			if c.id == id:
				var out: Dictionary = c.duplicate()
				out["set"] = s.id
				return out
	return {}


static func count() -> int:
	var n := 0
	for s in sets():
		n += (s.cards as Array).size()
	return n


## The save's album: {owned: [ids], sets_paid: [set ids]}, filled in place.
static func of(save: Dictionary) -> Dictionary:
	var have = save.get("cards", null)
	if typeof(have) != TYPE_DICTIONARY:
		have = {}
		save["cards"] = have
	if not have.has("owned"):
		have["owned"] = []
	if not have.has("sets_paid"):
		have["sets_paid"] = []
	return have


static func owned(save: Dictionary, id: String) -> bool:
	return (of(save).owned as Array).has(id)


## How many of a set are held.
static func held_in(save: Dictionary, set_id: String) -> int:
	var n := 0
	for s in sets():
		if s.id == set_id:
			for c in s.cards:
				if owned(save, str(c.id)):
					n += 1
	return n


## The set a character's day draws from ("" for none).
static func set_for(who: String) -> String:
	for s in sets():
		if (s.who as Array).has(who):
			return str(s.id)
	return ""


## Gives a card: new ({id, new: true, set_done: set id or "", tara}) or a
## repeat (turned into stars). Stars are added to the save.
static func give(save: Dictionary, b: Balance, id: String) -> Dictionary:
	var c := card(id)
	if c.is_empty():
		return {}
	var album := of(save)
	var out := {"id": id, "new": false, "set_done": "", "tara": 0}
	if (album.owned as Array).has(id):
		out.tara = int(b.n("cards.repeat_tara"))
	else:
		album.owned.append(id)
		out.new = true
		var set_id := str(c.set)
		var size := 0
		for s in sets():
			if s.id == set_id:
				size = (s.cards as Array).size()
		if held_in(save, set_id) == size and not (album.sets_paid as Array).has(set_id):
			album.sets_paid.append(set_id)
			out.set_done = set_id
			out.tara = int(b.n("cards.set_tara"))
	save["tara"] = int(save.get("tara", 0)) + int(out.tara)
	return out


## The card after a day as `who` (a festival's on its day), from rng.
static func draw(save: Dictionary, b: Balance, who: String, festival_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var fest: String = str(data().festival_cards.get(festival_id, ""))
	if fest != "":
		return give(save, b, fest)
	var set_id := set_for(who)
	if set_id == "":
		return {}
	var pool: Array = []
	for s in sets():
		if s.id == set_id:
			pool = s.cards
	# New ones come up a little more often than repeats.
	var fresh := pool.filter(func(c): return not owned(save, str(c.id)))
	var pick: Dictionary = fresh[rng.randi() % fresh.size()] if not fresh.is_empty() and rng.randf() < b.n("cards.new_chance") else pool[rng.randi() % pool.size()]
	return give(save, b, str(pick.id))
