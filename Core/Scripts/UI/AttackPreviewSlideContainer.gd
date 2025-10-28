class_name AttackPreviewSlideContainer
extends SlidePanelContainer

@export_category("Content")
@export var top_hp_bar: TopHPBar
@export var attack_name_label: Label
@export var min_max_dmg_label: Label      # hook to your DamagePreviewLabel
@export var accuracy_pool_label: Label    # hook to your AccuracyLabel
@export var target_successes_label: Label # hook to your DifficultyLabel

func get_damage_preview(attack: AttackAction, attacker: Unit, target: Unit) -> Dictionary:
	if attack == null or attacker == null or target == null:
		return {"min": 0, "max": 0}

	var att := attacker.get_attributes_container()
	var tgt := target.get_attributes_container()
	
	var tgt_hp_att: Attribute = tgt.get_attribute("posture")
	var tgt_curr_hp: int = tgt_hp_att.get_current_modified_value()
	var tgt_max_hp: int = tgt_hp_att.get_max_value()
	
	

	var dmg_attr := 0
	if att and attack.damage_attribute != "":
		dmg_attr = att.get_attribute_current_value(attack.damage_attribute)

	var defense := tgt.get_defence() if tgt != null else 0
	var base := 0#attack.base_damage

	var max_dmg := maxi(0, base + dmg_attr - defense)
	var min_dmg := 1  # adjust if/when you add true spread
	
	top_hp_bar.health_bar.show_preview(tgt_curr_hp, tgt_max_hp, min_dmg, max_dmg, 0.3, true)
	
	return {"min": min_dmg, "max": max_dmg}

func fill_from_attack(attack: AttackAction, attacker: Unit, target: Unit) -> void:
	if attack == null or attacker == null or target == null:
		clear(); return

	if attack_name_label: attack_name_label.text = attack.action_name

	var att := attacker.get_attributes_container()
	var acc_names: Array[String] = [""]#attack.get_accuracy_attributes()
	var acc_attr := acc_names[0] if acc_names.size() >= 1 else ""
	var acc_skill := acc_names[acc_names.size()-1] if acc_names.size() >= 2 else ""
	var acc_val := 0
	var skill_val := 0
	if att:
		if acc_attr != "":  acc_val = att.get_attribute(acc_attr).get_current_modified_value()
		if acc_skill != "": skill_val = att.get_attribute(acc_skill).get_current_modified_value()
	if accuracy_pool_label:
		accuracy_pool_label.text = "Acc: %d" % [acc_val + skill_val]

	var pv := get_damage_preview(attack, attacker, target)
	if min_max_dmg_label:
		min_max_dmg_label.text = "Dmg: %d–%d" % [pv.min, pv.max]

	if target_successes_label:
		target_successes_label.text = "Obs: %d" % [attack.base_target_number]
	


func clear() -> void:
	if attack_name_label: attack_name_label.text = ""
	if min_max_dmg_label: min_max_dmg_label.text = ""
	if accuracy_pool_label: accuracy_pool_label.text = ""
	if target_successes_label: target_successes_label.text = ""
