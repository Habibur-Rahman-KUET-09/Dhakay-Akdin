## Kashem Bhai, the peanut seller on the buses (hawker_day.gd).
extends "res://tests/check.gd"

const HawkerDay = preload("res://scripts/rules/hawker_day.gd")
const Balance = preload("res://scripts/rules/balance.gd")

var b := Balance.new()


func _on_bus(owned: Array = []) -> HawkerDay:
	var h := HawkerDay.new(b, 4, owned)
	var events := []
	for i in 40:
		events.append_array(h.update(0.5))
		if events.has(HawkerDay.Event.BUS_CAME):
			break
	return h


func test_a_basket_from_the_wholesaler() -> void:
	var h := HawkerDay.new(b, 4)
	eq(h.stock, int(b.n("hawker.capacity")), "a full basket")
	eq(h.cost(), 0, "on credit: nothing owed yet")
	h.sold = 10
	h.dropped = 2
	eq(h.cost(), 12 * int(b.n("hawker.wholesale")), "pays for what he sold and dropped")
	var big := HawkerDay.new(b, 4, ["big_basket"])
	eq(big.stock, int(b.n("hawker.upgrades.big_basket.capacity")), "a bigger basket")


func test_waiting_then_on_a_bus() -> void:
	var h := HawkerDay.new(b, 4)
	check(not h.on_bus, "waiting at the stop")
	h = _on_bus()
	check(h.on_bus and h.at_stop, "on board")
	check(h.riders.size() >= 10, "a busload")
	check(h.buyers().is_empty(), "nobody's hand up before he calls")


func test_calling_and_selling() -> void:
	var h := _on_bus()
	for r in h.riders:
		r.wants = 1
		r.item = "badam"
	var shown := h.shout("perfect")
	eq(shown, h.riders.size(), "a perfect call: every one who wants some")
	eq(h.shout("perfect"), 0, "once a stretch")
	var r: Dictionary = h.buyers()[0]
	var stock := h.stock
	eq(h.sell(r.id), [HawkerDay.Event.SOLD], "sold")
	eq(h.stock, stock - 1, "a packet less")
	eq(h.money, h.price("badam"), "paid")
	eq(h.sell(r.id), [], "they have theirs")
	var m := _on_bus(["masala"])
	eq(m.price("badam"), int(b.n("hawker.upgrades.masala.price")), "masala sells dearer")
	var poor := _on_bus()
	for x in poor.riders:
		x.wants = 1
	var n := 0
	for i in 20:
		var t := _on_bus()
		for x in t.riders:
			x.wants = 1
		n += t.shout("miss")
	check(n < 20 * 10, "a poor call: fewer hands")
	eq(HawkerDay.call_quality(0.5), "perfect", "the middle")
	eq(HawkerDay.call_quality(0.65), "good", "near it")
	eq(HawkerDay.call_quality(0.95), "miss", "far off")


func test_off_before_the_conductor_throws_him_off() -> void:
	var h := _on_bus()
	var events := []
	for i in 400:
		events.append_array(h.update(0.25))
		if events.has(HawkerDay.Event.THROWN_OFF):
			break
	check(events.has(HawkerDay.Event.WARNED), "warned first")
	check(events.has(HawkerDay.Event.THROWN_OFF), "then put off")
	eq(h.thrown, 1, "counted")
	eq(h.dropped, int(b.n("hawker.dropped")), "a packet or two dropped")
	check(not h.on_bus, "at the stop again")
	var k := _on_bus()
	events = []
	for i in 200:
		events.append_array(k.update(0.25))
		if events.has(HawkerDay.Event.ARRIVED):
			break
	eq(k.get_off(), [HawkerDay.Event.GOT_OFF], "off at a stop")
	eq(k.thrown, 0, "not thrown")


func test_babus_bus_lets_him_ride_longer() -> void:
	var h := HawkerDay.new(b, 4)
	h._babu_at = 1
	var events := []
	for i in 40:
		events.append_array(h.update(0.5))
		if events.has(HawkerDay.Event.BUS_CAME):
			break
	check(events.has(HawkerDay.Event.BABU_BUS), "Babu's bus")
	eq(h.free_stops, int(b.n("hawker.babu_free_stops")), "four stops free")


func test_sold_out_and_the_day() -> void:
	var h := _on_bus()
	h.stock = 1
	for r in h.riders:
		r.wants = 2
		r.item = "badam"
		r.shown = true
	var got: Array = h.sell(h.riders[0].id)
	check(got.has(HawkerDay.Event.SOLD_OUT), "the last packet")
	eq(h.last_sale.n, 1, "only what was left")
	eq(h.sell(h.riders[1].id), [], "nothing more to sell")
	eq(h.earned(), h.money - h.cost(), "takings less the wholesaler")
	check(h.stars() >= 1.0 and h.stars() <= 5.0, "a rating")
	h.clock = h.day_seconds
	check(h.update(0.1).has(HawkerDay.Event.DAY_OVER), "the day ends")


func test_water_with_the_cooler() -> void:
	var h := _on_bus(["cooler"])
	h.riders[0].item = "water"
	h.riders[0].wants = 1
	h.riders[0].shown = true
	var stock := h.stock
	h.sell(h.riders[0].id)
	eq(h.money, int(b.n("hawker.water_price")), "a bottle of water")
	eq(h.stock, stock, "no peanuts used")
	eq(h.water_sold, 1, "counted")
