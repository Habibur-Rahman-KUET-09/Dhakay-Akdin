## Spoken lines (content/voices.json; the speech files are made by
## tool/make_voices.py into voices/). One line at a time: a line asked for
## while another is being said waits its turn (at most two wait). Lines
## without a speech file, or with voices turned off, are skipped quietly,
## so the game plays the same before the voices are made.
extends Node

const SETTINGS := "user://settings.cfg"
const CONTENT := "res://content/voices.json"

## How many lines each group has, read once.
static var _sizes := {}

var _player: AudioStreamPlayer
var _queue: Array[String] = []


static func wanted() -> bool:
	var c := ConfigFile.new()
	if c.load(SETTINGS) == OK:
		return bool(c.get_value("sound", "voices", true))
	return true


static func save_wanted(value: bool) -> void:
	var c := ConfigFile.new()
	c.load(SETTINGS)
	c.set_value("sound", "voices", value)
	c.save(SETTINGS)


static func path_of(id: String) -> String:
	return "res://voices/%s.mp3" % id


## The speech file of a story line, by who says it and the Bangla words.
static func story_id(by: String, text: String) -> String:
	return "story_" + ("%s|%s" % [by, text]).md5_text().substr(0, 10)


## A group's lines that have speech: ["hail_normal_0", …].
static func ids_of(group: String) -> Array[String]:
	if _sizes.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONTENT))
		if typeof(parsed) == TYPE_DICTIONARY:
			for g in parsed.lines:
				_sizes[g] = (parsed.lines[g] as Array).size()
	var out: Array[String] = []
	for i in int(_sizes.get(group, 0)):
		var id := "%s_%d" % [group, i]
		if ResourceLoader.exists(path_of(id)):
			out.append(id)
	return out


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.finished.connect(_next)


## Says one of a group's lines, picked at random. `now` cuts off whatever
## is being said (a new passenger matters more than the last one's thanks).
func say(group: String, now := false) -> void:
	var ids := ids_of(group)
	if not ids.is_empty():
		play(ids[randi() % ids.size()], now)


func play(id: String, now := false) -> void:
	if not wanted() or not ResourceLoader.exists(path_of(id)):
		return
	if now:
		stop()
	if _player.playing:
		if _queue.size() < 2:
			_queue.append(id)
		return
	_player.stream = load(path_of(id))
	_player.play()


func stop() -> void:
	_queue.clear()
	_player.stop()


func _next() -> void:
	if not _queue.is_empty():
		_player.stream = load(path_of(_queue.pop_front()))
		_player.play()
