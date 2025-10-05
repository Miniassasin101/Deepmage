@tool
class_name CharacterSheet
extends Node

## Manages and controls all of the components to a unit like different actions, attributes, inventory, ect.
## Also will be able to make a mega-resource in order to save everything, or have character sheet templates.

@export_category("References")
@export var unit: Unit = null
@export var action_container: ActionContainer = null
@export var attributes_container: AttributesContainer = null

@export_category("Attributes")
@export var attributes: Array[Attribute] = []

func _ready() -> void:
	if Engine.is_editor_hint():
		if get_tree():
			await get_tree().process_frame
			await get_tree().process_frame
		if attributes_container:
			if !attributes_container.starting_attributes.is_empty() and attributes.is_empty():
				attributes.assign(attributes_container.starting_attributes)
				print_debug("attributes setup successfully")
			else:
				print_debug("starting attributes are empty or attributes arent empty")
		else:
			print_debug("no attributes container")
		return

	if !unit:
		unit = get_parent() if get_parent() is Unit else null
		
	if unit:
		if !unit.character_sheet:
			unit.character_sheet = self
	
	if action_container:
		action_container.unit = unit
	
	if attributes_container:
		attributes_container.unit = unit

func get_action_container() -> ActionContainer:
	return action_container

func get_attributes_container() -> AttributesContainer:
	return attributes_container
