class_name LibrarySkillBar
extends PanelContainer

signal on_add_to_tactics(skill_to_add: Skill)

@export_category("References")
@export var category_label: Label
@export var skill_name_label: Label
@export var type_trait_hbox: HBoxContainer
@export var skill_name_panel_container: PanelContainer
@export var type_label: Label

@export_group("Trait Labels")
@export var hide_not_filled_traits: bool = true
@export var trait_label_1: Label
@export var trait_label_2: Label
@export var trait_label_3: Label

@export_group("LabelSettings")
@export var red_label_settings: LabelSettings
@export var blue_label_settings: LabelSettings
@export var purple_label_settings: LabelSettings
@export var gray_label_settings: LabelSettings

@export_group("Styleboxes")
@export var red_style_box: StyleBoxFlat
@export var blue_style_box: StyleBoxFlat
@export var gray_style_box: StyleBoxFlat

@export_category("Hover Settings")
@export var hover_in_duration_seconds: float = 0.12
@export var hover_out_duration_seconds: float = 0.18

@export_category("Highlight Settings")
@export var highlight_container: PanelContainer
@export var style_box_unhighlighted_texture: StyleBoxFlat = null
@export var style_box_highlighted_texture: StyleBoxFlat = null
@export var style_box_selected_texture: StyleBoxFlat = null

var is_selected: bool = false

var is_highlighted: bool = false

var is_hovered: bool = false



var current_skill: Skill = null




# --- Helpers to turn enum value -> readable text ---
static func _enum_name_from_dictionary(enum_dict: Dictionary, enum_value: int) -> String:
	var key_variant: Variant = enum_dict.find_key(enum_value)
	if key_variant == null:
		return str(enum_value)
	var key_text: String = str(key_variant)
	key_text = key_text.replace("_", " ")
	return key_text.capitalize()

static func _category_text(cat_value: int) -> String:
	return _enum_name_from_dictionary(Skill.SkillCategory, cat_value)

static func _type_text(type_value: int) -> String:
	return _enum_name_from_dictionary(Skill.SkillType, type_value)






func _ready() -> void:
	if not gui_input.is_connected(_on_library_gui_input):
		gui_input.connect(_on_library_gui_input)

func populate_from_skill(in_skill: Skill) -> void:
	if in_skill == null:
		return
	current_skill = in_skill

	# Texts
	if skill_name_label != null:
		skill_name_label.text = in_skill.skill_name

	if category_label != null:
		category_label.text = _category_text(int(in_skill.skill_category))
	if type_label != null:
		type_label.text = _type_text(int(in_skill.skill_type))

	# Category color -> name panel stylebox
	if skill_name_panel_container != null:
		var use_style: StyleBoxFlat = _get_style_for_category(int(in_skill.skill_category))
		if use_style != null:
			var unique_box: StyleBoxFlat = use_style.duplicate()
			# Make sure center draws; set once defensively
			unique_box.draw_center = true
			skill_name_panel_container.add_theme_stylebox_override("panel", unique_box)
			# If you want the whole LibrarySkillBar background to match too, uncomment:
			# add_theme_stylebox_override("panel", unique_box.duplicate())

	# LabelSettings
	if category_label != null:
		if int(in_skill.skill_category) == int(Skill.SkillCategory.ACTIVE):
			category_label.label_settings = red_label_settings
		elif int(in_skill.skill_category) == int(Skill.SkillCategory.PASSIVE):
			category_label.label_settings = blue_label_settings
		else:
			category_label.label_settings = gray_label_settings

	if type_label != null:
		var use_settings: LabelSettings = gray_label_settings
		if int(in_skill.skill_type) == int(Skill.SkillType.ATTACK):
			use_settings = red_label_settings
		elif int(in_skill.skill_type) == int(Skill.SkillType.SUPPORT):
			use_settings = blue_label_settings
		elif int(in_skill.skill_type) == int(Skill.SkillType.SABOTAGE):
			use_settings = purple_label_settings
		else:
			use_settings = gray_label_settings
		type_label.label_settings = use_settings

	# Traits
	_set_trait_text(trait_label_1, in_skill.trait_1)
	_set_trait_text(trait_label_2, in_skill.trait_2)
	_set_trait_text(trait_label_3, in_skill.trait_3)

func _set_trait_text(trait_label: Label, trait_value: String) -> void:
	if trait_label == null:
		return
	var cleaned: String = trait_value.strip_edges()
	var looks_like_placeholder: bool = cleaned.begins_with("Trait ")
	if hide_not_filled_traits and (cleaned == "" or looks_like_placeholder):
		trait_label.visible = false
	else:
		trait_label.visible = true
		trait_label.text = cleaned

func _on_library_gui_input(input_event: InputEvent) -> void:
	var mouse_button: InputEventMouseButton = input_event as InputEventMouseButton
	if mouse_button == null:
		return
	if not mouse_button.pressed:
		return

	# Right-click with no modifiers → request add to tactics
	var is_right_click: bool = int(mouse_button.button_index) == MOUSE_BUTTON_RIGHT
	var shift_down: bool = Input.is_key_pressed(KEY_SHIFT)
	var ctrl_down: bool = Input.is_key_pressed(KEY_CTRL)

	if is_right_click and not shift_down and not ctrl_down and current_skill != null:
		on_add_to_tactics.emit(current_skill)

func _get_style_for_category(cat_value: int) -> StyleBoxFlat:
	var picked: StyleBoxFlat = null
	if int(cat_value) == int(Skill.SkillCategory.ACTIVE):
		picked = red_style_box
	elif int(cat_value) == int(Skill.SkillCategory.PASSIVE):
		picked = blue_style_box
	else:
		picked = gray_style_box

	if picked == null:
		# Fallback so it never silently fails
		var fallback_box: StyleBoxFlat = StyleBoxFlat.new()
		if int(cat_value) == int(Skill.SkillCategory.ACTIVE):
			fallback_box.bg_color = Color(0.55, 0.12, 0.14, 1.0) # red-ish
		elif int(cat_value) == int(Skill.SkillCategory.PASSIVE):
			fallback_box.bg_color = Color(0.12, 0.34, 0.45, 1.0) # blue-ish
		else:
			fallback_box.bg_color = Color(0.28, 0.28, 0.30, 1.0) # gray-ish
		fallback_box.border_width_all = 1
		fallback_box.border_color = fallback_box.bg_color.darkened(0.35)
		fallback_box.corner_radius_all = 8
		return fallback_box
	else:
		return picked



func set_highlight(turn_highlight_on: bool) -> void:
	if is_selected:
		return
	
	if turn_highlight_on:
		highlight_container.add_theme_stylebox_override("panel", style_box_highlighted_texture)
		is_highlighted = true
	else:
		highlight_container.add_theme_stylebox_override("panel", style_box_unhighlighted_texture)
		is_highlighted = false


func set_selected(in_is_selected: bool) -> void:
	if !in_is_selected:
		is_selected = false
		set_highlight(is_hovered)
	else:
		is_selected = true
		is_highlighted = false
		highlight_container.add_theme_stylebox_override("panel", style_box_selected_texture)


func _on_mouse_entered() -> void:

	is_hovered = true
	
	set_highlight(true)





func _on_mouse_exited() -> void:
	if !is_selected:
		set_highlight(false)
