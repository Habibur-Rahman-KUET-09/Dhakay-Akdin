## The free season pass (season.gd).
extends "res://tests/check.gd"

const Season = preload("res://scripts/rules/season.gd")
const Balance = preload("res://scripts/rules/balance.gd")


func test_points_open_tiers_and_prizes_are_claimed_once() -> void:
	var b := Balance.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var save := {"tara": 0}
	eq(Season.tiers().size(), 20, "20 tiers")
	var got := Season.note(save, 130, "2026-11-10")
	eq(int(got.new_tiers), 1, "130 points: the first tier")
	eq(Season.waiting(save, "2026-11-10"), 1, "one prize waiting")
	var prize := Season.claim(save, b, "2026-11-10", 1, rng)
	eq(int(prize.tara), 3, "the first prize: 3 stars")
	eq(int(save.tara), 3, "given")
	eq(Season.claim(save, b, "2026-11-10", 1, rng), {}, "once")
	eq(Season.claim(save, b, "2026-11-10", 2, rng), {}, "not before it opens")
	Season.note(save, 400, "2026-11-11")
	prize = Season.claim(save, b, "2026-11-11", 2, rng)
	check(bool(prize.card.new), "tier 2: a card not held yet")
	prize = Season.claim(save, b, "2026-11-11", 5, rng)
	check((save.cosmetics as Array).has("outfit_check"), "tier 5: an outfit, given")


func test_a_new_month_starts_again() -> void:
	var save := {}
	Season.note(save, 500, "2026-11-30")
	eq(Season.open_tiers(save, "2026-11-30"), 5, "five tiers in November")
	eq(Season.open_tiers(save, "2026-12-01"), 0, "December starts again")
