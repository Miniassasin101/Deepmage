class_name SkillsLibraryUI
extends PanelContainer

## Emitted when the user wants to add a skill from the library to tactics.
signal on_add_to_tactics(skill_to_add: Skill)


@export_category("References")
@export var search_line_edit: LineEdit
@export var skills_scroll_container: ScrollContainer
@export var skill_library_vbox: VBoxContainer

@export_category("Prefabs")
@export var library_skill_bar_prefab: PackedScene

var current_unit: Unit = null



func _ready() -> void:
	# Optional: make scroll a little chunkier, same as before.
	if skills_scroll_container != null:
		var vertical_scroll_bar: VScrollBar = skills_scroll_container.get_v_scroll_bar()
		if vertical_scroll_bar != null:
			vertical_scroll_bar.step = 30.0
	
	# Search → refresh
	if search_line_edit != null and not search_line_edit.text_changed.is_connected(_on_search_changed):
		search_line_edit.text_changed.connect(_on_search_changed)
	
	
	_refresh_skill_list()


func refresh_from_global_library() -> void:
	# Public helper if you ever need to force a refresh from outside.
	_refresh_skill_list()


func _on_search_changed(_new_text: String) -> void:
	_refresh_skill_list()


func _refresh_skill_list() -> void:
	if skill_library_vbox == null:
		return
	
	_clear_skill_list()
	
	var combat_system: CombatSystem = CombatSystem.instance
	if combat_system == null:
		return
	
	var skill_library: SkillLibrary = combat_system.get_skill_library()
	if skill_library == null:
		return
	
	var sorted_skills: Array[Skill] = skill_library.get_skills_sorted_by_category_type_name()
	
	var normalized_query: String = ""
	if search_line_edit != null:
		normalized_query = search_line_edit.text.strip_edges().to_lower()
	
	var allow_all: bool = DebugSettings.instance != null and DebugSettings.instance.allow_all_skills_in_tactics

	var cm: ClassManager = null
	if current_unit != null and current_unit.character_sheet != null:
		cm = current_unit.character_sheet.class_manager

	for skill_entry: Skill in sorted_skills:
		if skill_entry == null:
			continue

		if not _matches_query(skill_entry, normalized_query):
			continue

		if !allow_all and cm != null:
			if !cm.can_use_skill(skill_entry):
				continue

		
		var row_bar: LibrarySkillBar = library_skill_bar_prefab.instantiate() as LibrarySkillBar
		skill_library_vbox.add_child(row_bar)
		row_bar.populate_from_skill(skill_entry)
		
		if not row_bar.on_add_to_tactics.is_connected(_on_row_add_to_tactics):
			row_bar.on_add_to_tactics.connect(_on_row_add_to_tactics)


func _matches_query(skill_entry: Skill, normalized_query: String) -> bool:
	# Empty search → show everything.
	if normalized_query == "" or normalized_query.length() == 0:
		return true
	
	var text_chunks: Array[String] = []
	
	# Name
	if skill_entry.skill_name != null and str(skill_entry.skill_name) != "":
		text_chunks.append(str(skill_entry.skill_name).to_lower())
	
	# Category / type (as text; good enough for filtering)
	text_chunks.append(str(skill_entry.skill_category).to_lower())
	text_chunks.append(str(skill_entry.skill_type).to_lower())
	
	# Traits
	if str(skill_entry.trait_1) != "":
		text_chunks.append(str(skill_entry.trait_1).to_lower())
	if str(skill_entry.trait_2) != "":
		text_chunks.append(str(skill_entry.trait_2).to_lower())
	if str(skill_entry.trait_3) != "":
		text_chunks.append(str(skill_entry.trait_3).to_lower())
	
	var combined_text: String = " ".join(text_chunks)
	return combined_text.find(normalized_query) != -1


func _clear_skill_list() -> void:
	if skill_library_vbox == null:
		return
	
	for child_control in skill_library_vbox.get_children():
		child_control.queue_free()


func _on_row_add_to_tactics(skill_to_add: Skill) -> void:
	if skill_to_add == null:
		return

	var allow_all: bool = DebugSettings.instance != null and DebugSettings.instance.allow_all_skills_in_tactics
	if !allow_all and current_unit != null and current_unit.character_sheet != null:
		var cm: ClassManager = current_unit.character_sheet.find_child("ClassManager") as ClassManager
		if cm != null and !cm.can_use_skill(skill_to_add):
			CombatLog.instance.add_log("Cannot add skill (not available): " + skill_to_add.skill_name)
			return

	on_add_to_tactics.emit(skill_to_add)



func set_current_unit(u: Unit) -> void:
	current_unit = u
	_refresh_skill_list()
