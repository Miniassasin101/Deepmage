class_name ConditionChip
extends PanelContainer


@export var name_label: Label
@export var icon_texture_rect: TextureRect

var blueprint: ConditionBlueprint = null

var is_disabled: bool = false


func populate_from_blueprint(in_bp: ConditionBlueprint) -> void:
	blueprint = in_bp
	if name_label != null:
		name_label.text = in_bp.display_name
	if icon_texture_rect != null:
		icon_texture_rect.texture = in_bp.icon_texture





func _get_drag_data(at_position: Vector2) -> Variant:
	if blueprint == null or is_disabled:
		return null

	var payload: Dictionary = {
		"dd_type": "condition_blueprint",
		"blueprint": blueprint,                        # <-- use this
		"display_name": blueprint.display_name
	}

	var preview_chip: ConditionChip = duplicate() as ConditionChip
	preview_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_chip.scale = Vector2(0.6, 0.6)

	var wrapper: Control = Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(preview_chip)
	preview_chip.position = -at_position * preview_chip.scale

	set_drag_preview(wrapper)
	return payload
