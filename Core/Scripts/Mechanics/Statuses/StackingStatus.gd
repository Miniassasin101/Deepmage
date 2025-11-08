
class_name StackingStatus
extends Status

@export var amount_per_stack_int: int = 1        # for flat effects (AP, PP, Initiative, Accuracy, Evade)
@export var percent_per_stack: float = 5.0       # for % potency or poison
@export var show_floating_text: bool = true

func _init() -> void:
	status_level = 1
	expire_timing = ExpireTiming.EndOfRound  # default for this family

func merge_with(other_status: Status) -> void:
	var other: StackingStatus = other_status as StackingStatus
	if other == null:
		return
	var previous_level: int = status_level
	status_level += other.status_level
	_on_stacks_changed(previous_level, status_level)

# Hook for children that must reapply deltas (accuracy/evade/etc.)
func _on_stacks_changed(_old_level: int, _new_level: int) -> void:
	pass

func _spawn_float(unit: Unit, text_to_show: String) -> void:
	if show_floating_text:
		Utilities.spawn_text_line(unit, text_to_show)
