## The leaderboards (leaderboard.gd): the numbers on the public card, and
## stars for the top three when a period is over.
extends "res://tests/check.gd"

const Leaderboard = preload("res://scripts/rules/leaderboard.gd")
const Progress = preload("res://scripts/rules/progress.gd")
const Balance = preload("res://scripts/rules/balance.gd")

var b := Balance.new()


func test_periods() -> void:
	eq(Leaderboard.period_id("day", "2026-11-25"), "d20261125", "a day")
	eq(Leaderboard.period_id("month", "2026-11-25"), "m202611", "a month")
	eq(Leaderboard.before_id("month", "2027-01-05"), "m202612", "the month before, across a year")
	eq(Leaderboard.before_id("day", "2026-12-01"), "d20261130", "the day before, across a month")
	eq(Leaderboard.field("ever", "bus", "2026-11-25"), "lb_ever_bus", "all time")
	eq(Leaderboard.field("week", "all", "2026-11-25"), "lb_%s_all" % Leaderboard.period_id("week", "2026-11-25"), "a week")


func test_days_go_on_the_card() -> void:
	var d := Progress.fresh()
	Leaderboard.note(d, "rickshaw", 500, "2026-11-24")
	Leaderboard.note(d, "tea", 200, "2026-11-24")
	var f := Leaderboard.fields(d, "2026-11-24")
	eq(f.get("lb_d20261124_rickshaw"), 500, "Rahim Chacha today")
	eq(f.get("lb_d20261124_all"), 700, "all together today")
	eq(f.get("lb_m202611_tea"), 200, "Monir Mama this month")
	eq(f.get("lb_ever_all"), 700, "all time")
	check(not f.has("lb_d20261124_bus"), "nothing for Babu")
	Leaderboard.note(d, "rickshaw", 100, "2026-11-25")
	f = Leaderboard.fields(d, "2026-11-25")
	eq(f.get("lb_d20261125_rickshaw"), 100, "the new day")
	eq(f.get("lb_d20261124_rickshaw"), 500, "yesterday kept, for its prizes")
	eq(f.get("lb_m202611_rickshaw"), 600, "the month adds up")
	eq(Leaderboard.mine(d, "ever", "rickshaw", "2026-11-25"), 600, "my all-time number")
	f = Leaderboard.fields(d, "2026-11-28")
	check(not f.has("lb_d20261124_rickshaw") and not f.has("lb_d20261125_rickshaw"), "days gone by fall off the card")


func test_stars_for_the_top_three_once() -> void:
	var d := Progress.fresh()
	Leaderboard.note(d, "bus", 900, "2026-11-24")
	var checks := Leaderboard.to_check(d, "2026-11-25")
	var fields: Array = checks.map(func(c): return c.field)
	check(fields.has("lb_d20261124_bus") and fields.has("lb_d20261124_all"), "yesterday's lists to look at")
	check(not fields.has("lb_d20261124_tea"), "not lists I was not in")
	var tara := int(d.tara)
	var first: Dictionary = checks.filter(func(c): return c.field == "lb_d20261124_bus")[0]
	eq(Leaderboard.settle(d, b, first, 1), 5, "first yesterday: 5 stars")
	eq(int(d.tara), tara + 5, "given")
	eq(Leaderboard.settle(d, b, first, 1), 0, "once")
	var all: Dictionary = checks.filter(func(c): return c.field == "lb_d20261124_all")[0]
	eq(Leaderboard.settle(d, b, all, 0), 0, "not in the top three")
	check(Leaderboard.to_check(d, "2026-11-25").filter(func(c): return c.period == "day").is_empty(), "looked at, not again")


func test_the_public_card_and_names() -> void:
	var d := Progress.fresh()
	Leaderboard.note(d, "tea", 300, "2026-11-25")
	var c := Leaderboard.card(d, "2026-11-25")
	eq(c.get("lb_d20261125_tea"), 300, "the numbers")
	check(c.has("name") and c.has("week_taka"), "with the friends' part")
	check(not c.has("taka") and not c.has("save"), "and nothing else of the save")
	eq(Leaderboard.shown_name("  Mina ", "abcd1234", "Player"), "Mina", "a chosen name")
	eq(Leaderboard.shown_name("", "abcd1234", "Player"), "Player ABCD", "no name: Player and a bit of the account")
