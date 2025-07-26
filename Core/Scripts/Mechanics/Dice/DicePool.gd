# DicePool.gd
extends Resource
class_name DicePool

## How many d6 dice are going to be rolled
@export var dice_count: int = 1

## Rolls this number or higher count as successes, ex: Pokerole is 4+ but shadowrun is 5+
@export var success_threshold: int = 5  # Rolls ≥ this count as “success”

## How many die have to come up as successes in order for it to succeed.
@export var target_successes: int = 0     # How many successes needed

## In-Order array of all of the die results. Ex: [1,2,6,4,5]
var results: Array[int] = []

## By how much above or under the target value the result was
var degree_of_success: int = 0

## -1 = crit fail, 0 = fail, 1 = success, 2 = crit
var success_level: int = 0

var success_count: int = 0



func _init(_dice_count: int = dice_count, _target_successes: int = target_successes, _success_threshold: int = success_threshold) -> void:
	dice_count = _dice_count
	target_successes = _target_successes
	success_threshold = _success_threshold
	
	roll()


func roll(pool_size: int = -1) -> void:
	# Roll N d6s and store them
	results.clear()
	var count: int = pool_size if pool_size >= 0 else dice_count
	for i in range(count):
		results.append(randi() % 6 + 1)
	dice_count = count
	
	# Optionally auto-evaluate after rolling
	evaluate()


func evaluate(_target: int = -1) -> int:
	# If caller passed a new target, use it
	if _target >= 0:
		target_successes = _target

	success_count = get_success_count()

	
	var diff: int = success_count - target_successes

	degree_of_success = diff
	
	if degree_of_success >= 0:
		success_level = 1
	elif degree_of_success <= -1:
		success_level = 0



	return success_level


func get_success_count() -> int:
	var c: int = 0
	for r in results:
		if r >= success_threshold:
			c += 1
	return c

func get_result_counts() -> Dictionary:
	# Returns a dict {1: n1, 2: n2, …, 6: n6}
	var tally := {1:0,2:0,3:0,4:0,5:0,6:0}
	for r in results:
		tally[r] += 1
	return tally

func get_average() -> float:
	if results.is_empty():
		return 0.0
	var total: int = results.reduce(func(accum, val):
		return accum + val, 0)
	return float(total) / results.size()

func get_max() -> int:
	return 0 if results.is_empty() else results.max()  # this inline is okay since it's just 2 values

func get_min() -> int:
	return 0 if results.is_empty() else results.min()

func to_str() -> String:
	# Include success_level in the string
	var level_name: String = "" 
	match success_level:
		2: level_name = "Crit Success"
		1: level_name = "Success"
		0: level_name = "Failure"
		-1: level_name = "Crit Failure"
		_: level_name = "Unknown"
	return "Rolls: %s | Successes: %d/%d | Result: %s (%d)" % [
		results,
		success_count,
		target_successes,
		level_name,
		success_level
	]
