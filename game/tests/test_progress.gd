## What carries over between days (progress.gd).
extends "res://tests/check.gd"

const Progress = preload("res://scripts/rules/progress.gd")
const Balance = preload("res://scripts/rules/balance.gd")

const PATH := "user://test_save.json"


func _fresh() -> Progress:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	return Progress.new(Balance.new(), PATH)


func test_a_good_day_is_shared_out() -> void:
	var p := _fresh()
	var out := p.apply_day({"earned": 800, "trips": 9, "stars": 4.6, "fines": 0})
	eq(out.fund, 80, "a tenth to the mohalla fund")
	eq(out.school, 120, "720 kept, 120 over the 600 target to the school fee")
	eq(out.kept, 600, "the rest in his pocket")
	eq(p.data.taka, 600, "savings")
	eq(p.data.rickshaw.school, 120, "school fee put by")
	eq(p.data.fund, 80, "fund")
	eq(out.xp, 50 + 5 * 20, "XP: 50 + 20 per star (4.6 rounds to 5)")
	check(out.level_up, "150 XP passes the 120 needed for level 2")
	eq(p.level(), 2, "level 2")
	eq(p.xp(), 30, "30 XP into level 2")
	check(p.unlocked("tea_stall"), "the tea stall opens at level 2")
	check(out.best, "a first day is the best day")
	eq(p.data.day, 1, "day 1 done")
	eq(p.data.history[0].earned, 800, "in the record")


func test_a_poor_day_still_counts() -> void:
	var p := _fresh()
	var out := p.apply_day({"earned": 300, "trips": 4, "stars": 3.0, "fines": 50})
	eq(out.fund, 30, "fund")
	eq(out.school, 0, "nothing over target")
	eq(p.data.taka, 270, "savings")
	check(not out.met, "target missed")
	out = p.apply_day({"earned": -50, "trips": 0, "stars": 0.0, "fines": 50})
	eq(out.earned, 0, "a day of fines earns nothing, never less")
	eq(out.xp, 25, "half the base XP for a day without trips")
	eq(p.data.day, 2, "still a day")


func test_the_fund_finishes_a_project() -> void:
	var p := _fresh()
	p.data.fund = 1950
	var out := p.apply_day({"earned": 600, "trips": 7, "stars": 4.0, "fines": 0})
	eq(out.project, "street_lights", "street lights done")
	eq(p.data.fund, 10, "what is left over carries on")
	eq(p.data.fundProject, "drain_cleaning", "the next project")


func test_upgrades_and_saving() -> void:
	var p := _fresh()
	eq(p.next_upgrade(), "new_rickshaw", "first on sale")
	check(not p.buy("new_rickshaw"), "too dear with no savings")
	p.data.taka = 2000
	check(p.buy("new_rickshaw"), "bought")
	eq(p.data.taka, 500, "paid 1500")
	near(p.speed_factor(), 1.15, "15% faster")
	eq(p.next_upgrade(), "battery_rickshaw", "next on sale")
	p.save()
	var again := Progress.new(Balance.new(), PATH)
	eq(again.data.taka, 500, "savings kept across a restart")
	check(again.has_upgrade("new_rickshaw"), "upgrade kept")
	DirAccess.remove_absolute(PATH)


func test_history_keeps_the_last_ten_days() -> void:
	var p := _fresh()
	for i in 14:
		p.apply_day({"earned": 100 * i, "trips": i, "stars": 4.0, "fines": 0})
	eq(p.data.history.size(), 10, "ten days")
	eq(p.data.history[0].day, 14, "newest first")
	eq(p.data.rickshaw.bestDay, 1300, "best day")


func test_battery_and_tea_cups() -> void:
	var p := _fresh()
	near(p.energy_factor(), 1.0, "no upgrade: full cost")
	p.data.rickshaw.upgrades = ["new_rickshaw", "battery_rickshaw"]
	near(p.energy_factor(), 0.5, "battery rickshaw: half")
	p.apply_day({"earned": 300, "trips": 3, "stars": 4.0, "fines": 0, "teas": 2})
	p.apply_day({"earned": 300, "trips": 3, "stars": 4.0, "fines": 0})
	eq(p.data.rickshaw.teas, 2, "cups of tea counted")


func test_a_day_at_the_tea_stall() -> void:
	var p := _fresh()
	var got := p.apply_tea_day({"earned": 400, "served": 20, "happy": 15, "lost": 5, "stars": 4.0})
	eq(got.fund, 40, "a tenth to the fund")
	eq(got.kept, 360, "the rest saved")
	eq(p.data.taka, 360, "in the savings")
	eq(p.data.tea.days, 1, "one day at the stall")
	eq(p.data.tea.served, 20, "customers counted")
	eq(p.data.day, 1, "the mohalla's day moves on")
	eq(got.xp, 130, "XP: 50 + 4 stars × 20")
	eq(p.data.history[0].who, "tea", "the record says whose day it was")
	check(got.best, "best day at the stall")
