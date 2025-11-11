#SignalBus.gd
#Autoloaded Singleton
extends Node


signal on_unit_selected(unit: Unit)

signal on_unit_unselected(unit: Unit)

signal instantiate_initiative_queue

signal on_action_started(in_action: Action)

signal on_action_ended(in_action: Action)


signal on_combat_started




## Turn Signals
signal on_round_start(round_number: int)                     # HOOK: round-start passives
signal on_round_end(round_number: int)                       # HOOK: round-end passives
signal on_planning_ai_start(round_number: int)
signal on_planning_ai_end(round_number: int)
signal on_planning_player_start(round_number: int)
signal on_planning_player_end(round_number: int)

signal on_cycle_begin(pass_index: int)               # HOOK: per-pass effects (e.g., stance upkeep)
signal on_cycle_end(pass_index: int)

signal on_turn_start(unit: Unit)                             # HOOK: turn-start (AP/PP drains, auras)
signal on_before_action(user: Unit, action_id: String, ctx: Dictionary)   # HOOK: “before ally/enemy attacks”
signal on_after_action(user: Unit, action_id: String, ctx: Dictionary)    # HOOK: cleanse, follow-ups
signal on_reaction(user: Unit, reaction_id: String, ctx: Dictionary)      # HOOK: counters/guards
signal on_turn_end(unit: Unit)                               # HOOK: regen, end-of-turn ticks

signal on_unit_defeated(unit: Unit)                          # HOOK: on death
signal on_team_wiped(is_enemy_team: bool)









## UI Signals

signal update_stat_bars

signal end_turn

signal on_ui_update

signal on_selected_action_changed(action: Action)


signal open_character_sheet
signal update_character_sheet
