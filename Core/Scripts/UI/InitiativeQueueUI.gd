class_name InitiativeQueueUI
extends Control

@export var unit_manager: UnitManager
@export var unit_stats_bar_scene: PackedScene
@export var unit_stats_container: VBoxContainer
@export var show_stats_for_all_units: bool = true  # Boolean to control stats bar creation for all units or just player units

# Dictionary to store references to each unit's stats bar
var unit_stats_bars: Dictionary = {}
var units_to_create_for: Array

var is_first_setup: bool = true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#instantiate_initiative_queue()
	#SignalBus.on_ui_update.connect(_on_update_stats_bars)
#	SignalBus.on_unit_added.connect(instantiate_initiative_queue)
	#SignalBus.on_unit_removed.connect(instantiate_initiative_queue)
	
	SignalBus.instantiate_initiative_queue.connect(instantiate_initiative_queue)
	SignalBus.update_stat_bars.connect(_on_update_stats_bars)
	
	SignalBus.on_unit_selected.connect(on_unit_selected)
	SignalBus.on_unit_unselected.connect(on_unit_unselected)
	
	#UIBus.update_stat_bars.connect(_on_update_stats_bars)



func instantiate_initiative_queue(_unit: Unit = null) -> void:
	if unit_manager:
		# Remove all current children from the container.
		for child: UnitStatsBar in unit_stats_container.get_children():
			child.abort_tween()
			child.abort_pulse()
			child.queue_free()
		unit_stats_bars.clear()

		# Get the units based on your flag.
		if show_stats_for_all_units:
			units_to_create_for = unit_manager.get_all_units()
		else:
			units_to_create_for = unit_manager.get_player_units()

		# If the TurnSystem has an initiative order, order the units accordingly.
		if TurnSystem.instance != null and TurnSystem.instance.initiative_queue.size() > 0:
			var ordered_units: Array = []
			for unit in TurnSystem.instance.initiative_queue:
				if unit in units_to_create_for:
					ordered_units.append(unit)
			units_to_create_for = ordered_units

		# Create a stats bar for each unit in the ordered array.
		for unit in units_to_create_for:
			var stats_bar = unit_stats_bar_scene.instantiate() as UnitStatsBar
			unit_stats_container.add_child(stats_bar)
			stats_bar.update_stats(unit, is_first_setup)  # Initialize with current values.
			unit_stats_bars[unit] = stats_bar
			
		
		is_first_setup = false


func _on_update_stats_bars() -> void:
	for unit: Unit in unit_stats_bars.keys():
		if is_instance_valid(unit):
			var stats_bar: UnitStatsBar = unit_stats_bars[unit]
			stats_bar.update_stats(unit)
			if unit.turn_state == Unit.TurnState.TURN_STARTED: #unit == TurnSystem.instance.current_unit_turn:
				stats_bar.start_drift()
			else:
				stats_bar.stop_drift()
		else:
			unit_stats_bars.erase(unit)


func on_unit_selected(unit: Unit) -> void:

	var stats_bar: UnitStatsBar = unit_stats_bars[unit] if unit_stats_bars.has(unit) else null
	if stats_bar:
		
		stats_bar.start_pulse()


func on_unit_unselected(unit: Unit) -> void:


	var stats_bar: UnitStatsBar = unit_stats_bars[unit] if unit_stats_bars.has(unit) else null
	if stats_bar:
		

		stats_bar.stop_pulse()
