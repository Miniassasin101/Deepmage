@abstract
class_name Effect
extends Resource

signal effect_finished

@export var ui_name: StringName
@export var target_key: StringName = "target_unit"   # editor-selectable: "target_unit", "user", "self", etc.

var context: Dictionary = {}

func set_context(in_ctx: Dictionary) -> void:
	context = in_ctx

func _resolve_target_unit() -> Unit:
	var target: Unit = null
	if context.has(target_key):
		target = context[target_key]
	elif target_key == "self":
		if context.has("user"):
			target = context["user"]
	elif target_key == "user":
		if context.has("user"):
			target = context["user"]
	return target

func apply() -> void:
	pass

func can_apply() -> bool:
	return false
