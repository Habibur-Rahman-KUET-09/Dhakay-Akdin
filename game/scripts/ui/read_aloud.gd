## Reading the screen out loud with the phone's own voice (its text to
## speech; on Android, Google's Bangla voice), for players who find
## reading hard: notices, a hand activity's instructions, the day's end.
## Off unless chosen; silent where the device has no voice for the
## language.
extends RefCounted

const SETTINGS := "user://settings.cfg"


static func wanted() -> bool:
	var c := ConfigFile.new()
	if c.load(SETTINGS) == OK:
		return bool(c.get_value("play", "read_aloud", false))
	return false


static func save_wanted(value: bool) -> void:
	var c := ConfigFile.new()
	c.load(SETTINGS)
	c.set_value("play", "read_aloud", value)
	c.save(SETTINGS)


## Says `text` in `lang` ("bn" or "en"), cutting off whatever was being
## read.
static func say(text: String, lang: String) -> void:
	if text.strip_edges() == "" or not wanted():
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	var voices := DisplayServer.tts_get_voices_for_language(lang)
	if voices.is_empty():
		return
	DisplayServer.tts_speak(text, voices[0], 80, 1.0, 1.0, 0, true)
