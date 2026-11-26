## Playing a story together on one phone (together.gd): how many are
## playing, then the opening scene, then each character's turn — the phone
## passed to whoever plays them, their scene, their hand activity, how it
## went — and the ending the turns earned, with its stars.
## Online (online.gd, from the room's lobby): each plays their own
## characters' turns on their own phone; for the others' turns the phone
## waits, then shows how it went. Every phone reaches the same ending.
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
const Online = preload("res://scripts/rules/online.gd")
const Cloud = preload("res://scripts/ui/cloud.gd")


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
## Online: the room ({} on one phone), the cloud, what I have written
## (my name and my turns' scores), the turn being waited for.
var online := {}
var cloud: Cloud
var _mine := {}
var _waiting := -1
var _beat := 0.0
## {uid: [last heartbeat, seconds unchanged]}: who has gone (Online.gone).
var _seen := {}


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
	if Online.active() and str(Online.room.kind) == "story":
		online = Online.room.duplicate(true)
		Online.room = {}
		cloud = Cloud.new()
		add_child(cloud)
		_mine = {"name": str(online.names.get(online.me, "")), "beat": 0}
		_send_mine()
		_begin((online.players as Array).size())
		return
	_ask_players()


## Online: a heartbeat every few seconds, so the others can tell when this
## phone has gone (closed, or put away) and let the bot play its turns.
func _process(dt: float) -> void:
	if online.is_empty() or step_i >= (story.steps as Array).size():
		return
	_beat += dt
	if _beat >= b.n("online.beat_s"):
		_beat = 0.0
		_mine.beat = int(_mine.get("beat", 0)) + 1
		_send_mine()


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
	if not online.is_empty():
		var owner := Online.owner_of(online.players, str(step.who))
		if owner == Online.BOT:
			# Nobody in the room plays this one: the bot does, at once.
			_their_score(step_i, Online.bot_score(str(online.code), step_i), s.t("onBot"))
		elif owner == str(online.me):
			_card(s.t("onYourTurn", {"name": who}), [s.t("onYourTurnLine")], [[s.t("tgReady"), Look.YELLOW, _my_turn]])
		else:
			_wait_for(step_i, owner, who)
		return
	if players > 1:
		# Pass the phone: whose turn it is.
		_card(s.t("tgTurn", {"name": who}), [s.t("tgPass", {"name": who})], [[s.t("tgReady"), Look.YELLOW, _play_step]])
	else:
		_play_step()


## My turn online: unless, while this phone was away, the others gave it
## to the bot (then that score stands, the same on every phone).
func _my_turn() -> void:
	var i := step_i
	var m := await cloud.moves(str(online.code))
	if i != step_i:
		return
	var bot := Online.bot_mark(m, i) if not m.has("_error") else -1.0
	if bot >= 0.0:
		_their_score(i, bot, s.t("onBot"))
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
	if not online.is_empty():
		_mine["s%d" % step_i] = got
		_send_mine()
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
	if not online.is_empty():
		_leave_room()
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
	if not online.is_empty():
		lines.append(s.t("onTogetherDone"))
		_card(_title(), lines, [[s.t("onAgain"), Look.YELLOW, func(): get_tree().change_scene_to_file.call_deferred("res://scenes/online.tscn")], [s.t("back"), Color.WHITE, _go_home]])
		return
	_card(_title(), lines, [[s.t("tgAgain"), Look.YELLOW, _again], [s.t("back"), Color.WHITE, _go_home]])


# --- Online: the others' turns -------------------------------------------------


## Someone else's turn: wait (asking every second or two) for their score,
## then show how it went. If their phone has gone quiet, the bot plays it
## (and says so to the others, so every phone takes the same score); after
## a long wait anyway, offer to play it here.
func _wait_for(i: int, owner: String, who: String) -> void:
	_waiting = i
	var name := str(online.names.get(owner, ""))
	_card(s.t("onTheirTurn", {"name": name, "who": who}), [s.t("onTheirTurnLine")], [])
	var waited := 0.0
	var offered := false
	while _waiting == i and is_inside_tree():
		await get_tree().create_timer(b.n("online.poll_s")).timeout
		if _waiting != i:
			return
		waited += b.n("online.poll_s")
		var m := await cloud.moves(str(online.code))
		if _waiting != i:
			return
		if m.has("_error"):
			continue
		# A turn another phone gave to the bot stands, even if its player
		# came back and played it late: every phone the same.
		var bot := Online.bot_mark(m, i)
		var score := Online.score_of(m, owner, i)
		if score >= 0.0 and bot < 0.0:
			_waiting = -1
			_their_score(i, score, name)
			return
		if bot < 0.0 and Online.gone(_seen, m, owner, b.n("online.poll_s"), b.n("online.gone_s")):
			bot = Online.bot_score(str(online.code), i)
			_mine["g%d" % i] = bot
			_send_mine()
		if bot >= 0.0:
			_waiting = -1
			print("[online] %s has gone: the bot plays step %d" % [name, i])
			_their_score(i, bot, s.t("onGoneBot", {"name": name}))
			return
		if waited >= b.n("online.wait_s") and not offered:
			offered = true
			_card(s.t("onTheirTurn", {"name": name, "who": who}), [s.t("onTooLong", {"name": name})],
				[[s.t("onPlayIt"), Look.YELLOW, func():
					_waiting = -1
					_play_step()]])


func _their_score(i: int, score: float, name: String) -> void:
	_bonus = 0.0
	scores.append(score)
	print("[together] step %d by %s: %.2f" % [i, name, score])
	var step: Dictionary = story.steps[i]
	var good := score >= b.n("together.good")
	var text: Dictionary = step.get("good" if good else "bad", {})
	_card(s.t("tgGood" if good else "tgBad"), [s.t("onPlayedBy", {"name": name}), str(text.get(s.lang, text.get("en", "")))],
		[[s.t("tgNext") if step_i + 1 < (story.steps as Array).size() else s.t("tgEnding"), Look.YELLOW, _next_step]])


## My part of the room, written again (a few tries).
func _send_mine() -> void:
	for attempt in 3:
		if await cloud.move_put(str(online.code), _mine) == "":
			return
		await get_tree().create_timer(1.0).timeout


## Done: my part taken away; the host closes the room a little later, once
## the others have had time to read the last turn.
func _leave_room() -> void:
	var code := str(online.code)
	var host := str(online.host) == str(online.me)
	await cloud.move_delete(code)
	if host:
		await get_tree().create_timer(20.0).timeout
		if is_inside_tree():
			await cloud.room_delete(code)


func _again() -> void:
	Together.next = str(story.id)
	get_tree().reload_current_scene()


func _go_home() -> void:
	CrashWatch.stop()
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
