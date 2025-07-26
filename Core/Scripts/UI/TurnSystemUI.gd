class_name TurnSystemUI
extends Control


@export var turn_system: TurnSystem
@export var combat_system: CombatSystem

@export var end_turn_container: PanelContainer
@export var end_turn_button: Button
@export var end_phase_container: PanelContainer
@export var end_phase_button: Button

@export var turn_phase_label: Label
@export var round_counter_label: Label
@export var cycle_counter_label: Label
@export var movement_gait_label: Label

@export var enemy_turn_container: PanelContainer



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#SignalBus.on_turn_changed.connect(on_turn_changed)
	#SignalBus.on_cycle_changed.connect(on_cycle_changed)
	#SignalBus.on_phase_changed.connect(on_phase_changed)
	#SignalBus.on_ui_update.connect(on_ui_update)
	#UIBus.on_ui_update.connect(on_ui_update)
	

	on_ui_update()


func on_ui_update() -> void:

	update_turn_label()
	#update_phase_label()
	#update_cycle_label()
	#update_gait_label()

func _on_end_turn_button_pressed() -> void:
	SignalBus.end_turn.emit()

func on_turn_changed() -> void:

	update_turn_label()

func on_phase_changed() -> void:
	update_phase_label()

func on_cycle_changed() -> void:
	update_cycle_label()

func update_turn_label() -> void:
	#round_counter_label.text = "Round " + str(turn_system.round_number)
	pass

func update_cycle_label() -> void:
	#cycle_counter_label.text = "Cycle " + str(turn_system.current_cycle)
	pass
	
func update_phase_label() -> void:
	#turn_phase_label.text = combat_system.get_current_phase_name() + " Phase"
	pass
	
