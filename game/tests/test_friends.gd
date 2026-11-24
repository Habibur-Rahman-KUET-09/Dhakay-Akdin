## Playing with friends (friends.gd), and the online card's values (cloud.gd).
extends "res://tests/check.gd"

const Friends = preload("res://scripts/rules/friends.gd")
const Balance = preload("res://scripts/rules/balance.gd")
const Progress = preload("res://scripts/rules/progress.gd")
const Cloud = preload("res://scripts/ui/cloud.gd")

const PATH := "user://test_friends_save.json"
## A Tuesday; its week began on Saturday the 21st.
const DAY := "2026-11-24"

var b := Balance.new()


func _data() -> Dictionary:
	var d := Progress.fresh()
	Friends.of(d).name = "Ratul"
	Friends.of(d).code = "K7M2QX"
	return d


## A friend with a card: this week's money, last week's, what they gave,
## today's legs.
func _friend(d: Dictionary, uid: String, card: Dictionary) -> void:
	eq(Friends.add(d, b, uid, "AAAAA" + uid.substr(0, 1).to_upper(), str(card.get("name", uid)), "me"), "", "added " + uid)
	Friends.take_cards(d, {uid: card})


func test_codes_and_names() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var code := Friends.make_code(rng)
	eq(code.length(), 6, "six letters")
	check(Friends.valid_code(code), "a made code is valid")
	check(not Friends.valid_code("ABCDE1"), "no 1")
	check(not Friends.valid_code("ABCDEO"), "no O")
	check(not Friends.valid_code("ABCDE"), "too short")
	eq(Friends.clean_code(" k7m-2qx "), "K7M2QX", "typed codes tidied")
	eq(Friends.clean_name("  রাতুল   ভাই  "), "রাতুল ভাই", "spaces collapsed")
	eq(Friends.clean_name("   "), "", "nothing left")
	eq(Friends.clean_name("<b>Hi</b>"), "bHib", "no marks that could mean something")
	eq(Friends.clean_name("abcdefghijklmnopqrstuvwxyz").length(), Friends.NAME_LENGTH, "kept short")


func test_weeks_start_on_saturday() -> void:
	eq(Friends.week_of("2026-11-21"), Friends.week_of(DAY), "Saturday starts the week")
	eq(Friends.week_of("2026-11-27"), Friends.week_of(DAY), "Friday ends it")
	check(Friends.week_of("2026-11-20") != Friends.week_of(DAY), "the Friday before is last week")
	eq(Friends.last_week(DAY), Friends.week_of("2026-11-20"), "last week")


func test_the_week_rolls_over() -> void:
	var d := _data()
	Friends.note_day(d, "rickshaw", 500, 4.0, "2026-11-20")
	Friends.note_day(d, "tea", 200, 3.0, "2026-11-20")
	var f := Friends.of(d)
	eq(f.week_taka, 700, "two days in a week")
	Friends.note_day(d, "bus", 300, 4.5, DAY)
	eq(f.week_taka, 300, "a new week")
	eq(f.prev_taka, 700, "last week kept")
	eq(f.legs, {"bus": 4.5}, "today's legs only")
	Friends.note_day(d, "bus", 100, 2.0, "2026-12-09")
	eq(f.prev_taka, 0, "a week skipped: nothing last week")


func test_adding_removing_blocking() -> void:
	var d := _data()
	eq(Friends.add(d, b, "me", "ZZZZZZ", "x", "me"), "self", "not myself")
	eq(Friends.add(d, b, "u1", "K7M2QX", "x", "me"), "self", "not my own code")
	eq(Friends.add(d, b, "u1", "ABCDEF", "  Mina ", "me"), "", "a friend")
	eq(Friends.add(d, b, "u1", "ABCDEF", "Mina", "me"), "already", "only once")
	eq(Friends.of(d).list[0].name, "Mina", "name tidied")
	Friends.block(d, "u1")
	check(not Friends.is_friend(d, "u1"), "blocked is removed")
	eq(Friends.add(d, b, "u1", "ABCDEF", "Mina", "me"), "blocked", "and cannot be added back")


func test_the_week_list_and_its_prize() -> void:
	var d := _data()
	Friends.note_day(d, "rickshaw", 500, 4.0, "2026-11-20")
	Friends.note_day(d, "rickshaw", 100, 4.0, DAY)
	var w := Friends.week_of(DAY)
	var lw := Friends.last_week(DAY)
	_friend(d, "u1", {"name": "Mina", "week": w, "week_taka": 900, "prev_week": lw, "prev_taka": 300})
	_friend(d, "u2", {"name": "Sabbir", "week": lw, "week_taka": 50})
	var rows := Friends.board(d, "me", DAY)
	eq(rows.map(func(r): return r.name), ["Mina", "Ratul", "Sabbir"], "by this week's money")
	eq(rows[2].taka, 0, "a card from last week counts nothing now")
	eq(Friends.claim_week(d, b, DAY), "prize", "first last week: 500 over 300 and 50")
	check((d.cosmetics as Array).has(Friends.PRIZE), "the golden paint")
	eq(Friends.claim_week(d, b, DAY), "", "once a week")
	var d2 := _data()
	Friends.note_day(d2, "rickshaw", 500, 4.0, "2026-11-20")
	_friend(d2, "u1", {"name": "Mina", "week": lw, "week_taka": 600})
	eq(Friends.claim_week(d2, b, DAY), "", "second is no prize")
	var d3 := _data()
	Friends.note_day(d3, "rickshaw", 500, 4.0, "2026-11-20")
	eq(Friends.claim_week(d3, b, DAY), "", "alone is no prize")


func test_the_prize_is_not_for_sale() -> void:
	var p := Progress.new(b, PATH)
	p.data = Progress.fresh()
	p.data.taka = 5000
	check(not p.buy_look("rickshaw", Friends.PRIZE), "won, not bought")
	p.data.cosmetics.append(Friends.PRIZE)
	check(p.wear_look("rickshaw", Friends.PRIZE), "but worn once won")


func test_gifts_and_stickers() -> void:
	var d := _data()
	for i in 3:
		check(not Friends.send(d, b, "me", "tea", "", DAY).is_empty(), "gift %d" % i)
	check(Friends.send(d, b, "me", "paan", "", DAY).is_empty(), "three a day")
	Friends.unsend(d, "tea", DAY)
	var item := Friends.send(d, b, "me", "paan", "", DAY)
	eq(item, {"from": "me", "name": "Ratul", "kind": "paan", "sticker": "", "date": DAY}, "a failed send gives one back")
	check(Friends.send(d, b, "me", "sticker", "hello", DAY).is_empty(), "only preset stickers")
	check(Friends.send(d, b, "me", "money", "", DAY).is_empty(), "only tea and paan")
	eq(Friends.send(d, b, "me", "sticker", "josh", DAY).sticker, "josh", "a sticker")
	eq(Friends.left_today(d, b, "gift", "2026-11-25"), 3, "a new day")


func test_receiving() -> void:
	var d := _data()
	Friends.block(d, "bad")
	var tara := int(d.tara)
	var taken := Friends.receive(d, b, [
		{"from": "u1", "name": "Mina", "kind": "tea"},
		{"from": "u1", "name": "Mina", "kind": "tea"},
		{"from": "u2", "name": "Sabbir", "kind": "paan"},
		{"from": "u2", "name": "Sabbir", "kind": "sticker", "sticker": "josh"},
		{"from": "bad", "name": "X", "kind": "tea"},
		{"from": "u2", "name": "Sabbir", "kind": "sticker", "sticker": "rude words"},
		"not an item",
	])
	eq(taken, 4, "two teas, a paan, a sticker")
	eq(Friends.of(d).tea, 2, "the blocked one's tea dropped")
	eq(int(d.tara), tara + 2, "paan: stars")
	eq(Friends.of(d).mail[0].sticker, "josh", "newest first")
	for i in 5:
		Friends.receive(d, b, [{"from": "u1", "name": "Mina", "kind": "tea"}])
	near(Friends.drink_tea(d, b), 30.0, "three cups count, 10 each")
	eq(Friends.of(d).tea, 0, "drunk")


func test_the_joint_fund() -> void:
	var d := _data()
	Friends.note_given(d, 15000)
	eq(Friends.claim_joint(d, b), [], "alone it does not count")
	_friend(d, "u1", {"name": "Mina", "given": 10000})
	eq(Friends.joint_total(d), 25000, "together")
	var j := Friends.joint(d, b)
	check(j[0].done, "the school, 20000")
	eq(j[1].got, 5000, "then the playground")
	var tara := int(d.tara)
	eq(Friends.claim_joint(d, b), ["school"], "the school is done")
	eq(int(d.tara), tara + 10, "stars for it")
	eq(Friends.claim_joint(d, b), [], "once")


func test_the_relay_day() -> void:
	var d := _data()
	_friend(d, "u1", {"name": "Mina", "legs_date": DAY, "legs": {"tea": 4.0}})
	near(Friends.relay_energy(d, b, DAY), 20.0, "a good morning at the stall")
	near(Friends.relay_energy(d, b, "2026-11-25"), 0.0, "only today")
	eq(Friends.relay_bonus(d, b, "bus", 1000, DAY), 0, "nobody rode the rickshaw")
	_friend(d, "u2", {"name": "Sabbir", "legs_date": DAY, "legs": {"rickshaw": 3.0}})
	eq(Friends.relay_bonus(d, b, "bus", 1000, DAY), 0, "a poor noon does not help")
	_friend(d, "u3", {"name": "Tania", "legs_date": DAY, "legs": {"rickshaw": 4.5}})
	eq(Friends.relay_bonus(d, b, "bus", 1000, DAY), 100, "a good noon: a tenth more")
	eq(Friends.relay(d, DAY).rickshaw.name, "Tania", "the best of each leg")
	check(not Friends.claim_relay(d, b, DAY), "nobody played the bus yet")
	Friends.note_day(d, "bus", 400, 4.0, DAY)
	var tara := int(d.tara)
	check(Friends.claim_relay(d, b, DAY), "all three, together")
	eq(int(d.tara), tara + 5, "stars")
	check(not Friends.claim_relay(d, b, DAY), "once a day")


func test_days_feed_the_friends_part() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	var p := Progress.new(b, PATH)
	p.today = DAY
	p.daily().featured = true
	_friend(p.data, "u1", {"name": "Mina", "legs_date": DAY, "legs": {"rickshaw": 4.5}})
	var out := p.apply_bus_day({"earned": 1000, "riders": 30, "stars": 4.0})
	eq(out.relay_bonus, 100, "the relay's tenth")
	eq(out.earned, 1100, "in the day's money")
	var f := Friends.of(p.data)
	eq(f.week_taka, 1100, "this week's money")
	eq(f.given, 110, "a tenth given to the fund")
	eq(f.legs, {"bus": 4.0}, "today's leg")
	var c := Friends.card(p.data, DAY)
	eq(c.week_taka, 1100, "on the card")
	eq(c.legs_date, DAY, "with today's legs")
	check(not c.has("taka") and not c.has("save"), "nothing else of the save")


func test_old_saves_get_a_friends_part() -> void:
	var d := Progress.fresh()
	d.erase("friends")
	var f := Friends.of(d)
	eq(f.code, "", "filled in")
	f.code = "ABCDEF"
	eq(Friends.of(d).code, "ABCDEF", "the same dictionary each time")


func test_firestore_values_round_trip() -> void:
	var v := {"a": 1, "b": 2.5, "c": "x", "d": true, "e": [1, "y"], "f": {"g": 3}}
	var fields := Cloud.to_fields_of(v)
	eq(fields.fields.a, {"integerValue": "1"}, "whole numbers as text")
	eq(Cloud.from_fields(fields.fields), v, "back again")
