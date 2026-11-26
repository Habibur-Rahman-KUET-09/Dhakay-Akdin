## Notices when the game ended without coming back to the home screen (a
## crash, or the phone killing it) and keeps that run's log for the player
## to copy and send. Godot writes logs to user://logs when file logging is
## on (project.godot).
extends RefCounted

const MARK := "user://playing.txt"


## Call when a heavy scene starts: if the game dies before stop(), the
## next start knows.
static func start(what: String) -> void:
	var f := FileAccess.open(MARK, FileAccess.WRITE)
	if f:
		f.store_string("%s %s\n" % [what, Time.get_datetime_string_from_system()])
	print("[watch] start ", what)


static func stop() -> void:
	if FileAccess.file_exists(MARK):
		DirAccess.remove_absolute(MARK)


## The last run's log when that run did not end cleanly, else "".
static func last_crash() -> String:
	if not FileAccess.file_exists(MARK):
		return ""
	var what := FileAccess.get_file_as_string(MARK).strip_edges()
	stop()
	# The current log is this run's; the newest older one is the crashed run's.
	var logs := []
	for f in DirAccess.get_files_at("user://logs"):
		if f.ends_with(".log") and f != "godot.log":
			logs.append(f)
	logs.sort()
	var text := ""
	if not logs.is_empty():
		var lines := FileAccess.get_file_as_string("user://logs/" + logs.back()).split("\n")
		text = "\n".join(lines.slice(maxi(0, lines.size() - 80)))
	var info := "%s | %s | %s | %s" % [
		OS.get_model_name(), OS.get_name(), RenderingServer.get_video_adapter_name(),
		ProjectSettings.get_setting("application/config/version", "dev"),
	]
	# The game was sent to the background and Android closed it there
	# later: not a crash, though the report is still worth having.
	var kind := "Crash during"
	var tail := text.strip_edges().split("\n")
	if not tail.is_empty() and str(tail[tail.size() - 1]).contains("[app] paused"):
		kind = "Closed in the background during"
	return "%s: %s\n%s\n%s" % [kind, what, info, text]
