## [b]Class:[/b] ReactionResolver
## [i]Stateless resolver that picks a cosmetic Reaction from a unit's ReactionPack.[/i]
##
## [b]Responsibilities[/b][br]
## • Evaluates a unit's [ReactionPack] rules against the current [CombatEventData].[br]
## • Respects [member CombatEventData.reaction_override] set by passive skills at
##   [constant SkillTriggerSystem.TriggerPhase.BEFORE_HIT_RESOLVES].[br]
## • Returns the winning [Reaction], or [code]null[/code] if nothing should play.[br]
##
## [b]Usage[/b][br]
## Called from [method CombatSystem.determine_reaction]. Not a Node; no instance needed.
class_name ReactionResolver
extends RefCounted


## Picks the appropriate cosmetic [Reaction] for [param defender] given [param cd].[br]
##
## Resolution order:[br]
## 1. [member CombatEventData.reaction_override] — set by a passive skill; used immediately.[br]
## 2. The defender's [member Unit.reaction_pack] rules, evaluated highest priority first.[br]
## 3. The pack's [member ReactionPack.fallback_reaction] if no rule matched.[br]
## 4. [code]null[/code] if the unit has no pack assigned.
static func resolve(cd: CombatEventData, defender: Unit) -> Reaction:
	if cd == null or defender == null:
		return null

	# Passive override: a BEFORE_HIT_RESOLVES skill already chose the reaction.
	if cd.reaction_override != null:
		return cd.reaction_override

	var pack: ReactionPack = defender.reaction_pack
	if pack == null:
		return null

	# Sort rules descending by priority, return first match.
	var sorted_rules: Array[ReactionRule] = pack.rules.duplicate()
	sorted_rules.sort_custom(func(a: ReactionRule, b: ReactionRule) -> bool:
		return a.priority > b.priority)

	for rule in sorted_rules:
		if rule == null:
			continue
		if rule.matches(cd, defender):
			return rule.reaction_action

	return pack.fallback_reaction
