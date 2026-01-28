@abstract
class_name Status
extends Resource

@export var ui_name: String = "None"
enum StatusCategory {NONE, BLESSING, AFFLICTION, SPECIAL}
@export var status_category: StatusCategory = StatusCategory.NONE

@export var status_level: int = 0



# This is the interval at which the condition applies.
# Is checked to see if it applies once a turn, round, cycle, day, ect.
# Never doesnt mean it cant apply, just that it wont do so unprompted.
# Some Statuses are only read from and remove themselves at the beginning of each round.
enum ApplicationInterval {Never, PerRound, PerTurn, PerAttack, PerSkillEnd, PerSkillDeclared}
@export var application_interval: ApplicationInterval = ApplicationInterval.Never


# Simple lifetime control for common needs (no timers needed for now)
enum ExpireTiming { Never, EndOfTurn, EndOfRound, OnUse }
@export var expire_timing: ExpireTiming = ExpireTiming.Never



@export var tags_type: Array[StringName] = []

## The types of abilities that this status blocks while on a character, Ex: "attack" or "move"
@export var blocking_tags: Array[StringName] = []


var owner: Unit = null


# Virtual Function that checks to see if the status can apply
func can_apply(_unit: Unit) -> bool:
	
	
	
	return true

# Virtual Function that is overriden to do the functionality
func apply(_unit: Unit) -> void:
	pass


func can_modify_status(_status: Status) -> bool:
	return false  # By default, statuses do not modify others.

func modify_status(_status: Status) -> void:
	pass  # Override in specific statuses.

func modify_mana_cost(_unit: Unit, _skill: Skill, cost: int) -> int:
	return cost



func increase_level(by_amount: int = 1) -> void:
	status_level += by_amount
	
func decrease_level(by_amount: int = 1) -> void:
	status_level -= by_amount


func status_category_matches_category(in_category: int) -> bool:
	if in_category == status_category:
		return true
	return false

func merge_with(_other_status: Status) -> void:
	# Default implementation: no merging.
	pass


func on_added(_unit: Unit) -> void:
	pass
func on_removed(_unit: Unit) -> void:
	pass


# Phase hooks (interval-ready)
func on_turn_start(_unit: Unit) -> void:
	pass
func on_turn_end(_unit: Unit) -> void:
	pass
func on_round_start(_unit: Unit, _round_index: int) -> void:
	pass
func on_round_end(_unit: Unit, _round_index: int) -> void:
	pass
func on_skill_declared(_unit: Unit, _ctx: Dictionary) -> void:
	pass
func on_skill_end(_unit: Unit, _ctx: Dictionary) -> void:
	pass


# Combat timing hooks
func on_before_damage_applied(_unit: Unit, _cd: CombatEventData) -> void:
	pass
func on_after_damage_applied(_unit: Unit, _cd: CombatEventData) -> void:
	pass



func remove_self(unit: Unit) -> void:
	var controller: StatusController = unit.get_status_controller()
	if controller != null:
		controller.remove_status(self)


# New virtual function to determine if this status blocks targeting from the given ability and attacker.
func blocks_targeting(_skill: Skill, _targ_pack: TargetPackage) -> bool:
	# By default, no condition blocks targeting.
	return false
