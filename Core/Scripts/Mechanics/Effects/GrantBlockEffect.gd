class_name GrantBlockEffect
extends Effect

@export var block_value: int = 5
@export var use_expire_rule: Status.ExpireTiming = Status.ExpireTiming.Never
@export var show_text: bool = true

func apply() -> void:
	var target_unit: Unit = _resolve_target_unit()
	if target_unit == null:
		emit_signal("effect_finished")
		return

	var controller: StatusController = target_unit.get_status_controller()
	if controller == null:
		emit_signal("effect_finished")
		return

	var block_status: BlockStatus = BlockStatus.new()
	block_status.status_level = block_value
	block_status.expire_timing = use_expire_rule
	block_status.ui_name = "Block"

	controller.add_status(block_status)

	if show_text:
		Utilities.spawn_text_line(target_unit, "Gained Block", Color.CORNFLOWER_BLUE)

	emit_signal("effect_finished")
