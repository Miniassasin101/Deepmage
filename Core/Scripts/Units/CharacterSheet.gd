class_name CharacterSheet
extends Node

## Manages and controls all of the components to a unit like different actions, attributes, inventory, ect.
## Also will be able to make a mega-resource in order to save everything, or have character sheet templates.

@export_category("References")
@export var unit: Unit = null
@export var action_container: ActionContainer = null
@export var attributes_container: AttributesContainer = null


func get_action_container() -> ActionContainer:
	return action_container

func get_attributes_container() -> AttributesContainer:
	return attributes_container
