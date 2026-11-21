## Shows a freshly built 3D scene a part at a time, behind the loading
## screen, noting each part in the log and the crash marker first. A phone
## whose graphics chip dies drawing something (a Redmi with an Adreno 610
## crashed on the first frame) then says which part it was.
extends RefCounted

const CrashWatch = preload("res://scripts/ui/crash_watch.gd")


## The things under root that draw: Label3Ds only, or everything else.
## Nodes in `leave_out` (and below them) are skipped.
static func geometry(root: Node, labels: bool, leave_out: Array = []) -> Array:
	var out := []
	var todo: Array[Node] = [root]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		if leave_out.has(n):
			continue
		todo.append_array(n.get_children())
		if n is GeometryInstance3D and (n is Label3D) == labels:
			out.append(n)
	return out


## groups: [[name, nodes], ...]. Hides them all, then shows one group a
## frame or two at a time. Nodes that were hidden to begin with stay so.
static func run(owner: Node, tag: String, groups: Array) -> void:
	var shown := {}
	for g in groups:
		for n in g[1]:
			if (n as Node3D).visible:
				shown[n] = true
				(n as Node3D).visible = false
	for g in groups:
		CrashWatch.start("%s: show %s" % [tag, g[0]])
		print("[show] ", g[0], " (", g[1].size(), ")")
		for n in g[1]:
			if shown.has(n):
				(n as Node3D).visible = true
		await owner.get_tree().process_frame
		await owner.get_tree().process_frame
