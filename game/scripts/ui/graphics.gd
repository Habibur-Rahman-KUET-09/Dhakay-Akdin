## How much the 3D scenes ask of the phone's graphics chip: "high" (4x
## edge smoothing, glow, colour grading, sun shadows) or "low" (none of
## them). Some chips crash on the extras (an Adreno 610 did, on the first
## frame), so older Adrenos start on low, a crash in a 3D scene drops to
## low, and the player can switch on the mohalla screen.
extends RefCounted

const SETTINGS := "user://settings.cfg"


static func level() -> String:
	var c := ConfigFile.new()
	if c.load(SETTINGS) == OK:
		var v: String = c.get_value("graphics", "level", "")
		if v == "high" or v == "low":
			return v
	return default_level()


## Low in a phone's browser (WebGL there is far slower than the app) and
## on Adreno chips older than the 700s; high elsewhere.
static func default_level() -> String:
	if OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return "low"
	var gpu := RenderingServer.get_video_adapter_name()
	var re := RegEx.create_from_string("Adreno[^0-9]*([0-9]+)")
	var m := re.search(gpu)
	if m != null and int(m.get_string(1)) < 700:
		return "low"
	return "high"


static func save_level(value: String) -> void:
	var c := ConfigFile.new()
	c.load(SETTINGS)
	c.set_value("graphics", "level", value)
	c.save(SETTINGS)


## Everything extra off: how a 3D scene starts, before it is shown.
static func plain(viewport: Viewport, env: Environment, sun: DirectionalLight3D) -> void:
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	env.glow_enabled = false
	env.adjustment_enabled = false
	sun.shadow_enabled = false


## Sets up a 3D scene's viewport, environment and sun for the level.
static func apply(viewport: Viewport, env: Environment, sun: DirectionalLight3D) -> void:
	var high := level() == "high"
	viewport.msaa_3d = Viewport.MSAA_4X if high else Viewport.MSAA_DISABLED
	env.glow_enabled = high
	env.adjustment_enabled = high
	sun.shadow_enabled = high
	print("[graphics] ", level(), " on ", RenderingServer.get_video_adapter_name())
