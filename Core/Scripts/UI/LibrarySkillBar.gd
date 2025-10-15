## [b]Class:[/b] LibrarySkillBar
## [i]A row in the Skill Library panel representing a single [Class Skill]. Shows category/type/traits, colors itself by category, and lets the user add the skill to tactics with a right-click.[/i]
##
## [b]Responsibilities[/b][br]
## • Displays a skill’s name, category, type, and up to three trait labels.[br]
## • Colors the name panel and labels using category/type-themed [Class LabelSettings] and [Class StyleBoxFlat]s.[br]
## • Emits [signal LibrarySkillBar.on_add_to_tactics] when the user requests to add the skill to the current tactics.[br]
##
## [b]Usage[/b][br]
## • Call [method populate_from_skill] with a [Class Skill] to bind data and update visuals.[br]
## • Right-click on the row (no modifiers) to emit [signal on_add_to_tactics] with this row’s skill.[br]
##
## [b]Notes[/b][br]
## • Logic unchanged; documentation comments only.[br]
## • Trait labels can be auto-hidden if they look like placeholders (see [member hide_not_filled_traits]).

class_name LibrarySkillBar
extends PanelContainer

## Emitted when the user asks to add this skill to the Tactics list (via right-click, no modifiers).
## Payload: ([param skill_to_add]: [Class Skill])
signal on_add_to_tactics(skill_to_add: Skill)

@export_category("References")
## Label showing the skill’s category (e.g., Active/Passive).
@export var category_label: Label
## Label showing the skill’s display name.
@export var skill_name_label: Label
## Container for type/trait labels.
@export var type_trait_hbox: HBoxContainer
## Colored panel behind the skill name (style changes by category).
@export var skill_name_panel_container: PanelContainer
## Label showing the skill’s type (e.g., Attack/Support/Sabotage).
@export var type_label: Label

@export_group("Trait Labels")
## If [code]true[/code], hides empty/placeholder trait labels automatically.
@export var hide_not_filled_traits: bool = true
## Optional trait labels (up to three).
@export var trait_label_1: Label
@export var trait_label_2: Label
@export var trait_label_3: Label

@export_group("LabelSettings")
## Label settings applied to category/type labels (red/blue/purple/gray themes).
@export var red_label_settings: LabelSettings
@export var blue_label_settings: LabelSettings
@export var purple_label_settings: LabelSettings
@export var gray_label_settings: LabelSettings

@export_group("Styleboxes")
## Styleboxes used to color the name panel by category.
@export var red_style_box: StyleBoxFlat
@export var blue_style_box: StyleBoxFlat
@export var gray_style_box: StyleBoxFlat

@export_category("Hover Settings")
## Hover tween durations (not used directly here; kept for parity with other rows).
@export var hover_in_duration_seconds: float = 0.12
@export var hover_out_duration_seconds: float = 0.18

@export_category("Highlight Settings")
## Optional highlight frame container and its styleboxes for hover/selection feedback.
@export var highlight_container: PanelContainer
@export var style_box_unhighlighted_texture: StyleBoxFlat = null
@export var style_box_highlighted_texture: StyleBoxFlat = null
@export var style_box_selected_texture: StyleBoxFlat = null

## Selection/hover state flags used by highlight helpers.
var is_selected: bool = false
var is_highlighted: bool = false
var is_hovered: bool = false

## The [Class Skill] this row is currently representing (set by [method populate_from_skill]).
var current_skill: Skill = null


# --- Helpers to turn enum value -> readable text ---
## Utility: look up the name for [param enum_value] inside [param enum_dict] (like [member Skill.SkillCategory]).
static func _enum_name_from_dictionary(enum_dict: Dictionary, enum_value: int) -> String:
	var key_variant: Variant = enum_dict.find_key(enum_value)
	if key_variant == null:
		return str(enum_value)
	var key_text: String = str(key_variant)
	key_text = key_text.replace("_", " ")
	return key_text.capitalize()

## Human-readable text for [Class Skill].SkillCategory.
static func _category_text(cat_value: int) -> String:
	return _enum_name_from_dictionary(Skill.SkillCategory, cat_value)

## Human-readable text for [Class Skill].SkillType.
static func _type_text(type_value: int) -> String:
	return _enum_name_from_dictionary(Skill.SkillType, type_value)


## [b]Engine callback:[/b] hooks the row-level GUI input for right-click actions.
func _ready() -> void:
	if not gui_input.is_connected(_on_library_gui_input):
		gui_input.connect(_on_library_gui_input)


## Populate UI from a [Class Skill]: labels, themed colors, and trait texts.
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


## Helper to assign/hide a trait label based on [param trait_value].
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


## Row-level input: Right-Click (no Shift/Ctrl) emits [signal on_add_to_tactics] with [member current_skill].
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


## Picks a category-appropriate [Class StyleBoxFlat] for the name panel. Returns a fallback if none set.
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


## Turns highlight on/off unless the row is currently [member is_selected].
func set_highlight(turn_highlight_on: bool) -> void:
	if is_selected:
		return
	
	if turn_highlight_on:
		highlight_container.add_theme_stylebox_override("panel", style_box_highlighted_texture)
		is_highlighted = true
	else:
		highlight_container.add_theme_stylebox_override("panel", style_box_unhighlighted_texture)
		is_highlighted = false


## Sets this row’s [member is_selected] state and applies the selected highlight stylebox.
func set_selected(in_is_selected: bool) -> void:
	if !in_is_selected:
		is_selected = false
		set_highlight(is_hovered)
	else:
		is_selected = true
		is_highlighted = false
		highlight_container.add_theme_stylebox_override("panel", style_box_selected_texture)


## Pointer entered: set [member is_hovered] and apply highlight.
func _on_mouse_entered() -> void:
	is_hovered = true
	set_highlight(true)


## Pointer exited: if not selected, remove highlight.
func _on_mouse_exited() -> void:
	if !is_selected:
		set_highlight(false)
