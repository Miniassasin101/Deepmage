class_name LevelRankBuildSource
extends BuildSource

@export_range(1, 9, 1) var rank: int = 1

## Tune these however you want.
@export_group("Scaling")
@export var posture_per_rank: int = 2
@export var might_per_3_ranks: int = 1
@export var magic_per_3_ranks: int = 1

## Computed mods are generated at rebuild time (based on current rank).
func get_computed_attribute_mods() -> Array[AttributeMod]:
	var out: Array[AttributeMod] = []

	# Posture (your HP-like attribute)
	var posture_mod := AttributeMod.new()
	posture_mod.attribute_name = &"posture"
	posture_mod.flat = posture_per_rank * rank
	out.append(posture_mod)

	# Every 3 ranks grant Might
	var might_mod := AttributeMod.new()
	might_mod.attribute_name = &"might"
	might_mod.flat = int(rank / 3) * might_per_3_ranks
	out.append(might_mod)

	# Every 3 ranks grant Magic
	var magic_mod := AttributeMod.new()
	magic_mod.attribute_name = &"magic"
	magic_mod.flat = int(rank / 3) * magic_per_3_ranks
	out.append(magic_mod)

	return out
