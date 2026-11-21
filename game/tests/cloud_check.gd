## Checks the online copy end to end against the real Firebase project,
## with the build's own settings (content/cloud.json): makes a nameless
## account, copies a save, reads it back, then deletes both. Prints the
## outcome, never the settings.
##   godot --headless --path game -s res://tests/cloud_check.gd
extends SceneTree

const Cloud = preload("res://scripts/ui/cloud.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cloud := Cloud.new()
	root.add_child(cloud)
	if not cloud.enabled():
		print("cloud: off (no content/cloud.json)")
		quit(0)
		return
	var e := await cloud.ensure_user()
	if e != "":
		print("cloud: sign-up failed: ", e)
		quit(1)
		return
	print("cloud: a nameless account made")
	e = await cloud.upload({"day": 7, "taka": 123, "note": "build check"})
	if e != "":
		print("cloud: copy failed: ", e)
		await cloud.delete_account()
		quit(1)
		return
	var back := await cloud.download()
	var ok: bool = not back.is_empty() and int(back.save.get("taka", 0)) == 123 and int(back.day) == 7
	print("cloud: read back ", "ok" if ok else "WRONG")
	e = await cloud.delete_account()
	print("cloud: cleaned up ", "ok" if e == "" else e)
	quit(0 if ok else 1)
