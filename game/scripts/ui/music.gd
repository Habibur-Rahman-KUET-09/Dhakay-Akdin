## The game's music: original folk-style loops made by
## tool/make_sounds.py (sounds/tune*.ogg), one for the home screen and one
## for each place, played over and over while music is wanted. Whether the
## player wants it is kept in the settings file.
extends AudioStreamPlayer

const SETTINGS := "user://settings.cfg"

## Which tune: "tune" (home), "tune_rickshaw", "tune_tea", "tune_bus",
## "tune_festival". Set before the player is added.
var track := "tune"


static func wanted() -> bool:
	var c := ConfigFile.new()
	if c.load(SETTINGS) == OK:
		return bool(c.get_value("sound", "music", true))
	return true


static func save_wanted(value: bool) -> void:
	var c := ConfigFile.new()
	c.load(SETTINGS)
	c.set_value("sound", "music", value)
	c.save(SETTINGS)


func _ready() -> void:
	stream = load("res://sounds/%s.ogg" % track)
	finished.connect(_again)
	if wanted():
		play()


func _again() -> void:
	if wanted():
		play()


## Turns the tune on or off, and remembers it.
func switch(value: bool) -> void:
	save_wanted(value)
	if value and not playing:
		play()
	elif not value:
		stop()
