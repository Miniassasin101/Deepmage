class_name SelfHPPercentBelowCondition
extends SkillCondition

@export var hp_attribute_name: String = "posture"
@export var threshold_01: float = 0.75

var ui_name: String = "HP%<Threshold(Self)"

func _get_percent(unit_ref: Unit) -> float:
	if unit_ref == null:
		return -1.0
	var attrs: AttributesContainer = unit_ref.get_attributes_container()
	if attrs == null:
		return -1.0
	var attr: Attribute = attrs.get_attribute(hp_attribute_name)
	if attr == null:
		return -1.0

	var current_value: int = maxi(attr.get_current_modified_value(), 0)
	var maximum_value: int = attr.get_max_value()

	if maximum_value <= 0:
		return -1.0

	return float(current_value) / float(maximum_value)

func check_condition(skill: Skill, _target: Unit) -> bool:
	var pct: float = _get_percent(skill.unit)
	if pct < 0.0:
		return false
	if pct < threshold_01:
		return true
	else:
		return false
