@abstract
class_name TargetPreference
extends SkillCondition

var hp_attribute_name: String = "posture"

# A soft filter that may narrow (or leave unchanged) a list of candidate targets.
# Order matters: earlier preferences run first and constrain the pool for later ones.

func apply(_skill: Skill, _candidates: Array[Unit]) -> Array[Unit]:
	# Default: no change (safe base behavior).
	return _candidates

func try_get_attr_container(unit: Unit) -> Object:
	return unit.get_attributes_container()


func try_get_hp_current(unit: Unit) -> int:
	var attrs: AttributesContainer = unit.character_sheet.get_attributes_container()
	return attrs.get_attribute_current_value(hp_attribute_name)


func try_get_hp_max(unit: Unit) -> int:
	var attrs: AttributesContainer = unit.character_sheet.get_attributes_container()
	return attrs.get_attribute(hp_attribute_name).maximum_value


func try_get_hp_percent(unit: Unit) -> float:
	var cur := float(try_get_hp_current(unit))
	var maxv := float(try_get_hp_max(unit))
	if maxv > 0.0 and cur >= 0.0:
		return cur / maxv
	return -1.0


func unit_has_tag_like(unit: Unit, tag_lower: String) -> bool:
	# Flexible tag check: supports Unit.has_tag(tag) or Unit.tags Array
	if unit == null:
		return false

	return unit.has_tag(tag_lower)
