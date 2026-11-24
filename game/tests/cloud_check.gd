## Checks the online copy end to end against the real Firebase project,
## with the build's own settings (content/cloud.json): makes a nameless
## account, copies a save, reads it back, then deletes both. Prints the
## outcome, never the settings. Then the friends' parts the same way.
##   godot --headless --path game -s res://tests/cloud_check.gd
extends SceneTree

const Cloud = preload("res://scripts/ui/cloud.gd")
const Friends = preload("res://scripts/rules/friends.gd")


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
	var code: String = await _friends(cloud)
	e = await cloud.delete_account(code)
	print("cloud: cleaned up ", "ok" if e == "" else e)
	quit(0 if ok else 1)


## Friends: a code claimed and found, a card written and read, an item
## sent to oneself and taken. Says which step failed (the Firestore rules
## must allow codes, profiles and inbox). Returns the code to let go of.
func _friends(cloud) -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var code := ""
	for i in 3:
		code = Friends.make_code(rng)
		var e: String = await cloud.claim_code(code)
		if e == "":
			break
		if e != "ALREADY_EXISTS":
			print("cloud: friends: code failed: ", e)
			return ""
	if await cloud.find_code(code) != cloud.uid:
		print("cloud: friends: code not found back")
		return code
	var e2: String = await cloud.publish_card({"name": "check", "code": code, "week_taka": 55, "legs": {"tea": 4.5}})
	if e2 != "":
		print("cloud: friends: card failed: ", e2)
		return code
	var got: Dictionary = await cloud.cards([cloud.uid])
	var card_ok: bool = int(got.get(cloud.uid, {}).get("week_taka", 0)) == 55 and float(got.get(cloud.uid, {}).get("legs", {}).get("tea", 0.0)) == 4.5
	e2 = await cloud.send_item(cloud.uid, {"from": cloud.uid, "name": "check", "kind": "tea", "sticker": "", "date": "2026-01-01"})
	if e2 != "":
		print("cloud: friends: gift failed: ", e2)
		return code
	var inbox: Array = await cloud.take_inbox()
	var inbox_ok: bool = inbox.size() == 1 and str(inbox[0].get("kind", "")) == "tea"
	print("cloud: friends ", "ok" if card_ok and inbox_ok else "WRONG (card %s, inbox %s)" % [card_ok, inbox_ok])
	return code
