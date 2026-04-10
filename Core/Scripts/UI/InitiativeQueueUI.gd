class_name InitiativeQueueUI
extends Control

@export var unit_manager: UnitManager
@export var unit_stats_bar_scene: PackedScene
@export var unit_stats_container: VBoxContainer
@export var show_stats_for_all_units: bool = true  # Boolean to control stats bar creation for all units or just player units
@export var scroll_container: ScrollContainer = null
@export var panelcontainer: PanelContainer = null
@export_category("UI Settings")
@export var max_height: float = 650.0
# Dictionary to store references to each unit's stats bar
var unit_stats_bars: Dictionary = {}
var units_to_create_for: Array

var is_first_setup: bool = true

const unit_stats_bar_height: float = 60.1

static var instance: InitiativeQueueUI = null




# Called when the node enters the scene tree
func _ready() -> void:
	if instance != null:
		push_error("There's more than one InitiativeQueueUI! - " + str(instance))
		queue_free()
		return
	instance = self
	
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
		
		update_scroll_size()

func update_scroll_size() -> void:
	if !scroll_container:
		return
	
	var cont_num: int = unit_stats_bars.size()
	var max_size: float = cont_num * (unit_stats_bar_height + 3.9)
	max_size = minf(max_height, max_size)
	
	
	#panelcontainer.size.y = max_size + 1
	scroll_container.custom_minimum_size.y = max_size 
	#await get_tree().process_frame
	#panelcontainer.size_flags_changed.emit()
	#panelcontainer.size.y = max_size + 1
	#panelcontainer.force_update_transform()
	



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
		
		scroll_container.ensure_control_visible(stats_bar)


func on_unit_unselected(unit: Unit) -> void:


	var stats_bar: UnitStatsBar = unit_stats_bars[unit] if unit_stats_bars.has(unit) else null
	if stats_bar:
		

		stats_bar.stop_pulse()
