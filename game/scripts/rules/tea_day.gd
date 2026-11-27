## Monir Mama's day at his tea stall (§৪.৩): 6 am to 11 pm in a few
## minutes. Customers sit down on the bench with an order of one or two
## things and wait as long as their patience lasts. Each thing is made by
## tapping its steps in order (cup, kettle, milk, sugar for milk tea); the
## wrong step spoils it. The kettle holds eight cups and takes a while to
## fill again. More customers in the morning and evening rush. Rahim
## Chacha and Babu stop by once a day. Upgrades (§৪.৩): a new bench
## (more customers, more patient), a second kettle (one pours while the
## other fills), an awning (rain does not keep people away) and a fridge
## (cold drinks, most on a hot day). A shower on some days, a hot day on
## others. No drawing here, so it can be tested.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")
const Hands = preload("res://scripts/rules/activities.gd")
const Calendar = preload("res://scripts/rules/calendar.gd")

enum Event {
	ARRIVED, ## someone sat down
	GAVE, ## a thing was handed over
	SERVED, ## a customer got everything and paid
	LEFT, ## a customer gave up and went
	WRONG_STEP, ## that step does not make anything: start again
	NOBODY_WANTS, ## a finished thing nobody is waiting for: thrown away
	KETTLE_EMPTY, ## the last cup poured: fill it again
	REFILLING, ## the kettle is being filled
	KETTLE_FULL, ## and is full again
	RAIN_START,
	RAIN_END,
	DAY_OVER,
	WHO, ## ready, but whose order was it? Tap them (give_to)
	WRONG_PERSON, ## handed to someone who did not order it
	PHONE_PAY, ## paid by phone: check the SMS (settle_phone)
	CHANGED, ## someone changed their (hidden) order: last_change
	NO_CUPS, ## no clean cup left: wash some (wash)
	CREDIT_ASK, ## a neighbour asks to pay later: credit_ask (settle_credit)
}

## What can be ordered, in the order shown on the counter.
const STEPS := ["cup", "kettle", "milk", "sugar", "banana", "bun_jar", "betel_leaf", "areca", "lime"]
## How often each thing is ordered (out of 100); cold drinks once there is
## a fridge (twice as often on a hot day).
const ORDER_WEIGHTS := {"milk_tea": 40, "liquor_tea": 20, "bun": 14, "paan": 14, "banana": 12}
const COLD_DRINK_WEIGHT := 12
## Customer kinds (out of 100): patience comes from the balance file.
const KIND_WEIGHTS := {"normal": 60, "office": 25, "elder": 15}
const SEATS := 4

var b: Balance
var rng := RandomNumberGenerator.new()
var menu: Dictionary
var clock := 0.0
var day_seconds := 240.0
var over := false
## On the bench: {id, seat, kind, items (left to give), ordered (all),
## patience, left (seconds), bill, name}.
var customers: Array = []
## The steps tapped so far for the thing being made.
var tray: Array = []
var kettle := 8
var kettle_size := 8
var refill_left := 0.0
var money := 0
var tips := 0
var sold := 0
var served := 0
var happy := 0
var lost := 0
## The customer just served, for the screen: {name, kind, bill, tip, happy}.
var last_served := {}
## When Rahim Chacha and Babu come (seconds into the day); -1 once they
## have.
var rahim_at := -1.0
var babu_at := -1.0
var upgrades: Array = []
## The second kettle (with that upgrade): cups, and seconds left filling.
var has_second := false
var kettle2 := 0
var refill2_left := 0.0
## Weather: a shower from rain_at (or none), and a hot day.
var raining := false
var rain_at := -1.0
var rain_seconds := 60.0
var hot := false
var weather := RandomNumberGenerator.new()
## Today's festival (when the scene gives the date): happy customers tip
## half the festival's extra.
var festival := {}
## Ramadan: few come for tea while people fast; before iftar (17:00 to
## 19:00) everyone served also takes a packet of chola and peyaju.
var ramadan := false
var iftar_sold := 0
## "No, make it a black tea": {seat, from, to} of the last change.
var last_change := {}
## More or fewer customers than usual (a story day: the eviction, the
## cricket final), 1 as usual.
var arrival_factor := 1.0
var _weights := {}
## Things sold by kind (for the day's challenge).
var sold_items := {}
## The named neighbours who may stop by today (set by the scene), how they
## feel (id -> -5..5), and what happened with them: [{id, delta, what}].
var npc_pool: Array = []
var relations := {}
var npc_log: Array = []
var _next_in := 2.0
var _next_id := 0
## The hand activities (on when the scene says so): how well each step of
## the thing in hand was done (0–1; activities.gd), what each customer
## wants in it (sugar spoons in milk tea, zarda in paan), and cups made
## just right. Their own dice, so the rest plays the same.
var interactive := false
var perfect := 0
var _quality: Array = []
var _hand_rng := RandomNumberGenerator.new()
## Paid by phone (hands on): {fare, npc, sms} while the SMS is checked;
## what came of each; the mohalla level (harder fakes later).
var phone_pay := {}
var phone_log: Array = []
var level := 1
var _phone_rng := RandomNumberGenerator.new()
## Remembering orders (with the hands on): in the rush an order is said
## once and shown for a few seconds, then it is up to Monir Mama to
## remember it; Rahim Chacha and Babu are never asked, he knows their
## usual. Handing it to the right person (give_to) earns a little more;
## the wrong one costs them patience. How many were remembered today.
var memory := false
var remembered := 0
var mixed_up := 0
## Phase 6 (hands on). Cups: a tea takes a clean one, and the cup comes
## back dirty; with none clean, wash some. The credit book: now and then a
## neighbour asks to pay later ({npc, bill, items} in credit_ask while
## Monir Mama decides). `ledger` is the save's book (shared, so it carries
## over): [{npc, owed, written, days, tries}]; due ones are asked for at
## the start of a day (collect). Own dice.
var cups_total := 8
var cups_clean := 8
var cups_dirty := 0
var washed := 0
var credit_ask := {}
var ledger: Array = []
var credit_given := 0
var credit_collected := 0
var credit_lost := 0
var _credit_rng := RandomNumberGenerator.new()


func _init(balance: Balance, seed_value := -1, owned: Array = [], date := "") -> void:
	b = balance
	upgrades = owned
	if seed_value >= 0:
		rng.seed = seed_value
		weather.seed = seed_value + 7
		_hand_rng.seed = seed_value + 13
		_phone_rng.seed = seed_value + 17
		_credit_rng.seed = seed_value + 19
	else:
		rng.randomize()
		weather.randomize()
		_hand_rng.randomize()
		_phone_rng.randomize()
		_credit_rng.randomize()
	menu = (b.at("tea_stall.menu") as Dictionary).duplicate(true)
	day_seconds = b.n("tea_stall.day_seconds")
	kettle_size = int(b.n("tea_stall.kettle_cups"))
	kettle = kettle_size
	cups_total = int(b.n("tea_stall.cups"))
	cups_clean = cups_total
	rahim_at = rng.randf_range(0.2, 0.7) * day_seconds
	babu_at = weather.randf_range(0.4, 0.9) * day_seconds
	has_second = upgrades.has("second_kettle")
	if has_second:
		kettle2 = kettle_size
	_weights = ORDER_WEIGHTS.duplicate()
	# The month makes rain or heat likelier (the monsoon, April's heat).
	var rain_chance := b.n("tea_stall.rain_chance_per_day")
	var hot_chance := b.n("tea_stall.hot_chance_per_day")
	if date != "":
		var calendar := Calendar.new()
		rain_chance = calendar.rain_chance(rain_chance, date)
		hot_chance = calendar.hot_chance(hot_chance, date)
		festival = calendar.festival(date)
		ramadan = calendar.ramadan(date)
	if weather.randf() < rain_chance:
		rain_at = weather.randf_range(0.15, 0.75) * day_seconds
		rain_seconds = b.n("tea_stall.rain_seconds")
	elif weather.randf() < hot_chance:
		hot = true
	if upgrades.has("fridge"):
		menu["cold_drink"] = {"price": int(b.n("tea_stall.upgrades.fridge.price")), "steps": ["fridge"]}
		_weights["cold_drink"] = COLD_DRINK_WEIGHT * (2 if hot else 1)


func has(upgrade: String) -> bool:
	return upgrades.has(upgrade)


## The steps on the counter: the fridge too, once there is one.
func steps() -> Array:
	return STEPS + (["fridge"] if has("fridge") else [])


## Starts the day's shower now (tests).
func start_rain() -> void:
	rain_at = clock


## The hour of the day, 6.0 to 23.0.
func hour() -> float:
	return lerpf(b.n("tea_stall.start_hour"), b.n("tea_stall.end_hour"), clampf(clock / day_seconds, 0.0, 1.0))


## In the morning or evening rush?
## From level 3, now and then someone whose order is already hidden
## changes their tea (milk tea to black, or back): once each, said aloud.
func _change_orders(events: Array) -> void:
	if not memory or level < 3:
		return
	for c in customers:
		if c.has("changed") or not order_hidden(c) or c.kind in ["rahim", "babu"]:
			continue
		c["changed"] = true
		if _phone_rng.randf() >= b.n("tea_stall.change_chance"):
			continue
		var i := (c.items as Array).find("milk_tea")
		var to := "liquor_tea"
		if i < 0:
			i = (c.items as Array).find("liquor_tea")
			to = "milk_tea"
		if i < 0:
			continue
		var from: String = c.items[i]
		c.items[i] = to
		c.bill = int(c.bill) - price(from) + price(to)
		last_change = {"seat": int(c.seat), "from": from, "to": to, "kind": str(c.kind), "npc": str(c.get("npc", ""))}
		events.append(Event.CHANGED)


## Ramadan's hour before iftar, when the stall sells iftar too.
func iftar_time() -> bool:
	return ramadan and hour() >= 17.0 and hour() < 19.0


func rush() -> bool:
	var h := hour()
	for r in b.at("tea_stall.rush_hours"):
		if h >= float(r[0]) and h < float(r[1]):
			return true
	return false


func price(item: String) -> int:
	return int(menu[item].price)


func steps_of(item: String) -> Array:
	return menu[item].steps


## Average rating for the day, 1–5: the share of customers who went away
## happy.
func stars() -> float:
	var total := served + lost
	if total == 0:
		return 0.0
	return 1.0 + 4.0 * float(happy) / total


func update(dt: float) -> Array:
	if over:
		return []
	var events := []
	clock += dt
	if rain_at >= 0.0:
		var now := clock >= rain_at and clock < rain_at + rain_seconds
		if now != raining:
			raining = now
			events.append(Event.RAIN_START if now else Event.RAIN_END)
	if refill_left > 0.0:
		refill_left -= dt
		if refill_left <= 0.0:
			refill_left = 0.0
			kettle = kettle_size
			events.append(Event.KETTLE_FULL)
	if refill2_left > 0.0:
		refill2_left -= dt
		if refill2_left <= 0.0:
			refill2_left = 0.0
			kettle2 = kettle_size
			events.append(Event.KETTLE_FULL)
	for c in customers.duplicate():
		c.left -= dt
		if c.left <= 0.0:
			customers.erase(c)
			lost += 1
			if c.get("npc", "") != "":
				npc_log.append({"id": c.npc, "delta": -1, "what": "waited"})
			events.append(Event.LEFT)
	_change_orders(events)
	_next_in -= dt
	if _next_in <= 0.0:
		var every := b.n("tea_stall.rush_arrival_every_s" if rush() else "tea_stall.arrival_every_s")
		if has("bench"):
			every /= b.n("tea_stall.upgrades.bench.arrivals")
		# Rain keeps people away, unless there is an awning to sit under.
		if raining and not has("awning"):
			every /= b.n("tea_stall.rain_arrivals")
		if ramadan:
			every *= b.n("tea_stall.ramadan_day_arrivals") if hour() < 17.0 else 1.0
		every /= maxf(0.1, arrival_factor)
		_next_in = every * rng.randf_range(0.6, 1.4)
		if _arrive():
			events.append(Event.ARRIVED)
	if rahim_at >= 0.0 and clock >= rahim_at and _arrive("rahim"):
		rahim_at = -1.0
		events.append(Event.ARRIVED)
	if babu_at >= 0.0 and clock >= babu_at and _arrive("babu"):
		babu_at = -1.0
		events.append(Event.ARRIVED)
	if clock >= day_seconds:
		over = true
		customers.clear()
		events.append(Event.DAY_OVER)
	return events


func _free_seat() -> int:
	for seat in SEATS:
		if not customers.any(func(c): return c.seat == seat):
			return seat
	return -1


## Someone sits down, if there is room: a passer-by, or one of the
## regulars ("rahim": milk tea and a bun; "babu": black tea and paan).
func _arrive(regular := "") -> bool:
	var seat := _free_seat()
	if seat < 0:
		return false
	var kind := regular if regular != "" else _pick(KIND_WEIGHTS)
	var items := []
	if regular == "rahim":
		items = ["milk_tea", "bun"]
	elif regular == "babu":
		items = ["liquor_tea", "paan"]
	else:
		items = [_pick(_weights)]
		if rng.randf() < 0.35:
			items.append(_pick(_weights))
	var patience := b.n("tea_stall.patience_s." + ("normal" if regular != "" else kind)) + (4.0 if regular != "" else 0.0)
	if has("bench"):
		patience += b.n("tea_stall.upgrades.bench.patience_bonus_s")
	var bill := 0
	for it in items:
		bill += price(it)
	_next_id += 1
	var npc := ""
	if regular == "" and not npc_pool.is_empty() and rng.randf() < 0.2:
		npc = npc_pool.pop_back()
	var c := {
		"id": _next_id, "seat": seat, "kind": kind, "items": items.duplicate(), "ordered": items,
		"patience": patience, "left": patience, "bill": bill, "npc": npc,
		# Rahim Chacha takes two spoons; Babu chews his paan with zarda.
		"sugar": 2 if regular == "rahim" else _hand_rng.randi_range(1, 3),
		"zarda": true if regular == "babu" else _hand_rng.randf() < 0.5,
	}
	if memory and regular != "":
		c["hide_at"] = clock
	elif memory and rush():
		c["hide_at"] = clock + b.n("tea_stall.order_show_s")
	customers.append(c)
	return true


## Whether this customer's order is no longer shown (to be remembered).
func order_hidden(c: Dictionary) -> bool:
	return c.has("hide_at") and clock >= float(c.hide_at)


func _pick(weights: Dictionary) -> String:
	var total := 0
	for k in weights:
		total += int(weights[k])
	var roll := rng.randi_range(1, total)
	for k in weights:
		roll -= int(weights[k])
		if roll <= 0:
			return k
	return weights.keys()[0]


## The thing the tray makes exactly, or "".
func made() -> String:
	for item in menu:
		if steps_of(item) == tray:
			return item
	return ""


## Some menu thing starts with these steps.
func _leads_somewhere(steps: Array) -> bool:
	for item in menu:
		var s := steps_of(item)
		if s.size() >= steps.size() and s.slice(0, steps.size()) == steps:
			return true
	return false


## A waiting customer wants something that goes on from what is in the
## tray (milk tea after cup and kettle).
func _wanted_further() -> bool:
	for c in customers:
		for it in c.items:
			var s := steps_of(it)
			if s.size() > tray.size() and s.slice(0, tray.size()) == tray:
				return true
	return false


## Who would get `item` if it were handed over now: the one who has
## waited longest for it; {} if nobody.
func next_for(item: String) -> Dictionary:
	var who: Dictionary = {}
	for c in customers:
		if c.items.has(item) and (who.is_empty() or c.left < who.left):
			who = c
	return who


## The first-day guide: what to press next for the order waited on
## longest. A step ("cup", "kettle", …), "give" when it is made, "discard"
## when the tray has gone wrong, or "" with nobody waiting.
func guide_step() -> String:
	var first: Dictionary = {}
	for c in customers:
		if not (c.items as Array).is_empty() and (first.is_empty() or c.left < first.left):
			first = c
	if first.is_empty():
		return ""
	for it in first.items:
		var want := steps_of(it)
		if want == tray:
			return "give"
		if want.size() > tray.size() and want.slice(0, tray.size()) == tray:
			return _or_wash(str(want[tray.size()]))
	return "discard" if not tray.is_empty() else _or_wash(str(steps_of(first.items[0])[0]))


## A cup is wanted but none is clean: wash some first.
func _or_wash(step: String) -> String:
	return "wash" if step == "cup" and interactive and cups_clean <= 0 else step


## The spoons of sugar the next milk tea should have.
func sugar_wanted() -> int:
	return int(next_for("milk_tea").get("sugar", 2))


## Whether the next paan should have zarda.
func zarda_wanted() -> bool:
	return bool(next_for("paan").get("zarda", false))


## Fans the clay stove: a kettle on to fill fills `seconds` sooner. False
## if none is filling.
func fan(seconds: float) -> bool:
	if refill_left > 0.0:
		refill_left = maxf(0.0, refill_left - seconds)
		return true
	if refill2_left > 0.0:
		refill2_left = maxf(0.0, refill2_left - seconds)
		return true
	return false


## Taps a step at the counter; `quality` (0–1) is how well it was done by
## hand, or −1 when it was just tapped.
func tap(step: String, quality := -1.0) -> Array:
	if over:
		return []
	var pour_from := 0
	if step == "kettle":
		if kettle > 0 and refill_left <= 0.0:
			pour_from = 1
		elif has_second and kettle2 > 0 and refill2_left <= 0.0:
			pour_from = 2
		elif kettle <= 0 and refill_left <= 0.0:
			# Empty: tapping it puts it on to fill.
			refill_left = b.n("tea_stall.kettle_refill_s")
			return [Event.REFILLING]
		elif has_second and kettle2 <= 0 and refill2_left <= 0.0:
			refill2_left = b.n("tea_stall.kettle_refill_s")
			return [Event.REFILLING]
		else:
			return []
	# A cup: there must be a clean one (hands on).
	if step == "cup" and interactive and cups_clean <= 0 and not tray.has("cup"):
		return [Event.NO_CUPS]
	var next := tray.duplicate()
	next.append(step)
	if not _leads_somewhere(next):
		_clear_tray()
		_quality.clear()
		return [Event.WRONG_STEP]
	if step == "cup" and interactive:
		cups_clean -= 1
	if quality >= 0.0:
		_quality.append(quality)
	var events := []
	if pour_from == 1:
		kettle -= 1
	elif pour_from == 2:
		kettle2 -= 1
	if pour_from > 0 and has_second:
		# Two kettles: an empty one goes straight on to fill.
		if kettle == 0 and refill_left <= 0.0:
			refill_left = b.n("tea_stall.kettle_refill_s")
			events.append(Event.REFILLING)
		if kettle2 == 0 and refill2_left <= 0.0:
			refill2_left = b.n("tea_stall.kettle_refill_s")
			events.append(Event.REFILLING)
	elif pour_from == 1 and kettle == 0:
		events.append(Event.KETTLE_EMPTY)
	tray = next
	# Done, and nobody waits for more on top of it: hand it over.
	if made() != "" and not _wanted_further():
		events.append_array(give())
	return events


## Hands over what is in the tray to whoever has waited longest for it
## (among those whose order is still shown; when only remembered orders
## want it, the tray stays in hand: WHO).
func give() -> Array:
	var item := made()
	if item == "":
		return []
	var who: Dictionary = {}
	var hidden := false
	for c in customers:
		if not c.items.has(item):
			continue
		if order_hidden(c):
			hidden = true
		elif who.is_empty() or c.left < who.left:
			who = c
	if who.is_empty() and hidden:
		return [Event.WHO]
	_clear_tray()
	var q := _made_quality()
	if who.is_empty():
		return [Event.NOBODY_WANTS]
	return _hand(item, who, q)


## How well the thing in hand was made by hand (−1: not by hand at all);
## forgotten once asked.
func _made_quality() -> float:
	var q := -1.0
	if not _quality.is_empty():
		q = 0.0
		for x in _quality:
			q += float(x)
		q /= _quality.size()
	_quality.clear()
	return q


## Hands what is in the tray to whoever sits in `seat`: right, and it is
## theirs (a little more if it had to be remembered); wrong, and they
## wait longer for it, and it stays in hand.
func give_to(seat: int) -> Array:
	var item := made()
	if item == "":
		return []
	var who: Dictionary = {}
	for c in customers:
		if c.seat == seat:
			who = c
	if who.is_empty():
		return []
	if not who.items.has(item):
		who.left = maxf(1.0, who.left - 2.0)
		mixed_up += 1
		return [Event.WRONG_PERSON]
	_clear_tray()
	var q := _made_quality()
	if order_hidden(who):
		remembered += 1
		var extra := int(b.n("tea_stall.usual_tip" if who.kind in ["rahim", "babu"] else "tea_stall.remember_tip"))
		money += extra
		tips += extra
		who["remembered"] = int(who.get("remembered", 0)) + extra
	return _hand(item, who, q)


func _hand(item: String, who: Dictionary, q: float) -> Array:
	who.items.erase(item)
	money += price(item)
	sold += 1
	sold_items[item] = int(sold_items.get(item, 0)) + 1
	var events := [Event.GAVE]
	if who.items.is_empty():
		customers.erase(who)
		served += 1
		# Quick service (more than half their patience left): happy, and a tip.
		var glad: bool = who.left >= who.patience * 0.5
		# A badly made cup spoils it, however quick.
		if q >= 0.0 and q < 0.35:
			glad = false
		var tip := int(who.get("remembered", 0))
		var just_right := glad and q >= 0.85
		if just_right:
			perfect += 1
			tip += int(b.n("tea_stall.perfect_tip"))
			money += int(b.n("tea_stall.perfect_tip"))
			tips += int(b.n("tea_stall.perfect_tip"))
		if glad:
			happy += 1
			var t := maxi(1, roundi(who.bill * b.n("tea_stall.happy_tip_share"))) + roundi(float(festival.get("tip", 0)) * 0.5)
			tip += t
			money += t
			tips += t
		# A neighbour who thinks well of the stall leaves a bit more.
		var npc: String = who.get("npc", "")
		var thanks := npc != "" and int(relations.get(npc, 0)) >= 3
		if thanks:
			tip += 20
			money += 20
			tips += 20
		if npc != "" and glad:
			npc_log.append({"id": npc, "delta": 1, "what": "served"})
		last_served = {"kind": who.kind, "bill": who.bill, "tip": tip, "happy": glad, "npc": npc, "thanks": thanks, "perfect": just_right,
			"remembered": int(who.get("remembered", 0)) > 0}
		events.append(Event.SERVED)
		# Ramadan, before iftar: a packet of chola and peyaju with it.
		if iftar_time():
			var packet := int(b.n("tea_stall.iftar_price"))
			money += packet
			who.bill = int(who.bill) + packet
			iftar_sold += 1
		# A neighbour may ask to have it written in the book: the bill
		# waits on Monir Mama's answer.
		if interactive and npc != "" and credit_ask.is_empty() and _credit_rng.randf() < b.n("tea_stall.credit_chance"):
			credit_ask = {"npc": npc, "bill": int(who.bill), "items": (who.ordered as Array).duplicate()}
			money -= int(who.bill)
			events.append(Event.CREDIT_ASK)
		# Now and then the bill comes by phone: it waits for the SMS check.
		elif interactive and phone_pay.is_empty() and _phone_rng.randf() < b.n("tea_stall.phone_pay_chance"):
			var fake := _phone_rng.randf() < b.n("rickshaw.phone_fake_chance")
			phone_pay = {"fare": int(who.bill), "npc": npc, "sms": Hands.phone_sms(_phone_rng, int(who.bill), level, fake)}
			money -= int(who.bill)
			events.append(Event.PHONE_PAY)
	return events


## The SMS checked: the bill is taken unless a fake was believed; a real
## one called fake leaves them unhappy (and a neighbour remembers).
func settle_phone(said_fake: bool) -> String:
	if phone_pay.is_empty():
		return ""
	var result := Hands.phone_result(phone_pay.sms, said_fake)
	if result != "fooled":
		money += int(phone_pay.fare)
	if result == "wrong":
		happy = maxi(0, happy - 1)
		if str(phone_pay.npc) != "":
			npc_log.append({"id": phone_pay.npc, "delta": -1, "what": "doubted"})
	phone_log.append(result)
	phone_pay = {}
	return result


## Throws away what is in the tray.
func discard() -> void:
	_clear_tray()
	_quality.clear()


## Empties the tray: a cup in it is a dirty cup now (drunk from, or
## thrown out).
func _clear_tray() -> void:
	if interactive and tray.has("cup"):
		cups_dirty += 1
	tray.clear()


## Washes up to n dirty cups. Returns how many.
func wash(n: int) -> int:
	var k := clampi(n, 0, cups_dirty)
	cups_dirty -= k
	cups_clean += k
	washed += k
	return k


## Monir Mama's answer to "write it down, I'll pay later": `give` credit
## (the bill goes in the book as `written`; they are pleased) or not
## (they pay now, a little put out). Returns "cash", or ledger_result's
## word for what was written.
func settle_credit(give: bool, written := -1) -> String:
	if credit_ask.is_empty():
		return ""
	var ask := credit_ask
	credit_ask = {}
	var bill := int(ask.bill)
	if not give:
		money += bill
		npc_log.append({"id": ask.npc, "delta": -1, "what": "no_credit"})
		return "cash"
	if written < 0:
		written = bill
	ledger.append({"npc": ask.npc, "owed": bill, "written": written, "days": 0, "tries": 0})
	credit_given += bill
	npc_log.append({"id": ask.npc, "delta": 1, "what": "credit"})
	return Hands.ledger_result(written, bill)


## Everything still owed in the book.
func owed_total() -> int:
	var n := 0
	for e in ledger:
		n += int(e.written)
	return n


## The start of a day: a day older for everyone in the book; those due
## are asked, and pay (what was written; only what they had if more was
## written, and they are put out) or not. After a few times asked, the
## debt is given up. Returns [{npc, paid, amount}] for those asked.
func collect() -> Array:
	var out := []
	for e in ledger.duplicate():
		e.days = int(e.days) + 1
		if int(e.days) < int(b.n("tea_stall.credit_days")):
			continue
		var paid := _credit_rng.randf() < Hands.repay_chance(int(relations.get(e.npc, 0)))
		if paid:
			var amount := mini(int(e.written), int(e.owed))
			money += amount
			credit_collected += amount
			if int(e.written) > int(e.owed):
				npc_log.append({"id": e.npc, "delta": -1, "what": "overcharged"})
			ledger.erase(e)
			out.append({"npc": e.npc, "paid": true, "amount": amount})
			continue
		e.tries = int(e.tries) + 1
		out.append({"npc": e.npc, "paid": false, "amount": int(e.written)})
		if int(e.tries) >= int(b.n("tea_stall.credit_tries")):
			ledger.erase(e)
			credit_lost += int(e.written)
			npc_log.append({"id": e.npc, "delta": -1, "what": "unpaid"})
	return out
