# Test.gd
class_name Test
extends Resource

@export var skill_rank: int = 1        # e.g. your Shooting skill
@export var attribute_rank: int = 1    # e.g. Agility
@export var limit_rank: int = 1        # max successes you can apply
@export var threshold: int = -1        # required hits (–1 → “simple” = 1)

# Populated after you run the test:
var hits: int = -1                     # applied (capped) successes
var pool: DicePool = null              # last DicePool instance for inspection

var success: bool = false

func _init(_skill_rank: int = 1,
		   _attribute_rank: int = 1,
		   _limit_rank: int = 1,
		   _threshold: int = -1) -> void:
	# initialize all exported settings
	skill_rank    = _skill_rank
	attribute_rank = _attribute_rank
	limit_rank     = _limit_rank
	threshold      = _threshold

	# reset any previous run data
	hits = -1
	pool = null

func run_test() -> bool:
	# 1) Figure out how many dice
	var total_dice = skill_rank + attribute_rank

	# 2) Figure out how many successes are required
	var req_successes = 1
	if threshold > 0:
		req_successes = threshold
	else:
		req_successes = 1

	# 3) Build & roll the pool
	pool = DicePool.new(total_dice, req_successes)
	
	# 4) Apply the limit
	var raw_successes = pool.success_count
	hits = raw_successes
	if hits > limit_rank:
		hits = limit_rank

	# 5) Return whether we met or exceeded the required successes
	if hits >= req_successes:
		success = true
		return true
	else:
		return false

func to_str() -> String:
	# Recompute for display
	var total_dice = skill_rank + attribute_rank

	var req_successes = 1
	if threshold > 0:
		req_successes = threshold
	else:
		req_successes = 1

	var raw_hits = 0
	if pool != null:
		raw_hits = pool.success_count

	var result_text = "Failure"
	if hits >= req_successes:
		result_text = "Success"

	return "Dice Rolled: %d (Skill %d + Attr %d)\nRaw Hits: %d\nLimit: %d → Applied Hits: %d\nThreshold: %d → %s" % [
		total_dice, skill_rank, attribute_rank,
		raw_hits, limit_rank, hits,
		req_successes, result_text
	]
