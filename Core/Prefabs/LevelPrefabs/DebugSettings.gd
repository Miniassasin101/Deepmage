class_name DebugSettings
extends Node

@export var control_enemy_debug: bool = true



static var instance: DebugSettings = null



# Called when the node enters the scene tree
func _ready() -> void:
	if instance != null:
		push_error("There's more than one DebugSettings! - " + str(instance))
		queue_free()
		return
	instance = self


func _unhandled_input(_event: InputEvent) -> void:
	if !(Input.is_action_just_pressed("testkey_n") and Input.is_action_pressed("testkey_c")):
		return
	
	#log_positions()
	add_satellite()

func log_positions() -> void:
	var unit: Unit = UnitManager.instance.get_first_unit()
	if !unit:
		return
	var positions: Array[Vector3] = \
	PathfindingSystem.instance.get_radial_points_surrounding_unit(unit, 1.6, 10)
	var string: String = "Radial Positions: "
	for pos in positions:
		string += str(pos)
		string += ", "
		Utilities.create_debug_sphere(pos, 6.0)
		
	Console.print_line(string, true)

func add_satellite() -> void:
	var unit: Unit = TurnSystem.instance.selected_unit
	if !unit:
		return
	
	var sphere: TestBall = Utilities.create_debug_sphere(unit.get_global_position(), 25.0)
	
	unit.satellite_controller.spawn_satellite(sphere)
