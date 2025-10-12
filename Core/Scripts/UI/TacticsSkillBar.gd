class_name TacticsSkillBar
extends PanelContainer

@export_category("References")
@export var priority_number_label: Label
@export var skill_name_label: Label
@export var conditions_rhbox: ReorderableHBox

@export var red_style_box: StyleBoxFlat
@export var blue_style_box: StyleBoxFlat
@export var gray_style_box: StyleBoxFlat

var priority_num: int = 0
var max_conditions_count: int = 4


var current_skill: Skill = null

var current_conditions: Array[SkillCondition] = []


func _ready() -> void:
	# Keep the label order → skill arrays in sync when the user drags items.
	if conditions_rhbox and not conditions_rhbox.reordered.is_connected(_on_conditions_reordered):
		conditions_rhbox.reordered.connect(_on_conditions_reordered)


func populate_from_skill(in_skill: Skill) -> void:
	if !in_skill:
		return
	
	current_skill = in_skill
	
	set_skill_name(in_skill.skill_name)
	
	set_skill_conditions_from(in_skill)
	
	if in_skill.skill_type == in_skill.SkillType.ACTIVE:
		set_self_as_active()
	elif  in_skill.skill_type == in_skill.SkillType.PASSIVE:
		set_self_as_passive()

func set_skill_conditions_from(in_skill: Skill) -> void:
	# Build default UI order: external conditions first, then preferences.
	var external_conditions: Array[SkillCondition] = in_skill.get_external_skill_conditions()
	var target_preferences: Array[TargetPreference] = in_skill.get_target_preferences()

	current_conditions.clear()
	current_conditions.append_array(external_conditions)
	current_conditions.append_array(target_preferences)

	# Fill any number of Label children under conditions_rhbox.
	var label_controls: Array[Control] = conditions_rhbox._get_visible_children()
	var label_count: int = label_controls.size()
	var fill_count: int = min(current_conditions.size(), label_count)

	for label_index in range(label_count):
		var label_node := label_controls[label_index] as Label
		if label_node == null:
			continue

		# Assign condition or leave blank.
		var cond_at_index: SkillCondition = null
		if label_index < fill_count:
			cond_at_index = current_conditions[label_index]

		# Store the object on the node so reordering the nodes reorders the data too.
		label_node.set_meta("skill_condition", cond_at_index)

		if cond_at_index != null:
			label_node.set_text(Utilities.get_condition_display_name(cond_at_index))
		else:
			label_node.set_text("Blank")




func _on_conditions_reordered(_from_index: int, _to_index: int) -> void:
	# Recompute the unified order from the current node order.
	var new_order: Array[SkillCondition] = []
	var label_controls: Array[Control] = conditions_rhbox._get_visible_children()

	for child_control in label_controls:
		var label_node := child_control as Label
		if label_node == null:
			continue
		if label_node.has_meta("skill_condition"):
			var cond_obj: SkillCondition = label_node.get_meta("skill_condition") as SkillCondition
			# We only keep non-null conditions (blank labels are placeholders).
			if cond_obj is SkillCondition and cond_obj != null:
				new_order.append(cond_obj)

	current_conditions.assign(new_order)

	# Push the split order back into the Skill so logic respects UI order.
	_apply_conditions_order_to_skill()

	# Optional: refresh texts (not strictly required because labels keep their own text).
	#_refresh_condition_labels()


func _apply_conditions_order_to_skill() -> void:
	if current_skill == null:
		return

	var new_external: Array[SkillCondition] = []
	var new_preferences: Array[TargetPreference] = []

	for cond in current_conditions:
		if cond == null:
			continue
		# TargetPreference extends SkillCondition, so check that first.
		if cond is TargetPreference:
			new_preferences.append(cond as TargetPreference)
		else:
			new_external.append(cond)

	# Write back to the skill so runtime logic uses the new order.
	current_skill.external_skill_conditions = new_external
	current_skill.target_preferences = new_preferences



func set_skill_conditions(in_skill: Skill) -> void:
	
	var external_conditions: Array[SkillCondition] = in_skill.get_external_skill_conditions()
	var target_preferences: Array[TargetPreference] = in_skill.get_target_preferences()
	var labels: Array[Control] = conditions_rhbox._get_visible_children()
	var iter_num: int = 0
	
	for i in range(max_conditions_count):
		var condition: SkillCondition = external_conditions.get(i)
		var cond_label: Label = labels.get(i) as Label
		if !condition:
			pass
			
		if condition:
			cond_label.set_text(Utilities.get_condition_display_name(condition))
			current_conditions.append(condition)
		else:
			cond_label.set_text("Blank")



func set_skill_name(in_name: String) -> void:
	if !skill_name_label:
		return
	skill_name_label.set_text(in_name)


func set_priority_num(in_priority: int) -> void:
	if in_priority >= 0 and in_priority <= 10:
		priority_num = in_priority
		priority_number_label.set_text(str(priority_num))
		
	return

func set_self_as_active() -> void:
	add_theme_stylebox_override("panel", red_style_box)

func set_self_as_passive() -> void:
	add_theme_stylebox_override("panel", blue_style_box)


func get_current_skill() -> Skill:
	return current_skill
