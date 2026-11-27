## Julekha Khala's fuchka cart (fuchka_day.gd).
extends "res://tests/check.gd"

const FuchkaDay = preload("res://scripts/rules/fuchka_day.gd")
const Balance = preload("res://scripts/rules/balance.gd")

var b := Balance.new()


func _cart(owned: Array = []) -> FuchkaDay:
	var f := FuchkaDay.new(b, 3, owned)
	f.customers.clear()
	f.sumi_at = -1.0
	return f


func _someone(f: FuchkaDay, seat: int, sour: int, chilli: int, item := "fuchka") -> Dictionary:
	var c := {"id": 100 + seat, "seat": seat, "kind": "student", "item": item, "sour": sour, "chilli": chilli,
		"patience": 20.0, "left": 20.0, "npc": ""}
	f.customers.append(c)
	return c


func _plate(f: FuchkaDay, sour: int, chilli: int) -> void:
	f.step("puri")
	f.step("filling")
	for i in sour:
		f.step("sour")
	for i in chilli:
		f.step("chilli")


func test_a_plate_is_made_in_order() -> void:
	var f := _cart()
	eq(f.step("sour"), [FuchkaDay.Event.NOT_READY], "no plate yet")
	f.step("puri")
	eq(f.step("chilli"), [FuchkaDay.Event.NOT_READY], "fill it first")
	check(not f.plate_ready(), "not ready before the filling")
	f.step("filling")
	f.step("sour")
	f.step("sour")
	eq(f.plate.sour, 2, "two measures of sour")
	eq(f.step("doi"), [FuchkaDay.Event.NOT_READY], "no yoghurt pot yet")
	f.step("sour", 3.4)
	eq(f.plate.sour, 3, "poured by hand: the level it reached")


func test_just_right_a_little_off_or_wrong() -> void:
	var f := _cart()
	_someone(f, 0, 3, 1)
	_plate(f, 3, 1)
	eq(f.give_to(0), [FuchkaDay.Event.SERVED], "served")
	eq(f.last_served.verdict, "exact", "just as wanted")
	eq(f.money, 40 + 10 + 6, "price, the tip for just right, a little more")
	_someone(f, 1, 3, 1)
	_plate(f, 2, 1)
	f.give_to(1)
	eq(f.last_served.verdict, "close", "a little less sour")
	eq(f.happy, 2, "still glad")
	_someone(f, 2, 3, 1)
	_plate(f, 1, 3)
	f.give_to(2)
	eq(f.last_served.verdict, "wrong", "far off")
	eq(f.happy, 2, "not glad")
	eq(f.served, 3, "all three paid")
	eq(f.give_to(3), [FuchkaDay.Event.NOT_READY], "no plate in hand")


func test_rain_spoils_puris_unless_covered() -> void:
	var f := _cart()
	f.start_rain()
	f.update(0.1)
	check(f.raining, "raining")
	var c := _someone(f, 0, 2, 1)
	_plate(f, 2, 1)
	eq(f.distance(f.plate, c), 1, "soggy puris in the rain")
	f.cover()
	eq(f.distance(f.plate, c), 0, "covered: fine")
	f.update(f.rain_seconds + 1.0)
	check(not f.covered, "the plastic comes off after the rain")
	var u := _cart(["umbrella"])
	check(u.covered, "the umbrella covers it always")


func test_doi_fuchka_once_there_is_a_pot() -> void:
	var f := _cart(["doi"])
	check(f.steps().has("doi"), "a doi button")
	var c := _someone(f, 0, 2, 1, "doi_fuchka")
	_plate(f, 2, 1)
	eq(f.distance(f.plate, c), 2, "plain fuchka for a doi fuchka: wrong")
	f.step("doi")
	eq(f.distance(f.plate, c), 0, "with doi: right")
	f.give_to(0)
	eq(f.last_served.price, 60, "doi fuchka costs more")


func test_the_day_school_out_sumi_and_people() -> void:
	var f := FuchkaDay.new(b, 5, [], "2026-11-25")
	check(f.sumi_at > 0.0 and f.sumi_at < f.day_seconds * 0.2, "Sumi comes when school lets out")
	var came := 0
	var sumi := false
	while not f.over:
		var events := f.update(0.5)
		came += events.count(FuchkaDay.Event.ARRIVED)
		for c in f.customers:
			if c.kind == "sumi":
				sumi = true
				check(c.chilli == 0, "Sumi takes no chilli")
				f.customers.erase(c)
				break
	check(came > 20, "a day's customers (%d)" % came)
	check(sumi, "Sumi came")
	var winter := FuchkaDay.new(b, 5, [], "2026-01-10")
	check(winter.winter, "January is winter")


func test_first_day_guide_for_a_plate() -> void:
	var day := FuchkaDay.new(Balance.new(), 3)
	day.customers = [{"seat": 1, "left": 10.0, "item": "fuchka", "sour": 2, "chilli": 1}, {"seat": 0, "left": 20.0, "item": "fuchka", "sour": 0, "chilli": 0}]
	eq(day.guide_step(), {"step": "puri", "seat": 1}, "the longest wait first: crack the puris")
	day.step("puri", 1.0)
	eq(str(day.guide_step().step), "filling", "then the filling")
	day.step("filling")
	eq(str(day.guide_step().step), "sour", "sour to two")
	day.step("sour")
	day.step("sour")
	eq(str(day.guide_step().step), "chilli", "then chilli")
	day.step("chilli")
	eq(day.guide_step(), {"step": "give", "seat": 1}, "ready: their card")
	day.step("chilli")
	eq(str(day.guide_step().step), "discard", "too hot: throw it away")
	day.customers = []
	eq(day.guide_step(), {}, "nobody here")
