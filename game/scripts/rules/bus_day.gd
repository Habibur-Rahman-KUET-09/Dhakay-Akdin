## Babu's trip on a local bus (§৪.২), Mirpur 10 to Motijheel through nine
## stops. Before each stop he calls its name: tap while the moving marker
## is in the middle of the bar for two more passengers, near it for one.
## Everyone who gets on owes a fare (10 taka, 5 more a stop, 35 at most)
## and pays with a note; Babu gives change from his bag, note by note.
## Short change starts an argument; too much is his own money gone. With
## no change in the bag he can owe it till their stop, or ask round for
## change (time). Students offer half. A passenger whose fare was never
## asked gets off without paying. On time at the end: a bonus. No drawing
## here, so it can be tested.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")

enum Event {
	CALL_OPEN, ## the next stop is near: call it now
	CALLED, ## called (last_call: "perfect", "good" or "miss")
	ARRIVED, ## at a stop (stop_i)
	BOARDED, ## someone got on
	ALIGHTED, ## someone got off
	SLIPPED, ## someone got off without having been asked to pay
	OWED_PAID, ## change owed was given at their stop
	OWED_SHORT, ## change owed could not be given: they went off angry
	DEPARTED, ## the bus pulls away
	SETTLED, ## a fare taken and the change right
	ARGUMENT, ## short change: an argument
	OVERPAID, ## too much change: Babu's loss
	SWAPPED, ## change got from the other passengers
	TRIP_OVER,
}

## Notes in use, smallest first.
const NOTES := [5, 10, 20, 50, 100, 500]
## What a note is broken into when Babu asks round for change.
const BREAK := {500: [100, 100, 100, 100, 50, 20, 20, 10], 100: [50, 20, 20, 10], 50: [20, 20, 10], 20: [10, 5, 5]}

var b: Balance
var rng := RandomNumberGenerator.new()
var route: Array = []
## The last stop reached (0 at the start, standing at Mirpur 10).
var stop_i := 0
var at_stop := true
var travel_left := 0.0
var dwell_left := 0.0
var clock := 0.0
## The time the trip should take, for the bonus.
var target_time := 0.0
var over := false
## Calling the next stop: open in the last seconds before it.
var call_open := false
var called := false
var call_t := 0.0
var last_call := ""
var extra_boarders := 0
## On the bus: {id, from, to, fare, kind ("normal" | "student"), note,
## paid, owed}.
var riders: Array = []
## The one whose fare is being taken, or {}.
var asking := {}
## The fare agreed with them (half for a student if Babu agrees).
var asking_fare := 0
## The change bag: note -> count.
var bag := {}
var bag_start := 0
var rating := 5.0
var boarded := 0
var slipped := 0
var arguments := 0
var overpaid := 0
var bonus := 0
## Seconds an argument holds everything up.
var locked_left := 0.0
var _next_id := 0


func _init(balance: Balance, seed_value := -1) -> void:
	b = balance
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	route = b.at("bus.route")
	# The change bag: small notes worth start_change (200: 4×5, 5×10, 4×20, 1×50).
	bag = {5: 4, 10: 5, 20: 4, 50: 1, 100: 0, 500: 0}
	bag_start = bag_value()
	var between: Array = b.at("bus.seconds_between_stops")
	var per_stop := (float(between[0]) + float(between[1])) / 2.0 + b.n("bus.dwell_s") + 4.0 * b.n("bus.dwell_per_person_s")
	target_time = (per_stop + 1.0) * (route.size() - 1) + 6.0
	_board_at(0, rng.randi_range(2, 4))
	dwell_left = b.n("bus.dwell_s") + 1.0


func stop_id(i: int) -> String:
	return route[clampi(i, 0, route.size() - 1)]


func bag_value() -> int:
	var total := 0
	for note in bag:
		total += int(note) * int(bag[note])
	return total


## What the trip has made: the bag's growth, and the bonus.
func earned() -> int:
	return bag_value() - bag_start + bonus


## Fare from stop a to stop b.
func fare(from_i: int, to_i: int) -> int:
	var f := int(b.n("bus.fare_min")) + int(b.n("bus.fare_per_stop")) * maxi(0, to_i - from_i - 1)
	return mini(f, int(b.n("bus.fare_max")))


## Where the calling marker is on its bar, 0 to 1 and back.
func marker() -> float:
	var x := fmod(call_t * 1.3, 2.0)
	return x if x <= 1.0 else 2.0 - x


func unpaid() -> Array:
	return riders.filter(func(r): return not r.paid)


func update(dt: float) -> Array:
	if over:
		return []
	var events := []
	clock += dt
	if locked_left > 0.0:
		locked_left -= dt
		return events
	if at_stop:
		dwell_left -= dt
		if dwell_left <= 0.0:
			if stop_i >= route.size() - 1:
				_finish(events)
				return events
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


## Babu calls the stop: how close the marker is to the middle decides how
## many more people get on.
func call_stop() -> Array:
	if not call_open:
		return []
	call_open = false
	called = true
	var off := absf(marker() - 0.5)
	if off <= b.n("bus.perfect_zone"):
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
	# Off: those for this stop. Unasked, they slip off without paying.
	for r in riders.duplicate():
		if r.to != stop_i:
			continue
		riders.erase(r)
		moved += 1
		if asking.get("id", -1) == r.id:
			asking = {}
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
	rating = clampf(rating, 1.0, 5.0)
	# On: more at the big stops, and more for a good call. Not at the end.
	if stop_i < route.size() - 1:
		var range_of: Array = b.at("bus.boarders")
		var n := rng.randi_range(int(range_of[0]), int(range_of[1]))
		if (b.at("bus.busy_stops") as Array).has(stop_id(stop_i)):
			n += 2
		n += extra_boarders
		n = mini(n, int(b.n("bus.seats")) + int(b.n("bus.standing")) - riders.size())
		moved += _board_at(stop_i, n)
		for i in n:
			events.append(Event.BOARDED)
	dwell_left = b.n("bus.dwell_s") + moved * b.n("bus.dwell_per_person_s")


## n people get on at stop i, each for a later stop.
func _board_at(i: int, n: int) -> int:
	for k in n:
		_next_id += 1
		var to := rng.randi_range(i + 1, route.size() - 1)
		var f := fare(i, to)
		var kind := "student" if rng.randf() < b.n("bus.student_chance") else "normal"
		riders.append({
			"id": _next_id, "from": i, "to": to, "fare": f, "kind": kind,
			"note": _note_for(f if kind == "normal" else int(f * b.n("bus.student_share"))),
			"paid": false, "owed": 0,
		})
		boarded += 1
	return n


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
			if r.note < asking_fare:
				r.note = _note_for(asking_fare)
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
	bag[note] = int(bag.get(note, 0)) + 1
	asking.paid = true
	asking = {}


func _finish(events: Array) -> void:
	over = true
	if clock <= target_time:
		bonus = int(b.n("bus.on_time_bonus"))
	riders.clear()
	events.append(Event.TRIP_OVER)
