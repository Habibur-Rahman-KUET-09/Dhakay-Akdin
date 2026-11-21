## Fares, passengers and ratings for Rahim Chacha (§৪.১), from the numbers
## in balance.json. No drawing here, so it can be tested.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")

const TYPES := ["normal", "miser", "hurry", "elder"]

var b: Balance


func _init(balance: Balance) -> void:
	b = balance


func _n(key: String) -> float:
	return b.n("rickshaw." + key)


## Rounded to the nearest 5 taka (never below 5).
func round_fare(x: float) -> int:
	var step := _n("fare_round_to")
	return int(maxf(step, roundf(x / step) * step))


## The fair fare for a trip of `tiles` on the shortest legal way.
func fair(tiles: int) -> int:
	return round_fare(_n("fare_base") + tiles * _n("fare_per_tile"))


## Picks a passenger type by the weights in balance.json.
func pick_type(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for t in TYPES:
		total += b.n("rickshaw.passengers.%s.weight" % t)
	var r := rng.randf() * total
	for t in TYPES:
		r -= b.n("rickshaw.passengers.%s.weight" % t)
		if r <= 0.0:
			return t
	return TYPES[0]


## What a passenger of this type offers for a trip whose fair fare is `fair_fare`.
func offer(type: String, fair_fare: int, rng: RandomNumberGenerator) -> int:
	var range_of: Array = b.at("rickshaw.passengers.%s.offer" % type)
	return round_fare(fair_fare * rng.randf_range(float(range_of[0]), float(range_of[1])))


## Rahim Chacha's counter-offer.
func counter(fair_fare: int) -> int:
	return round_fare(fair_fare * _n("counter_offer_factor"))


func accepts_counter(type: String, rng: RandomNumberGenerator, rain := false) -> bool:
	var chance := b.n("rickshaw.passengers.%s.counter_accept" % type) + (_n("rain_counter_bonus") if rain else 0.0)
	return rng.randf() < chance


## Seconds the passenger expects the trip to take.
func eta(tiles: int, top_speed: float) -> float:
	return maxf(1.0, tiles / top_speed * _n("eta_slack"))


## Stars out of 5: one off for every 10% late, half off for every flooded
## tile with the passenger aboard; elders who were treated well give half
## a star more.
func stars(elapsed: float, expected: float, flooded: int, type: String) -> float:
	var late := maxf(0.0, elapsed / expected - 1.0)
	var s := 5.0 - floorf(late / _n("late_step") + 1e-6)
	s -= flooded * _n("waterlog_star_penalty")
	if type == "elder":
		s += 0.5
	return clampf(s, 1.0, 5.0)


func tip(given_stars: float) -> int:
	return int(_n("five_star_tip")) if given_stars >= 5.0 else 0
