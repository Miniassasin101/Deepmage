class_name AttackPreviewSlideContainer
extends SlidePanelContainer

@export_category("Content")
@export var attack_name_label: Label
@export var min_max_dmg_label: Label
@export var accuracy_pool_label: Label
@export var target_successes_label: Label

func fill_from_attack(attack: AttackAction, attacker: Unit, target: Unit) -> void:
	if attack == null or attacker == null or target == null:
		clear()
		return

	# Attack name
	if attack_name_label:
		attack_name_label.text = attack.action_name

	# Attacker attributes container
	var att_cont: AttributesContainer = null
	if attacker:
		att_cont = attacker.get_attributes_container()

	# Accuracy preview pieces
	var acc_names: Array[String] = attack.get_accuracy_attributes()
	var acc_attr_name: String = ""
	var acc_skill_name: String = ""

	if acc_names.size() >= 1:
		acc_attr_name = acc_names[0]
	if acc_names.size() >= 2:
		acc_skill_name = acc_names[acc_names.size() - 1]

	var acc_attr_val: int = 0
	var acc_skill_val: int = 0

	if att_cont != null:
		if acc_attr_name != "":
			acc_attr_val = att_cont.get_attribute(acc_attr_name).get_current_modified_value()
		if acc_skill_name != "":
			acc_skill_val = att_cont.get_attribute(acc_skill_name).get_current_modified_value()

	if accuracy_pool_label:
		var total_acc := acc_attr_val + acc_skill_val
		accuracy_pool_label.text = "Acc: %s" % [total_acc]

	# Damage pool preview (deterministic min–max display)
	var dmg_attr_val: int = 0
	if att_cont != null and attack.damage_attribute != "":
		dmg_attr_val = att_cont.get_attribute_current_value(attack.damage_attribute)

	var defense: int = 0
	var def_cont: AttributesContainer = null
	if target != null:
		def_cont = target.get_attributes_container()
		if def_cont != null:
			defense = def_cont.get_defence()

	var base: int = attack.base_damage
	var pool: int = dmg_attr_val + base - defense
	if pool < 0:
		pool = 0

	if min_max_dmg_label:
		min_max_dmg_label.text = "Dmg: 0–%d" % [pool]

	var target_success: int = attack.base_target_number # + Multiple action penalty
	# Success condition note
	if target_successes_label:
		target_successes_label.text = "Obs: " + str(target_success)

func clear() -> void:
	if attack_name_label:
		attack_name_label.text = ""
	if min_max_dmg_label:
		min_max_dmg_label.text = ""
	if accuracy_pool_label:
		accuracy_pool_label.text = ""
	if target_successes_label:
		target_successes_label.text = ""
