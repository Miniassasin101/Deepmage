class_name TacticsManagerUI
extends PanelContainer



@export_category("References")
@export_group("Label References")
@export var tactics_header_label: Label
@export var conditions_header_hbox: HBoxContainer
@export_group("")
@export var active_skills_rvbox: ReorderableVBox
@export var passive_skills_rvbox: ReorderableVBox
@export var skill_library_vbox: VBoxContainer
@export var conditions_library_ui: ConditionsLibraryUI


@export_category("Settings")
@export_range(1, 6) var max_conditions_count: int = 4

@export_category("Prefabs")
@export var tactics_skill_bar_prefab: PackedScene
@export var library_skill_bar_prefab: PackedScene


var current_unit: Unit = null

var active_skills: Array[Skill] = []

var passive_skills: Array[Skill] = []




func _ready() -> void:
	active_skills_rvbox.reordered.connect(on_active_skills_reordered)
	_populate_skill_library()

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
	
	#if !sorted_skills.is_empty():
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
		if a_skill.skill_name == "Ball Throw":
			pass
		active_skills_rvbox.add_child(new_skillbar)
		new_skillbar.populate_from_skill(a_skill)
		new_skillbar.set_priority_num(iteration_num)
		
		new_skillbar.on_tactics_skill_bar_update.connect(on_tactics_skill_bar_update)
		
		iteration_num += 1
		
		if iteration_num >= 10:
			break



func on_tactics_skill_bar_update() -> void:
	reprioritize_skills(active_skills_rvbox)


func clear_all_skills() -> void:
	active_skills.clear()
	passive_skills.clear()
	
	
	for child in active_skills_rvbox.get_children():
		child.queue_free()
	
	for child in passive_skills_rvbox.get_children():
		child.queue_free()
	
	



# Skill Library Functions:
func _populate_skill_library() -> void:
	if skill_library_vbox == null:
		return
	_clear_library()

	var combat_system: CombatSystem = CombatSystem.instance
	if combat_system == null:
		return
	var library: SkillLibrary = combat_system.get_skill_library()
	if library == null:
		return

	var sorted_skills: Array[Skill] = library.get_skills_sorted_by_category_type_name()
	for lib_skill in sorted_skills:
		if lib_skill == null:
			continue
		var lib_bar: LibrarySkillBar = library_skill_bar_prefab.instantiate() as LibrarySkillBar
		skill_library_vbox.add_child(lib_bar)
		lib_bar.populate_from_skill(lib_skill)
		if not lib_bar.on_add_to_tactics.is_connected(_on_library_add_skill):
			lib_bar.on_add_to_tactics.connect(_on_library_add_skill)

func _clear_library() -> void:
	if skill_library_vbox == null:
		return
	for lib_child in skill_library_vbox.get_children():
		lib_child.queue_free()

func _on_library_add_skill(skill_from_library: Skill) -> void:
	# Duplicate and wipe external conditions / preferences as requested
	if skill_from_library == null:
		return
	var new_skill: Skill = skill_from_library.duplicate(true)
	new_skill.external_skill_conditions = []
	new_skill.target_preferences = []
	new_skill.is_disabled = false

	var target_container: ReorderableVBox = _get_container_for_category(new_skill.skill_category)
	if target_container == null:
		return

	var new_bar: TacticsSkillBar = _spawn_tactics_bar_for_skill(new_skill, target_container)
	if new_bar == null:
		return

	# Place at end of that container
	reprioritize_skills(target_container)


func _get_container_for_category(in_category: int) -> ReorderableVBox:
	if int(in_category) == int(Skill.SkillCategory.ACTIVE):
		return active_skills_rvbox
	elif int(in_category) == int(Skill.SkillCategory.PASSIVE):
		return passive_skills_rvbox
	else:
		# Default to active for FREE or others, adjust as you prefer
		return active_skills_rvbox

func _spawn_tactics_bar_for_skill(in_skill: Skill, target_rvbox: ReorderableVBox) -> TacticsSkillBar:
	if in_skill == null or target_rvbox == null:
		return null
	var new_skillbar: TacticsSkillBar = tactics_skill_bar_prefab.instantiate() as TacticsSkillBar
	new_skillbar.max_conditions_count = max_conditions_count
	target_rvbox.add_child(new_skillbar)
	new_skillbar.populate_from_skill(in_skill)

	# Set priority label immediately (end of list for now)
	var new_index: int = target_rvbox.get_child_count()
	new_skillbar.set_priority_num(new_index)
	
	new_skillbar.on_tactics_skill_bar_update.connect(on_tactics_skill_bar_update)

	return new_skillbar
