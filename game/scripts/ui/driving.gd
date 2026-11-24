## How the player likes to drive, kept with the other settings. Easy
## driving: at a junction where the rickshaw would stop and wait, it takes
## the way to where it is going by itself (off unless chosen).
extends RefCounted

const SETTINGS := "user://settings.cfg"


static func easy() -> bool:
	var c := ConfigFile.new()
	if c.load(SETTINGS) == OK:
		return bool(c.get_value("play", "easy_driving", false))
	return false


static func save_easy(value: bool) -> void:
	var c := ConfigFile.new()
	c.load(SETTINGS)
	c.set_value("play", "easy_driving", value)
	c.save(SETTINGS)
