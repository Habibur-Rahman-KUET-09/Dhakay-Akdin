## Runs every test_* method in the test files and quits with 1 on failure:
##   godot --headless --path game -s res://tests/run_tests.gd
## CI also fails on any SCRIPT ERROR in the output, so a test that crashes
## half way is caught too.
extends SceneTree

const FILES := ["res://tests/test_rules.gd", "res://tests/test_content.gd", "res://tests/test_progress.gd", "res://tests/test_tea.gd", "res://tests/test_bus.gd", "res://tests/test_story.gd", "res://tests/test_hands.gd", "res://tests/test_friends.gd", "res://tests/test_leaderboard.gd", "res://tests/test_fuchka.gd", "res://tests/test_odd_jobs.gd", "res://tests/test_league.gd", "res://tests/test_together.gd", "res://tests/test_delivery.gd", "res://tests/test_night.gd"]


func _initialize() -> void:
	var count := 0
	var failed: Array[String] = []
	for path in FILES:
		var script = load(path)
		if script == null:
			failed.append("cannot load " + path)
			continue
		for m in script.get_script_method_list():
			if not m.name.begins_with("test_"):
				continue
			var t = script.new()
			t.current = "%s %s" % [path.get_file(), m.name]
			t.call(m.name)
			count += 1
			failed.append_array(t.failures)
	for f in failed:
		printerr("FAIL " + f)
	print("%d tests, %d failures" % [count, failed.size()])
	quit(1 if failed.size() > 0 or count == 0 else 0)
