@abstract
class_name Status
extends Resource

@export var ui_name: String = "None"

@export_enum("NONE", "BLESSING", "AFFLICTION", "SPECIAL") var status_category : int = 0

@export var status_level: int = 0



# This is the interval at which the condition applies.
# Is checked to see if it applies once a turn, round, cycle, day, ect.
# Never doesnt mean it cant apply, just that it wont do so unprompted.
# Some Statuses are only read from and remove themselves at the beginning of each round.
enum ApplicationInterval {Never, PerRound, PerTurn, PerModify, PerSkillEnd, PerSkillDeclared}
@export var application_interval: ApplicationInterval = ApplicationInterval.Never




@export var tags_type: Array[StringName] = []

## The types of abilities that this condition blocks while on a character, Ex: "attack" or "move"
@export var blocking_tags: Array[StringName] = []


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


func remove_self(unit: Unit) -> void:
	unit.conditions_manager.remove_condition(self)


# New virtual function to determine if this status blocks targeting from the given ability and attacker.
func blocks_targeting(_skill: Skill, _targ_pack: TargetPackage) -> bool:
	# By default, no condition blocks targeting.
	return false
