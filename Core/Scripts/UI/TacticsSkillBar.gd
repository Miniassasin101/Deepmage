class_name TacticsSkillBar
extends PanelContainer

@export_category("References")
@export var priority_number_label: Label
@export var skill_name_label: Label
@export var conditions_rhbox: ReorderableHBox

@export var red_style_box: StyleBoxFlat
@export var blue_style_box: StyleBoxFlat
@export var gray_style_box: StyleBoxFlat

var priority_num: int = 0
var conditions_count: int = 4


func populate_from_skill(in_skill: Skill) -> void:
	if !in_skill:
		return
	
	set_skill_name(in_skill.skill_name)
	

func set_skill_name(in_name: String) -> void:
	if !skill_name_label:
		return
	skill_name_label.set_text(in_name)


func set_priority_num(in_priority: int) -> void:
	if in_priority >= 0 and in_priority <= 10:
		priority_num = in_priority
		priority_number_label.set_text(str(priority_num))
		
	return
