class_name UnitManager
extends Node


var units: Array[Unit] = []

static var instance: UnitManager = null



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


func get_first_unit() -> Unit:
	if units.is_empty():
		return null
	
	return units.front()


func get_all_units() -> Array[Unit]:
	return units
