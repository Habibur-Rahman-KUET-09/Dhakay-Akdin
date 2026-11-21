## Takes screenshots of the home screen and the 3D town for review:
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
	await _frames(10)
	_save("2-start")
	await _seconds(3.0)
	_save("3-driving")
	drive.shift.swipe(1)
	await _seconds(4.0)
	_save("4-after-right-turn")
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
