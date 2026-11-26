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
	eq(s.t("rickshawToPlace", {"place": "চিড়িয়াখানা", "tiles": 12}), "চিড়িয়াখানা · আর ১২ ব্লক", "placeholders, numbers in Bangla digits")
	eq(s.t("onPlayedBy", {"name": "Rakib99"}), "খেললেন Rakib99", "a chosen name stays as it is")
	s.lang = "en"
	eq(s.t("rickshawToPlace", {"place": "Zoo", "tiles": 12}).contains("12"), true, "English digits in English")
	eq(s.t("noSuchKey"), "noSuchKey", "missing key shows itself")


func test_rickshaw_paintings_and_tips_exist() -> void:
	var Goods = load("res://scripts/rules/goods.gd")
	var s := Strings.new()
	for l in Goods.looks("rickshaw"):
		if l.has("picture"):
			check(ResourceLoader.exists("res://textures/ui/%s.png" % l.picture), "painting %s" % l.picture)
		check(s.has("look_" + str(l.id)), "name of %s" % l.id)
	check(load("res://scripts/ui/tips.gd").count(s) >= 10, "loading tips")
