## What carries over between days (progress.gd).
extends "res://tests/check.gd"

const Progress = preload("res://scripts/rules/progress.gd")
const Balance = preload("res://scripts/rules/balance.gd")
const Daily = preload("res://scripts/rules/daily.gd")

const PATH := "user://test_save.json"


func _fresh() -> Progress:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	var p := Progress.new(Balance.new(), PATH)
	# A fixed date, with today's double money already used, so the numbers
	# below are the plain ones.
	p.today = "2026-11-02"
	p.daily().featured = true
	return p


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


func test_tea_stall_upgrades() -> void:
	var p := _fresh()
	eq(p.next_upgrade("tea"), "bench", "a bench first")
	eq(p.price("bench", "tea"), 800, "800 taka")
	p.data.taka = 2500
	check(p.buy("bench", "tea"), "bought")
	check(p.has_upgrade("bench", "tea") and not p.has_upgrade("bench"), "the stall's, not the rickshaw's")
	eq(p.next_upgrade("tea"), "second_kettle", "then a second kettle")
	check(p.buy("second_kettle", "tea"), "bought")
	eq(p.data.taka, 500, "paid 800 + 1200")
	eq(p.next_upgrade(), "new_rickshaw", "the rickshaw's own list is apart")


func test_a_day_on_the_bus() -> void:
	var p := _fresh()
	var got := p.apply_bus_day({"earned": 500, "riders": 30, "stars": 4.4})
	eq(got.fund, 50, "a tenth to the fund")
	eq(p.data.taka, 450, "the rest saved")
	eq(p.data.bus.riders, 30, "riders counted")
	eq(p.data.history[0].who, "bus", "the record says whose day it was")


func test_bus_upgrades() -> void:
	var p := _fresh()
	eq(p.next_upgrade("bus"), "notebook", "a notebook first")
	eq(p.price("change_bag", "bus"), 1800, "the bigger bag: 1800")
	p.data.taka = 1000
	check(p.buy("notebook", "bus"), "bought")
	eq(p.next_upgrade("bus"), "change_bag", "then the bag")



# --- Week 10: today's character, challenge, streak, story, neighbours ---------


func test_todays_character_doubles_the_first_day() -> void:
	var p := _fresh()
	p.data.daily = {"date": "", "featured": false, "challenge": false}
	eq(p.featured(), "rickshaw", "only the rickshaw open: it is today's")
	var got := p.apply_day({"earned": 300, "trips": 3, "stars": 4.0, "fines": 0})
	check(got.featured, "today's character")
	eq(got.earned, 600, "double money")
	got = p.apply_day({"earned": 300, "trips": 3, "stars": 4.0, "fines": 0})
	eq(got.earned, 300, "only the first day")


func test_streak_and_its_stars() -> void:
	var p := _fresh()
	var stars := []
	for d in ["2026-11-02", "2026-11-03", "2026-11-04"]:
		p.today = d
		p.daily().featured = true
		stars.append(p.apply_day({"earned": 100, "trips": 1, "stars": 3.0, "fines": 0}).streak_stars)
	eq(stars, [5, 5, 10], "stars for days one, two, three")
	eq(p.data.streak.count, 3, "three days running")
	p.today = "2026-11-06"
	p.daily().featured = true
	p.apply_day({"earned": 100, "trips": 1, "stars": 3.0, "fines": 0})
	eq(p.data.streak.count, 1, "a day missed: start again")
	eq(p.data.streak.best, 3, "the best run kept")


func test_seventh_day_brings_the_festive_hood() -> void:
	var p := _fresh()
	for i in 7:
		p.today = Time.get_date_string_from_unix_time(Daily.day_number("2026-11-02") * 86400 + i * 86400)
		p.daily().featured = true
		p.apply_day({"earned": 100, "trips": 1, "stars": 3.0, "fines": 0})
	check(p.data.cosmetics.has("festive_hood"), "a festive hood on the seventh day")
	eq(p.data.tara, 5 + 5 + 10 + 10 + 10 + 15, "stars on the six days before")


func test_challenge_met_gives_stars() -> void:
	var p := _fresh()
	var c := p.challenge()
	eq(c.who, "rickshaw", "a rickshaw challenge while only the rickshaw is open")
	var before := int(p.data.tara)
	var stats := {c.stat: c.goal}
	var got := p.apply_day({"earned": 100, "trips": 1, "stars": 3.0, "fines": 0, "stats": stats})
	check(got.challenge, "met")
	eq(int(p.data.tara) - before, 3 + got.streak_stars, "3 stars for it")
	check(not p.apply_day({"earned": 100, "trips": 1, "stars": 3.0, "fines": 0, "stats": stats}).challenge, "once a day")


func test_early_unlock_with_stars() -> void:
	var p := _fresh()
	check(not p.unlocked("bus"), "the bus is for level 4")
	check(not p.unlock_early("bus"), "no stars yet")
	p.data.tara = 35
	check(p.unlock_early("bus"), "30 stars")
	check(p.unlocked("bus") and p.open_characters().has("bus"), "open now")
	eq(p.data.tara, 5, "paid")


func test_a_chapter_read() -> void:
	var p := _fresh()
	var got := p.finish_chapter("babu_3", {"taka": 200, "npc": ["kamal", 3]})
	eq(got.xp, 100, "100 XP")
	eq(got.tara, 5, "5 stars")
	check(p.seen("babu_3"), "marked read")
	eq(p.data.taka, 200, "the choice's money")
	eq(p.relation("kamal"), 3, "Kamal Bhai remembers")
	eq(p.finish_chapter("babu_3").xp, 0, "only once")


func test_neighbours_remember() -> void:
	var p := _fresh()
	p.apply_tea_day({"earned": 100, "served": 5, "happy": 5, "lost": 0, "stars": 5.0,
		"npcs": [{"id": "rafiq", "delta": 1, "what": "served"}, {"id": "rafiq", "delta": 1, "what": "served"}]})
	eq(p.relation("rafiq"), 2, "Rafiq Chacha likes the stall")
	eq(p.data.log[0].who, "tea", "noted in the mohalla's notebook")
	p.apply_npcs([{"id": "rafiq", "delta": -9, "what": "left"}], "tea")
	eq(p.relation("rafiq"), -5, "no lower than -5")
