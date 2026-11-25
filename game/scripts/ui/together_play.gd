## Playing a story together on one phone (together.gd): how many are
## playing, then the opening scene, then each character's turn — the phone
## passed to whoever plays them, their scene, their hand activity, how it
## went — and the ending the turns earned, with its stars.
extends Control

const Look = preload("res://scripts/ui/look.gd")
const Strings = preload("res://scripts/ui/strings.gd")
const Balance = preload("res://scripts/rules/balance.gd")
const Progress = preload("res://scripts/rules/progress.gd")
const Story = preload("res://scripts/rules/story.gd")
const Together = preload("res://scripts/rules/together.gd")
const StoryPlayer = preload("res://scripts/ui/story_player.gd")
const ReadAloud = preload("res://scripts/ui/read_aloud.gd")
const CrashWatch = preload("res://scripts/ui/crash_watch.gd")
const Hands = preload("res://scripts/rules/activities.gd")
const Door = preload("res://scripts/ui/activities/door.gd")
const Pour = preload("res://scripts/ui/activities/pour.gd")
const Push = preload("res://scripts/ui/activities/push.gd")
const Crowd = preload("res://scripts/ui/activities/crowd.gd")
const Pump = preload("res://scripts/ui/activities/pump.gd")
const Stir = preload("res://scripts/ui/activities/stir.gd")
const Balloons = preload("res://scripts/ui/activities/balloons.gd")
const Choose = preload("res://scripts/ui/activities/choose.gd")


var s := Strings.new()
var b: Balance
var progress: Progress
var together := Together.new()
var story_text := Story.new()
var story := {}
var players := 1
var scores: Array = []
var step_i := -1
## A choice's mark on the next step's score, and money it brought.
var _bonus := 0.0
var _taka := 0
var _page: Control


func _ready() -> void:
	s.lang = Strings.saved_lang()
	b = Balance.new()
	progress = Progress.new(b)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("1D1A1A")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	story = together.story(Together.next)
	Together.next = ""
	if story.is_empty():
		_go_home()
		return
	_ask_players()


func _title() -> String:
	return str(story.title.get(s.lang, story.title.en))


## A card in the middle of the screen with a title, lines and buttons.
func _card(title: String, lines: Array, buttons: Array) -> void:
	if _page != null:
		_page.queue_free()
	var room := Look.safe_insets(get_viewport())
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.card(Look.CREAM, 20, 3))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_top = room.x + 40
	panel.offset_bottom = -room.y - 40
	add_child(panel)
	_page = panel
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	var head := Look.title(title, 34)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(head)
	var said := PackedStringArray()
	for l in lines:
		var label := Look.label(str(l), 18, true)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(label)
		said.append(str(l))
	for bt in buttons:
		var button := Look.chunky(str(bt[0]), bt[1], Look.OUTLINE if bt[1] != Look.MAGENTA else Color.WHITE, 20)
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.custom_minimum_size = Vector2(0, 62)
		button.pressed.connect(bt[2])
		col.add_child(button)
	ReadAloud.say("%s। %s" % [title, " ".join(said)], s.lang)


## How many play: one plays every turn; two or three pass the phone.
func _ask_players() -> void:
	var about := str(story.about.get(s.lang, story.about.en))
	_card(_title(), [about, s.t("tgHowMany")], [
		[s.t("tgPlayers", {"n": 1}), Look.YELLOW, _begin.bind(1)],
		[s.t("tgPlayers", {"n": 2}), Look.YELLOW, _begin.bind(2)],
		[s.t("tgPlayers", {"n": 3}), Look.YELLOW, _begin.bind(3)],
		[s.t("back"), Color.WHITE, _go_home],
	])


func _begin(n: int) -> void:
	players = n
	CrashWatch.start("together: " + str(story.id))
	print("[together] ", story.id, ", ", n, " players")
	_scene(str(story.opening), _next_step)


## A story scene (story.json), then `then`.
func _scene(id: String, then: Callable) -> void:
	if _page != null:
		_page.queue_free()
		_page = null
	var sc := story_text.scene(id)
	if sc.is_empty():
		then.call()
		return
	var player := StoryPlayer.new()
	player.setup(story_text, sc, s)
	player.finished.connect(func(_id: String, effects: Dictionary):
		_bonus += float(effects.get("together", 0.0))
		_taka += int(effects.get("taka", 0))
		then.call())
	add_child(player)


func _next_step() -> void:
	step_i += 1
	if step_i >= (story.steps as Array).size():
		_ending()
		return
	var step: Dictionary = story.steps[step_i]
	var who := s.t(_name_key(str(step.who)))
	if players > 1:
		# Pass the phone: whose turn it is.
		_card(s.t("tgTurn", {"name": who}), [s.t("tgPass", {"name": who})], [[s.t("tgReady"), Look.YELLOW, _play_step]])
	else:
		_play_step()


func _name_key(cast_id: String) -> String:
	return {"babu": "busName", "monir": "teaName", "rahim": "rickshawName"}.get(cast_id, cast_id)


func _play_step() -> void:
	var step: Dictionary = story.steps[step_i]
	_scene(str(step.scene), _game.bind(step))


## The step's hand activity.
func _game(step: Dictionary) -> void:
	var act
	match str(step.game):
		"door":
			act = Door.new()
		"pour":
			act = Pour.new()
		"push":
			act = Push.new()
			# Pushing a little: Monir Mama's word about the dry lanes (a good
			# turn before) halves the way to go.
			var need := 1.0
			var helper := int(step.get("helped_by", -1))
			if helper >= 0 and helper < scores.size() and float(scores[helper]) >= b.n("together.good"):
				need = b.n("together.help_pushes")
			var pushed := [0.0, -1]
			act.on_push = func(hand: int) -> Array:
				pushed[0] = float(pushed[0]) + Hands.push_amount(hand, int(pushed[1]))
				pushed[1] = hand
				return [1] if float(pushed[0]) >= need else []
		"crowd":
			act = Crowd.new()
			act.waiting = 5
			act.on_push = func() -> Array: return [1]
		"pump":
			act = Pump.new()
		"stir":
			act = Stir.new()
			act.spoons_wanted = int(step.get("spoons", 2))
		"balloons":
			act = Balloons.new()
		"choose":
			act = Choose.new()
			act.rounds = step.get("rounds", [])
		_:
			_scored(0.5, null, step)
			return
	var key := str(step.get("title", "tg_" + str(step.game)))
	act.setup(s, key, key + "_hint")
	act.done.connect(_scored.bind(act, step))
	add_child(act)


func _scored(score: float, act, step: Dictionary) -> void:
	# Pushing out of the water: the quicker the better.
	if act != null and str(step.game) == "push" and not act.quick:
		score = Together.push_score(act.t)
	var got := Together.step_score(score, _bonus)
	_bonus = 0.0
	scores.append(got)
	print("[together] step %d (%s): %.2f" % [step_i, str(step.game), got])
	var good := got >= b.n("together.good")
	var text: Dictionary = step.get("good" if good else "bad", {})
	_card.call_deferred(s.t("tgGood" if good else "tgBad"), [str(text.get(s.lang, text.get("en", "")))],
		[[s.t("tgNext") if step_i + 1 < (story.steps as Array).size() else s.t("tgEnding"), Look.YELLOW, _next_step]])


## The ending the turns earned, its stars, and a better feeling at home
## for a good one.
func _ending() -> void:
	var rank := Together.ending(b, scores)
	var endings: Array = story.endings
	_scene(str(endings[rank]), _results.bind(rank))


func _results(rank: int) -> void:
	var got := Together.settle(progress.data, b, str(story.id), rank)
	if rank == 2:
		for who in Together.CAST:
			progress.add_family(who, 1)
	if _taka > 0:
		progress.data.taka = int(progress.data.taka) + _taka
	progress.save()
	load("res://scripts/ui/cloud.gd").backup(self, progress.data)
	CrashWatch.stop()
	print("[together] ending %d, %s" % [rank, str(got)])
	var lines := [s.t("tgEnd_%d" % rank)]
	if int(got.stars) > 0:
		lines.append(s.t("tgStars", {"n": int(got.stars)}))
	elif not got.best:
		lines.append(s.t("tgNoNewStars"))
	if rank == 2:
		lines.append(s.t("tgFamilyUp"))
	if _taka > 0:
		lines.append(s.t("tgTaka", {"n": _taka}))
	_card(_title(), lines, [[s.t("tgAgain"), Look.YELLOW, _again], [s.t("back"), Color.WHITE, _go_home]])


func _again() -> void:
	Together.next = str(story.id)
	get_tree().reload_current_scene()


func _go_home() -> void:
	CrashWatch.stop()
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
