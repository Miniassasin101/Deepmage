## [b]Class:[/b] CombatSystem
## [i]Central coordinator for resolving combat actions using a Gubat Banwa–style flow.[/i]
## 
## [b]Responsibilities[/b][br]
## • Owns the active [code]CombatEventData[/code] for an in-progress attack.[br]
## • Applies GB dice logic: EVD gate, melee chaining (top-or-higher), ranged crit (top-or-higher), Prowess/Defense, and minimum damage rules.[br]
## • Determines and awaits defender [b]Reactions[/b] (e.g. [code]"Block"[/code], [code]"Evade"[/code]).[br]
## • Emits detailed logs when [member combat_debug_enabled] is [code]true[/code].
##
## [b]Design Notes[/b][br]
## • Singleton-like: first instance sets [code]CombatSystem.instance[/code]; later instances self-remove in [method Node._ready].[br]
## • Core resolution lives in [method _resolve_attack_gubat_banwa]. Per-die meta is handled by [method _roll_single_die_meta].[br]
## • A legacy single-die helper exists as [method _process_single_violence_die] (kept for reference/tests).[br]
## • Inline comments explain the sequence; documentation comments use BBCode so tooltips render nicely in the Inspector and class reference.
class_name CombatSystem
extends Node


## If [code]true[/code], emit a step-by-step debug dump to [code]CombatLog[/code] during resolution.
@export var combat_debug_enabled: bool = false

## Optional reference to a system that handles skill-related triggers, hooks, and events.
@export var skill_trigger_system: SkillTriggerSystem = null

@export_category("Libraries")
## Reference to the global [Class SkillLibrary] used for skill lookups and shared data.
@export var skill_library: SkillLibrary = null

## Reference to the global [Class ConditionLibrary] used for condition lookups and shared data.
@export var condition_library: ConditionLibrary = null

## The working record for the currently executing combat event; populated throughout resolution.
var current_combat_event_data: CombatEventData = null

## Singleton-style static pointer to the active [Class CombatSystem] instance.
static var instance: CombatSystem = null


## [b]Engine callback:[/b] sets the singleton [member instance] and guards against duplicates.
## If another instance exists, logs an error via [method Object.push_error] and frees this node with [method Node.queue_free].
func _ready() -> void:
	if instance != null:
		push_error("There's more than one CombatSystem! - " + str(instance))
		queue_free()
		return
	instance = self


## Declare and resolve an attack from [param attacker] to [param defender] using [param action].
## Initializes a fresh [code]CombatEventData[/code], logs, runs GB resolution, then resolves any queued Reaction.
##
## [b]Parameters[/b][br]
## • [param action]: [Class AttackAction] — the action to resolve.[br]
## • [param attacker]: [Class Unit] — the attacking unit.[br]
## • [param defender]: [Class Unit] — the defending unit.
##
## [b]Side Effects[/b][br]
## • Populates [member current_combat_event_data] with dice results, flags, and totals.[br]
## • May spawn floating text via [code]Utilities.spawn_text_line[/code].[br]
## • May enqueue/resolve a Reaction on the defender via their [code]ActionContainer[/code].
func declare_attack(action: AttackAction, attacker: Unit, defender: Unit) -> void:
	current_combat_event_data = CombatEventData.new()

	# Set combat event participants 
	current_combat_event_data.attacker = attacker
	current_combat_event_data.defender = defender

	# Set Combat Event Action
	current_combat_event_data.action = action

	# High-level log of the attempt
	CombatLog.instance.add_log()
	CombatLog.instance.add_log(attacker.ui_name + " attacks " + defender.ui_name + " with " + action.action_name)

	# Hook point: “ally attacked”, “enemy attacked”, etc. (left as a placeholder)
	
	# Optional: prompt target’s reaction animation if this is an [i]attack[/i]-tagged action
	if action.tags.has("attack"):
		#await prompt_player_reaction(defender)
		pass

	# 2) Resolve using Gubat Banwa steps
	if action.is_attack == false:
		return
	await _resolve_attack_gubat_banwa(action, attacker, defender)

	# Execute a queued Reaction (if any)
	if current_combat_event_data.reaction:
	
		current_combat_event_data.reaction.resolve_reaction()


## [b]Core GB-style resolution[/b]: multi-die roll with EVD gate, melee chain on top-or-higher,
## ranged crit on top-or-higher, Prowess application, Defense subtraction, and min-1 if any die landed.
##
## [b]Highlights[/b][br]
## • “Top-or-higher” threshold is [code]modified_roll >= die_size[/code].[br]
## • Melee chains may continue while results remain top-or-higher (capped with a small loop guard).[br]
## • Any ranged crit adds Prowess [i]once per attack[/i].[br]
## • Flat bonuses and die-result Merit/Demerit are supported via context hooks and [_compute_die_result_modifier].
##
## [b]Parameters[/b][br]
## • [param action]: [Class AttackAction][br]
## • [param attacker]: [Class Unit][br]
## • [param defender]: [Class Unit]
func _resolve_attack_gubat_banwa(action: AttackAction, attacker: Unit, defender: Unit) -> void:
	var cd: CombatEventData = current_combat_event_data

	# Reset
	cd.per_die_results.clear()
	cd.total_initial_damage = 0
	cd.total_after_defense = 0
	cd.any_die_hit = false
	cd.was_crit_any = false
	cd.chained_count = 0

	var attacker_attrs := attacker.get_attributes_container()
	var defender_attrs := defender.get_attributes_container()

	# Gather stats
	var prowess_value: int = attacker_attrs.get_attribute_current_value(action.prowess_attribute)  # FER/SPI
	var defense_value: int = defender_attrs.get_attribute_current_value(action.defense_attribute)  # PAR/RES
	var evd_value: int = defender_attrs.get_attribute_current_value("evade")                       # EVD

	# Merit/Demerit etc.
	var die_result_modifier: int = 0
	var bonus_damage_flat: int = 0

	# Allow the active Reaction (if any) to modify the resolution context before rolling.
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
		prowess_value      = ctx.prowess_value
		defense_value      = ctx.defense_value
		evd_value          = ctx.evd_value
		die_result_modifier = ctx.die_result_modifier
		bonus_damage_flat   = ctx.bonus_damage_flat

	# Add situational Merit/Demerit (e.g., flanking, elevation, range bands, combo penalties)
	die_result_modifier += _compute_die_result_modifier(action, attacker, defender)

	var die_size: int = maxi(2, action.die_size)
	var die_count: int = maxi(1, action.die_count)

	var total_roll_sum: int = 0
	var any_non_evaded := false
	var any_ranged_crit := false

	# Roll base dice and process EVD/chain/crit meta
	for _i in die_count:
		var outcome := _roll_single_die_meta(die_size, die_result_modifier, evd_value)
		outcome["source"] = "base"
		cd.per_die_results.append(outcome)

		if not outcome.evaded:
			any_non_evaded = true
			total_roll_sum += outcome.modified
			if not action.is_melee_attack and outcome.crit:
				any_ranged_crit = true

			# Melee chains can continue
			if action.is_melee_attack and outcome.chained:
				var keep_chaining := true
				var chain_cap: int = 3
				while keep_chaining and chain_cap >= 0:
					var chain_outcome := _roll_single_die_meta(die_size, die_result_modifier, evd_value)
					chain_outcome["is_chain_die"] = true
					cd.per_die_results.append(chain_outcome)

					if not chain_outcome.evaded:
						total_roll_sum += chain_outcome.modified
						any_non_evaded = true
					# For melee, continue chaining only on further top-or-higher
					keep_chaining = chain_outcome.chained
					if keep_chaining:
						cd.chained_count += 1
						chain_cap -= 1

	# Build damage once (GB order)
	# Initial: sum of kept dice + Prowess (once)
	var initial_damage := total_roll_sum
	if any_non_evaded:
		initial_damage += prowess_value
		# Ranged crit adds Prowess again (once per attack)
		if not action.is_melee_attack and any_ranged_crit:
			initial_damage += prowess_value

	# Flat bonus if any (rare)
	initial_damage += bonus_damage_flat

	cd.total_initial_damage = initial_damage

	# Defense once
	var after_defense := initial_damage - defense_value

	# Min 1 if at least one die hit (EVD didn’t stop everything)
	if any_non_evaded and after_defense < 1:
		after_defense = 1

	cd.any_die_hit = any_non_evaded
	cd.was_crit_any = any_ranged_crit
	cd.total_after_defense = max(0, after_defense)
	cd.effective_damage = cd.total_after_defense

	# Logs
	if not any_non_evaded:
		CombatLog.instance.add_log("Evaded (all dice).")
	else:
		if not action.is_melee_attack and any_ranged_crit:
			CombatLog.instance.add_log("Critical Hit! (+%s prowess)" % action.prowess_attribute)
		CombatLog.instance.add_log("Total Damage: %d" % cd.effective_damage)

	# Flag mirror for consumers of [code]CombatEventData[/code]
	cd.is_hit = any_non_evaded
	cd.is_graze = false
	cd.is_success = any_non_evaded
	cd.is_critical_success = any_ranged_crit

	# Small feedback text for chains/crit
	if cd.chained_count >= 1:
		Utilities.spawn_text_line(attacker, "Chained!", Color.ROYAL_BLUE)
	elif cd.was_crit_any:
		Utilities.spawn_text_line(attacker, "Crit!", Color.ROYAL_BLUE)
	
	# Determine and await defender Reaction
	await determine_reaction(cd)

	# Optional: dump a full debug report of this event to CombatLog
	_debug_dump_current_event()


## Roll a single die and return meta needed by the caller (no Prowess or Defense here).
##
## [b]Returns[/b] a [Class Dictionary] with keys:[br]
## • [code]"roll"[/code] (raw), [code]"modified"[/code] (after die_mod),[br]
## • [code]"evaded"[/code] (true if [code]modified <= EVD[/code]),[br]
## • [code]"chained"[/code] (true if top-or-higher),[br]
## • [code]"crit"[/code] (same threshold; caller uses it for ranged crit logic).
##
## [b]Parameters[/b][br]
## • [param die_size]: int — faces on the die (e.g., 6 for d6).[br]
## • [param die_mod]: int — modifier added to the roll before EVD/chain/crit tests.[br]
## • [param evd_value]: int — evade threshold.
func _roll_single_die_meta(
	die_size: int,
	die_mod: int,
	evd_value: int
) -> Dictionary:
	var raw_roll: int = randi_range(1, die_size)
	var modified_roll: int = raw_roll + die_mod

	var evaded := modified_roll <= evd_value
	var chained := (modified_roll >= die_size)  # top-or-higher
	var crit := (modified_roll >= die_size)     # same threshold; only used for ranged in caller

	return {
		"roll": raw_roll,
		"modified": modified_roll,
		"evaded": evaded,
		"chained": chained,
		"crit": crit
	}

## [i]Legacy helper[/i]: Resolve a single “violence die” end-to-end (roll → EVD → damage → defense).
## The multi-die flow uses [_roll_single_die_meta] instead. Kept for parity/tests.
##
## [b]Returns[/b] a [Class Dictionary] including [code]"raw_damage"[/code] and [code]"after_defense"[/code] for that die.
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


## Compute the net die-result modifier (Merit/Demerit) for situational factors.
##
## [b]Examples (to implement):[/b][br]
## • Flanking (melee) → +1[br]
## • Higher vantage for ranged → +1[br]
## • Below minimum range (ranged) → −2 (GB guideline)[br]
## • Combo penalties for follow-ups in a “riff” → −2, −3, …
func _compute_die_result_modifier(_action: AttackAction, _attacker: Unit, _defender: Unit) -> int:
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


## Choose and run the defender’s Reaction based on the event flags.[br]
## If [member CombatEventData.is_hit] is true → try [code]"Block"[/code]; otherwise → [code]"Evade"[/code].[br]
## If a Reaction is found and used, waits for its [signal Reaction.on_action_ended] before continuing.
func determine_reaction(cd: CombatEventData) -> void:
	if cd.is_hit:
		cd.reaction = cd.defender.get_action_container().get_action_by_name("Block")
	else:
		cd.reaction = cd.defender.get_action_container().get_action_by_name("Evade")
	if cd.reaction:
		var react: Reaction = cd.defender.get_action_container().use_action(cd.reaction, cd.defender)
		await react.on_action_ended
	return


## Emit a multi-section debug dump to [code]CombatLog[/code]: header, core stats, gates snapshot,
## per-die lines, totals/flags, and the chosen Reaction (if any). Only runs if [member combat_debug_enabled] is true.
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
	CombatLog.instance.add_log(header)

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
	CombatLog.instance.add_log(core)


	# Gates snapshot (at resolution)
	var attacker_attrs := cd.attacker.get_attributes_container()
	var defender_attrs := cd.defender.get_attributes_container()
	var prowess_val := attacker_attrs.get_attribute_current_value(cd.action.prowess_attribute)
	var defense_val := defender_attrs.get_attribute_current_value(cd.action.defense_attribute)
	var evd_val := defender_attrs.get_attribute_current_value("evade")

	var gates := "  Gates: %s=%d | %s=%d | EVD=%d" % [cd.action.prowess_attribute.to_pascal_case(), prowess_val, cd.action.defense_attribute.to_pascal_case(), defense_val, evd_val]
	CombatLog.instance.add_log(gates)


	# Per-die results
	CombatLog.instance.add_log("  Dice:")

	for idx in cd.per_die_results.size():
		var d: Dictionary = cd.per_die_results[idx]
		var line := "    die[%d]: roll=%d | mod=%d | evaded=%s | chain=%s | crit=%s | raw=%d | %s" % [
			idx,
			int(d.get("roll", -1)),
			int(d.get("modified", -1)),
			str(d.get("evaded", false)),
			str(d.get("chained", false)),
			str(d.get("crit", false)),
			int(d.get("raw_damage", 0)),
			" (chain)" if bool(d.get("is_chain_die", false)) else ""
		]
		CombatLog.instance.add_log(line)

	# Totals and flags
	var totals := "  Totals: hit_any=%s | crit_any=%s | chained=%d | total_after_def=%d" % [
		str(cd.any_die_hit), str(cd.was_crit_any), cd.chained_count, cd.total_after_defense
	]
	CombatLog.instance.add_log(totals)

	var flags := "  Flags: is_hit=%s | is_success=%s | is_crit=%s | is_graze=%s | dmg=%d" % [
		str(cd.is_hit), str(cd.is_success), str(cd.is_critical_success), str(cd.is_graze), cd.effective_damage
	]
	CombatLog.instance.add_log(flags)


	# Reaction (if any)
	if cd.reaction != null:
		var react_line: String = "  Reaction: %s" % [cd.reaction.action_name]
		CombatLog.instance.add_log(react_line)


## Get the global [Class SkillLibrary] reference.
func get_skill_library() -> SkillLibrary:
	return skill_library

## Get the global [Class ConditionLibrary] reference.
func get_condition_library() -> ConditionLibrary:
	return condition_library
