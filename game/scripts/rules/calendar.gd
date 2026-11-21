## The year in Dhaka, from content/calendar.json: how rainy, hot or foggy
## each month is (the monsoon from June to September, fog on winter
## mornings) and the festivals on fixed dates. Dates are "YYYY-MM-DD";
## no drawing here, so it can be tested.
extends RefCounted

const PATH := "res://content/calendar.json"

var months: Array = []
var festivals: Array = []


func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		months = parsed.months
		festivals = parsed.festivals


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
	return {}
