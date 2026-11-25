## Ratul's deliveries (delivery.gd) and his days in the save.
extends "res://tests/check.gd"

const Delivery = preload("res://scripts/rules/delivery.gd")
const Day = preload("res://scripts/rules/day.gd")
const RoadMap = preload("res://scripts/rules/road_map.gd")
const Balance = preload("res://scripts/rules/balance.gd")

var b := Balance.new()


func _d(owned: Array = []) -> Delivery:
	var map: RoadMap = RoadMap.load_area("mirpur")
	return Delivery.new(b, map, 3, owned)


## Lets time pass until an order is offered.
func _offered(d: Delivery) -> Dictionary:
	for i in 200:
		if d.update(0.5, Vector2i(-1, -1)).has(Delivery.OFFER):
			return d.offer
	return {}


func test_kitchens_on_the_map() -> void:
	var d := _d()
	check(d.kitchens.size() >= 4, "several kitchens")
	for k in d.kitchens:
		check(d.map.is_road(k.at), "%s on a road" % k.id)
	var ats := d.kitchens.map(func(k): return k.at)
	for i in ats.size():
		check(ats.count(ats[i]) == 1, "one kitchen a spot")
	eq(_d().kitchens.map(func(k): return k.at), ats, "the same spots every day")


func test_an_order_offered_taken_or_gone() -> void:
	var d := _d()
	var o := _offered(d)
	check(not o.is_empty(), "an order comes in")
	var tiles := d.map.distance(o.kitchen.at, o.to)
	check(tiles >= int(b.n("delivery.min_tiles")) and tiles <= int(b.n("delivery.max_tiles")), "a fair ride: %d" % tiles)
	check(int(o.pay) > 0 and int(o.pay) % 5 == 0, "paid in fives")
	var events := []
	for i in 40:
		events.append_array(d.update(0.5, Vector2i(-1, -1)))
		if events.has(Delivery.OFFER_GONE):
			break
	check(events.has(Delivery.OFFER_GONE), "not taken: gone to someone else")
	eq(d.declined, 1, "counted")
	_offered(d)
	check(d.accept(), "taken")
	eq(d.active.size(), 1, "one order")
	eq(d.current().kind, "pick", "first to the kitchen")


func test_picked_up_when_ready_and_delivered_hot() -> void:
	var d := _d()
	_offered(d)
	d.accept()
	var o: Dictionary = d.active[0]
	var events := d.arrive(o.kitchen.at)
	eq(events, [Delivery.COOKING], "still cooking: wait")
	events = []
	for i in 40:
		events.append_array(d.update(0.5, o.kitchen.at))
		if events.has(Delivery.PICKED):
			break
	check(events.has(Delivery.PICKED), "picked up once ready, while waiting there")
	eq(d.current().kind, "drop", "then to the flat")
	d.gates = []
	events = d.arrive(o.to)
	eq(events, [Delivery.DELIVERED], "handed over")
	eq(d.last_done.stars, 5.0, "still hot: five stars")
	eq(d.money, int(o.pay) + int(b.n("delivery.tip_hot")), "pay and a tip")
	check(d.active.is_empty(), "done")


func test_food_goes_cold() -> void:
	var d := _d()
	_offered(d)
	d.accept()
	var o: Dictionary = d.active[0]
	o.ready_left = 0.0
	d.arrive(o.kitchen.at)
	check(o.picked, "picked")
	var events := []
	for i in 200:
		events.append_array(d.update(0.5, Vector2i(-1, -1)))
	check(events.has(Delivery.COLD), "cold after a while")
	d.gates = []
	d.arrive(o.to)
	eq(d.last_done.stars, 2.0, "cold food: two stars")
	eq(d.cold_ones, 1, "counted")
	eq(d.stars_for(0.5), 4.0, "warm: four")
	var bag := _d(["hot_bag"])
	_offered(bag)
	bag.accept()
	var o2: Dictionary = bag.active[0]
	o2.picked = true
	bag.update(10.0, Vector2i(-1, -1))
	d = _d()
	_offered(d)
	d.accept()
	var o3: Dictionary = d.active[0]
	o3.picked = true
	d.update(10.0, Vector2i(-1, -1))
	check(float(o2.heat) > float(o3.heat), "the insulated bag keeps it hot longer")


func test_the_guard_at_the_gate() -> void:
	var d := _d()
	b.raw.delivery.gate_chance = 1.0
	_offered(d)
	d.accept()
	var o: Dictionary = d.active[0]
	o.ready_left = 0.0
	d.arrive(o.kitchen.at)
	eq(d.arrive(o.to), [Delivery.GATE], "a word with the guard first")
	check((d.gate.question.options as Array).size() == 3, "three answers")
	eq(d.settle_gate(false), [Delivery.DELIVERED], "then handed over")
	eq(d.last_done.stars, 4.0, "a star less for a bad answer")
	b.raw.delivery.gate_chance = 0.3


func test_several_orders_and_the_arrow() -> void:
	var d := _d()
	for i in 3:
		_offered(d)
		d.accept()
	eq(d.active.size(), 3, "three at once")
	for i in 30:
		d.update(1.0, Vector2i(-1, -1))
	eq(d.offer, {}, "no more while three are on")
	var first: Dictionary = d.current()
	d.switch_target()
	check(d.current() != first, "the arrow on to another stop")
	d.switch_target()
	d.switch_target()
	eq(d.current(), first, "and round again")


func test_a_delivery_day() -> void:
	var map: RoadMap = RoadMap.load_area("mirpur")
	var day := Day.new(map, b, 5)
	var d := Delivery.new(b, map, 3)
	day.start_delivery(d)
	check(day.waiting.is_empty(), "no passengers waiting")
	eq(day.destination, day.driver.cell, "nowhere to go yet")
	day.hours_key = "delivery"
	eq(day.hour(), b.n("delivery.start_hour"), "his hours")
	var events := []
	for i in 60:
		events.append_array(day.update(0.5))
		if events.has(Delivery.OFFER):
			break
	check(events.has(Delivery.OFFER), "orders come in on the day")
	d.accept()
	day._aim()
	eq(day.destination, d.active[0].kitchen.at, "the arrow to the kitchen")


const Progress = preload("res://scripts/rules/progress.gd")
const Story = preload("res://scripts/rules/story.gd")
const PATH := "user://test_delivery_save.json"


func test_ratul_opens_at_level_seven_and_saves_his_evenings() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	var p := Progress.new(b, PATH)
	p.data.mohalla.level = 6
	check(not p.open_characters().has("delivery"), "not at level 6")
	p.data.mohalla.level = 7
	check(p.open_characters().has("delivery"), "open at level 7")
	var taka := int(p.data.taka)
	var out := p.apply_delivery_day({"earned": 400, "orders": 9, "stars": 4.6, "stats": {"orders": 9, "hot": 6, "earned": 400}})
	eq(int(out.earned), 400, "the evening's money")
	eq(int(p.data.delivery.orders), 9, "orders counted")
	eq(int(p.data.delivery.days), 1, "a day")
	eq(int(p.data.taka) - taka, 400 - int(out.fund), "saved, less the fund's tenth")
	eq(p.data.history[0].who, "delivery", "in the history")
	check(p.buy("hot_bag", "delivery") or int(p.data.taka) < p.price("hot_bag", "delivery"), "his upgrades are for sale")
	eq(p.next_upgrade("delivery") in ["gear_cycle", "hot_bag", "raincoat"], true, "from his own list")
	var st := Story.new()
	eq(st.chapters.filter(func(c): return c.who == "delivery").size(), 5, "five chapters of his own")
	check(not st.scene("family_high_delivery").is_empty() and not st.scene("family_low_delivery").is_empty(), "family scenes")
