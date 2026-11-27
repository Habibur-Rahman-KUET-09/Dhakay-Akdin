## The home page's rules: what opens day by day (unlocks.gd), the
## player's own settings (prefs.gd), and Banglish words (strings.gd).
extends "res://tests/check.gd"

const Unlocks = preload("res://scripts/rules/unlocks.gd")
const Prefs = preload("res://scripts/ui/prefs.gd")
const Strings = preload("res://scripts/ui/strings.gd")


func test_one_more_thing_opens_each_day() -> void:
	var save := {"day": 0}
	eq(Unlocks.newly_open(save), [], "the first day: only the game")
	check(not Unlocks.is_open(save, "cards"), "no album yet")
	eq(Unlocks.next(save), {"feature": "cards", "days": 1}, "the album, after a day")
	save.day = 1
	eq(Unlocks.newly_open(save), ["cards"], "a day played: the album")
	eq(Unlocks.newly_open(save), [], "said once")
	save.day = 2
	eq(Unlocks.newly_open(save), ["pass"], "then the pass")
	save.day = 9
	eq(Unlocks.newly_open(save), ["friends", "board"], "a jump: both, in order")
	eq(Unlocks.next(save), {}, "all open")


func test_an_old_save_is_not_flooded_with_news() -> void:
	var save := {"day": 30}
	eq(Unlocks.newly_open(save), [], "a long-time player: everything open, nothing announced")
	check(Unlocks.is_open(save, "board"), "the lists are open")
	var just := {"day": 2}
	eq(Unlocks.newly_open(just), ["pass"], "an older save at day 2: the pass is news, the album is not")


func test_night_follows_the_clock_unless_chosen() -> void:
	Prefs.reload()
	var was := Prefs.theme()
	Prefs.save_theme("auto")
	check(Prefs.night(21), "9 in the evening: night")
	check(not Prefs.night(10), "10 in the morning: day")
	Prefs.save_theme("night")
	check(Prefs.night(10), "chosen: night all day")
	Prefs.save_theme(was)


func test_banglish_words_and_plain_digits() -> void:
	var s := Strings.new()
	s.lang = "bn"
	s.banglish = false
	eq(s.t("stFriends"), "বন্ধু", "Bangla")
	eq(s.num("12"), "১২", "Bangla digits")
	s.banglish = true
	eq(s.t("stFriends"), "Dostora", "Banglish where a line has it")
	eq(s.num("12"), "12", "plain digits")
	eq(s.t("stPass"), "Pass", "Banglish")
	s.lang = "en"
	eq(s.t("stFriends"), "Friends", "English stays English")


func test_a_quick_day_is_a_minute_with_a_smaller_target() -> void:
	var Balance = load("res://scripts/rules/balance.gd")
	var b = Balance.new()
	var was: bool = Balance.quick
	Balance.quick = false
	eq(b.n("tea_stall.day_seconds"), b.plain("tea_stall.day_seconds"), "a usual day")
	Balance.quick = true
	eq(b.n("tea_stall.day_seconds"), 60.0, "a quick day: a minute")
	eq(b.n("hawker.daily_target"), roundf(b.plain("hawker.daily_target") * 60.0 / b.plain("hawker.day_seconds")), "the target shrinks with it")
	eq(b.quick_share("bus"), 1.0, "the bus runs on trips, not a clock")
	Balance.quick = was
