class_name CharacterSheet
extends Node

@export_category("References")
@export var unit: Unit = null
@export var action_container: ActionContainer = null
@export var attributes_container: AttributesContainer = null
@export var magic_controller: MagicController = null
@export var class_manager: ClassManager = null

@export_category("Attributes Preset")
@export var attributes_profile: AttributesProfile

@export_category("Build Preset")
@export var build_profile: BuildProfile

@export_category("Magic Preset")
@export var magic_types: Array[StringName] = []


func _ready() -> void:
	if !unit:
		unit = get_parent() if get_parent() is Unit else null
	if unit and !unit.character_sheet:
		unit.character_sheet = self

	if action_container:
		action_container.unit = unit
	if attributes_container:
		attributes_container.unit = unit
	if magic_controller:
		magic_controller.unit = unit

	# ClassManager is typically a child of CharacterSheet in your setup.
	if class_manager == null:
		class_manager = find_child("ClassManager", true, false) as ClassManager

	# Apply presets AFTER references are wired.
	call_deferred("_apply_presets")


func _apply_presets() -> void:
	_apply_attributes_profile()
	_apply_build_profile()
	_apply_magic_preset_fallback()


func _apply_attributes_profile() -> void:
	if attributes_container == null or attributes_profile == null:
		return

	# Calls a helper on AttributesContainer (shown below).
	# Keeps CharacterSheet clean and makes it reusable.
	attributes_container.apply_profile(attributes_profile)


func _apply_build_profile() -> void:
	if build_profile == null or class_manager == null:
		return

	# Push the preset into ClassManager, then rebuild.
	build_profile.apply_to_class_manager(class_manager)
	class_manager.call_deferred("rebuild_build")


func _apply_magic_preset_fallback() -> void:
	# Optional: If you’re not using ClassManager/build_profile on a unit,
	# this lets you quickly force magic types for testing.
	if build_profile != null:
		return
	if magic_controller == null:
		return

	var compiled: PackedStringArray = []
	for t: StringName in magic_types:
		var s := String(t)
		if !compiled.has(s):
			compiled.append(s)
	magic_controller.magic_types = compiled


func get_action_container() -> ActionContainer:
	return action_container

func get_attributes_container() -> AttributesContainer:
	return attributes_container
