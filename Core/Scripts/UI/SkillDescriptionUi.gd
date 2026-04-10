class_name SkillDescriptionUI
extends PanelContainer

const ACTIVE_BORDER_COLOR := Color(0.61, 0.12, 0.12, 1)
const PASSIVE_BORDER_COLOR := Color(0.121999994, 0.5042667, 0.61, 1)
const ACTIVE_POINTS_COLOR := Color(1, 0.63, 0.63, 1)
const PASSIVE_POINTS_COLOR := Color(0.63, 0.8951667, 1, 1)

@export var skill_name_label: Label = null
@export var points_label: Label
@export var potency_label: Label
@export var damage_type_label: Label
@export var hit_rate_label: Label
@export var skill_type_label: Label

@export var triggering_conditions_label: Label
@export var flavor_description_label: Label
@export var effects_label: Label

@export var skill_stats_container: PanelContainer
@export var skill_name_container: PanelContainer

var current_skill: Skill

func load_data_from_skill(in_skill: Skill) -> void:
	if in_skill == current_skill or in_skill == null:
		return
	current_skill = in_skill

	var is_passive := in_skill.skill_category == Skill.SkillCategory.PASSIVE
	_apply_theme(is_passive)

	skill_name_label.set_text(in_skill.skill_name)
	points_label.set_text("◆".repeat(in_skill.skill_cost) + "◇".repeat(max(0, 3 - in_skill.skill_cost)))
	if in_skill.skill_type == Skill.SkillType.ATTACK:
		potency_label.set_text(str(in_skill.base_power))
		damage_type_label.set_text("Impact")
	else:
		potency_label.set_text("None")
		damage_type_label.set_text("None")

	hit_rate_label.set_text(str(in_skill.base_accuracy + 5))

	match in_skill.skill_type:
		Skill.SkillType.ATTACK:
			skill_type_label.set_text("Attack")
		Skill.SkillType.SUPPORT:
			skill_type_label.set_text("Support")
		Skill.SkillType.SABOTAGE:
			skill_type_label.set_text("Sabotage")
		Skill.SkillType.SPECIAL:
			skill_type_label.set_text("Special")

	if !in_skill.trigger_description.is_empty():
		triggering_conditions_label.set_text(in_skill.trigger_description)
	else:
		triggering_conditions_label.set_text("Triggering Conditions or Requirements")

	var description_text: String = ""
	for desc in in_skill.description:
		description_text += desc
		description_text += "\n"
	if !description_text.is_empty():
		flavor_description_label.set_text(description_text)


func _apply_theme(is_passive: bool) -> void:
	var border_color := PASSIVE_BORDER_COLOR if is_passive else ACTIVE_BORDER_COLOR
	var points_color := PASSIVE_POINTS_COLOR if is_passive else ACTIVE_POINTS_COLOR

	var root_style: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	root_style.border_color = border_color
	add_theme_stylebox_override("panel", root_style)

	var stats_style: StyleBoxFlat = skill_stats_container.get_theme_stylebox("panel").duplicate()
	stats_style.border_color = border_color
	skill_stats_container.add_theme_stylebox_override("panel", stats_style)

	var name_style: StyleBoxFlat = skill_name_container.get_theme_stylebox("panel").duplicate()
	name_style.border_color = border_color
	skill_name_container.add_theme_stylebox_override("panel", name_style)

	var points_settings: LabelSettings = points_label.label_settings.duplicate()
	points_settings.font_color = points_color
	points_label.label_settings = points_settings
