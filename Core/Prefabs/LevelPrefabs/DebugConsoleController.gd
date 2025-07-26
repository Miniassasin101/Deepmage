class_name DebugConsoleController
extends Node


var last_pool: DicePool = DicePool.new()

func _ready() -> void:
	Console.add_command("hello", console_hello, 0, 0, "Prints Hello")
	Console.add_command("print_text", print_text_on_first_unit, 1, 1, "Prints Inputted Text on first Unit in manager")
	Console.add_command("dp_roll", dp_roll, ["pool_size","target_successes","success_threshold"], 0,"Rolls a new DicePool.  omit args to reuse previous values.")
	Console.add_command("dp_show", dp_show, [], 0,"Print summary (results, successes, level) of last pool.")
	Console.add_command("dp_counts", dp_counts, [], 0,"Show tally of faces (1–6) from last pool.")
	Console.add_command("dp_avg", dp_avg, [], 0,"Show average roll of last pool.")
	Console.add_command("dp_max", dp_max, [], 0,"Show max roll of last pool.")
	Console.add_command("dp_min", dp_min, [], 0,"Show min roll of last pool.")




func console_hello() -> void:
	Console.print_line("Hello!", true)

func print_text_on_first_unit(text: String) -> void:
	
	var first_u: Unit = UnitManager.instance.get_first_unit()
	if !first_u:
		return
	
	Utilities.spawn_text_line(first_u, text)

func dp_roll(pool_size: String = "", target: String = "", threshold: String = "") -> void:
	# Determine pool size
	var ps: int = last_pool.dice_count
	if pool_size != "":
		ps = pool_size.to_int()

	# Determine target successes
	var tg: int = last_pool.target_successes
	if target != "":
		tg = target.to_int()

	# Determine success threshold
	var th: int = last_pool.success_threshold
	if threshold != "":
		th = threshold.to_int()

	# Create & roll a new pool
	last_pool = DicePool.new()
	last_pool.success_threshold = th
	last_pool.target_successes = tg
	last_pool.roll(ps)
	last_pool.evaluate()   # updates degree_of_success & success_level

	Console.print_line("→ Rolled %d d6 (≥%d) → target %d successes" %
		[ps, th, tg], true)
	Console.print_line(last_pool.to_str(), true)


func dp_show() -> void:
	Console.print_line(last_pool.to_str(), true)

func dp_counts() -> void:
	var counts = last_pool.get_result_counts()
	Console.print_line("Face counts: %s" % counts, true)

func dp_avg() -> void:
	Console.print_line("Average roll: %.2f" % last_pool.get_average(), true)

func dp_max() -> void:
	Console.print_line("Max roll: %d" % last_pool.get_max(), true)

func dp_min() -> void:
	Console.print_line("Min roll: %d" % last_pool.get_min(), true)
