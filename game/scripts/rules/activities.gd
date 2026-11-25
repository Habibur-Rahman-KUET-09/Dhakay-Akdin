## How well a hand activity went (the little things done with the fingers:
## pouring tea from up high, stirring in the sugar, folding a paan,
## pumping a tyre, sorting notes between the fingers, slapping the bus).
## Scores run 0 (badly) to 1 (just right); the scenes turn them into tips,
## stars and seconds. No drawing here, so it can be tested.
extends RefCounted

## Pouring from up high (one stroke: the cup lifted and lowered once):
## each full stroke, high enough, makes froth; four make a perfect cup.
## Spilling (lifting too high) spoils it.
const POUR_STROKES := 4
const POUR_HIGH := 0.45
const POUR_SPILL := 0.97


static func pour_score(strokes: Array, spilled: bool) -> float:
	var good := 0
	for h in strokes:
		if float(h) >= POUR_HIGH:
			good += 1
	var s := minf(1.0, float(good) / POUR_STROKES)
	return s * (0.4 if spilled else 1.0)


## Sugar: the spoons the customer asked for, and the stirring (three
## turns round the cup to dissolve it).
static func sugar_score(spoons: int, wanted: int, turns: float) -> float:
	var right := 1.0 if spoons == wanted else (0.5 if absi(spoons - wanted) == 1 else 0.15)
	return right * clampf(0.4 + 0.2 * turns, 0.4, 1.0)


## A paan: the leaf with areca and lime on it, zarda only if wanted,
## folded shut.
static func paan_score(on_leaf: Array, wants_zarda: bool, folded: bool) -> float:
	var s := 0.0
	if on_leaf.has("areca"):
		s += 0.3
	if on_leaf.has("lime"):
		s += 0.3
	if on_leaf.has("zarda") == wants_zarda:
		s += 0.2
	if folded:
		s += 0.2
	return s


## A tyre pumped to `pressure` (1 is the green mark's top): "soft" below
## the green, "ok" in it, "burst" past it.
const PUMP_GREEN := [0.75, 1.0]


static func pump_result(pressure: float) -> String:
	if pressure > PUMP_GREEN[1]:
		return "burst"
	return "ok" if pressure >= PUMP_GREEN[0] else "soft"


## The hood in the rain: full marks within 3 seconds, none by 8.
static func hood_score(seconds: float) -> float:
	return clampf(1.0 - (seconds - 3.0) / 5.0, 0.0, 1.0)


## Pushing through deep water: every push with the other hand than the
## last counts in full, the same hand twice only a little.
static func push_amount(hand: int, last_hand: int) -> float:
	return 0.12 if hand != last_hand else 0.03


## Slaps on the side of the bus, by their times: "one" (stop), "two"
## (go: two close together), "" (nothing yet / too far apart).
const SLAP_GAP := 0.45


static func slaps(times: Array) -> String:
	if times.is_empty():
		return ""
	if times.size() >= 2 and float(times[-1]) - float(times[-2]) <= SLAP_GAP:
		return "two"
	return "one"


## Which finger a note goes between, as conductors keep them: 5 and 10,
## 20, 50, then 100 and up.
static func finger_for(note: int) -> int:
	if note <= 10:
		return 0
	if note == 20:
		return 1
	if note == 50:
		return 2
	return 3


## Hanging at the door: how steady Babu is, from the lean (−1…1; 0 is
## upright). Steady enough to reach out within 0.35.
static func steady(lean: float) -> bool:
	return absf(lean) <= 0.35


## Paid by phone (made-up "TakaPhone" mobile money): the SMS that came.
## Real: from the service, the right amount, just now, its name spelt
## right. A fake gets one thing wrong, harder ones at higher levels: the
## amount (from the start), an old message (level 3), from an ordinary
## number (level 5), the name misspelt (level 8).
## {amount, from_service, name_ok, today, trx, fake, kind}.
static func phone_sms(rng: RandomNumberGenerator, fare: int, level: int, fake: bool) -> Dictionary:
	var sms := {"amount": fare, "from_service": true, "name_ok": true, "today": true,
		"trx": "%X" % rng.randi_range(0x10000000, 0x7FFFFFFF), "fake": fake, "kind": "real"}
	if not fake:
		return sms
	var kinds := ["amount"]
	if level >= 3:
		kinds.append("old")
	if level >= 5:
		kinds.append("sender")
	if level >= 8:
		kinds.append("spelling")
	var kind: String = kinds[rng.randi() % kinds.size()]
	sms.kind = kind
	match kind:
		"amount":
			# A digit off: 80 asked, 8 or 18 sent.
			sms.amount = int(fare / 10.0) if fare >= 20 and rng.randf() < 0.5 else maxi(1, fare - 10 * rng.randi_range(1, 3))
		"old":
			sms.today = false
		"sender":
			sms.from_service = false
		"spelling":
			sms.name_ok = false
	return sms


## What came of it: "fine" (real, taken), "caught" (fake, spotted: they
## pay cash), "fooled" (fake, taken: the fare is lost), "wrong" (real, but
## called fake: they are hurt).
static func phone_result(sms: Dictionary, said_fake: bool) -> String:
	if sms.fake:
		return "caught" if said_fake else "fooled"
	return "wrong" if said_fake else "fine"



## The chain come off the gear (phase 6): back on within 4 seconds is
## best, none by 12; meanwhile the rickshaw stands and the horns go.
static func chain_score(seconds: float) -> float:
	return clampf(1.0 - (seconds - 4.0) / 8.0, 0.0, 1.0)


## What someone leaves behind on the seat, by the kind of passenger they
## are: rickshaw passengers (normal, miser, hurry, elder) and bus riders
## (student, needy, and "woman" for a woman of any other kind).
const LOST_ITEMS := {
	"normal": "phone", "miser": "umbrella", "hurry": "file", "elder": "glasses",
	"student": "book", "needy": "bag", "woman": "purse",
}


static func lost_item(kind: String) -> String:
	return str(LOST_ITEMS.get(kind, "phone"))


## The places to choose from when remembering where someone got off:
## the right one and the first others in `pool` (no repeats), `n` in all,
## shuffled. Places are compared by `key` (dictionaries) or as they are.
static func lost_choices(rng: RandomNumberGenerator, right, pool: Array, n := 3, key := "") -> Array:
	var same := func(a, b) -> bool:
		return (a[key] == b[key]) if key != "" else (a == b)
	var out := [right]
	for p in pool:
		if out.size() >= n:
			break
		if not out.any(func(o): return same.call(o, p)):
			out.append(p)
	for i in out.size():
		var j := rng.randi_range(i, out.size() - 1)
		var x = out[i]
		out[i] = out[j]
		out[j] = x
	return out


## Washing the cups at the stall: scrubbing a cup round and round makes it
## clean after this many turns; the score is the share of the dirty ones
## washed.
const WASH_TURNS := 1.5


static func wash_score(washed: int, dirty: int) -> float:
	return 1.0 if dirty <= 0 else clampf(float(washed) / dirty, 0.0, 1.0)


## The credit book: the sum written down for what they had. "right";
## "short" (written less: the difference is Monir Mama's loss); "over"
## (written more: they will argue when they pay).
static func ledger_result(written: int, owed: int) -> String:
	if written == owed:
		return "right"
	return "short" if written < owed else "over"


## The chance someone on credit pays when it falls due, by how they feel
## about the mohalla (−5…5).
static func repay_chance(relation: int) -> float:
	if relation >= 2:
		return 0.95
	if relation >= 0:
		return 0.75
	return 0.4
