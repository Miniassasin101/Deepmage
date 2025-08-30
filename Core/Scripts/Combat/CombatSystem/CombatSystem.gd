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

	# Check if target wants to do a reaction
	await prompt_player_reaction(defender)

	setup_tests()

	current_combat_event_data.reaction.resolve_reaction()


	var effective_damage: int = maxi(action.base_damage - current_combat_event_data.armor_test_hits, 0)

	current_combat_event_data.effective_damage += effective_damage


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


	pass

func prompt_player_reaction(defender: Unit) -> void:
	UnitActionSystem.instance.prompt_reaction(defender)

	var selected_reaction: Action = await UnitActionSystem.instance.reaction_confirmed

	if selected_reaction:
		#Utilities.spawn_text_line(defender, "Reacting with: " + selected_reaction.action_name)

		defender.get_action_container().use_action(selected_reaction, null)

		current_combat_event_data.reaction = selected_reaction


func setup_tests() -> void:
	setup_attacker_test()
	setup_defender_test()
	setup_degree_of_success()
	setup_armor()


func setup_attacker_test() -> void:


	var accuracy_names: Array[String] = current_combat_event_data.action.get_accuracy_attributes()

	var att_cont: AttributesContainer = current_combat_event_data.attacker.get_attributes_container()

	var attribute_value: int = att_cont.get_attribute(accuracy_names.front()).get_current_modified_value()
	var skill_value: int = att_cont.get_attribute(accuracy_names.back()).get_current_modified_value()

	var test: Test = Test.new(skill_value, attribute_value, 20)
	test.run_test()

	current_combat_event_data.attacker_test = test
	current_combat_event_data.attacker_hits = test.hits



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





func setup_degree_of_success() -> void:

	var degree_of_success: int = current_combat_event_data.attacker_test.hits - current_combat_event_data.defender_test.hits

	if degree_of_success >= 1:
		current_combat_event_data.is_success = true
	elif degree_of_success == 0:
		current_combat_event_data.is_graze = true

	current_combat_event_data.net_hits = degree_of_success


func setup_armor() -> void:
	var att_cont: AttributesContainer = current_combat_event_data.defender.get_attributes_container()

	var armor_name: String = "armor"
	var endurance_name: String = "endurance"

	var armor_val: int = att_cont.get_attribute(armor_name).get_current_modified_value()
	var endurance_val: int = att_cont.get_attribute(endurance_name).get_current_modified_value()

	var test: Test = Test.new(armor_val, endurance_val, 20)
	test.run_test()

	current_combat_event_data.armor_test = test

	current_combat_event_data.armor_test_hits = test.hits
