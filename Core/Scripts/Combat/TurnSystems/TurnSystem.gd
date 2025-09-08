class_name TurnSystem
extends Node


@export_category("References")
@export var unit_manager: UnitManager


## How many rounds have passed since combat began.
var round_number: int = 1

## How many turns have passed since combat began.
var turn_number: int = 1

## Dictionary of units and their current initiative scores
var initiative_scores: Dictionary[Unit, int] = {}


## Sorted list of units in initiative queue
var initiative_queue: Array[Unit] = []

## Current actionable units
var current_group: Array[Unit] = []


## Ghost units to preview new initiative if action is taken
var ghost_scores: Dictionary[Unit, int] = {}


## The unit that is last selected by the player.
var selected_unit: Unit = null

var is_combat_started: bool = false

var is_player_turn: bool = true

## The tick value of the unit with the lowest score, usually the one up next.
## Used to
var lowest_initiative_score: int = 0


static var instance: TurnSystem = null


func _ready() -> void:
	if instance != null:
		push_error("There's more than one TurnSystem! - " + str(instance))
		queue_free()
		return
	instance = self
	
	
	SignalBus.end_turn.connect(_on_end_turn)


#func _physics_process(_delta: float) -> void:
	#if !is_combat_started:
		#if Input.is_action_just_pressed("testkey_n"):
			#start_combat()

func _unhandled_input(_event: InputEvent) -> void:
	if !is_combat_started:
		if Input.is_action_just_pressed("testkey_n"):
			start_combat()

## This is the first function that is called when combat begins. Will return with an error if initiative hasnt been rolled
## Likely it should also probably trigger initiative at the same time.
func start_combat() -> void:
	if is_combat_started == true:
		return
	UnitActionSystem.instance.is_enabled = true
	# 1) Reset every unit’s initiative and put them into the queue
	_initialize_initiative()
	
	roll_initiative()
	
	# Setup the ui of initiative
	SignalBus.instantiate_initiative_queue.emit()
	
	is_combat_started = true
	
	advance_group()
	SignalBus.update_stat_bars.emit()
	
	CombatLog.instance.toggle_log()


## Clears any initiative scores before setting up a new initiative. Then sets the units' turn state to in queue
func _initialize_initiative():
	initiative_scores.clear()
	#var count = 0
	for unit in unit_manager.get_all_units():
		initiative_scores[unit] = 0 #count
		unit.turn_state = Unit.TurnState.IN_QUEUE
		#count += 1


func roll_initiative() -> void:
	for unit in unit_manager.get_all_units():
		var roll: DicePool = DicePool.new(unit.speed)
		print_debug(roll.to_str())
		var initiative: int = roll.success_count
		initiative_scores[unit] = initiative
	
	sort_queue()


func sort_queue():
	initiative_queue.assign(initiative_scores.keys())
	initiative_queue.sort_custom(_compare_initiative)


func _compare_initiative(a:Unit, b:Unit) -> bool:
	return initiative_scores[b] > initiative_scores[a]


func advance_round() -> void:
	round_number += 1
	_initialize_initiative()
	roll_initiative()
	SignalBus.instantiate_initiative_queue.emit()
	
	for u in initiative_queue:
		u.turn_state = Unit.TurnState.IN_QUEUE
	
	advance_group()
	
	SignalBus.on_ui_update.emit()
	


## Clears the current group and removes them from the initiative queue before forming the next one.
func advance_group() -> void:
	# Reset all units to being in the queue at beginning of turn
	for u in current_group:
		u.turn_state = Unit.TurnState.TURN_ENDED
		initiative_queue.pop_front()
	
	current_group.clear()
	
	if initiative_queue.is_empty():
		advance_round()
		return
	
	# Save the leading unit, their score, and whether they are an enemy.
	var leading_unit: Unit = initiative_queue.front()
	#var leading_score: int = initiative_scores[leading_unit]
	var is_lead_enemy: bool = leading_unit.is_enemy
	
	
	# Groups happen when multiple characters on the same team can go one after another. If not, then the group consists of just one unit.
	for u in initiative_queue:
		if u.is_enemy != is_lead_enemy:
			break
		u.turn_state = Unit.TurnState.TURN_STARTED
		current_group.append(u)
	
	#lowest_initiative_score = lead
	
	begin_group_turn()
	

## Starts the next member of the current group's turn. If empty, goes to on_group_exhausted logic
func begin_group_turn():
	if current_group.is_empty():
		return
  # pick the index of the first who’s still queued
	var next: int = current_group.find_custom(func(u: Unit): return u.turn_state == Unit.TurnState.TURN_STARTED)
	if next < 0:
	# everyone in this group already acted → rotate initiative
		_on_group_exhausted()
		return

	set_selected_unit(current_group[next])
	selected_unit.turn_state = Unit.TurnState.TURN_STARTED

	is_player_turn = not selected_unit.is_enemy

  # give control back to the ActionSystem
	if is_player_turn or DebugSettings.instance.control_enemy_debug:
		UnitActionSystem.instance.set_selected_unit(selected_unit)

	#CombatSystem.instance.start_turn(selected_unit)


func _on_group_exhausted():
  # everyone in this group has gone; move on to the next group and update ui

	advance_group()
	#SignalBus.instantiate_stats_bars.emit()
	#SignalBus.update_stat_bars.emit()


func _on_end_turn():
	if not selected_unit:
		return
	selected_unit.turn_state = Unit.TurnState.TURN_ENDED
	UnitActionSystem.instance.set_busy(false)
	begin_group_turn()
	SignalBus.update_stat_bars.emit()



func can_select_unit(to_unit: Unit) -> bool:
	return is_unit_in_group(to_unit) and to_unit != selected_unit

func is_unit_in_group(in_unit: Unit) -> bool:
	for u in current_group:
		if u == in_unit:
			return true
	return false





func set_selected_unit(in_unit: Unit) -> void:
	if !can_select_unit(in_unit):
		return
	
	# Make the previous selected unit's square white again
	if selected_unit:
		selected_unit.selection_visual.clear_material()
		SignalBus.on_unit_unselected.emit(selected_unit)
	
	selected_unit = in_unit
	SignalBus.on_unit_selected.emit(selected_unit)
	selected_unit.selection_visual.set_blue()
	selected_unit.selection_visual.pulse_square()
