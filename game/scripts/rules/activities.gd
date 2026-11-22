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
