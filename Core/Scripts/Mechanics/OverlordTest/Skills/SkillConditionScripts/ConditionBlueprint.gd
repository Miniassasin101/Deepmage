class_name ConditionBlueprint
extends Resource

@export var display_name: String = "Unnamed Condition"
@export var category_name: String = "General"       # e.g., Target, HP, Position, Status, Ally, Enemy
@export var icon_texture: Texture2D = null          # optional
@export var prototype: SkillCondition               # a configured SkillCondition Resource to clone

func instantiate_condition() -> SkillCondition:
	if prototype == null:
		return null
	var fresh: SkillCondition = prototype.duplicate(true)
	return fresh
