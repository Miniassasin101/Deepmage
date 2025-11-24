## [b]Class:[/b] TacticsManagerUI
## [i]Editor/UI panel for building and reordering a unit’s tactics: active/passive skills and their conditions.[/i]
##
## [b]Responsibilities[/b][br]
## • Displays a unit’s active/passive skills using [Class ReorderableVBox] lists.[br]
## • Lets players reorder skills; priorities are mirrored back into the unit’s [code]TacticsController[/code].[br]
## • Populates a skill “library” list from the global [Class SkillLibrary] and lets users add skills to tactics.[br]
## • Draws column headers for per-skill condition slots (purely visual, driven by [member max_conditions_count]).[br]
##
## [b]Key Flows[/b][br]
## • On reorder: [method on_active_skills_reordered] → [method reprioritize_skills] → [method populate_unit_from_tactics_ui].[br]
## • On library add: [_on_library_add_skill] duplicates the library skill and spawns a [Class TacticsSkillBar] in the proper list.[br]
## • On unit select: [method populate_from_unit] rebuilds the UI from the unit’s current tactic.[br]
##
## [b]Notes[/b][br]
## • Logic unchanged; only documentation comments added.[br]
## • Uses project-specific UI controls: [Class ReorderableVBox], [Class TacticsSkillBar], [Class LibrarySkillBar], and [Class ConditionsLibraryUI].

class_name TacticsManagerUI
extends PanelContainer


@export_category("References")
@export_group("Label References")
## Header label at the top of the panel (e.g., “[UnitName] Tactics Manager”).
@export var tactics_header_label: Label
## Row container holding the “Condition 1..N” header labels.
@export var conditions_header_hbox: HBoxContainer
@export_group("")
## Reorderable list for [b]active[/b] skills currently on the unit.
@export var active_skills_rvbox: ReorderableVBox
## Reorderable list for [b]passive[/b] skills currently on the unit (optional use in this UI).
@export var passive_skills_rvbox: ReorderableVBox

## Vertical list of addable skills coming from the global [Class SkillLibrary].
@export var skill_library_vbox: VBoxContainer
## Reference to the conditions library pane/widget for browsing/adding conditions.
@export var conditions_library_ui: ConditionsLibraryUI

@export var skill_lib_scroll_container: ScrollContainer
@export var skills_library_ui: SkillsLibraryUI   # <— new

@export_category("Settings")
## Maximum number of per-skill condition columns to show (visual + bar capacity).
@export_range(1, 6) var max_conditions_count: int = 4

@export_category("Prefabs")
## Prefab for rows that represent skills in the tactics lists ([Class PackedScene] → [Class TacticsSkillBar]).
@export var tactics_skill_bar_prefab: PackedScene
## Prefab for rows that represent skills inside the library ([Class PackedScene] → [Class LibrarySkillBar]).
@export var library_skill_bar_prefab: PackedScene


## The unit currently being edited/viewed by this panel.
var current_unit: Unit = null

## Local cache of current active skills (optional; bar is the source of truth).
var active_skills: Array[Skill] = []

## Local cache of current passive skills (optional; bar is the source of truth).
var passive_skills: Array[Skill] = []


## [b]Engine callback:[/b] wires signals and populates the skill library once.
func _ready() -> void:
	active_skills_rvbox.reordered.connect(on_active_skills_reordered)
	
	if skills_library_ui != null and not skills_library_ui.on_add_to_tactics.is_connected(_on_library_add_skill):
		skills_library_ui.on_add_to_tactics.connect(_on_library_add_skill)
	



## Called when [member active_skills_rvbox] reorders a child; re-number priorities and mirror to the unit.
## [param _from_index] and [param _to_index] are provided by [Class ReorderableVBox].
func on_active_skills_reordered(_from_index: int, _to_index: int) -> void:
	reprioritize_skills()


## Walks visible children of a [Class ReorderableVBox], assigns sequential priorities (1..N)
## to each [Class TacticsSkillBar], collects their [Class Skill]s, and mirrors the new order to the unit.
## Uses project helper [method ReorderableVBox._get_visible_children].
func reprioritize_skills() -> void:
	var iter_num: int = 1
	var sorted_active_skills: Array[Skill] = []
	var sorted_passive_skills: Array[Skill] = []
	
	var active_rvbox: ReorderableVBox = active_skills_rvbox
	var passive_rvbox: ReorderableVBox = passive_skills_rvbox
	
	
	for child in active_rvbox._get_visible_children():
		if child is TacticsSkillBar:
			child.set_priority_num(iter_num)
			iter_num += 1
			var curr_skill: Skill = child.get_current_skill()
			if curr_skill:
				sorted_active_skills.append(curr_skill)
	
	# Reset iteration number for passive skills
	iter_num = 1
	
	for child in passive_rvbox._get_visible_children():
		if child is TacticsSkillBar:
			child.set_priority_num(iter_num)
			iter_num += 1
			var curr_skill: Skill = child.get_current_skill()
			if curr_skill:
				sorted_passive_skills.append(curr_skill)
	
	
	
	#if !sorted_skills.is_empty():
	populate_unit_from_tactics_ui(sorted_active_skills, sorted_passive_skills)


## Writes the new prioritized skill array back into the unit’s tactic via [code]TacticsController[/code].
## [param resorted_skills] is the new order from the UI.
func populate_unit_from_tactics_ui(resorted_active_skills: Array[Skill], resorted_passive_skills: Array[Skill]) -> void:
	if !current_unit:
		return
	
	current_unit.tactics_controller.set_current_tactic_from_skills(resorted_active_skills, resorted_passive_skills)


## Populates the entire panel from [param in_unit]: header, clears old bars, spawns bars for active skills.
func populate_from_unit(in_unit: Unit) -> void:
	if !in_unit:
		return
	
	current_unit = in_unit
	
	set_tactics_header(in_unit.ui_name)
	
	clear_all_skills()

	setup_skills_container(in_unit)



## Sets the title label at the top using the unit’s display name.
func set_tactics_header(in_unit_ui_name: String) -> void:
	tactics_header_label.set_text(in_unit_ui_name + " Tactics Manager")


## Rebuilds “Condition 1..N” column headers according to [member max_conditions_count].
## Duplicates the first child label as a template, clears existing children, then adds N labels.
func setup_conditions_headers() -> void:
	var condition_header_template: Label = conditions_header_hbox.get_children().front() as Label
	
	condition_header_template = condition_header_template.duplicate()
	
	for child in conditions_header_hbox.get_children():
		child.queue_free()
	
	for i in range(max_conditions_count):
		var new_header: Label = condition_header_template.duplicate()
		new_header.set_text("Condition " + str(i + 1))
		conditions_header_hbox.add_child(new_header)
		


## Spawns [Class TacticsSkillBar] rows for the unit’s valid active skills into [param in_skill_cont].
## Bars are initialized with [member max_conditions_count] and wired for update callbacks.
func setup_skills_container(in_unit: Unit) -> void:
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
	
	# Reset the iteration number for passive skills
	iteration_num = 1
	
	for p_skill in p_skills:
		var new_skillbar: TacticsSkillBar = tactics_skill_bar_prefab.instantiate() as TacticsSkillBar
		
		new_skillbar.max_conditions_count = max_conditions_count

		passive_skills_rvbox.add_child(new_skillbar)
		new_skillbar.populate_from_skill(p_skill)
		new_skillbar.set_priority_num(iteration_num)
		
		new_skillbar.on_tactics_skill_bar_update.connect(on_tactics_skill_bar_update)
		
		iteration_num += 1
		
		if iteration_num >= 10:
			break





## Called by child bars when their contents change; re-derives priority and mirrors to the unit.
func on_tactics_skill_bar_update() -> void:
	reprioritize_skills()



## Clears both active/passive containers and resets local caches. Removes all bar children.
func clear_all_skills() -> void:
	active_skills.clear()
	passive_skills.clear()
	
	
	for child in active_skills_rvbox.get_children():
		child.queue_free()
	
	for child in passive_skills_rvbox.get_children():
		child.queue_free()


# --------------------------------------------------------------------------------------
# Skill Library Functions
# --------------------------------------------------------------------------------------




## Handles “Add to Tactics” from a library row: duplicates the skill, clears external conditions/preferences,
## chooses the correct container by category, spawns a bar, then fixes/prioritizes ordering.
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
	reprioritize_skills()


## Chooses the correct target container for a given [param in_category].[br]
## Defaults to the active list for FREE/unknown categories.
func _get_container_for_category(in_category: int) -> ReorderableVBox:
	if int(in_category) == int(Skill.SkillCategory.ACTIVE):
		return active_skills_rvbox
	elif int(in_category) == int(Skill.SkillCategory.PASSIVE):
		return passive_skills_rvbox
	else:
		# Default to active for FREE or others, adjust as you prefer
		return active_skills_rvbox


## Instantiates a [Class TacticsSkillBar] for [param in_skill], adds it to [param target_rvbox],
## sets its priority label to the end-of-list position, and wires update callbacks.
## [b]Returns:[/b] the created bar or [code]null[/code] on failure.
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
