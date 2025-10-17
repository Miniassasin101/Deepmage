## ActiveSkillBar.gd
class_name ActiveSkillBar
extends SlidePanelContainer

@export var label_node: Label



func set_text(skill_text: String) -> void:
	if label_node != null:
		label_node.text = skill_text
