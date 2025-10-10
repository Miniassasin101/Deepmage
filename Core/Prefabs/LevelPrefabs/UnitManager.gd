class_name UnitManager
extends Node


var units: Array[Unit] = []

static var instance: UnitManager = null

var unit_number: int = 1


func _ready() -> void:
	if instance != null:
		push_error("There's more than one UnitManager! - " + str(instance))
		queue_free()
		return
	instance = self
	
	initialize_units()

func initialize_units() -> void:
	# Iterate through all children and add those of type Unit to the units array
	for child in get_children():
		if child is Unit:
			if child in units:
				continue
			units.append(child)
			#setup_unit_stats(child)

func setup_unit_stats(in_unit: Unit) -> void:
	if !in_unit.character_sheet:
		return
	#var start: Array[Attribute] = in_unit.character_sheet.attributes_container.starting_attributes

	#in_unit.character_sheet.attributes_container.starting_attributes.assign(in_unit.character_sheet.attributes_profile.attributes)

func get_first_unit() -> Unit:
	if units.is_empty():
		return null
	
	return units.front()


func get_unit_by_name(in_name: String) -> Unit:
	for unit in units:
		if unit.ui_name.to_pascal_case() == in_name.to_pascal_case():
			return unit
	
	return null



func get_all_units() -> Array[Unit]:
	return units
