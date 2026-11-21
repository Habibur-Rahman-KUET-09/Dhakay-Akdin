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
