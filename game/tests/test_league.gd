## Phase 7: the weekly area league (league.gd) and friends' tea stalls in
## my town (friends.gd, day.gd).
extends "res://tests/check.gd"

const League = preload("res://scripts/rules/league.gd")
const Friends = preload("res://scripts/rules/friends.gd")
const Leaderboard = preload("res://scripts/rules/leaderboard.gd")
const Balance = preload("res://scripts/rules/balance.gd")
const Progress = preload("res://scripts/rules/progress.gd")
const RoadMap = preload("res://scripts/rules/road_map.gd")
const Day = preload("res://scripts/rules/day.gd")
const Ranked = preload("res://scripts/rules/ranked.gd")

## A Tuesday; its week began on Saturday the 21st.
const DAY := "2026-11-24"
const PATH := "user://test_league_save.json"

var b := Balance.new()


func test_trips_count_for_the_area() -> void:
	var d := Progress.fresh()
	League.note(d, "mirpur", 5, "2026-11-20")
	League.note(d, "mirpur", 3, DAY)
	League.note(d, "old_dhaka", 2, DAY)
	League.note(d, "nowhere", 9, DAY)
	eq(League.mine(d, "mirpur", DAY), 3, "this week only")
	var w := Friends.week_of(DAY)
	var lw := Friends.last_week(DAY)
	eq(League.fields(d, DAY), {
		League.field("mirpur", w): 3, League.field("old_dhaka", w): 2, League.field("mirpur", lw): 5,
	}, "this week's and last week's on the card")
	var card := Leaderboard.card(d, DAY)
	eq(card.get(League.field("old_dhaka", w)), 2, "in the public card")
	League.note(d, "mirpur", 1, "2026-12-09")
	eq(League.of(d).prev, {}, "a week skipped: nothing last week")


func test_who_wins() -> void:
	eq(League.average({"count": 4, "sum": 30}), 7.5, "an average")
	eq(League.average({}), 0.0, "nobody")
	eq(League.winner(b, {"mirpur": {"count": 40, "sum": 200}, "old_dhaka": {"count": 5, "sum": 40}}), "old_dhaka", "the higher average, not the bigger side")
	eq(League.winner(b, {"mirpur": {"count": 4, "sum": 20}, "old_dhaka": {"count": 2, "sum": 10}}), "", "a tie: nobody")
	eq(League.winner(b, {"mirpur": {"count": 4, "sum": 20}, "old_dhaka": {"count": 0, "sum": 0}}), "", "nobody on one side: no contest")


func test_prize_and_decorations() -> void:
	var d := Progress.fresh()
	League.note(d, "mirpur", 6, "2026-11-20")
	var tara := int(d.tara)
	eq(League.settle(d, b, DAY, "mirpur"), int(b.n("league.win_tara")), "rode for the winners")
	eq(int(d.tara), tara + int(b.n("league.win_tara")), "stars")
	eq(League.settle(d, b, DAY, "mirpur"), 0, "once a week")
	check(League.decked(d, "mirpur", DAY), "the winners' streets decked out")
	check(not League.decked(d, "old_dhaka", DAY), "not the other side's")
	check(not League.decked(d, "mirpur", "2026-12-01"), "for the week after only")
	var e := Progress.fresh()
	League.note(e, "old_dhaka", 6, "2026-11-20")
	eq(League.settle(e, b, DAY, "mirpur"), 0, "rode for the losers: nothing")
	var f := Progress.fresh()
	eq(League.settle(f, b, DAY, "mirpur"), 0, "did not ride last week")


func test_rickshaw_days_feed_the_league() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	var p := Progress.new(b, PATH)
	p.today = DAY
	p.apply_day({"earned": 500, "trips": 7, "stars": 4.0, "fines": 0, "teas": 0, "visits": {"u1": 2}})
	eq(League.mine(p.data, "mirpur", DAY), 7, "trips for Mirpur")
	eq(Friends.of(p.data).visits_sent, {"u1": 2}, "customers for a friend")
	eq(Friends.card(p.data, DAY).visits, {"u1": 2}, "on my card")


# --- Friends' stalls -------------------------------------------------------------


func _with_friends() -> Dictionary:
	var d := Progress.fresh()
	var f := Friends.of(d)
	f.list = [{"uid": "u1", "code": "AAAAAA", "name": "Mina"}, {"uid": "u2", "code": "BBBBBB", "name": "Sabbir"},
		{"uid": "u3", "code": "CCCCCC", "name": "Tania"}, {"uid": "u4", "code": "DDDDDD", "name": "Rafi"}]
	return d


func test_stalls_stand_by_the_road() -> void:
	var map: RoadMap = RoadMap.load_area("mirpur")
	var d := _with_friends()
	var formats := {"bn": "{name}-এর চায়ের দোকান", "en": "{name}'s tea stall"}
	var places := Friends.shop_places(d, map, formats)
	eq(places.size(), 3, "three at most")
	eq(places[0].names.en, "Mina's tea stall", "named for the friend")
	eq(places[0].friend, "u1", "whose")
	for pl in places:
		eq(map.kind_at(pl.at), RoadMap.Kind.ROAD, "on an ordinary road")
		check(not map.places.any(func(x): return absi(x.at.x - pl.at.x) + absi(x.at.y - pl.at.y) < 3), "clear of the real places")
	check(absi(places[0].at.x - places[1].at.x) + absi(places[0].at.y - places[1].at.y) >= 4, "apart")
	eq(Friends.shop_places(d, map, formats)[1].at, places[1].at, "the same spot every day")
	eq(Friends.shop_places(Progress.fresh(), map, formats), [], "no friends, no stalls")


func test_passengers_ask_for_a_friends_stall() -> void:
	var map: RoadMap = RoadMap.load_area("mirpur")
	var bb := Balance.new()
	bb.raw.rickshaw.friend_shop_chance = 1.0
	var day := Day.new(map, bb, 5)
	day.friend_places = Friends.shop_places(_with_friends(), map, {"bn": "{name}", "en": "{name}"})
	day.waiting.clear()
	day._top_up()
	check(not day.waiting.is_empty(), "people waiting")
	for w in day.waiting:
		check(str(w.place.get("friend", "")) != "", "everyone for a friend's stall (chance 1)")
	var w: Dictionary = day.waiting[0]
	day.riding = {"place": w.place, "at": w.place.at, "type": "normal", "fare": 50, "tiles": 10,
		"since": day.clock, "eta": 30.0, "flooded": 0, "npc": ""}
	day._deliver([])
	eq(day.friend_visits, {str(w.place.friend): 1}, "a customer for that friend")
	eq(day.last_trip.friend, str(w.place.name), "said on screen")


func test_paid_for_customers_friends_brought() -> void:
	var d := _with_friends()
	var f := Friends.of(d)
	f.cards = {"u1": {"name": "Mina", "visits": {"me": 3, "other": 9}}, "u2": {"name": "Sabbir", "visits": {}}}
	var taka := int(d.taka)
	var got := Friends.claim_visits(d, b, "me")
	eq(got, [{"name": "Mina", "n": 3, "taka": 3 * int(b.n("friends.shop_visit_taka"))}], "Mina's rickshaw brought three")
	eq(int(d.taka), taka + 3 * int(b.n("friends.shop_visit_taka")), "into the savings")
	eq(Friends.claim_visits(d, b, "me"), [], "paid once")
	f.cards.u1.visits.me = 5
	eq(Friends.claim_visits(d, b, "me")[0].n, 2, "only the new ones")


# --- Today's race with a ghost (race.gd) ---------------------------------------------


const Race = preload("res://scripts/rules/race.gd")


func test_the_same_ride_for_everyone_today() -> void:
	var map: RoadMap = RoadMap.load_area("mirpur")
	var r := Race.route(map, DAY)
	check(not r.is_empty(), "a ride")
	eq(Race.route(map, DAY), r, "the same for everyone on a date")
	var d := map.distance(r.start, r.place.at)
	check(d >= 14 and d <= 26, "a fair distance: %d" % d)
	check(Race.route(map, "2026-11-25") != r, "another the next day")


func test_rides_written_down_small() -> void:
	var pts := PackedVector2Array([Vector2(10.04, -3.5), Vector2(12.5, 400.2), Vector2(-7.0, 0.0)])
	var text := Race.encode(pts)
	check(text.length() < 30, "a few bytes")
	var back := Race.decode(text)
	eq(back.size(), 3, "every point")
	check(absf(back[1].y - 400.2) < 0.06, "to a tenth of a metre")
	eq(Race.decode(""), PackedVector2Array(), "nothing")
	near(Race.at_time(back, 0.1).x, (10.0 + 12.5) / 2.0, "half way between two points")
	eq(Race.at_time(back, 99.0), back[2], "at the end once over")


func test_the_ghost_and_the_prizes() -> void:
	var d := _with_friends()
	var f := Friends.of(d)
	f.cards = {"u1": {"race": {"date": DAY, "time": 50.0, "path": "x"}}, "u2": {"race": {"date": DAY, "time": 42.0, "path": "y"}},
		"u3": {"race": {"date": "2026-11-23", "time": 30.0, "path": "z"}}}
	var g := Race.ghost(d, DAY)
	eq([g.name, g.time, g.friend], ["Sabbir", 42.0, true], "the fastest friend today")
	var tara := int(d.tara)
	var got := Race.finish(d, b, DAY, 45.0, "mine", g)
	eq(got, {"stars": int(b.n("race.finish_tara")), "best": true, "beat": false}, "first finish: stars, not beaten")
	got = Race.finish(d, b, DAY, 40.0, "faster", g)
	eq(got, {"stars": int(b.n("race.beat_tara")), "best": true, "beat": true}, "beat the ghost")
	got = Race.finish(d, b, DAY, 39.0, "again", g)
	eq(got.stars, 0, "stars once a day each")
	eq(int(d.tara), tara + int(b.n("race.finish_tara")) + int(b.n("race.beat_tara")), "all told")
	eq(Race.card(d, DAY), {"race": {"date": DAY, "time": 39.0, "path": "again"}}, "today's best on the card")
	eq(Race.card(d, "2026-11-25"), {}, "nothing the next day")
	var alone := Progress.fresh()
	eq(Race.ghost(alone, DAY), {}, "no ghost at first")
	Race.finish(alone, b, DAY, 61.0, "p", {})
	eq(Race.ghost(alone, DAY), {"name": "", "time": 61.0, "path": "p", "friend": false}, "then my own")


func test_racing_the_rickshaw() -> void:
	var map: RoadMap = RoadMap.load_area("mirpur")
	var day := Day.new(map, Balance.new(), 5)
	var r := Race.route(map, DAY)
	day.start_race(r)
	eq(day.driver.cell, r.start, "at the start")
	eq(day.destination, r.place.at, "the arrow to the finish")
	check(day.waiting.is_empty(), "nobody waiting")
	day._top_up()
	check(day.waiting.is_empty(), "and nobody comes")
	var events := []
	day.driver.cell = r.place.at
	day._entered(events)
	eq(events, [Day.RACE_DONE], "the finish")
	check(day.over, "over")


# --- The weekly tournament (ranked.gd) -------------------------------------------


func test_rank_ladder() -> void:
	var b := Balance.new()
	eq(Ranked.rank_id(b, Ranked.rank_of(b, 0)), "notun", "no points: new")
	eq(Ranked.rank_id(b, Ranked.rank_of(b, 300)), "paka", "300: pro")
	eq(Ranked.rank_id(b, Ranked.rank_of(b, 5000)), "kingbodonti", "lots: legend")
	eq(Ranked.to_next(b, 250), 50, "50 to go")
	eq(Ranked.to_next(b, 5000), -1, "nothing above the top")


func test_days_climb_and_a_new_week_pays_once() -> void:
	var b := Balance.new()
	var data := {"tara": 0}
	var r := Ranked.note(data, b, 130, "2026-11-23")
	eq(r.points, 130, "a day's XP")
	check(not r.up, "still new")
	r = Ranked.note(data, b, 190, "2026-11-25")
	check(r.up, "up to pro")
	eq(Ranked.claim(data, b, "2026-11-26"), {}, "nothing to pay in the same week")
	# Saturday 28 November: a new week.
	eq(Ranked.points(data, "2026-11-28"), 0, "a new week starts from nothing")
	var paid := Ranked.claim(data, b, "2026-11-28")
	eq(int(paid.tara), 3, "last week's pro prize")
	eq(int(data.tara), 3, "the stars added")
	eq(Ranked.claim(data, b, "2026-11-29"), {}, "paid once")


func test_week_days_left() -> void:
	eq(Ranked.days_left("2026-11-28"), 7, "Saturday: the whole week")
	eq(Ranked.days_left("2026-12-04"), 1, "Friday: the last day")


# --- The school league and today's challenge board ---------------------------------


func test_school_points_go_on_the_card() -> void:
	var School = load("res://scripts/rules/school.gd")
	var data := {}
	eq(School.fields(data, DAY), {}, "no place picked: nothing")
	School.choose(data, "kuet")
	eq(School.fields(data, DAY), {}, "no points yet: nothing")
	Ranked.note(data, b, 150, DAY)
	eq(School.fields(data, DAY), {School.field("kuet", Friends.week_of(DAY)): 150}, "the week's points under KUET")
	School.choose(data, "nowhere")
	eq(School.mine(data), "kuet", "an unknown place is not taken")
	var board: Array = School.board({"kuet": {"count": 2, "sum": 300.0}, "buet": {"count": 1, "sum": 500.0}, "du": {"count": 0}})
	eq(board.map(func(r): return r.id), ["buet", "kuet"], "most points first, empty places left out")


func test_todays_challenge_board() -> void:
	var data := {}
	var f := Friends.of(data)
	f.list = [{"uid": "u1", "name": "Rakib"}, {"uid": "u2", "name": "Mim"}]
	f.cards = {"u1": {"race": {"date": DAY, "time": 41.0}}, "u2": {"race": {"date": "2026-01-01", "time": 30.0}}}
	var r := Race.of(data)
	r.date = DAY
	r.best = 38.5
	var board := Race.board(data, DAY)
	eq(board.size(), 2, "me and the friend who rode today")
	check(board[0].me and float(board[0].time) == 38.5, "fastest first: me")
	eq(str(board[1].name), "Rakib", "then Rakib")
