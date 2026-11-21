## Content files load and hold what the game reads from them.
extends "res://tests/check.gd"

const Balance = preload("res://scripts/rules/balance.gd")
const Strings = preload("res://scripts/ui/strings.gd")


## Every script compiles (a parse error elsewhere would only show on the
## phone).
func test_every_script_compiles() -> void:
	var dirs := ["res://scripts"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			dirs.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var script: GDScript = load(dir.path_join(f))
				check(script != null and script.can_instantiate(), "%s compiles" % f)


func test_balance_numbers() -> void:
	var b := Balance.new()
	check(b.n("rickshaw.speed_tiles_per_s") > 0.0, "rickshaw speed")
	check(b.n("rickshaw.waterlog_speed") > 0.0, "waterlog speed")
	eq(b.n("unlocks.tea_stall") >= 1.0, true, "tea stall unlock level")


func test_strings_in_both_languages() -> void:
	var s := Strings.new()
	for lang in ["bn", "en"]:
		s.lang = lang
		check(s.t("appTitle") != "appTitle", "%s title" % lang)
	s.lang = "bn"
	eq(s.t("rickshawToPlace", {"place": "চিড়িয়াখানা", "tiles": 12}), "চিড়িয়াখানা · আর 12 ব্লক", "placeholders")
	eq(s.t("noSuchKey"), "noSuchKey", "missing key shows itself")
