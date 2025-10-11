class_name UnitCharacterSheetUI
extends Control


@export_category("References")
@export var mouse_controller: MouseController = null
@export var pathfinding: PathfindingSystem= null

@export_category("Scenes")
@export var character_sheet_part_panel_scene: PackedScene  # (Not used for body parts anymore)
@export var weapon_details_popup_scene: PackedScene = null

@export_category("Labels")
@export var unit_name_label: Label
#@export var armor_points_label: Label
@export var speed_label: Label
@export var jump_label: Label
#@export var health_points_label: Label
@export var posture_points_label: Label

@export var experience_rolls_label: Label
@export var movement_rate_label: Label
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
@export var conditions_container: VBoxContainer
@export var weapons_container: WeaponsContainer
@export var items_container: HBoxContainer

@export_category("Buttons")
@export var close_button: Button

var is_open: bool = false
var last_unit: Unit = null

func _ready() -> void:
	visible = false
	SignalBus.open_character_sheet.connect(_on_open_character_sheet)
	close_button.pressed.connect(_on_close_button_pressed)


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("testkey_c"):
		open_character_sheet()




func open_character_sheet(in_unit: Unit = null) -> void:
	# Grab the unit under the mouse or whichever unit you want

	var hovered_unit: Unit = mouse_controller.get_current_hovered_unit() if !in_unit else in_unit
		#pathfinding.pathfinding_grid_system.get_grid_position(result)
	if hovered_unit:
		# Emit your signal passing in the unit reference
		_on_open_character_sheet(hovered_unit)


func _on_open_character_sheet(unit: Unit) -> void:
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
		# Update labels
		_populate_from_unit(unit)
		# Update conditions list.
		#_populate_conditions(unit)
		#populate_weapons_from_unit(unit)
		show()
		is_open = true
		return

	# Same unit and already visible → toggle off
	hide()
	is_open = false
	last_unit = null


func _on_close_button_pressed() -> void:
	hide()
	is_open = false
	return

func _populate_from_unit(unit: Unit) -> void:
	# Update basic attribute labels.
	if !is_instance_valid(unit):
		return
	unit_name_label.text = unit.ui_name

	#armor_points_label.text = str(unit.get_attributes_container().get_attribute("armor").get_current_modified_value())\
	# + "/" + str(unit.get_attributes_container().get_attribute("armor").maximum_value)
	#health_points_label.text = _get_attribute_or_na(unit, "health")\
	# + "/" + str(unit.get_attributes_container().get_attribute("health").maximum_value)
	posture_points_label.text = _get_attribute_or_na(unit, "posture")\
	 + "/" + str(unit.get_attributes_container().get_attribute("posture").maximum_value)
	speed_label.set_text(_get_attribute_or_na(unit, "speed"))
	jump_label.text = _get_attribute_or_na(unit, "jump")
	experience_rolls_label.text = "EXP: " + _get_attribute_or_na(unit, "experience_rolls")
	movement_rate_label.text = "MOV: " + _get_attribute_or_na(unit, "movement_rate")
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

"""

func _populate_conditions(unit: Unit) -> void:
	# Clear the conditions container first.
	for child in conditions_container.get_children():
		child.queue_free()

	if not is_instance_valid(unit) or not is_instance_valid(unit.conditions_manager):
		return

	var all_conditions: Array[Condition] = unit.conditions_manager.get_all_conditions()
	
	for condition in all_conditions:
		var hbox = HBoxContainer.new()
		conditions_container.add_child(hbox)

		# Base text is the condition's name.
		var text = condition.ui_name
		
		# Optionally display extra details such as rounds left.
		if condition.has_method("get_remaining_rounds"):
			var rounds_left = condition.call("get_remaining_rounds")
			text += " (%d rounds left)" % int(rounds_left)

		# If the condition offers details, make it clickable.
		if condition.has_method("get_details_text"):
			var detail_button = Button.new()
			detail_button.text = text
			detail_button.pressed.connect(_on_condition_details_pressed.bind(condition))
			hbox.add_child(detail_button)
		else:
			var label = Label.new()
			label.text = text
			hbox.add_child(label)

func _on_condition_details_pressed(condition: Condition) -> void:
	var popup = AcceptDialog.new()
	popup.title = condition.ui_name
	
	var info_str = "Condition: %s" % condition.ui_name
	if condition.has_method("get_details_text"):
		info_str += "\n" + condition.get_details_text()
	else:
		info_str += "\n(No extra information available.)"
		
	popup.dialog_text = info_str
	UILayer.instance.add_child(popup)
	popup.popup_centered()

func show_weapon_details_popup(weapon: Weapon) -> void:
	# Shows a popup with detailed weapon information.
	assert(weapon is Weapon)
	var popup = ConfirmationDialog.new()
	popup.name = "WeaponDetailsPopup"
	popup.title = weapon.name
	popup.min_size = Vector2(400, 300)

	var weapon_info_container = VBoxContainer.new()

	var category_label = Label.new()
	category_label.text = "Category: %s" % weapon.category
	weapon_info_container.add_child(category_label)




	if weapon.traits.size() > 0:
		var traits_label = Label.new()
		traits_label.text = "Traits: %s" % ", ".join(weapon.traits)
		weapon_info_container.add_child(traits_label)

	if weapon.combat_effects.size() > 0:
		var effects_label = Label.new()
		effects_label.text = "Combat Effects: %s" % ", ".join(weapon.combat_effects)
		weapon_info_container.add_child(effects_label)

	var hands_label = Label.new()
	hands_label.text = "Hands Required: %s" % weapon.hands
	weapon_info_container.add_child(hands_label)

	popup.add_child(weapon_info_container)
	get_tree().root.add_child(popup)
	popup.popup_centered()
"""
