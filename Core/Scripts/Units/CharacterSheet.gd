@tool
class_name CharacterSheet
extends Node

## Manages and controls all of the components to a unit like different actions, attributes, inventory, ect.
## Also will be able to make a mega-resource in order to save everything, or have character sheet templates.

@export_category("References")
@export var unit: Unit = null
@export var action_container: ActionContainer = null
@export var attributes_container: AttributesContainer = null

@export_category("Attributes Preset")
@export var attributes_profile: AttributesProfile   # <- Pick a profile here per Unit

func _ready() -> void:
	if Engine.is_editor_hint():
		# Light editor wiring: push the profile into the container for you.
		if attributes_container and attributes_profile and attributes_container.profile != attributes_profile:
			attributes_container.profile = attributes_profile
		return

	if !unit:
		unit = get_parent() if get_parent() is Unit else null
	if unit and !unit.character_sheet:
		unit.character_sheet = self

	if action_container:
		action_container.unit = unit
	if attributes_container:
		attributes_container.unit = unit
		# Runtime safety: if the container has no snapshot, apply the profile now.
		if attributes_container.profile == null and attributes_profile != null:
			attributes_container.profile = attributes_profile

func get_action_container() -> ActionContainer:
	return action_container

func get_attributes_container() -> AttributesContainer:
	return attributes_container
