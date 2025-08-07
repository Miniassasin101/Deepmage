#SignalBus.gd
#Autoloaded Singleton
extends Node


signal on_unit_selected(unit: Unit)

signal on_unit_unselected(unit: Unit)

signal instantiate_initiative_queue

signal on_action_started(in_action: Action)

signal on_action_ended(in_action: Action)






## UI Signals

signal update_stat_bars

signal end_turn

signal on_ui_update

signal on_selected_action_changed(action: Action)


signal open_character_sheet
