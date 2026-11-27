## Lines for the end of any day: today's character, the challenge, the run
## of days, a gift. `got` is what progress.gd's apply_*_day returned.
extends RefCounted

const Strings = preload("res://scripts/ui/strings.gd")
const Cards = preload("res://scripts/rules/cards.gd")


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
	if int(got.get("rank_points", 0)) > 0:
		out.append(s.t("dayRankPoints", {"n": int(got.rank_points)}))
	var card: Dictionary = got.get("card", {})
	if not card.is_empty():
		var name := str(Cards.card(str(card.id)).get("name", {}).get(s.lang, ""))
		if card.new:
			out.append(s.t("cardNew", {"name": name}))
		else:
			out.append(s.t("cardAgain", {"name": name, "n": int(card.tara)}))
		if str(card.set_done) != "":
			out.append(s.t("cardSetDone", {"n": int(card.tara)}))
	if got.get("rank_up", false):
		out.append(s.t("rankUp", {"rank": s.t("rank_" + str(got.get("rank_id", "")))}))
	return out
