class_name UnitCharacterSheetUI
extends Control


@export_category("References")
@export var mouse_controller: MouseController = null
@export var pathfinding: PathfindingSystem= null
@export var tactics_manager_ui: TacticsManagerUI = null
@export var gear_container: GearContainer = null

@export_category("Scenes")
@export var character_sheet_part_panel_scene: PackedScene  # (Not used for body parts anymore)
@export var weapon_details_popup_scene: PackedScene = null

@export_category("Labels")
@export_group("Labels")
@export var unit_name_label: Label
@export var magic_class_label: Label
@export var martial_class_label: Label
#@export var armor_points_label: Label
@export var accuracy_label: Label
@export var critical_chance_label: Label
@export var martial_damage_label: Label
@export var channel_damage_label: Label
#@export var health_points_label: Label
@export var posture_points_label: Label

@export var experience_rolls_label: Label
@export var initiative_label: Label
@export var speed_label: Label
@export var unused_label_1: Label

# Attribute Labels
@export var might_label: Label
@export var endurance_label: Label
@export var agility_label: Label
@export var sense_label: Label
@export var mind_label: Label
@export var presence_label: Label

# Skill Labels
@export var martial_label: Label
@export var channel_label: Label
@export var parry_label: Label
@export var resist_label: Label
@export var clash_label: Label
@export var evade_label: Label
@export var will_label: Label

@export_category("Containers")
@export var status_container: VBoxContainer
@export var weapons_container: WeaponsContainer
@export var items_container: HBoxContainer
@export var tab_container: TabContainer

@export_category("Buttons")
@export var close_button: Button

var is_open: bool = false
var last_unit: Unit = null


static var tactic_presets: Array[Tactic] = []
static var copied_tactic_blueprint: Tactic = null

static var instance: UnitCharacterSheetUI = null


func _ready() -> void:
	if instance != null:
		push_error("There's more than one UnitCharacterSheetUI! - " + str(instance))
		queue_free()
		return
	instance = self
	visible = false

	# Ensure we always have 9 preset slots [0..8] for keys 1..9
	if tactic_presets.is_empty():
		var preset_slots_count: int = 9
		tactic_presets.resize(preset_slots_count)

	SignalBus.open_character_sheet.connect(_on_open_character_sheet)
	SignalBus.update_character_sheet.connect(update_character_sheet)
	close_button.pressed.connect(_on_close_button_pressed)


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("testkey_c"):
		open_character_sheet(null, 0)

	elif Input.is_action_just_pressed("t_key"):
		open_character_sheet(null, 1)
	

	_handle_tactics_preset_input(_event)


func update_character_sheet(update_skills: bool = false) -> void:
	if !is_open:
		return
	if !last_unit:
		return
	_populate_from_unit(last_unit, update_skills)

## Uses the tab index to open the character sheet at that tab through code.
func open_character_sheet(in_unit: Unit = null, tab_index: int = 0) -> void:
	# Grab the unit under the mouse or whichever unit you want

	var hovered_unit: Unit = mouse_controller.get_current_hovered_unit() if !in_unit else in_unit

	if hovered_unit:
		# Emit your signal passing in the unit reference
		_on_open_character_sheet(hovered_unit, tab_index)


func _on_open_character_sheet(unit: Unit, tab_index: int = 0) -> void:
	if not is_instance_valid(unit):
		hide()
		is_open = false
		last_unit = null
		return


	if not is_open and last_unit == unit:
		# Re-show the UI for the same unit
		show()
		is_open = true
		return


	if unit != last_unit:
		# Show and populate for a new unit
		last_unit = unit
		
		match tab_index:
			0:
				tab_container.set_current_tab(0)
			1:
				tab_container.set_current_tab(1)
		
		# Update labels
		_populate_from_unit(unit, true)
		# Update statuses list.
		#_populate_statuses(unit)
		#populate_weapons_from_unit(unit)
		show()
		is_open = true
		return
	
	if tab_container.get_current_tab() == 0 and Input.is_action_just_pressed("t_key"):
		tab_container.set_current_tab(1)
		return
	elif tab_container.get_current_tab() == 1 and Input.is_action_just_pressed("testkey_c"):
		tab_container.set_current_tab(0)
		return
	
	# Same unit and already visible → toggle off
	hide()
	is_open = false
	last_unit = null


func _on_close_button_pressed() -> void:
	hide()
	is_open = false
	return





func _populate_from_unit(unit: Unit, update_skills: bool = false) -> void:
	# Update basic attribute labels.
	if !is_instance_valid(unit):
		return
	unit_name_label.text = unit.ui_name
	
	magic_class_label.text = unit.character_sheet.class_manager.magic_class.ui_name
	martial_class_label.text = unit.character_sheet.class_manager.martial_class.ui_name
	
	#armor_points_label.text = str(unit.get_attributes_container().get_attribute("armor").get_current_modified_value())\
	# + "/" + str(unit.get_attributes_container().get_attribute("armor").maximum_value)
	#health_points_label.text = _get_attribute_or_na(unit, "health")\
	# + "/" + str(unit.get_attributes_container().get_attribute("health").maximum_value)
	posture_points_label.text = _get_attribute_or_na(unit, "posture")\
	 + "/" + str(unit.get_attributes_container().get_attribute("posture").get_max_value())
	martial_damage_label.set_text(get_min_max_martial_dmg(unit))
	channel_damage_label.set_text(get_min_max_channel_dmg(unit))
	accuracy_label.text = "+" + _get_attribute_or_na(unit, "accuracy")
	critical_chance_label.set_text("+" + _get_attribute_or_na(unit, "critical"))
	experience_rolls_label.text = "EXP: " + _get_attribute_or_na(unit, "experience_rolls")
	initiative_label.text = "INIT: " + _get_attribute_or_na(unit, "initiative")
	speed_label.set_text("SPD: " + _get_attribute_or_na(unit, "speed"))
	unused_label_1.text = ""


	might_label.text = _get_attribute_or_na(unit, "might")
	endurance_label.text = _get_attribute_or_na(unit, "endurance")
	agility_label.text = _get_attribute_or_na(unit, "agility")
	sense_label.text = _get_attribute_or_na(unit, "sense")
	mind_label.text = _get_attribute_or_na(unit, "mind")
	presence_label.text = _get_attribute_or_na(unit, "presence")
	

	martial_label.text = _get_attribute_or_na(unit, "martial")
	channel_label.text = _get_attribute_or_na(unit, "channel")
	parry_label.text = _get_attribute_or_na(unit, "parry")
	resist_label.text = _get_attribute_or_na(unit, "resist")
	clash_label.text = _get_attribute_or_na(unit, "clash")
	evade_label.text = _get_attribute_or_na(unit, "evade")
	will_label.text = _get_attribute_or_na(unit, "will")

	# Triggers the tactics manager to populate itself from the new unit
	if tactics_manager_ui and update_skills:
		tactics_manager_ui.populate_from_unit(unit)

	# Refresh the gear panel for the new unit.
	if gear_container != null:
		gear_container.show_for_unit(unit)

	_populate_statuses(unit)

	last_unit = unit


func get_min_max_martial_dmg(unit: Unit) -> String:
	var charsheet: CharacterSheet = unit.character_sheet
	var weapon: Weapon = charsheet.equipment_container.get_weapon("weapon_main")
	var weapon_min: int = 1 # Note Get weapon damages here
	var weapon_max: int = 3
	if weapon:
		weapon_min = weapon.damage_min
		weapon_max = weapon.damage_max
	
	var martial_val: int = int(_get_attribute_or_na(unit, "martial"))
	
	weapon_min += martial_val
	weapon_max += martial_val
	
	var string: String = str(weapon_min) + " - " + str(weapon_max)
	
	return string


func get_min_max_channel_dmg(unit: Unit) -> String:
	var focus_min: int = 1 # Note Get focus damages here
	var focus_max: int = 2
	
	var channel_val: int = int(_get_attribute_or_na(unit, "channel"))
	
	focus_min += channel_val
	focus_max += channel_val
	
	var string: String = str(focus_min) + " - " + str(focus_max)
	
	return string



#func populate_weapons_from_unit(unit: Unit) -> void:
	#if not is_instance_valid(unit) or not is_instance_valid(unit.equipment):
		#weapons_container.clear_weapons_display()
		#return
#
	#var all_equipped_items = unit.equipment.equipped_items
	#var equipped_weapons: Array[Weapon] = []
	#for item in all_equipped_items:
		#if item is Weapon:
			#equipped_weapons.append(item as Weapon)
	#
	#weapons_container.populate_weapons(equipped_weapons, self)

func _get_attribute_or_na(unit: Unit, attribute_name: String) -> String:
	if not is_instance_valid(unit) or not is_instance_valid(unit.get_attributes_container()):
		return "n/a"

	var attribute: Attribute = unit.get_attributes_container().get_attribute(attribute_name)
	if attribute == null:
		return "n/a"

	return str(int(attribute.get_current_modified_value()))


func _populate_statuses(unit: Unit) -> void:
	# Clear the status container first.
	for child in status_container.get_children():
		child.queue_free()

	if not is_instance_valid(unit) or not is_instance_valid(unit.status_controller):
		return

	var all_statuses: Array[Status] = unit.status_controller.statuses
	
	for status in all_statuses:

		# Base text is the status's name.
		var text = status.ui_name
		
		if status.status_level >= 2:
			text += " " + str(status.status_level)
			
		# Optionally display extra details such as rounds left.
		if status.has_method("get_remaining_rounds"):
			var rounds_left = status.call("get_remaining_rounds")
			text += " (%d rounds left)" % int(rounds_left)

		# If the status offers details, make it clickable.
		if status.has_method("get_details_text"):
			var detail_button = Button.new()
			detail_button.text = text
			detail_button.pressed.connect(_on_status_details_pressed.bind(status))
			status_container.add_child(detail_button)
		else:
			var label = Label.new()
			label.text = text
			status_container.add_child(label)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _on_status_details_pressed(status: Status) -> void:
	var popup = AcceptDialog.new()
	popup.title = status.ui_name
	
	var info_str = "Status: %s" % status.ui_name
	if status.has_method("get_details_text"):
		info_str += "\n" + status.get_details_text()
	else:
		info_str += "\n(No extra information available.)"
		
	popup.dialog_text = info_str
	UILayer.instance.add_child(popup)
	popup.popup_centered()



# Tactics Preset Functions - - - - - - - - - - - - - - - 
func _handle_tactics_preset_input(input_event: InputEvent) -> void:
	var key_event: InputEventKey = input_event as InputEventKey
	if key_event == null:
		return
	if key_event.pressed == false or key_event.echo:
		return

	# Only allow presets while the sheet is open
	if is_open == false:
		return
	if tab_container == null:
		return
	# Assuming tab 1 is your Tactics tab
	if tab_container.get_current_tab() != 1:
		return

	# Only during player planning
	if TurnSystem.instance != null:
		if TurnSystem.instance.current_phase != TurnSystem.RoundPhase.PLAYER_PLANNING:
			return

	# Ctrl+C / Ctrl+V for copy / paste
	if key_event.ctrl_pressed:
		if key_event.keycode == KEY_C:
			_copy_current_tactic_to_clipboard()
			return
		if key_event.keycode == KEY_V:
			_paste_clipboard_to_current_unit()
			return

	# Number keys 1..9 for presets
	var preset_index: int = _get_preset_index_from_keycode(key_event.keycode)
	if preset_index == -1:
		return

	# Shift + [num] → save; [num] → load
	if key_event.shift_pressed:
		_save_preset_from_current_unit(preset_index)
	else:
		_apply_preset_to_current_unit(preset_index)

func _get_preset_index_from_keycode(keycode_value: int) -> int:
	match keycode_value:
		KEY_1:
			return 0
		KEY_2:
			return 1
		KEY_3:
			return 2
		KEY_4:
			return 3
		KEY_5:
			return 4
		KEY_6:
			return 5
		KEY_7:
			return 6
		KEY_8:
			return 7
		KEY_9:
			return 8
		_:
			return -1


func _build_blueprint_from_tactic(source_tactic: Tactic) -> Tactic:
	if source_tactic == null:
		return null

	var blueprint_tactic: Tactic = Tactic.new()

	var source_active_skills: Array[Skill] = source_tactic.get_valid_active_skills()
	for source_active_skill in source_active_skills:
		if source_active_skill == null:
			continue
		var duplicated_active_skill: Skill = source_active_skill.duplicate(true)
		duplicated_active_skill.unit = null
		duplicated_active_skill._invalidate_condition_caches()
		blueprint_tactic.active_skills.append(duplicated_active_skill)

	var source_passive_skills: Array[Skill] = source_tactic.get_valid_passive_skills()
	for source_passive_skill in source_passive_skills:
		if source_passive_skill == null:
			continue
		var duplicated_passive_skill: Skill = source_passive_skill.duplicate(true)
		duplicated_passive_skill.unit = null
		duplicated_passive_skill._invalidate_condition_caches()
		blueprint_tactic.passive_skills.append(duplicated_passive_skill)

	return blueprint_tactic


func _save_preset_from_current_unit(preset_index: int) -> void:
	if last_unit == null:
		return
	if last_unit.tactics_controller == null:
		return

	var source_tactic: Tactic = last_unit.tactics_controller.current_tactic
	if source_tactic == null:
		return

	var blueprint_tactic: Tactic = _build_blueprint_from_tactic(source_tactic)
	if blueprint_tactic == null:
		return

	if preset_index < 0:
		return

	if preset_index >= tactic_presets.size():
		tactic_presets.resize(preset_index + 1)

	tactic_presets[preset_index] = blueprint_tactic
	CombatLog.instance.add_log("Saved tactics preset " + str(preset_index + 1) + " for " + last_unit.ui_name)


func _apply_preset_to_current_unit(preset_index: int) -> void:
	if last_unit == null:
		return
	if last_unit.tactics_controller == null:
		return
	if preset_index < 0 or preset_index >= tactic_presets.size():
		return

	var preset_tactic: Tactic = tactic_presets[preset_index]
	if preset_tactic == null:
		CombatLog.instance.add_log("No tactics preset in slot " + str(preset_index + 1))
		return

	# Duplicate and bind to this unit so skills are unique
	var duplicated_tactic_for_unit: Tactic = preset_tactic.duplicate(true)
	duplicated_tactic_for_unit.make_skills_unique(last_unit)
	last_unit.tactics_controller.current_tactic = duplicated_tactic_for_unit

	# Refresh the tactics UI so rows/conditions match the new tactic
	if tactics_manager_ui != null:
		tactics_manager_ui.populate_from_unit(last_unit)

	CombatLog.instance.add_log("Loaded tactics preset " + str(preset_index + 1) + " onto " + last_unit.ui_name)



func _copy_current_tactic_to_clipboard() -> void:
	if last_unit == null:
		return
	if last_unit.tactics_controller == null:
		return

	var source_tactic: Tactic = last_unit.tactics_controller.current_tactic
	if source_tactic == null:
		return

	copied_tactic_blueprint = _build_blueprint_from_tactic(source_tactic)
	if copied_tactic_blueprint != null:
		CombatLog.instance.add_log("Copied tactics from " + last_unit.ui_name)

func _paste_clipboard_to_current_unit() -> void:
	if last_unit == null:
		return
	if last_unit.tactics_controller == null:
		return
	if copied_tactic_blueprint == null:
		CombatLog.instance.add_log("No tactics copied to paste")
		return

	var duplicated_tactic_for_unit: Tactic = copied_tactic_blueprint.duplicate(true)
	duplicated_tactic_for_unit.make_skills_unique(last_unit)
	last_unit.tactics_controller.current_tactic = duplicated_tactic_for_unit

	if tactics_manager_ui != null:
		tactics_manager_ui.populate_from_unit(last_unit)

	CombatLog.instance.add_log("Pasted tactics onto " + last_unit.ui_name)
