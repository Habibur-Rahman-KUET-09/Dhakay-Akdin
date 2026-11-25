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


func test_the_online_copy_round_trips() -> void:
	var Cloud = load("res://scripts/ui/cloud.gd")
	var data := Progress.fresh()
	data.taka = 450
	data.day = 3
	var doc: Dictionary = Cloud.to_fields(data, "2026-11-21 10:00:00")
	var back: Dictionary = Cloud.from_doc(doc)
	eq(int(back.save.taka), 450, "the savings come back")
	eq(back.day, 3, "and the day")
	check(Cloud.from_doc({}).is_empty(), "nothing from nothing")
	eq(Cloud.error_of({"code": 0}), "NETWORK", "no reply: no network")
	eq(Cloud.error_of({"code": 400, "data": {"error": {"message": "WEAK_PASSWORD : Password should be at least 6 characters"}}}), "WEAK_PASSWORD", "sign-in errors by name")
	eq(Cloud.error_of({"code": 403, "data": {"error": {"message": "Missing or insufficient permissions.", "status": "PERMISSION_DENIED"}}}), "PERMISSION_DENIED", "Firestore errors by status")


func test_old_dhaka_opens_at_level_five() -> void:
	var p := _fresh()
	eq(p.rickshaw_area(), "mirpur", "Mirpur at first")
	check(not p.choose_area("old_dhaka"), "Old Dhaka shut at level 1")
	check(not p.choose_area("gulshan"), "no such area")
	p.data.mohalla.level = 5
	check(p.choose_area("old_dhaka"), "open at level 5")
	eq(p.rickshaw_area(), "old_dhaka", "riding there now")
	p.data.mohalla.level = 1
	eq(p.rickshaw_area(), "mirpur", "an old save past its level falls back to Mirpur")


func test_the_family_feeling_stays_within_0_and_10() -> void:
	if FileAccess.file_exists("user://test_family.json"):
		DirAccess.remove_absolute("user://test_family.json")
	var p := Progress.new(Balance.new(), "user://test_family.json")
	eq(p.family("rickshaw"), 5, "starts at 5")
	eq(p.add_family("rickshaw", 3), 8, "up")
	eq(p.add_family("rickshaw", 9), 10, "never past 10")
	eq(p.add_family("bus", -9), 0, "never under 0")
	eq(p.family("tea"), 5, "the others as they were")


func test_calls_from_home() -> void:
	const HomeCall = preload("res://scripts/rules/home_call.gd")
	const Strings = preload("res://scripts/ui/strings.gd")
	var calls := HomeCall.new()
	var s := Strings.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for who in ["rickshaw", "tea", "bus"]:
		var list: Array = calls.calls[who]
		check(list.size() >= 2, "%s has calls" % who)
		for c in list:
			check(s.t("caller_" + c.by) != "caller_" + c.by, "%s: who is calling" % c.id)
			check(c.has("bn") and c.has("en"), "%s in both languages" % c.id)
			for o in c.options:
				check(s.t("call_" + o) != "call_" + o, "%s: answer %s has words" % [c.id, o])
				if c.options[o].get("end_day", false):
					eq(who, "rickshaw", "only Rahim Chacha can go home")
		check(not calls.pick(who, rng, 5).is_empty(), "a call for %s" % who)
	var fever: Dictionary = calls.calls.rickshaw[1]
	eq(HomeCall.effect(fever, "send"), {"family": 1, "cost": 100, "end_day": false}, "sending money")
	eq(HomeCall.effect(fever, "go").end_day, true, "going home ends the day")
	eq(HomeCall.plan(rng, 1), -1.0, "not on the first level")
	var some := false
	for i in 50:
		var at := HomeCall.plan(rng, 3)
		if at >= 0.0:
			some = true
			check(at >= 0.3 and at <= 0.7, "in the middle of the day")
	check(some, "on some days")


func test_looks_bought_once_and_worn_one_per_slot() -> void:
	var p := _fresh()
	p.data.taka = 1000
	check(p.buy_look("rickshaw", "paint_sky"), "bought")
	eq(int(p.data.taka), 700, "paid")
	eq(p.worn("rickshaw", "paint").id, "paint_sky", "worn at once")
	check(not p.buy_look("rickshaw", "paint_sky"), "not twice")
	check(p.buy_look("rickshaw", "paint_parrot"), "another paint")
	eq(p.worn("rickshaw", "paint").id, "paint_parrot", "the new one is worn")
	check(p.wear_look("rickshaw", "paint_sky"), "back to the first")
	eq(p.worn("rickshaw", "paint").id, "paint_sky", "")
	p.wear_look("rickshaw", "paint_sky")
	eq(p.worn("rickshaw", "paint"), {}, "worn again: taken off")
	check(not p.wear_look("rickshaw", "art_peacock"), "not owned, not worn")
	check(not p.buy_look("tea", "paint_sky"), "a rickshaw paint is not for the stall")


func test_the_home_the_phone_and_the_samity() -> void:
	var p := _fresh()
	p.data.taka = 3000
	var family := p.family("rickshaw")
	check(p.buy_home("bed"), "a bed")
	eq(p.family("rickshaw"), family + 1, "the family is glad")
	near(p.home_energy(), 10.0, "rests better")
	check(not p.buy_home("house"), "the house is too dear")
	check(p.buy_phone(), "a phone")
	check(p.has_phone() and not p.buy_phone(), "only one")
	p.data.taka = 1000
	p.set_samity(true)
	var out := {}
	for i in 9:
		out = {}
		p._samity_day(out)
	eq(int(p.data.samity.paid), 270, "nine deposits")
	eq(int(p.data.taka), 730, "out of the savings")
	out = {}
	p._samity_day(out)
	eq(int(out.samity_payout), 330, "the tenth: all back, and the bonus")
	eq(int(p.data.taka), 1030, "a little more than before")
	p._samity_day({})
	p.set_samity(false)
	eq(int(p.data.taka), 1030, "leaving: what was paid in comes back")


func test_every_good_has_its_words() -> void:
	const Goods = preload("res://scripts/rules/goods.gd")
	const Strings = preload("res://scripts/ui/strings.gd")
	var s := Strings.new()
	for lang in ["bn", "en"]:
		s.lang = lang
		for who in ["rickshaw", "tea", "bus", "fuchka"]:
			check(not Goods.looks(who).is_empty(), "looks for %s" % who)
			for l in Goods.looks(who):
				for key in ["look_" + l.id, "lookHelp_" + l.slot]:
					check(s.t(key) != key, "%s: %s" % [lang, key])
				check(int(l.get("price", 0)) > 0 or int(l.get("tara", 0)) > 0 or bool(l.get("prize", false)), "%s has a price (or is a prize)" % l.id)
				if who == "bus":
					check(s.t(l.id) != l.id, "%s: the sign's words" % l.id)
		for h in Goods.home_items():
			for key in ["home_" + h.id, "homeHelp_" + h.id]:
				check(s.t(key) != key, "%s: %s" % [lang, key])
	check(int(Goods.phone().price) > 0 and int(Goods.samity().daily) > 0, "phone and samity priced")


func test_family_scenes_when_feelings_run_high_or_low() -> void:
	var p := _fresh()
	eq(p.family_scene_due(), "", "nothing at 5")
	p.add_family("rickshaw", 3)
	eq(p.family_scene_due(), "family_high_rickshaw", "8: a happy evening")
	p.scene_shown("family_high_rickshaw")
	eq(p.family_scene_due(), "", "once")
	p.add_family("rickshaw", -7)
	eq(p.family_scene_due(), "family_low_rickshaw", "1: Sumi is upset")
	const Story = preload("res://scripts/rules/story.gd")
	var st := Story.new()
	for who in ["rickshaw", "tea", "bus"]:
		for kind in ["high", "low"]:
			check(not st.scene("family_%s_%s" % [kind, who]).is_empty(), "a scene for %s %s" % [who, kind])
	for id in ["bed", "fan", "desk", "tv", "house"]:
		check(not st.scene("home_" + id).is_empty(), "a scene for the " + id)


func test_a_chapter_changes_the_next_days() -> void:
	var p := _fresh()
	p.finish_chapter("rahim_9", {"after": {"days": 2, "target": 200, "note": "flood_home", "who": "rickshaw"}})
	eq(int(p.story_effect("rickshaw").get("target", 0)), 200, "more to earn")
	eq(p.story_effect("tea"), {}, "only for Rahim Chacha")
	p.apply_tea_day({"earned": 100, "served": 5, "happy": 5, "lost": 0, "stars": 4.0})
	eq(int(p.story_effect("rickshaw").get("left", 0)), 2, "a tea day does not count")
	p.apply_day({"earned": 700, "trips": 8, "stars": 4.0, "fines": 0})
	eq(int(p.story_effect("rickshaw").get("left", 0)), 1, "one day done")
	p.apply_day({"earned": 700, "trips": 8, "stars": 4.0, "fines": 0})
	eq(p.story_effect("rickshaw"), {}, "over")
	const Story = preload("res://scripts/rules/story.gd")
	const Strings = preload("res://scripts/ui/strings.gd")
	var s := Strings.new()
	for c in Story.new().chapters:
		var afters := [c.get("after", {})]
		for o in c.get("choice", {}).get("options", []):
			afters.append(o.get("effects", {}).get("after", {}))
		for a in afters:
			if not a.is_empty():
				check(s.t("after_" + str(a.note)) != "after_" + str(a.note), "words for %s" % a.note)


func test_things_bought_with_stars() -> void:
	var p := _fresh()
	p.data.tara = 45
	p.data.taka = 0
	check(p.buy_look("rickshaw", "paint_night"), "a paint bought with 40 stars")
	eq(int(p.data.tara), 5, "stars spent, not money")
	check(not p.buy_boost("meal"), "8 stars for a meal: 5 is not enough")
	p.data.tara = 20
	check(p.buy_boost("meal"), "a meal for the next day")
	check(not p.buy_boost("meal"), "one waiting at a time")
	eq(int(p.take_boost("rickshaw").get("energy", 0)), 30, "used on the day")
	eq(p.take_boost("rickshaw"), {}, "and gone")
	const BusDay = preload("res://scripts/rules/bus_day.gd")
	var bus := BusDay.new(preload("res://scripts/rules/balance.gd").new(), 1)
	var before := bus.earned()
	bus.add_float({"10": 5, "20": 4, "50": 2})
	eq(bus.bag_value(), 550 + 230, "more small notes in the bag")
	eq(bus.earned(), before, "the float is not the day's money")
