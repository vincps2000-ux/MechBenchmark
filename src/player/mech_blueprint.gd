# mech_blueprint.gd — The single JSON-like source-of-truth for a mech design.
#
# A blueprint is a plain Dictionary containing only JSON types (String, float/
# int, bool, Array, Dictionary, null). Parts are referenced by their stable
# MechCatalog id and customizations are stored as human-readable strings, so a
# serialized blueprint can be opened and read in any text editor.
#
# The gameplay mech (MechLoadout and its part Resources) is *generated* from a
# blueprint by MechFactory — the blueprint itself never holds Resources.
class_name MechBlueprint
extends RefCounted

const FORMAT := "mechsurvivors/mech"
const VERSION := 2

var data: Dictionary = {}


func _init(p_data: Dictionary = {}) -> void:
	data = p_data
	if data.is_empty():
		data = {
			"format": FORMAT,
			"version": VERSION,
			"legs": null,
			"torsos": [],
			"weapons": [],
			"light_weapons": [],
			"utility_modules": [],
			"module_grids": [],
			"bindings": {},
		}


## Deep copy — history snapshots must not share nested containers.
func duplicate_blueprint() -> MechBlueprint:
	return MechBlueprint.new(data.duplicate(true))


## Structural equality (used by undo history to skip no-op steps).
## Values are canonicalized through a JSON round trip so int/float
## representation differences don't matter.
func equals(other: MechBlueprint) -> bool:
	if other == null:
		return false
	return _canonical(data) == _canonical(other.data)


static func _canonical(dict: Dictionary) -> String:
	var json := JSON.new()
	if json.parse(JSON.stringify(dict)) != OK:
		return ""
	return JSON.stringify(json.data, "", true)


## Pretty-printed JSON, suitable for the downloadable mech file.
func to_json_text() -> String:
	return JSON.stringify(data, "\t", false) + "\n"


## Parses JSON text into a blueprint. Returns null when the text is not valid
## JSON or is not a mech blueprint document. Parsing is silent (no engine
## errors) so callers can probe arbitrary files safely.
static func from_json_text(text: String) -> MechBlueprint:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	if not (json.data is Dictionary):
		return null
	var dict := json.data as Dictionary
	if str(dict.get("format", "")) != FORMAT:
		return null
	if int(dict.get("version", 0)) <= 0:
		return null
	return MechBlueprint.new(dict)
