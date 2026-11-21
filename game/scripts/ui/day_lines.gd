## Lines for the end of any day: today's character, the challenge, the run
## of days, a gift. `got` is what progress.gd's apply_*_day returned.
extends RefCounted

const Strings = preload("res://scripts/ui/strings.gd")


static func lines(got: Dictionary, s: Strings) -> Array:
	var out := []
	if got.get("featured", false):
		out.append(s.t("featuredDone"))
	if got.get("challenge", false):
		out.append(s.t("challengeDone"))
	if int(got.get("streak_stars", 0)) > 0:
		out.append(s.t("streakStars", {"n": int(got.streak), "stars": int(got.streak_stars)}))
	if got.get("streak_gift", "") != "":
		out.append(s.t("streakGift"))
	return out
