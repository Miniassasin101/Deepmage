class_name TacticsManagerUI
extends PanelContainer



@export_category("References")
@export_group("Label References")
@export var tactics_header_label: Label
@export var conditions_header_hbox: HBoxContainer
@export_group("")
@export var active_skills_rvbox: ReorderableVBox
@export var passive_skills_rvbox: ReorderableVBox


@export_category("Settings")
@export_range(1, 6) var max_conditions_count: int = 4

@export_category("Prefabs")
@export var tactics_skill_bar_prefab: PackedScene


var current_unit: Unit = null

var active_skills: Array[Skill] = []

var passive_skills: Array[Skill] = []




func _ready() -> void:
	active_skills_rvbox.reordered.connect(on_active_skills_reordered)
	pass

func on_active_skills_reordered(_from_index: int, _to_index: int) -> void:
	reprioritize_skills(active_skills_rvbox)

func reprioritize_skills(skills_rvbox: ReorderableVBox) -> void:
	var iter_num: int = 1
	var sorted_skills: Array[Skill] = []
	
	for child in skills_rvbox._get_visible_children():
		if child is TacticsSkillBar:
			child.set_priority_num(iter_num)
			iter_num += 1
			var curr_skill: Skill = child.get_current_skill()
			if curr_skill:
				sorted_skills.append(curr_skill)
	
	if !sorted_skills.is_empty():
		populate_unit_from_tactics_ui(sorted_skills)


func populate_unit_from_tactics_ui(resorted_skills: Array[Skill]) -> void:
	if !current_unit:
		return
	
	current_unit.tactics_controller.set_current_tactic_from_skills(resorted_skills, [])


func populate_from_unit(in_unit: Unit) -> void:
	if !in_unit:
		return
	
	current_unit = in_unit
	
	set_tactics_header(in_unit.ui_name)
	
	clear_all_skills()
	
	setup_skills_container(in_unit, active_skills_rvbox)
	#setup_skills_container(in_unit, passive_skills_rvbox)
	
	




func set_tactics_header(in_unit_ui_name: String) -> void:
	tactics_header_label.set_text(in_unit_ui_name + " Tactics Manager")


func setup_conditions_headers() -> void:
	var condition_header_template: Label = conditions_header_hbox.get_children().front() as Label
	
	condition_header_template = condition_header_template.duplicate()
	
	for child in conditions_header_hbox.get_children():
		child.queue_free()
	
	for i in range(max_conditions_count):
		var new_header: Label = condition_header_template.duplicate()
		new_header.set_text("Condition " + str(i + 1))
		conditions_header_hbox.add_child(new_header)



func setup_skills_container(in_unit: Unit, in_skill_cont: ReorderableVBox) -> void:
	var unit_tactic: Tactic = in_unit.tactics_controller.current_tactic
	var a_skills: Array[Skill] = unit_tactic.get_valid_active_skills()
	var p_skills: Array[Skill] = unit_tactic.get_valid_passive_skills()
	
	var iteration_num: int = 1
	
	for a_skill in a_skills:
		var new_skillbar: TacticsSkillBar = tactics_skill_bar_prefab.instantiate() as TacticsSkillBar
		
		new_skillbar.max_conditions_count = max_conditions_count
		
		active_skills_rvbox.add_child(new_skillbar)
		new_skillbar.populate_from_skill(a_skill)
		new_skillbar.set_priority_num(iteration_num)
		iteration_num += 1
	
	

func clear_all_skills() -> void:
	active_skills.clear()
	passive_skills.clear()
	
	
	for child in active_skills_rvbox.get_children():
		child.queue_free()
	
	for child in passive_skills_rvbox.get_children():
		child.queue_free()
