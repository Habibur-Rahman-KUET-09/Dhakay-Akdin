## The year in Dhaka, from content/calendar.json: how rainy, hot or foggy
## each month is (the monsoon from June to September, fog on winter
## mornings) and the festivals on fixed dates. Dates are "YYYY-MM-DD";
## no drawing here, so it can be tested.
extends RefCounted

const PATH := "res://content/calendar.json"

var months: Array = []
var festivals: Array = []
## The Eids, by date each year (they move with the moon), and Ramadan's
## first and last days each year.
var moon_festivals: Array = []
var ramadan_spans: Array = []


func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		months = parsed.months
		festivals = parsed.festivals
		moon_festivals = parsed.get("moon_festivals", [])
		ramadan_spans = parsed.get("ramadan", [])


## The month, 1 to 12 (0 if the date cannot be read).
static func month_of(date: String) -> int:
	if date.length() < 7:
		return 0
	var m := int(date.substr(5, 2))
	return m if m >= 1 and m <= 12 else 0


## The month's weather: {rain, hot, fog}; all plain for an unknown date.
func weather(date: String) -> Dictionary:
	var m := month_of(date)
	if m == 0 or months.size() < 12:
		return {"rain": 1.0, "hot": 1.0, "fog": 0.0}
	return months[m - 1]


## The chance of a shower today, from the usual chance and the month.
func rain_chance(usual: float, date: String) -> float:
	return clampf(usual * float(weather(date).rain), 0.0, 0.9)


func hot_chance(usual: float, date: String) -> float:
	return clampf(usual * float(weather(date).hot), 0.0, 0.9)


func fog_chance(date: String) -> float:
	return float(weather(date).fog)


## Today's festival, or {} on an ordinary day.
func festival(date: String) -> Dictionary:
	if date.length() < 10:
		return {}
	var md := date.substr(5, 5)
	for f in festivals:
		if f.date == md:
			return f
	var day := date.substr(0, 10)
	for f in moon_festivals:
		if (f.dates as Array).has(day):
			return f
	return {}


## How much busier the stalls are on a festival (1.0 on other days).
func crowd(date: String) -> float:
	return float(festival(date).get("crowd", 1.0))


## Whether the date is in the cricket season (the match on the stall's TV).
func cricket(date: String) -> bool:
	return date.length() >= 7 and (_cricket_months() as Array).has(month_of(date))


func _cricket_months() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://content/calendar.json"))
	return parsed.get("cricket_months", []) if typeof(parsed) == TYPE_DICTIONARY else []


## Whether the date is in Ramadan (people hurry home before iftar).
func ramadan(date: String) -> bool:
	if date.length() < 10:
		return false
	var day := date.substr(0, 10)
	for span in ramadan_spans:
		if day >= str(span[0]) and day <= str(span[1]):
			return true
	return false


## The day after `date` ("YYYY-MM-DD").
static func next_day(date: String) -> String:
	var t := Time.get_unix_time_from_datetime_string(date.substr(0, 10) + "T12:00:00")
	return Time.get_datetime_string_from_unix_time(t + 86400).substr(0, 10)


## Rafiq Chacha's morning news: what today (and tomorrow) bring, as
## [{key, values}] for the strings file: a festival today or tomorrow,
## Ramadan, and the month's weather (rain, fog, heat) so the day can be
## planned.
## The weather's seed for a date: the rickshaw's day draws its rain from it.
static func weather_seed(date: String) -> int:
	return hash("weather " + date)


## Whether Rahim Chacha's day on `date` has a shower, as Day decides it
## (the first draw from the date's weather, against the month's chance).
func rains_on(date: String, usual: float) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = weather_seed(date)
	return rng.randf() < rain_chance(usual, date)


func news(date: String, rain_usual := -1.0) -> Array:
	var out := []
	var today := festival(date)
	var tomorrow := festival(next_day(date))
	if not today.is_empty():
		out.append({"key": "news_festival_today", "values": {"name": today.name}})
	elif not tomorrow.is_empty():
		out.append({"key": "news_festival_tomorrow", "values": {"name": tomorrow.name}})
	if ramadan(date):
		out.append({"key": "news_ramadan", "values": {}})
	var w := weather(date)
	if rain_usual >= 0.0 and rains_on(next_day(date), rain_usual):
		out.append({"key": "news_rain_tomorrow", "values": {}})
	elif float(w.rain) >= 2.0:
		out.append({"key": "news_rain", "values": {}})
	elif float(w.fog) >= 0.5:
		out.append({"key": "news_fog", "values": {}})
	elif float(w.hot) >= 1.5:
		out.append({"key": "news_hot", "values": {}})
	if out.is_empty():
		out.append({"key": "news_quiet", "values": {}})
	return out
