## [b]Class:[/b] ReactionRule
## [i]A single condition-gated entry in a ReactionPack.[/i]
##
## [b]Responsibilities[/b][br]
## • Defines which cosmetic Reaction animation plays when all its conditions pass.[br]
## • Evaluated by [ReactionResolver] against a [CombatEventData] and the defending [Unit].[br]
## • All condition arrays are AND-gated; empty arrays match anything.
class_name ReactionRule
extends Resource


## Numeric outcome codes produced by [method _get_outcome].
enum Outcome {
	HIT   = 1,  ## Attack connected (non-crit).
	MISS  = 2,  ## Attack missed completely.
	CRIT  = 3,  ## Attack connected and was a critical hit.
	GRAZE = 4,  ## Attack grazed (partial, still counts as not-hit).
}


## Which outcomes activate this rule. Empty = matches any outcome.
@export var match_outcomes: Array[int] = []

## All of these tags must be on the attacking [Skill]. Empty = any skill.
@export var required_attack_tags: Array[String] = []

## All of these must be present in [member CombatEventData.combat_flags].
## Empty = no flag requirement.
@export var required_combat_flags: Array[String] = []

## All of these must be on the defending [Unit]'s tags array. Empty = any unit type.
@export var required_unit_tags: Array[String] = []

## None of these may be in [member CombatEventData.combat_flags].
## Use to skip a default animation when a passive already handled the visual
## (e.g. exclude [code]"deflected"[/code] from the standard block rule).
@export var excluded_combat_flags: Array[String] = []

## The reaction action to play when all conditions pass. Must extend [Reaction].
@export var reaction_action: Reaction = null

## Higher-priority rules are evaluated first; first match wins.
@export var priority: int = 0


## Returns [code]true[/code] if all conditions on this rule pass for the given event and defender.
func matches(cd: CombatEventData, defender: Unit) -> bool:
	if reaction_action == null:
		return false

	# Outcome check — skip if empty (matches any).
	if match_outcomes.size() > 0:
		var outcome: int = _get_outcome(cd)
		if not match_outcomes.has(outcome):
			return false

	# Attack skill tag check.
	if required_attack_tags.size() > 0:
		if cd.skill == null:
			return false
		for tag in required_attack_tags:
			if not cd.skill.has_tag(tag):
				return false

	# Required combat flag check.
	for flag in required_combat_flags:
		if not cd.combat_flags.has(flag):
			return false

	# Excluded combat flag check.
	for flag in excluded_combat_flags:
		if cd.combat_flags.has(flag):
			return false

	# Defending unit tag check.
	for tag in required_unit_tags:
		if not defender.has_tag(tag):
			return false

	return true


## Maps [CombatEventData] outcome flags to one of the [enum Outcome] values.
static func _get_outcome(cd: CombatEventData) -> int:
	if not cd.is_hit:
		return Outcome.GRAZE if cd.is_graze else Outcome.MISS
	return Outcome.CRIT if cd.is_critical_success else Outcome.HIT
