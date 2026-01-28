class_name MagicController
extends Node

@export var unit: Unit

## Types unlocked by classes/gear/etc. Example: ["fire"]
@export var magic_types: PackedStringArray = []

## Spells the unit has learned (Skill resources flagged as spells).
@export var learned_spells: Array[Skill] = []


func has_magic_type(t: StringName) -> bool:
	return magic_types.has(String(t))


func add_magic_type(t: StringName) -> void:
	var s := String(t)
	if !magic_types.has(s):
		magic_types.append(s)


func remove_magic_type(t: StringName) -> void:
	magic_types.erase(String(t))


func knows_spell(skill: Skill) -> bool:
	if skill == null:
		return false
	var needle := _skill_id(skill)
	for s: Skill in learned_spells:
		if s != null and _skill_id(s) == needle:
			return true
	return false


func learn_spell(skill: Skill) -> bool:
	if skill == null:
		return false

	# Safety: only learn true spells.
	# If your Skill resource uses a different flag/tag, adjust this check.
	if !skill.is_spell and !skill.has_tag("spell") and skill.magic_type == &"":
		return false

	if knows_spell(skill):
		return false

	learned_spells.append(skill)
	return true


func forget_spell(skill: Skill) -> bool:
	if skill == null:
		return false
	var needle := _skill_id(skill)
	for s: Skill in learned_spells:
		if s != null and _skill_id(s) == needle:
			learned_spells.erase(s)
			return true
	return false


func clear_spells() -> void:
	learned_spells.clear()


func _skill_id(skill: Skill) -> StringName:
	# Prefer resource_path so duplicates/renames are stable.
	if !skill.resource_path.is_empty():
		return StringName(skill.resource_path)
	return StringName(skill.skill_name.to_snake_case())
