class_name UnitManager
extends Node


var units: Array[Unit] = []

## Units currently in the Downed state. Populated by register_downed(), cleared by register_revived().
## Does not include units that were never downed. Use get_all_units() for every unit in the scene.
var downed_units: Array[Unit] = []

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


## Returns only units that are currently alive (not downed).
## Use this for targeting, initiative rolls, and combat checks.
func get_living_units() -> Array[Unit]:
	var living: Array[Unit] = []
	for u in units:
		if u.is_alive():
			living.append(u)
	return living


## Returns a copy of the downed units list.
func get_downed_units() -> Array[Unit]:
	return downed_units.duplicate()


## Called by Unit.apply_downed() — tracks the unit as downed.
func register_downed(unit: Unit) -> void:
	if !downed_units.has(unit):
		downed_units.append(unit)


## Called by Unit.revive() — removes the unit from the downed list.
func register_revived(unit: Unit) -> void:
	downed_units.erase(unit)
