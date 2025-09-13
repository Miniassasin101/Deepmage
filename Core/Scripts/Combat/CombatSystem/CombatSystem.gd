class_name CombatSystem
extends Node



static var instance: CombatSystem = null


var current_combat_event_data: CombatEventData = null


func _ready() -> void:
	if instance != null:
		push_error("There's more than one CombatSystem! - " + str(instance))
		queue_free()
		return
	instance = self




func declare_attack(action: AttackAction, attacker: Unit, defender: Unit) -> void:
	current_combat_event_data = CombatEventData.new()

	# Set combat event participants
	current_combat_event_data.attacker = attacker
	current_combat_event_data.defender = defender

	# Set Combat Event Action
	current_combat_event_data.action = action

	# On attack declared events trigger here

	#Utilities.spawn_text_line(attacker, "Attacking " + defender.ui_name + " with " + action.action_name)
	CombatLog.instance.add_log()
	CombatLog.instance.add_log(attacker.ui_name + " attacks " + defender.ui_name + " with " + action.action_name)
	
	setup_attacker_test()
	# Check if target wants to do a reaction
	await prompt_player_reaction(defender)


	setup_tests()

	current_combat_event_data.reaction.resolve_reaction()
	
	setup_effective_damage()





func debug_print_attack_results() -> void:
	var attacker_hits: int = current_combat_event_data.attacker_hits
	var defender_hits: int = current_combat_event_data.defender_hits

	var l1: String = "Attacker scored " + str(attacker_hits) + "\nDefender scored " + str(defender_hits)
	var l2: String = ""
	if current_combat_event_data.is_hit:
		l2 = "Result: Successful Hit"
	elif current_combat_event_data.is_graze:
		l2 = "Result: Grazed"
	else:
		l2 = "Result: Evaded"

	var l3: String = l1 + "\n" + l2
	print_debug(l3)

	print_debug("Armor hits: " + str(current_combat_event_data.armor_test_hits))




func prompt_player_reaction(defender: Unit) -> void:
	UnitActionSystem.instance.prompt_reaction(defender)

	var selected_reaction: Action = await UnitActionSystem.instance.reaction_confirmed

	if selected_reaction:
		#Utilities.spawn_text_line(defender, "Reacting with: " + selected_reaction.action_name)

		defender.get_action_container().use_action(selected_reaction, null)

		current_combat_event_data.reaction = selected_reaction
		
		CombatLog.instance.add_log(current_combat_event_data.defender.ui_name + " reacts with " + selected_reaction.action_name)


func setup_tests() -> void:

	setup_defender_test()
	setup_degree_of_success()


func setup_attacker_test() -> void:


	var accuracy_names: Array[String] = current_combat_event_data.action.get_accuracy_attributes()

	var att_cont: AttributesContainer = current_combat_event_data.attacker.get_attributes_container()

	var attribute_value: int = att_cont.get_attribute(accuracy_names.front()).get_current_modified_value()
	var skill_value: int = att_cont.get_attribute(accuracy_names.back()).get_current_modified_value()

	var test: Test = Test.new(skill_value, attribute_value, 20)
	test.run_test()

	current_combat_event_data.attacker_test = test
	current_combat_event_data.attacker_hits = test.hits
	
	#Utilities.spawn_text_line(current_combat_event_data.attacker, current_combat_event_data.action.action_name)
	CombatLog.instance.add_log(current_combat_event_data.attacker.ui_name + " scored " + str(test.hits) + " hits ")
	
	
	if !test.success:
		current_combat_event_data.is_hit = false



func setup_defender_test() -> void:
	
	var accuracy_names: Array[String] = current_combat_event_data.reaction.get_accuracy_attributes()

	var att_cont: AttributesContainer = current_combat_event_data.defender.get_attributes_container()

	var attribute_value: int = att_cont.get_attribute(accuracy_names.front()).get_current_modified_value()
	var skill_value: int = att_cont.get_attribute(accuracy_names.back()).get_current_modified_value()

	var test: Test = Test.new(skill_value, attribute_value, 20)
	test.run_test()
	print_debug(test.to_str())
	
	current_combat_event_data.defender_test = test
	current_combat_event_data.defender_hits = test.hits
	
	if not current_combat_event_data.reaction is PassAction:
		current_combat_event_data.required_successes = current_combat_event_data.defender_hits # Note: max of defender hits and M.A.P.
		CombatLog.instance.add_log(current_combat_event_data.defender.ui_name + " scored " + str(test.hits) + " hits")
	else:
		
		CombatLog.instance.add_log(current_combat_event_data.defender.ui_name + " Did Not React")





func setup_degree_of_success() -> void:
	
	var degree_of_success: int = current_combat_event_data.attacker_test.hits - current_combat_event_data.required_successes

	if degree_of_success >= 1:
		current_combat_event_data.is_success = true
		if degree_of_success >= 3:
			current_combat_event_data.is_critical_success = true
	elif degree_of_success == 0:
		current_combat_event_data.is_graze = true
	
	if !current_combat_event_data.attacker_test.success:
		current_combat_event_data.is_success = false

	current_combat_event_data.net_hits = degree_of_success








func setup_effective_damage() -> void:
	var attack_action: AttackAction = current_combat_event_data.action

	# Defense (track base+bonus for logging clarity)
	var defense: int = current_combat_event_data.defender.get_attributes_container().get_defence()

	var defense_bonus: int = current_combat_event_data.defense_bonus
	defense += defense_bonus

	# Damage pool components
	var damage_attribute_val: int = current_combat_event_data.attacker.get_attributes_container().get_attribute_current_value(attack_action.damage_attribute)
	var base_attack_action_dmg: int = attack_action.base_damage
	var damage_pool: int = damage_attribute_val + base_attack_action_dmg
	
	if current_combat_event_data.is_critical_success:
		damage_pool += current_combat_event_data.crit_bonus_damage_pool  # Typically 2
		CombatLog.instance.add_log("Crit!")
		current_combat_event_data.on_impact_lines.append("Crit!")
	
	# Net pool after defense
	var final_dmg_pool: int = maxi(damage_pool - defense, 0)

	# Log the calculation breakdown
	if current_combat_event_data.is_hit:
		CombatLog.instance.add_log("Damage Pool: " + str(damage_pool) + " - Defense: " + str(defense)+  " = Final Damage Pool: " + str(final_dmg_pool))

	var effective_damage: int = 0

	if final_dmg_pool >= 1:
		var dmg_pl: DicePool = DicePool.new(final_dmg_pool)
		effective_damage += dmg_pl.success_count

		var new_total := current_combat_event_data.effective_damage + effective_damage
		if current_combat_event_data.is_hit:
			CombatLog.instance.add_log(
				"Roll %d dice → %d hits ⇒ Effective Damage +%d (total %d)"
				% [final_dmg_pool, dmg_pl.success_count, effective_damage, new_total]
			)
	else:
		# Nothing to roll; defense fully absorbed it
		if current_combat_event_data.is_hit:
			CombatLog.instance.add_log(
				"No damage: pool %d - defense %d ≤ 0."
				% [damage_pool, defense]
			)

	current_combat_event_data.effective_damage += effective_damage
