## [b]Class:[/b] ReactionPack
## [i]A data-driven set of reaction rules assigned to a Unit.[/i]
##
## [b]Responsibilities[/b][br]
## • Holds an ordered list of [ReactionRule]s that map combat outcomes to cosmetic animations.[br]
## • Provides a [member fallback_reaction] for when no rule matches.[br]
## • Evaluated by [ReactionResolver] to pick the correct animation for any attack event.[br]
##
## [b]Usage[/b][br]
## Assign to [member Unit.reaction_pack] in the Inspector.
## Rules are evaluated highest-[member ReactionRule.priority]-first; first match wins.[br]
## Create one pack per unit archetype (humanoid, quadruped, construct, etc.) and share it
## across all units of that type as a shared resource.
class_name ReactionPack
extends Resource


## Ordered list of reaction rules. Evaluated highest priority first; first match wins.
@export var rules: Array[ReactionRule] = []

## Plays when no rule matches. Use a [PassAction] for a silent no-reaction fallback.
## Set to [code]null[/code] if no reaction should play at all when nothing matches.
@export var fallback_reaction: Reaction = null
