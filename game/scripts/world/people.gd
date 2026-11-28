## The real-looking people made from photos (tool/characters, the
## "characters" workflow), by who they play. Someone without a model here
## stays a cartoon hero (heroes.gd).
extends RefCounted

const Person = preload("res://scripts/world/person.gd")

const FILES := {"rickshaw": "rahim"}
const GESTURES := {"rickshaw": "ring"}


static func path(who: String) -> String:
	return "res://people/%s.glb" % FILES.get(who, "")


static func has(who: String) -> bool:
	return FILES.has(who) and ResourceLoader.exists(path(who))


## The person, facing -Z, standing on y = 0; null if there is none.
static func make(who: String) -> Node3D:
	if not has(who):
		return null
	var scene := load(path(who)) as PackedScene
	if scene == null:
		return null
	var p := Person.new()
	p.name = "Person"
	return p.setup(scene, str(GESTURES.get(who, "wave")))
