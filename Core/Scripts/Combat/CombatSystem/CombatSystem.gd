class_name CombatSystem
extends Node


@export var combat_debug_enabled: bool = false



var current_combat_event_data: CombatEventData = null

static var instance: CombatSystem = null




func _ready() -> void:
	if instance != null:
		push_error("There's more than one CombatSystem! - " + str(instance))
		queue_free()
		return
	instance = self




func declare_attack_dep(action: AttackAction, attacker: Unit, defender: Unit) -> void:
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
	if action.tags.has("attack"):
		await prompt_player_reaction(defender)
		
		setup_defender_test()

	setup_degree_of_success()

	
	if current_combat_event_data.reaction:
	
		current_combat_event_data.reaction.resolve_reaction()
	
	setup_effective_damage()


func declare_attack(action: AttackAction, attacker: Unit, defender: Unit) -> void:
	current_combat_event_data = CombatEventData.new()

	# Set combat event participants
	current_combat_event_data.attacker = attacker
	current_combat_event_data.defender = defender

	# Set Combat Event Action
	current_combat_event_data.action = action



	CombatLog.instance.add_log()
	CombatLog.instance.add_log(attacker.ui_name + " attacks " + defender.ui_name + " with " + action.action_name)

	# Trigger for ally attacked, enemy attacked, ect.
	
	
	#setup_attacker_test()
	# Check if target wants to do a reaction
	if action.tags.has("attack"):
		#await prompt_player_reaction(defender)
		pass
		
		#setup_defender_test()

	# 2) Resolve using Gubat Banwa steps
	_resolve_attack_gubat_banwa(action, attacker, defender)

	
	if current_combat_event_data.reaction:
	
		current_combat_event_data.reaction.resolve_reaction()
	
	#setup_effective_damage()


func _resolve_attack_gubat_banwa(action: AttackAction, attacker: Unit, defender: Unit) -> void:
	var cd: CombatEventData = current_combat_event_data

	# Reset the Combat Data
	cd.per_die_results.clear()
	cd.total_initial_damage = 0
	cd.total_after_defense = 0
	cd.any_die_hit = false
	cd.was_crit_any = false
	cd.chained_count = 0


	var attacker_attrs: AttributesContainer = attacker.get_attributes_container()
	var defender_attrs: AttributesContainer = defender.get_attributes_container()

	# --- Gather stats
	var prowess_value: int = attacker_attrs.get_attribute_current_value(action.prowess_attribute)  # FER/SPI mapping
	var defense_value: int = defender_attrs.get_attribute_current_value(action.defense_attribute)  # PAR/RES
	var evd_value: int = defender_attrs.get_attribute_current_value("evade")                      # EVD
	


	# Allow reaction to tweak gates
	var die_result_modifier: int = 0   # Merit/Demerit, vantage/flank, combo breaker, reaction buffs, etc.
	var bonus_damage_flat: int = 0     # rare flat adds

	if cd.reaction and cd.reaction.has_method("modify_attack_context"):
		var ctx := {
			"prowess_value": prowess_value,
			"defense_value": defense_value,
			"evd_value": evd_value,
			"die_result_modifier": die_result_modifier,
			"bonus_damage_flat": bonus_damage_flat,
			"is_melee_attack": action.is_melee_attack
		}
		cd.reaction.modify_attack_context(ctx)
		prowess_value = ctx.prowess_value
		defense_value = ctx.defense_value
		evd_value = ctx.evd_value
		die_result_modifier = ctx.die_result_modifier
		bonus_damage_flat = ctx.bonus_damage_flat

	die_result_modifier += _compute_die_result_modifier(action, attacker, defender)

	# --- Multi-die loop (each die is its own check)
	var die_size: int = maxi(2, action.die_size)
	var die_count: int = maxi(1, action.die_count)

	var contributed_damage_total: int = 0
	var any_non_evaded: bool = false
	var any_crit: bool = false
	var chain_stack: int = 0

	for die_index in die_count:
		var die_outcome: Dictionary = _process_single_violence_die(
			die_size,
			die_result_modifier,
			prowess_value,
			defense_value,
			evd_value,
			action.is_melee_attack
		)
		cd.per_die_results.append(die_outcome)

		if not die_outcome.evaded:
			any_non_evaded = true
			contributed_damage_total += die_outcome.after_defense
			if die_outcome.crit:
				any_crit = true

			# Melee CHAIN: if melee and die_outcome.chained, roll extra die (recursively)
			if action.is_melee_attack and die_outcome.chained:
				var chained_outcome: Dictionary = _process_single_violence_die(
					die_size,
					die_result_modifier,    # merit/demerit still applies
					prowess_value,
					defense_value,
					evd_value,
					true                    # still melee
				)
				chained_outcome["is_chain_die"] = true
				cd.per_die_results.append(chained_outcome)
				cd.chained_count += 1
				if not chained_outcome.evaded:
					any_non_evaded = true
					contributed_damage_total += chained_outcome.after_defense
					if chained_outcome.crit:
						any_crit = true
	
	# --- Totals
	cd.any_die_hit = any_non_evaded
	cd.was_crit_any = any_crit

	# Add any “flat” damage bonuses after defense (rare in GB; keep for hooks)
	contributed_damage_total = max(0, contributed_damage_total + bonus_damage_flat)

	cd.total_after_defense = contributed_damage_total
	cd.effective_damage = contributed_damage_total

	# Crit message on ranged crit.
	if not action.is_melee_attack and cd.was_crit_any:
		CombatLog.instance.add_log("Critical Hit! (+%s prowess)" % action.prowess_attribute)

	# Logging (helpful while tuning)
	if not any_non_evaded:
		CombatLog.instance.add_log("Evaded (all dice).")
	else:
		CombatLog.instance.add_log("Total Damage: %d" % cd.effective_damage)

	# Map to your UI flags
	cd.is_hit = any_non_evaded
	cd.is_graze = false
	cd.is_success = any_non_evaded
	cd.is_critical_success = any_crit

	# Prints the data to the log
	_debug_dump_current_event()




func _process_single_violence_die(
	die_size: int,
	die_mod: int,
	prowess_value: int,
	defense_value: int,
	evd_value: int,
	is_melee: bool
) -> Dictionary:
	# 1) Roll the Violence Die
	var raw_roll: int = randi_range(1, die_size)# % die_size + 1
	var modified_roll: int = raw_roll + die_mod

	# 2) EVD gate: if modified_roll <= evd_value → fully evaded
	if modified_roll <= evd_value:
		return {
			"roll": raw_roll,
			"modified": modified_roll,
			"evaded": true,
			"chained": false,
			"crit": false,
			"raw_damage": 0,
			"after_defense": 0
		}

	# 3) Base damage before defense: roll + Prowess
	#    (Chain/Crit modifies this below, then we subtract defense)
	var base_damage_before_defense: int = modified_roll + prowess_value

	var did_chain: bool = false
	var did_crit: bool = false

	# 4) Melee CHAIN on top result-or-higher; Ranged CRIT on top-or-higher
	if is_melee:
		if modified_roll >= die_size:
			did_chain = true
	else:
		if modified_roll >= die_size:
			did_crit = true
			# Ranged crit = add prowess again
			base_damage_before_defense += prowess_value

	# 5) Subtract defense, min 1 (since it passed the EVD gate)
	var after_defense_damage: int = base_damage_before_defense - defense_value
	if after_defense_damage < 1:
		after_defense_damage = 1

	return {
		"roll": raw_roll,
		"modified": modified_roll,
		"evaded": false,
		"chained": did_chain,
		"crit": did_crit,
		"raw_damage": base_damage_before_defense,
		"after_defense": after_defense_damage
	}



func _compute_die_result_modifier(action: AttackAction, attacker: Unit, defender: Unit) -> int:
	var net_modifier: int = 0

	# Example toggles:
	# if attacker is flanking defender and action.is_melee_attack:
	#     net_modifier += 1     # Merit
	# if action is ranged and attacker has higher vantage over defender:
	#     net_modifier -= 1     # Demerit
	# if below minimum range for ranged:
	#     net_modifier -= 2     # GB: 2 Demerit below min range
	# if this would be 2nd attack in a Riff: net_modifier -= 2 (Combo Breaker)
	# if 3rd+: net_modifier -= 3

	return net_modifier



func _debug_dump_current_event() -> void:
	if not combat_debug_enabled:
		return
	var cd := current_combat_event_data
	if cd == null:
		return

	var attacker_name := cd.attacker.ui_name if cd.attacker else "<none>"
	var defender_name := cd.defender.ui_name if cd.defender else "<none>"
	var action_name := cd.action.action_name if cd.action else "<none>"

	# Header
	var header := "[DEBUG] %s -> %s  (%s)" % [attacker_name, defender_name, action_name]
	CombatLog.instance.add_log(header, true)

	# Core stats
	var core := (
		"  Type: %s | Die: d%d x %d | Prowess: %s | Defense: %s | Melee: %s\n"
		% [
			cd.action.get_class(),
			cd.action.die_size,
			cd.action.die_count,
			cd.action.prowess_attribute,
			cd.action.defense_attribute,
			str(cd.action.is_melee_attack)
		]
	)
	CombatLog.instance.add_log(core, true)


	# Gates snapshot (at resolution)
	var attacker_attrs := cd.attacker.get_attributes_container()
	var defender_attrs := cd.defender.get_attributes_container()
	var prowess_val := attacker_attrs.get_attribute_current_value(cd.action.prowess_attribute)
	var defense_val := defender_attrs.get_attribute_current_value(cd.action.defense_attribute)
	var evd_val := defender_attrs.get_attribute_current_value("evade")

	var gates := "  Gates: Prowess=%d | Defense=%d | EVD=%d" % [prowess_val, defense_val, evd_val]
	CombatLog.instance.add_log(gates, true)


	# Per-die results
	CombatLog.instance.add_log("  Dice:", true)

	for idx in cd.per_die_results.size():
		var d: Dictionary = cd.per_die_results[idx]
		var line := "    die[%d]: roll=%d | mod=%d | evaded=%s | chain=%s | crit=%s | raw=%d | after_def=%d%s" % [
			idx,
			int(d.get("roll", -1)),
			int(d.get("modified", -1)),
			str(d.get("evaded", false)),
			str(d.get("chained", false)),
			str(d.get("crit", false)),
			int(d.get("raw_damage", 0)),
			int(d.get("after_defense", 0)),
			" (chain)" if bool(d.get("is_chain_die", false)) else ""
		]
		CombatLog.instance.add_log(line, true)

	# Totals and flags
	var totals := "  Totals: hit_any=%s | crit_any=%s | chained=%d | total_after_def=%d" % [
		str(cd.any_die_hit), str(cd.was_crit_any), cd.chained_count, cd.total_after_defense
	]
	CombatLog.instance.add_log(totals, true)


	var flags := "  Flags: is_hit=%s | is_success=%s | is_crit=%s | is_graze=%s | dmg=%d" % [
		str(cd.is_hit), str(cd.is_success), str(cd.is_critical_success), str(cd.is_graze), cd.effective_damage
	]
	CombatLog.instance.add_log(flags, true)


	# Reaction (if any)
	if cd.reaction != null:
		var react_line := "  Reaction: %s" % [cd.reaction.action_name if cd.reaction.has_method("action_name") else cd.reaction.get_class()]
		CombatLog.instance.add_log(react_line, true)





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

class CantStop:
	extends Resource
	var taco: int = 1



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
	
	if !attack_action.tags.has("attack"):
		return

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
