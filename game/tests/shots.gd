## Takes screenshots of the home screen, the 3D town and the tea stall for
## review:
##   godot --path game --resolution 540x960 -s res://tests/shots.gd -- <out dir>
## Needs a display (CI runs it under xvfb with software OpenGL).
extends SceneTree

var out := "shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var home = load("res://scenes/main.tscn").instantiate()
	root.add_child(home)
	await _frames(20)
	_save("1-home")
	# The bottom of the page, then the settings over it.
	var scroll: ScrollContainer = home.find_children("*", "ScrollContainer", true, false)[0]
	scroll.scroll_vertical = 5000
	await _frames(5)
	_save("1b-home-bottom")
	home._open_settings()
	await _frames(5)
	_save("1c-settings")
	home.queue_free()
	await _frames(2)
	var drive = load("res://scenes/rickshaw.tscn").instantiate()
	root.add_child(drive)
	drive.shift.pedal = true
	await _frames(10)
	_save("2-start")
	await _seconds(6.0)
	_save("3-driving")
	drive.shift.swipe(1)
	await _seconds(4.0)
	_save("4-after-right-turn")
	drive.queue_free()
	await _frames(2)
	# Monir Mama's tea stall with everything bought (bench, second kettle,
	# awning, fridge), a few customers in, a cup of tea on the go.
	var save = load("res://scripts/rules/progress.gd").new(load("res://scripts/rules/balance.gd").new())
	save.data.tea.upgrades = ["bench", "second_kettle", "awning", "fridge"]
	save.save()
	var tea = load("res://scenes/tea.tscn").instantiate()
	root.add_child(tea)
	await _frames(20)
	await _seconds(9.0)
	tea._on_step("cup")
	tea._on_step("kettle")
	await _frames(3)
	_save("5-tea-stall")
	tea.queue_free()
	await _frames(2)
	# Babu's bus: on the way, a fare being taken.
	var bus = load("res://scenes/bus.tscn").instantiate()
	root.add_child(bus)
	await _frames(20)
	await _seconds(6.0)
	bus._on_next_fare()
	await _frames(3)
	_save("6-bus")
	bus.queue_free()
	await _frames(2)
	# A story chapter: Rahim Chacha's first day.
	var strings = load("res://scripts/ui/strings.gd").new()
	strings.lang = "bn"
	var story = load("res://scripts/rules/story.gd").new()
	var reader = load("res://scripts/ui/story_player.gd").new()
	reader.setup(story, story.chapter("rahim_1"), strings)
	root.add_child(reader)
	await _frames(10)
	_save("7-story")
	reader.queue_free()
	await _frames(2)
	# Old Dhaka, once the mohalla reaches level 5: brick lanes, rickshaws.
	save = load("res://scripts/rules/progress.gd").new(load("res://scripts/rules/balance.gd").new())
	save.data.mohalla.level = 5
	save.choose_area("old_dhaka")
	save.save()
	drive = load("res://scenes/rickshaw.tscn").instantiate()
	root.add_child(drive)
	drive.shift.pedal = true
	await _frames(10)
	await _seconds(6.0)
	_save("8-old-dhaka")
	drive.queue_free()
	await _frames(2)
	# The hand activities, each as it opens (with a little done).
	var lines = load("res://scripts/ui/strings.gd").new()
	lines.lang = "bn"
	var acts := {
		"pour": "act_pour", "stir": "act_sugar", "paan": "act_paan", "stove": "act_stove", "haggle": "act_haggle",
		"pump": "act_pump", "push": "act_push", "notes": "act_notes", "door": "act_door", "crowd": "act_crowd",
	}
	for name in acts:
		var act = load("res://scripts/ui/activities/%s.gd" % name).new()
		act.setup(lines, acts[name], acts[name] + "_hint")
		match name:
			"pour":
				act.height = 0.6
				act.strokes = [0.7, 0.6]
			"stir":
				act.wanted = 3
				act.spoons = 2
				act.turns = 1.4
			"paan":
				act.wants_zarda = false
				act.on_leaf = ["areca"]
			"stove":
				act.filled = func(): return 0.4
				act.on_fan = func(_s): return true
			"haggle":
				act.mood_of = func(a): return (a - 40) / 30.0
				act.start(40, 100)
				act.asked = 65
			"pump":
				act.pressure = 0.85
			"push":
				act.progress = 0.4
			"notes":
				act.notes = [50, 20, 100]
				act.on_sort = func(_n): return true
			"crowd":
				act.waiting = 3
		root.add_child(act)
		await _frames(6)
		_save("9-" + name)
		act.queue_free()
		await _frames(2)
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	await create_timer(s).timeout


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := out.path_join(name + ".png")
	img.save_png(path)
	print("saved ", path)
