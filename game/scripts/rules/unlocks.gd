## What the home page shows as a player goes on: the first day is only
## the game; each new day opens one more thing (the card album, the season
## pass, friends and challenges, the lists), each with a little "opened!"
## the first time it is seen.
extends RefCounted

## Feature, and the days played (finished) it needs.
const AFTER := {"cards": 1, "pass": 2, "friends": 3, "board": 4}
const ORDER := ["cards", "pass", "friends", "board"]


static func is_open(save: Dictionary, feature: String) -> bool:
	return int(save.get("day", 0)) >= int(AFTER.get(feature, 0))


## Features open now that have not been announced yet (in order), noted as
## announced.
static func newly_open(save: Dictionary) -> Array:
	if not save.has("unlocked"):
		# Saves from before: what is already open counts as seen, so a
		# long-time player is not shown four "opened!" at once.
		var seen: Array = []
		for f in ORDER:
			if is_open(save, f) and int(save.get("day", 0)) > int(AFTER[f]):
				seen.append(f)
		save["unlocked"] = seen
	var fresh: Array = []
	for f in ORDER:
		if is_open(save, f) and not (save.unlocked as Array).has(f):
			fresh.append(f)
			save.unlocked.append(f)
	return fresh


## The next feature to open and the days still to play for it, or {}.
static func next(save: Dictionary) -> Dictionary:
	for f in ORDER:
		if not is_open(save, f):
			return {"feature": f, "days": int(AFTER[f]) - int(save.get("day", 0))}
	return {}
