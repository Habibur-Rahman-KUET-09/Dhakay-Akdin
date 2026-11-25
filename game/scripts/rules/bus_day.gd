## Babu's day on a local bus (§৪.২): Mirpur 10 to Motijheel through nine
## stops, and back again in the afternoon. Before each stop he calls its
## name: tap while the moving marker is in the middle of the bar for two
## more passengers, near it for one. Everyone who gets on owes a fare (10
## taka, 5 more a stop, 35 at most) and pays with a note; Babu gives change
## from his bag, note by note. Short change starts an argument; too much
## is his own money gone. With no change he can owe it till their stop, or
## ask round for change (time). Students offer half.
## Seats: two at the front for the elderly, four for women; when one of
## them stands while someone else has their seat, Babu has to move that
## someone, or the passengers grumble (and over 30 aboard, the crowding
## does too). A few try to slip off at their stop without paying: catch
## them at the door. A ticket checker gets on now and then: everyone not
## yet asked for their fare costs a fine. On time at the end of a trip: a
## bonus. Upgrades: a notebook (no one can hide from the fare), a bigger
## change bag, a louder voice. No drawing here, so it can be tested.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")
const Hands = preload("res://scripts/rules/activities.gd")

enum Event {
	CALL_OPEN, ## the next stop is near: call it now
	CALLED, ## called (last_call: "perfect", "good" or "miss")
	ARRIVED, ## at a stop (stop_i)
	BOARDED, ## someone got on
	ALIGHTED, ## someone got off
	SLIPPED, ## someone got off without paying
	OWED_PAID, ## change owed was given at their stop
	OWED_SHORT, ## change owed could not be given: they went off angry
	DEPARTED, ## the bus pulls away
	SETTLED, ## a fare taken and the change right
	ARGUMENT, ## short change: an argument
	OVERPAID, ## too much change: Babu's loss
	SWAPPED, ## change got from the other passengers
	AT_DOOR, ## someone is slipping out without paying: catch them
	CAUGHT, ## caught at the door: paid
	CHECKER, ## the ticket checker got on (last_fine: what it cost)
	SEATED, ## a seat problem put right
	TRIP_OVER, ## the end of a trip (trip: which)
	DAY_OVER,
	TOO_EARLY, ## "go" slapped while people were still getting on
	DOOR_JAM, ## the standing crowd blocks the door: push them back
	PUSHED, ## one more got on after a push
	NEEDY_LEFT, ## someone who needed a seat gave up standing and got off
}

## Notes in use, smallest first.
const NOTES := [5, 10, 20, 50, 100, 500]
## What a note is broken into when Babu asks round for change.
const BREAK := {500: [100, 100, 100, 100, 50, 20, 20, 10], 100: [50, 20, 20, 10], 50: [20, 20, 10], 20: [10, 5, 5]}
## Seat numbers (models.gd bus_seats: front row first, left to right):
## the elderly's and the women's; seats run 0–23, standing places 24–33.
const ELDER_SEATS := [0, 1]
const WOMEN_SEATS := [2, 3, 6, 7]
const SEATS := 24
const STANDING := 10
## How long someone slipping out waits at the door.
const DOOR_S := 2.5

var b: Balance
var rng := RandomNumberGenerator.new()
var route: Array = []
var upgrades: Array = []
## Which trip of the day (1, 2), and how many there are.
var trip := 1
var trips := 2
## The last stop reached (0 at the start of a trip).
var stop_i := 0
var at_stop := true
var travel_left := 0.0
var dwell_left := 0.0
var clock := 0.0
var trip_clock := 0.0
## The time a trip should take, for the bonus.
var target_time := 0.0
var over := false
## Calling the next stop: open in the last seconds before it.
var call_open := false
var called := false
var call_t := 0.0
var last_call := ""
var extra_boarders := 0
## On the bus: {id, from, to, fare, kind ("normal" | "student" |
## "elder"), woman, evader, note, paid, owed, seat}.
var riders: Array = []
## The one whose fare is being taken, or {}.
var asking := {}
## The fare agreed with them (half for a student if Babu agrees).
var asking_fare := 0
## Slipping out at this stop: [{rider, left}].
var at_door: Array = []
## The stop on this trip where the checker gets on, or -1.
var checker_at := -1
var last_fine := 0
## The change bag: note -> count.
var bag := {}
var bag_start := 0
var rating := 5.0
var boarded := 0
var slipped := 0
var caught := 0
var arguments := 0
var overpaid := 0
var fines := 0
var bonus := 0
## Seconds an argument (or asking round) holds everything up.
var locked_left := 0.0
## The named neighbours who may ride today (set by the scene), how they
## feel (id -> -5..5), and what happened with them: [{id, delta, what}].
var npc_pool: Array = []
var relations := {}
var npc_log: Array = []
var _next_id := 0
## The hand activities (on when the scene says so). Fares taken go to
## `loose` (crumpled in his hand) until sorted between his fingers into
## the bag; at a stop the bus waits for two slaps on its side to go (and
## goes by itself, a little late, after go_wait_s); a crowd standing at
## the door leaves people outside until pushed back.
var interactive := false
var loose: Array = []
var jam_waiting := 0
var _go := false
var _go_wait := 0.0
## With the hands on: now and then someone who needs a seat gets on (ill,
## or a mother with a baby: "needy"), and everyone seated shows what they
## are like ("phone", "tired", "reading", "plain"), so Babu can choose whom
## to ask to stand. Own dice, so the rest of the day plays the same.
var _seat_rng := RandomNumberGenerator.new()
## Paid by phone (hands on): {fare, npc, sms} while the SMS is checked;
## what the phone brought in; what came of each; the mohalla level.
var phone_pay := {}
var phone_money := 0
var phone_log: Array = []
var level := 1
var _phone_rng := RandomNumberGenerator.new()
## Money sent home by phone today (a call from home), out of the day's.
var sent_home := 0
## Riders who needed a seat, never got one, and got off early.
var needy_left := 0
var last_seat := ""


func _init(balance: Balance, seed_value := -1, owned: Array = []) -> void:
	b = balance
	upgrades = owned
	if seed_value >= 0:
		rng.seed = seed_value
		_seat_rng.seed = seed_value + 31
		_phone_rng.seed = seed_value + 47
	else:
		rng.randomize()
		_seat_rng.randomize()
		_phone_rng.randomize()
	route = (b.at("bus.route") as Array).duplicate()
	trips = int(b.n("bus.trips_per_day"))
	# The change bag: small notes worth 200 (4×5, 5×10, 4×20, 1×50); twice
	# that with the bigger bag.
	var k := 2 if has("change_bag") else 1
	bag = {5: 4 * k, 10: 5 * k, 20: 4 * k, 50: 1 * k, 100: 0, 500: 0}
	bag_start = bag_value()
	var between: Array = b.at("bus.seconds_between_stops")
	var per_stop := (float(between[0]) + float(between[1])) / 2.0 + b.n("bus.dwell_s") + 4.0 * b.n("bus.dwell_per_person_s")
	target_time = (per_stop + 1.0) * (route.size() - 1) + 6.0
	_start_trip()


func has(upgrade: String) -> bool:
	return upgrades.has(upgrade)


func _start_trip() -> void:
	stop_i = 0
	at_stop = true
	trip_clock = 0.0
	checker_at = rng.randi_range(2, route.size() - 2) if rng.randf() < 0.5 else -1
	_board_at(0, rng.randi_range(2, 4))
	dwell_left = b.n("bus.dwell_s") + 1.0


func stop_id(i: int) -> String:
	return route[clampi(i, 0, route.size() - 1)]


func bag_value() -> int:
	var total := 0
	for note in bag:
		total += int(note) * int(bag[note])
	for note in loose:
		total += int(note)
	return total


## What the day has made: the bag's growth, bonuses, less fines.
func earned() -> int:
	return bag_value() - bag_start + bonus - fines - sent_home + phone_money


## Fare from stop a to stop b.
func fare(from_i: int, to_i: int) -> int:
	var f := int(b.n("bus.fare_min")) + int(b.n("bus.fare_per_stop")) * maxi(0, to_i - from_i - 1)
	return mini(f, int(b.n("bus.fare_max")))


## Where the calling marker is on its bar, 0 to 1 and back.
func marker() -> float:
	var x := fmod(call_t * 1.3, 2.0)
	return x if x <= 1.0 else 2.0 - x


## The middle of the bar that makes a perfect call (wider with a loud voice).
func perfect_zone() -> float:
	return b.n("bus.perfect_zone") * (b.n("bus.upgrades.loud_voice.perfect_zone") if has("loud_voice") else 1.0)


## Riders whose fare is still to take. Those meaning to slip out keep
## out of Babu's way, unless he keeps a notebook.
func unpaid() -> Array:
	return riders.filter(func(r): return not r.paid and (not r.evader or has("notebook")))


func update(dt: float) -> Array:
	if over:
		return []
	var events := []
	clock += dt
	trip_clock += dt
	_grumble(dt)
	if locked_left > 0.0:
		locked_left -= dt
		return events
	if at_stop:
		for d in at_door.duplicate():
			d.left -= dt
			if d.left <= 0.0:
				at_door.erase(d)
				riders.erase(d.rider)
				slipped += 1
				events.append(Event.SLIPPED)
				events.append(Event.ALIGHTED)
		dwell_left -= dt
		if dwell_left <= 0.0 and at_door.is_empty():
			if stop_i >= route.size() - 1:
				_end_trip(events)
				return events
			# By hand, the bus waits for Babu's two slaps; Ostad goes on his
			# own after a while, and the passengers notice.
			if interactive and not _go:
				_go_wait += dt
				if _go_wait < b.n("bus.go_wait_s"):
					return events
				rating = clampf(rating - 0.05, 1.0, 5.0)
			_go = false
			_go_wait = 0.0
			jam_waiting = 0
			at_stop = false
			var between: Array = b.at("bus.seconds_between_stops")
			travel_left = rng.randf_range(float(between[0]), float(between[1]))
			called = false
			last_call = ""
			extra_boarders = 0
			events.append(Event.DEPARTED)
		return events
	travel_left -= dt
	if call_open:
		call_t += dt
	elif not called and travel_left <= b.n("bus.call_window_s"):
		call_open = true
		call_t = 0.0
		events.append(Event.CALL_OPEN)
	if travel_left <= 0.0:
		call_open = false
		_arrive(events)
	return events


## The passengers grumble while an old man or a woman stands with their
## seat taken, and while the bus is packed.
func _grumble(dt: float) -> void:
	var drain := 0.0
	if not problems().is_empty():
		drain += 0.03 * problems().size()
	if riders.size() > int(b.n("bus.crowded_above")):
		drain += 0.02
	if drain > 0.0:
		rating = clampf(rating - drain * dt, 1.0, 5.0)


## Babu calls the stop: how close the marker is to the middle decides how
## many more people get on.
func call_stop() -> Array:
	if not call_open:
		return []
	call_open = false
	called = true
	var off := absf(marker() - 0.5)
	if off <= perfect_zone():
		last_call = "perfect"
		extra_boarders = int(b.n("bus.call_perfect_extra"))
	elif off <= b.n("bus.good_zone"):
		last_call = "good"
		extra_boarders = int(b.n("bus.call_good_extra"))
	else:
		last_call = "miss"
		extra_boarders = 0
	return [Event.CALLED]


func _arrive(events: Array) -> void:
	stop_i += 1
	at_stop = true
	if not called:
		last_call = "miss"
	events.append(Event.ARRIVED)
	var moved := 0
	# Off: those for this stop. Unasked, they slip off without paying;
	# those who meant to make for the door, and can be caught there.
	for r in riders.duplicate():
		if r.to != stop_i:
			continue
		if asking.get("id", -1) == r.id:
			asking = {}
		if not r.paid and r.evader:
			at_door.append({"rider": r, "left": DOOR_S})
			events.append(Event.AT_DOOR)
			continue
		riders.erase(r)
		moved += 1
		if not r.paid:
			slipped += 1
			events.append(Event.SLIPPED)
		elif r.owed > 0:
			var notes := make_change(r.owed)
			if notes.is_empty():
				rating -= b.n("bus.late_owed_star_penalty") * 2.0
				events.append(Event.OWED_SHORT)
			else:
				_take_from_bag(notes)
				events.append(Event.OWED_PAID)
		events.append(Event.ALIGHTED)
	# A mother with a child, or someone unwell, left standing since the
	# last stop: they give up and get off here (paid or not), and the bus
	# thinks less of Babu.
	for r in riders.duplicate():
		if r.kind == "needy" and int(r.seat) >= SEATS and int(r.from) < stop_i and r.to != stop_i:
			riders.erase(r)
			if asking.get("id", -1) == r.id:
				asking = {}
			needy_left += 1
			rating -= b.n("bus.needy_left_star_penalty")
			moved += 1
			events.append(Event.NEEDY_LEFT)
	rating = clampf(rating, 1.0, 5.0)
	# On: more at the big stops, and more for a good call. Not at the end.
	var before := _next_id
	if stop_i < route.size() - 1:
		var range_of: Array = b.at("bus.boarders")
		var n := rng.randi_range(int(range_of[0]), int(range_of[1]))
		if (b.at("bus.busy_stops") as Array).has(stop_id(stop_i)):
			n += 2
		n += extra_boarders
		n = mini(n, SEATS + STANDING - riders.size())
		# A crowd standing by the door: half wait outside until pushed in.
		var standing := riders.filter(func(r): return r.seat >= SEATS).size()
		if interactive and n > 1 and standing >= int(b.n("bus.jam_standing")):
			jam_waiting = floori(n / 2.0)
			n -= jam_waiting
			events.append(Event.DOOR_JAM)
		moved += _board_at(stop_i, n)
		for i in n:
			events.append(Event.BOARDED)
	# The checker: a fine for everyone on before this stop who has not paid.
	if stop_i == checker_at:
		var due := 0
		for r in riders:
			if not r.paid and r.id <= before:
				due += int(b.n("bus.checker_fine"))
		last_fine = due
		fines += due
		events.append(Event.CHECKER)
	dwell_left = b.n("bus.dwell_s") + moved * b.n("bus.dwell_per_person_s")


## n people get on at stop i, each for a later stop, and find a place.
func _board_at(i: int, n: int) -> int:
	for k in n:
		_next_id += 1
		var to := rng.randi_range(i + 1, route.size() - 1)
		var f := fare(i, to)
		var roll := rng.randf()
		var kind := "normal"
		if roll < b.n("bus.student_chance"):
			kind = "student"
		elif roll < b.n("bus.student_chance") + 0.12:
			kind = "elder"
		var npc := ""
		if not npc_pool.is_empty() and rng.randf() < 0.12:
			npc = npc_pool.pop_back()
			# Farhan is a college student; the others ride as themselves.
			kind = "student" if npc == "farhan" else "normal"
		var r := {
			"id": _next_id, "from": i, "to": to, "fare": f, "kind": kind,
			"woman": rng.randf() < 0.35, "evader": rng.randf() < b.n("bus.evader_chance") and npc == "",
			"note": _note_for(f if kind != "student" else int(f * b.n("bus.student_share"))),
			"paid": false, "owed": 0, "seat": -1, "npc": npc,
		}
		if interactive:
			_who_they_are(r)
		r.seat = _place_for(r)
		riders.append(r)
		boarded += 1
	return n


## Needy or not, and what they are like in their seat.
func _who_they_are(r: Dictionary) -> void:
	if r.kind == "normal" and r.npc == "" and _seat_rng.randf() < b.n("bus.needy_chance"):
		r.kind = "needy"
		r["need"] = "mother" if _seat_rng.randf() < 0.5 else "sick"
		if r.need == "mother":
			r.woman = true
	if r.kind == "student":
		r["trait"] = "reading"
	else:
		var x := _seat_rng.randf()
		r["trait"] = "phone" if x < 0.4 else ("tired" if x < 0.75 else "plain")


## The elderly and the needy come first for the front seats.
static func _first(r: Dictionary) -> bool:
	return r.kind == "elder" or r.kind == "needy"


func _taken() -> Dictionary:
	var out := {}
	for r in riders:
		if r.seat >= 0:
			out[r.seat] = r
	return out


## Where someone gets on to: the elderly to their seats, women to theirs,
## then any ordinary seat; a man takes a special seat only when nothing
## else is free; otherwise standing.
func _place_for(r: Dictionary) -> int:
	var taken := _taken()
	var order := []
	if _first(r):
		order = ELDER_SEATS.duplicate()
	if r.woman:
		order += WOMEN_SEATS
	for s in SEATS:
		if not ELDER_SEATS.has(s) and not WOMEN_SEATS.has(s):
			order.append(s)
	if not r.woman and not _first(r):
		order += WOMEN_SEATS + ELDER_SEATS
	for s in order:
		if not taken.has(s):
			return s
	for s in range(SEATS, SEATS + STANDING):
		if not taken.has(s):
			return s
	return -1


## Seat problems now: "elder" (an elderly passenger standing while
## someone else sits in an elder seat), "women" (a woman standing while a
## man sits in a women's seat).
func problems() -> Array:
	var out := []
	var standing := riders.filter(func(r): return r.seat >= SEATS or r.seat < 0)
	if standing.any(func(r): return _first(r)) \
			and riders.any(func(r): return ELDER_SEATS.has(r.seat) and not _first(r)):
		out.append("elder")
	if standing.any(func(r): return r.woman) \
			and riders.any(func(r): return WOMEN_SEATS.has(r.seat) and not r.woman):
		out.append("women")
	# Someone who needs a seat standing, the front seats rightly taken:
	# Babu must ask someone else to stand (give_seat).
	if not out.has("elder") and standing.any(func(r): return r.kind == "needy") \
			and not seat_candidates().is_empty():
		out.append("need")
	return out


## Whom Babu could ask to stand for someone who needs the seat: up to
## three seated, ordinary passengers (not the elderly, the needy, or a
## woman in a women's seat), different kinds of people where possible.
func seat_candidates() -> Array:
	var out := []
	var seen := {}
	for pass_i in 2:
		for r in riders:
			if r.seat < 0 or r.seat >= SEATS or _first(r) or (r.woman and WOMEN_SEATS.has(r.seat)) or out.has(r):
				continue
			var t: String = r.get("trait", "plain")
			if pass_i == 0 and seen.has(t):
				continue
			seen[t] = true
			out.append(r)
			if out.size() == 3:
				return out
	return out


## Asks rider `id` to stand for the needy passenger. How it goes depends
## on who it was (last_seat): glad to ("phone", "plain"), fine ("reading"),
## or cross after a long day's work ("tired": an argument).
func give_seat(id: int) -> Array:
	var needy := {}
	for r in riders:
		if r.kind == "needy" and (r.seat >= SEATS or r.seat < 0):
			needy = r
			break
	var who := {}
	for r in seat_candidates():
		if r.id == id:
			who = r
	if needy.is_empty() or who.is_empty():
		return []
	var seat: int = who.seat
	who.seat = needy.seat
	needy.seat = seat
	last_seat = who.get("trait", "plain")
	match last_seat:
		"tired":
			rating = clampf(rating - 0.1, 1.0, 5.0)
			arguments += 1
			return [Event.SEATED, Event.ARGUMENT]
		"reading":
			rating = clampf(rating + 0.1, 1.0, 5.0)
		_:
			rating = clampf(rating + 0.2, 1.0, 5.0)
	return [Event.SEATED]


## Babu moves whoever has the wrong seat to stand, and gives it to the
## one who should have it.
func fix(problem: String) -> Array:
	var seats: Array = ELDER_SEATS if problem == "elder" else WOMEN_SEATS
	var wrong: Dictionary = {}
	var right: Dictionary = {}
	for r in riders:
		var belongs: bool = _first(r) if problem == "elder" else r.woman
		if seats.has(r.seat) and not belongs and wrong.is_empty():
			wrong = r
		elif (r.seat >= SEATS or r.seat < 0) and belongs and right.is_empty():
			right = r
	if wrong.is_empty() or right.is_empty():
		return []
	var seat: int = wrong.seat
	wrong.seat = right.seat
	right.seat = seat
	rating = clampf(rating + 0.1, 1.0, 5.0)
	return [Event.SEATED]


## Two slaps on the side: go. At a stop with everyone on, the bus pulls
## away; while people are still getting on, it is too early (they are
## cross).
func slap_go() -> Array:
	if not at_stop:
		return []
	if dwell_left > 0.0 or not at_door.is_empty():
		rating = clampf(rating - 0.1, 1.0, 5.0)
		return [Event.TOO_EARLY]
	_go = true
	return []


## Pushes the crowd at the door back: one more waiting outside gets on.
func push_in() -> Array:
	if jam_waiting <= 0 or not at_stop or riders.size() >= SEATS + STANDING:
		return []
	jam_waiting -= 1
	_board_at(stop_i, 1)
	dwell_left = maxf(dwell_left, 0.0) + b.n("bus.dwell_per_person_s")
	return [Event.BOARDED, Event.PUSHED]


## Puts one crumpled note (its value) from his hand into the bag, between
## the right fingers. False if there is no such note loose.
func sort_note(note: int) -> bool:
	var i := loose.find(note)
	if i < 0:
		return false
	loose.remove_at(i)
	bag[note] = int(bag.get(note, 0)) + 1
	return true


## Sorts every loose note at once, at the cost of a few seconds.
func sort_all() -> void:
	if loose.is_empty():
		return
	for note in loose:
		bag[note] = int(bag.get(note, 0)) + 1
	loose.clear()
	locked_left = maxf(locked_left, b.n("bus.sort_all_s"))


## Catches the one slipping out at the door: they pay the fare, exactly.
func catch() -> Array:
	if at_door.is_empty():
		return []
	var d: Dictionary = at_door.pop_front()
	var r: Dictionary = d.rider
	riders.erase(r)
	var left := int(r.fare)
	for note in [20, 10, 5]:
		while left >= note:
			bag[note] = int(bag.get(note, 0)) + 1
			left -= note
	caught += 1
	rating = clampf(rating + 0.1, 1.0, 5.0)
	return [Event.CAUGHT, Event.ALIGHTED]


## What someone pays with: the exact fare sometimes, mostly the next note
## up, now and then a big one.
func _note_for(amount: int) -> int:
	var roll := rng.randf()
	if roll < b.n("bus.big_note_chance"):
		return 500
	if roll < 0.35 and NOTES.has(amount):
		return amount
	for note in NOTES:
		if note > amount:
			return note
	return 500


## Starts taking someone's fare. A student offers half: `full` says
## whether Babu asks for the whole fare (they pay it, but grudgingly).
func ask(id: int, full := true) -> Dictionary:
	if locked_left > 0.0:
		return {}
	for r in riders:
		if r.id == id and not r.paid:
			asking = r
			asking_fare = r.fare
			if r.kind == "student":
				if full:
					rating -= 0.2
				else:
					asking_fare = int(r.fare * b.n("bus.student_share"))
					rating += 0.2
				rating = clampf(rating, 1.0, 5.0)
				if r.get("npc", "") != "":
					npc_log.append({"id": r.npc, "delta": -1 if full else 1, "what": "student_fare"})
			if r.note < asking_fare:
				r.note = _note_for(asking_fare)
			# A neighbour who thinks well of Babu has the fare ready, exactly.
			if r.get("npc", "") != "" and int(relations.get(r.npc, 0)) >= 3:
				r.note = asking_fare
			return r
	return {}


## The change due to the one being asked.
func change_due() -> int:
	return int(asking.note) - asking_fare if not asking.is_empty() else 0


## Notes that make `amount` from the bag (big notes first), or {} if it
## cannot be made. {} for 0 too.
func make_change(amount: int) -> Dictionary:
	if amount <= 0:
		return {}
	var order := NOTES.duplicate()
	order.reverse()
	var out := {}
	return out if _fill(amount, order, 0, out) else {}


func _fill(left: int, order: Array, i: int, out: Dictionary) -> bool:
	if left == 0:
		return true
	if i >= order.size():
		return false
	var note: int = order[i]
	var most := mini(int(bag.get(note, 0)), left / note)
	for use in range(most, -1, -1):
		if use > 0:
			out[note] = use
		else:
			out.erase(note)
		if _fill(left - use * note, order, i + 1, out):
			return true
	out.erase(note)
	return false


func can_make(amount: int) -> bool:
	return amount <= 0 or not make_change(amount).is_empty()


func _take_from_bag(notes: Dictionary) -> void:
	for note in notes:
		bag[note] = int(bag[note]) - int(notes[note])


## Hands over these notes (note -> count) as change. Right: settled.
## Short: an argument, the notes back in the bag, try again. Too much:
## settled, and the extra is Babu's loss.
func give(notes: Dictionary) -> Array:
	if asking.is_empty() or locked_left > 0.0:
		return []
	var total := 0
	for note in notes:
		if int(bag.get(note, 0)) < int(notes[note]):
			return []
		total += int(note) * int(notes[note])
	var due := change_due()
	if total < due:
		if asking.get("npc", "") != "":
			npc_log.append({"id": asking.npc, "delta": -1, "what": "short_change"})
		arguments += 1
		rating = clampf(rating - 0.5, 1.0, 5.0)
		locked_left = b.n("bus.argument_s")
		return [Event.ARGUMENT]
	_take_from_bag(notes)
	_collect()
	if total > due:
		overpaid += total - due
		return [Event.OVERPAID]
	return [Event.SETTLED]


## Now and then (hands on) the one being asked pays by phone instead: the
## SMS to check (settle_phone). True when they do.
func offer_phone() -> bool:
	if not interactive or asking.is_empty() or not phone_pay.is_empty():
		return false
	if _phone_rng.randf() >= b.n("bus.phone_pay_chance"):
		return false
	var fake := _phone_rng.randf() < b.n("rickshaw.phone_fake_chance")
	phone_pay = {"fare": asking_fare, "npc": str(asking.get("npc", "")), "sms": Hands.phone_sms(_phone_rng, asking_fare, level, fake)}
	return true


## The SMS checked: the fare is in unless a fake was believed; a real one
## called fake costs half a star (and a neighbour remembers). They count
## as paid either way.
func settle_phone(said_fake: bool) -> String:
	if phone_pay.is_empty():
		return ""
	var result := Hands.phone_result(phone_pay.sms, said_fake)
	if result != "fooled":
		phone_money += int(phone_pay.fare)
	if result == "wrong":
		rating = clampf(rating - 0.5, 1.0, 5.0)
		if str(phone_pay.npc) != "":
			npc_log.append({"id": phone_pay.npc, "delta": -1, "what": "doubted"})
	if not asking.is_empty():
		asking.paid = true
		asking = {}
	phone_log.append(result)
	phone_pay = {}
	return result


## No change: Babu takes the note and owes the change till their stop.
func later() -> Array:
	if asking.is_empty():
		return []
	asking.owed = change_due()
	rating = clampf(rating - b.n("bus.late_owed_star_penalty"), 1.0, 5.0)
	_collect()
	return [Event.SETTLED]


## Asks round the bus for change: the biggest note in the bag is broken
## into small ones, at the cost of a few seconds.
func swap() -> Array:
	for note in [500, 100, 50, 20]:
		if int(bag.get(note, 0)) > 0:
			bag[note] = int(bag[note]) - 1
			for small in BREAK[note]:
				bag[small] = int(bag.get(small, 0)) + 1
			locked_left = b.n("bus.swap_s")
			return [Event.SWAPPED]
	return []


func _collect() -> void:
	var note := int(asking.note)
	if interactive:
		loose.append(note)
	else:
		bag[note] = int(bag.get(note, 0)) + 1
	asking.paid = true
	asking = {}


## The end of a trip: a bonus if on time; then the way back, or home.
func _end_trip(events: Array) -> void:
	if trip_clock <= target_time:
		bonus += int(b.n("bus.on_time_bonus"))
	riders.clear()
	at_door.clear()
	asking = {}
	events.append(Event.TRIP_OVER)
	if trip < trips:
		trip += 1
		route.reverse()
		_start_trip()
	else:
		over = true
		events.append(Event.DAY_OVER)
