class_name StatusController
extends Node

signal status_check_complete

@export var unit: Unit

@export var starting_statuses: Array[Status] = []

@export var unit_vfx_manager: UnitVFXManager

var statuses: Array[Status] = []


func _ready() -> void:
	if unit == null:
		unit = get_parent() as Unit
		
	make_statuses_unique()
	# Listen to global phases (uses your SignalBus already fired in TurnSystem)
	if SignalBus.on_turn_start.is_connected(_on_turn_start) == false:
		SignalBus.on_turn_start.connect(_on_turn_start)
	if SignalBus.on_turn_end.is_connected(_on_turn_end) == false:
		SignalBus.on_turn_end.connect(_on_turn_end)
	if SignalBus.on_round_start.is_connected(_on_round_start) == false:
		SignalBus.on_round_start.connect(_on_round_start)
	if SignalBus.on_round_end.is_connected(_on_round_end) == false:
		SignalBus.on_round_end.connect(_on_round_end)

	if SignalBus.on_skill_declared.is_connected(_on_skill_declared) == false:
		SignalBus.on_skill_declared.connect(_on_skill_declared)
	if SignalBus.on_skill_end.is_connected(_on_skill_end) == false:
		SignalBus.on_skill_end.connect(_on_skill_end)


	_sync_status_vfx()

func _sync_status_vfx() -> void:
	if unit_vfx_manager == null:
		return

	var has_blessing: bool = false
	var has_affliction: bool = false

	for s in statuses:
		if s == null:
			continue
		if s.status_category == Status.StatusCategory.BLESSING:
			has_blessing = true
		elif s.status_category == Status.StatusCategory.AFFLICTION:
			has_affliction = true

		if has_blessing and has_affliction:
			break

	unit_vfx_manager.set_status_category_active(has_blessing, has_affliction)


func make_statuses_unique() -> void:
	var temp_statuses: Array[Status] = []
	for status in starting_statuses:
		temp_statuses.append(status.duplicate())
	statuses = temp_statuses



func before_attack_roll(in_unit: Unit, cd: CombatEventData) -> void:
	for status_inst in statuses: # however you store them
		if status_inst == null:
			continue

		status_inst.before_attack_roll(in_unit, cd)


# === Damage stage hooks ===
func before_damage_applied(cd: CombatEventData) -> void:
	for s in statuses:
		s.on_before_damage_applied(unit, cd)
	if cd.effective_damage < 0:
		cd.effective_damage = 0

func after_damage_applied(cd: CombatEventData) -> void:
	for s in statuses:
		s.on_after_damage_applied(unit, cd)


# === Interval ticks ===
func _on_turn_start(turn_unit: Unit) -> void:
	if turn_unit != unit:
		return
	for s in statuses:
		s.on_turn_start(unit)
	# No expirations here by default

func _on_turn_end(turn_unit: Unit) -> void:
	if turn_unit != unit:
		return
	for s in statuses:
		s.on_turn_end(unit)
	# Expire at EndOfTurn
	_prune_by_expire_rule(Status.ExpireTiming.EndOfTurn)

func _on_round_start(round_index: int) -> void:
	for s in statuses:
		s.on_round_start(unit, round_index)

func _on_round_end(round_index: int) -> void:
	for s in statuses:
		s.on_round_end(unit, round_index)
	# Expire at EndOfRound
	_prune_by_expire_rule(Status.ExpireTiming.EndOfRound)

func _prune_by_expire_rule(target_rule: int) -> void:
	var to_remove: Array[Status] = []
	for s in statuses:
		if s.expire_timing == target_rule:
			to_remove.append(s)
	for srm in to_remove:
		remove_status(srm)


func _on_skill_declared(user: Unit, ctx: Dictionary) -> void:
	if user != unit:
		return
	for status_ref: Status in statuses:
		if status_ref != null:
			status_ref.on_skill_declared(unit, ctx)

func _on_skill_end(user: Unit, ctx: Dictionary) -> void:
	if user != unit:
		return
	for status_ref: Status in statuses:
		if status_ref != null:
			status_ref.on_skill_end(unit, ctx)
	_prune_by_expire_rule(Status.ExpireTiming.OnUse)



func modify_mana_cost(skill: Skill, base_cost: int) -> int:
	var cost: int = base_cost
	for status_ref: Status in statuses:
		if status_ref != null:
			cost = int(status_ref.modify_mana_cost(unit, skill, cost))
	if cost < 0:
		cost = 0
	return cost



# === Utilities helpful for Cleanse effects later ===
func remove_by_category(category: int, max_remove_count: int = 9999) -> int:
	var removed: int = 0
	for s in statuses:
		if s.status_category == category and removed < max_remove_count:
			remove_status(s)
			removed += 1
	return removed

func remove_by_tag(tag: StringName, max_remove_count: int = 9999) -> int:
	var removed: int = 0
	for s in statuses:
		if s.tags_type.has(tag) and removed < max_remove_count:
			remove_status(s)
			removed += 1
	return removed




func add_status(in_status: Status, sync_vfx: bool = true) -> bool:
	if in_status == null:
		return false
	in_status.owner = unit
	var existing: Status = get_status_by_name(in_status.ui_name)
	if existing != null:
		existing.merge_with(in_status)
		return true
	statuses.append(in_status)
	if sync_vfx:
		_sync_status_vfx()
	in_status.on_added(unit)
	return true

func remove_status(in_status: Status) -> void:
	if in_status == null:
		return
	if statuses.has(in_status):
		in_status.on_removed(unit)
		statuses.erase(in_status)
		_sync_status_vfx()

func get_status_by_name(in_name: String) -> Status:
	var needle: String = in_name.to_snake_case()
	for s in statuses:
		if s.ui_name.to_snake_case() == needle:
			return s
	return null
