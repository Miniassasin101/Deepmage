@tool
class_name BuildProfile
extends Resource

## A reusable preset that points at your BuildSources (race/background/classes/feats/gear/rank).
## Assign this to CharacterSheet for quick iteration/testing.
##
## Optional: "Make Unique" duplicates the BuildSources (and their subresources)
## and marks them local to scene so edits won't affect other units.

@export var ui_name: String = "New Build Profile"

@export_group("Build Sources")
@export var race: BuildSource
@export var background: BuildSource
@export var martial_class: BuildSource
@export var magic_class: BuildSource
@export var progression: BuildSource
@export var feats: Array[BuildSource] = []
@export var gear_sources: Array[BuildSource] = []

@export_tool_button("Make Unique")
var make_unique_button = make_unique_sources


func apply_to_class_manager(cm: ClassManager) -> void:
	if cm == null:
		return

	# Copy references over so ClassManager can rebuild its compiled build state.
	cm.race = race
	cm.background = background
	cm.martial_class = martial_class
	cm.magic_class = magic_class
	cm.progression = progression

	# Duplicate arrays so the ClassManager can safely edit/replace its lists at runtime.
	cm.feats = feats.duplicate()
	cm.gear_sources = gear_sources.duplicate()


func make_unique_sources() -> void:
	# Deep-duplicate sources so edits to this preset won't affect other presets/units.
	# This is mainly for fast testing; long-term you’ll likely keep shared BuildSources.
	if race:
		race = _dup_local(race)
	if background:
		background = _dup_local(background)
	if martial_class:
		martial_class = _dup_local(martial_class)
	if magic_class:
		magic_class = _dup_local(magic_class)
	if progression:
		progression = _dup_local(progression)

	feats = _dup_array_local(feats)
	gear_sources = _dup_array_local(gear_sources)

	print_debug("BuildProfile: Made Sources Unique")


func _dup_local(src: BuildSource) -> BuildSource:
	var d: BuildSource = src.duplicate(true)
	d.resource_local_to_scene = true
	return d


func _dup_array_local(arr: Array[BuildSource]) -> Array[BuildSource]:
	var out: Array[BuildSource] = []
	for s: BuildSource in arr:
		if s == null:
			continue
		out.append(_dup_local(s))
	return out
