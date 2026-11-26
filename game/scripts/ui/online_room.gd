## The room for playing at the same time on several phones (online.gd): open
## one (a story to play together, or a live rickshaw race) and get its
## code, or type a friend's code to come in. Then the lobby: the code in
## big letters, who is here and whom they play; the host starts once a
## friend is in, and every phone goes to the story or the race together.
extends Control

const Look = preload("res://scripts/ui/look.gd")
const Strings = preload("res://scripts/ui/strings.gd")
const Balance = preload("res://scripts/rules/balance.gd")
const Progress = preload("res://scripts/rules/progress.gd")
const Together = preload("res://scripts/rules/together.gd")
const Friends = preload("res://scripts/rules/friends.gd")
const Online = preload("res://scripts/rules/online.gd")
const Race = preload("res://scripts/rules/race.gd")
const Cloud = preload("res://scripts/ui/cloud.gd")
const ReadAloud = preload("res://scripts/ui/read_aloud.gd")

var s := Strings.new()
var b: Balance
var progress: Progress
var together := Together.new()
var cloud: Cloud
var _page: Control
## The room: its code, whether I opened it, its last fields; everyone's
## parts.
var _code := ""
var _host := false
var _room := {}
var _moves := {}
var _who_box: VBoxContainer
var _start: Button
var _status: Label
var _poll_left := 0.0
var _polling := false
var _going := false


func _ready() -> void:
	s.lang = Strings.saved_lang()
	b = Balance.new()
	progress = Progress.new(b)
	Online.room = {}
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("1D1A1A")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	cloud = Cloud.new()
	add_child(cloud)
	set_process(false)
	if not cloud.enabled():
		_card(s.t("onTitle"), [s.t("onOff")], [[s.t("back"), Color.WHITE, _go_home]])
		return
	_choose()


func _my_name() -> String:
	var n := str(Friends.of(progress.data).name)
	return n if n != "" else s.t("onNoName")


## A card in the middle of the screen: a title, lines, extra controls and
## buttons [text, colour, callable].
func _card(title: String, lines: Array, buttons: Array, extra: Array = []) -> VBoxContainer:
	if _page != null:
		_page.queue_free()
	var room := Look.safe_insets(get_viewport())
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.card(Look.CREAM, 20, 3))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_top = room.x + 30
	panel.offset_bottom = -room.y - 30
	add_child(panel)
	_page = panel
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(col)
	var head := Look.title(title, 32)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(head)
	for l in lines:
		var label := Look.label(str(l), 17, true)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(label)
	for x in extra:
		col.add_child(x)
	for bt in buttons:
		var button := Look.chunky(str(bt[0]), bt[1], Look.OUTLINE if bt[1] != Look.MAGENTA and bt[1] != Look.SKY_DARK else Color.WHITE, 19)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 58)
		button.pressed.connect(bt[2])
		if bt.size() > 3:
			button.name = str(bt[3])
		col.add_child(button)
	ReadAloud.say(title, s.lang)
	return col


# --- Open a room, or come into one ------------------------------------------------


func _choose() -> void:
	var buttons := []
	var open := progress.open_characters()
	for st in together.stories:
		if together.is_open(progress.data, open, str(st.id)):
			buttons.append([s.t("onStory", {"title": str(st.title.get(s.lang, st.title.en))}), Look.YELLOW, _create.bind("story", str(st.id)), "OnStory_" + str(st.id)])
	buttons.append([s.t("onRace"), Look.SKY_DARK, _create.bind("race", ""), "OnRace"])
	buttons.append([s.t("onJoin"), Look.MAGENTA, _ask_code, "OnJoin"])
	buttons.append([s.t("back"), Color.WHITE, _go_home])
	var lines := [s.t("onAbout")]
	if not together.is_open(progress.data, open, "flood"):
		lines.append(s.t("onStoryLocked"))
	_card(s.t("onTitle"), lines, buttons)


func _ask_code() -> void:
	var edit := LineEdit.new()
	edit.name = "OnCode"
	edit.placeholder_text = s.t("onCodeHint")
	edit.max_length = 8
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size = Vector2(0, 64)
	edit.add_theme_font_size_override("font_size", 30)
	edit.add_theme_font_override("font", Look.font(Look.BOLD))
	var go := func(): _join(edit.text)
	edit.text_submitted.connect(func(_t): go.call())
	_card(s.t("onJoin"), [s.t("onJoinAbout")], [[s.t("onJoinGo"), Look.MAGENTA, go, "OnJoinGo"], [s.t("back"), Color.WHITE, _choose]], [edit])
	edit.grab_focus.call_deferred()


func _busy(text: String) -> void:
	_card(s.t("onTitle"), [text], [])


func _failed(e: String) -> void:
	var key: String = {"NOT_FOUND": "onNoRoom", "FULL": "onFull", "STARTED": "onStarted", "NETWORK": "onNetwork", "BADCODE": "onBadCode"}.get(e, "onError")
	print("[online] failed: ", e)
	_card(s.t("onTitle"), [s.t(key, {"e": e})], [[s.t("back"), Color.WHITE, _choose]])


func _create(kind: String, story: String) -> void:
	_busy(s.t("onOpening"))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var e := ""
	for i in 4:
		_code = Friends.make_code(rng)
		e = await cloud.room_create(_code, {"kind": kind, "story": story, "area": progress.rickshaw_area(), "state": "lobby", "date": progress.date()})
		if e != "ALREADY_EXISTS":
			break
	if e != "":
		_failed(e)
		return
	_host = true
	print("[online] opened ", kind, " ", story)
	await cloud.move_put(_code, {"name": _my_name()})
	_lobby()


func _join(text: String) -> void:
	var code := Friends.clean_code(text)
	if not Friends.valid_code(code):
		_failed("BADCODE")
		return
	_busy(s.t("onJoining"))
	var e := await cloud.room_join(code, int(b.n("online.max_players")))
	if e != "":
		_failed(e)
		return
	_code = code
	_host = false
	await cloud.move_put(_code, {"name": _my_name()})
	_lobby()


# --- The lobby -------------------------------------------------------------------


func _lobby() -> void:
	var code := Look.title(_code, 54, Look.SKY_DARK)
	code.name = "OnCodeShown"
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_who_box = VBoxContainer.new()
	_who_box.add_theme_constant_override("separation", 6)
	_status = Look.label("", 15, true, Look.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons := []
	if _host:
		buttons.append([s.t("onStart"), Look.MAGENTA, _on_start, "OnStart"])
	buttons.append([s.t("onLeave"), Color.WHITE, _leave, "OnLeave"])
	var col := _card(s.t("onLobby"), [s.t("onShareCode") if _host else s.t("onWaitHost")], buttons, [code, _who_box, _status])
	if _host:
		_start = col.get_node("OnStart")
		_start.disabled = true
	_poll_left = 0.0
	set_process(true)


func _process(dt: float) -> void:
	_poll_left -= dt
	if _poll_left > 0.0 or _polling or _going:
		return
	_poll_left = b.n("online.poll_s")
	_poll()


func _poll() -> void:
	_polling = true
	var r := await cloud.room_get(_code)
	var m := await cloud.moves(_code)
	_polling = false
	if _going:
		return
	if r.has("_error"):
		if str(r._error) == "NOT_FOUND" or str(r._error) == "PERMISSION_DENIED":
			set_process(false)
			_card(s.t("onTitle"), [s.t("onClosed")], [[s.t("back"), Color.WHITE, _go_home]])
		else:
			_status.text = s.t("onNetwork")
		return
	_room = r
	if not m.has("_error"):
		_moves = m
	_show_who()
	if not _host and str(r.get("state", "")) == "go":
		var players: Array = r.get("players", [])
		if players.has(cloud.uid):
			_launch()
		else:
			set_process(false)
			_card(s.t("onTitle"), [s.t("onLeftOut")], [[s.t("back"), Color.WHITE, _go_home]])


## Who is here, and (for a story) whom each plays.
func _show_who() -> void:
	for k in _who_box.get_children():
		k.queue_free()
	var here := Online.present(_room.get("players", []), _moves)
	var roles := Online.roles(here)
	var story := together.story(str(_room.get("story", "")))
	for uid in here:
		var name := str(_moves[uid].get("name", ""))
		var text := name + (" " + s.t("onYou") if uid == cloud.uid else "") + (" · " + s.t("onHost") if uid == str(_room.get("host", "")) else "")
		if not story.is_empty():
			var parts := PackedStringArray()
			for who in roles.get(uid, []):
				parts.append(s.t({"rahim": "rickshawName", "monir": "teaName", "babu": "busName"}[who]))
			text += "\n" + s.t("onPlays", {"who": ", ".join(parts)})
		var row := Look.label(text, 16, true, Look.PARROT_DARK if uid == cloud.uid else Look.OUTLINE)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_who_box.add_child(row)
	if not story.is_empty() and roles.has(Online.BOT):
		var parts := PackedStringArray()
		for who in roles[Online.BOT]:
			parts.append(s.t({"rahim": "rickshawName", "monir": "teaName", "babu": "busName"}[who]))
		var bot := Look.label(s.t("onBotPlays", {"who": ", ".join(parts)}), 16, true, Look.OUTLINE)
		bot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_who_box.add_child(bot)
	var kind_line := s.t("onRaceKind") if str(_room.get("kind", "")) == "race" else s.t("onStoryKind", {"title": str(story.get("title", {}).get(s.lang, story.get("title", {}).get("en", "")))})
	_status.text = kind_line + "\n" + s.t("onCount", {"n": here.size(), "max": int(b.n("online.max_players"))})
	if _host and _start != null:
		_start.disabled = here.size() < 2


func _on_start() -> void:
	var here := Online.present(_room.get("players", []), _moves)
	if here.size() < 2:
		return
	_going = true
	var e := await cloud.room_update(_code, {"state": "go", "players": here})
	if e != "":
		_going = false
		_status.text = s.t("onError", {"e": e})
		return
	_room["players"] = here
	_launch()


## Into the story or the race, with the room's details for it.
func _launch() -> void:
	_going = true
	set_process(false)
	var names := {}
	for uid in _moves:
		names[uid] = str(_moves[uid].get("name", ""))
	Online.room = {"code": _code, "kind": str(_room.get("kind", "")), "host": str(_room.get("host", "")),
		"players": (_room.get("players", []) as Array).duplicate(), "me": cloud.uid, "names": names,
		"story": str(_room.get("story", "")), "area": str(_room.get("area", "mirpur")), "seed": _code}
	print("[online] go: ", Online.room.kind, ", ", Online.room.players.size(), " players")
	if Online.room.kind == "story":
		Together.next = Online.room.story
		get_tree().change_scene_to_file.call_deferred("res://scenes/together.tscn")
	else:
		Race.next = true
		get_tree().change_scene_to_file.call_deferred("res://scenes/rickshaw.tscn")


func _leave() -> void:
	set_process(false)
	_going = true
	_busy(s.t("onLeaving"))
	await cloud.move_delete(_code)
	if _host:
		await cloud.room_delete(_code)
	_go_home()


func _go_home() -> void:
	Online.room = {}
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
