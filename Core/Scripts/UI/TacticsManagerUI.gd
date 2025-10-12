class_name TacticsManagerUI
extends PanelContainer



@export_category("References")
@export_group("Label References")
@export var tactics_header_label: Label
@export_group("")
@export var active_skills_rvbox: ReorderableVBox
@export var passive_skills_rvbox: ReorderableVBox


@export_category("Settings")
@export_range(1, 6) var conditions_count: int = 4

@export_category("Prefabs")
@export var tactics_skill_bar_prefab: PackedScene

var current_unit: Unit = null

var active_skills: Array[Skill] = []

var passive_skills: Array[Skill] = []


func _ready() -> void:
	pass


func populate_from_unit(in_unit: Unit) -> void:
	if !in_unit:
		return
	
	set_tactics_header(in_unit.ui_name)
	
	clear_all_skills()
	
	setup_skills_container(in_unit, active_skills_rvbox)
	#setup_skills_container(in_unit, passive_skills_rvbox)
	
	




func set_tactics_header(in_unit_ui_name: String) -> void:
	tactics_header_label.set_text(in_unit_ui_name + " Tactics Manager")

func setup_skills_container(in_unit: Unit, in_skill_cont: ReorderableVBox) -> void:
	var unit_tactic: Tactic = in_unit.tactics_controller.current_tactic
	var a_skills: Array[Skill] = unit_tactic.get_valid_active_skills()
	var p_skills: Array[Skill] = unit_tactic.get_valid_passive_skills()
	var iteration_num: int = 1
	for a_skill in a_skills:
		var new_skillbar: TacticsSkillBar = tactics_skill_bar_prefab.instantiate() as TacticsSkillBar
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



func populate_unit_from_tactics_ui() -> void:
	pass
