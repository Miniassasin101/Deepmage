class_name UseFirstSkillAction
extends Action

# Uses the Tactics system to choose which skill, if any, to use.

@export_category("Action Variables")
# (No exported variables yet. Consider exposing a delay, fallback behavior, etc.)
# TODO: Add configurable post-skill delay, and a toggle to skip delay when no skill.


func start_action(target_package: TargetPackage = null) -> void:
	# Entry point called by the action system.
	super.start_action(target_package)

	# Ask TacticsController for the first valid skill.
	var p_skill: Skill = target_package.get_skill()
	var chosen_skill: Skill = unit.tactics_controller.get_first_valid_active_skill() if !p_skill else p_skill
	var prio_num: int = unit.tactics_controller.get_skill_priority_num(chosen_skill)
	
	# If no valid skill exists, log and fail gracefully.
	if chosen_skill == null:
		on_tactic_failed()
	else:
		# Activate the chosen skill and wait until it finishes.
		#Utilities.spawn_text_line(unit, "Skill: " + chosen_skill.skill_name + " (" + str(prio_num) + ")")
		chosen_skill.activate_skill()
		await chosen_skill.on_skill_ended

	# Small delay to improve readability/flow in combat logs/animations.
	await unit.get_tree().create_timer(0.5).timeout

	# Conclude the action lifecycle.
	end_action()


func end_action() -> void:
	# Standard action termination hook.
	super.end_action()


func on_tactic_failed() -> void:
	# Notify players/UI and log.
	Utilities.spawn_text_line(unit, "No Valid Skill")
	CombatLog.instance.add_log("No Valid Skill on " + unit.ui_name)

	# TODO: Consider a fallback (e.g., wait/guard/move) when no skill is available.
	# TODO: Consider emitting a signal so higher-level AI can react to failure cases.


func can_activate_on_target(target_package: TargetPackage) -> bool:
	# Gate to ensure the action is only run on its owning unit.
	if !target_package:
		return false

	if !unit:
		return false

	if unit != target_package.get_unit():
		return false

	return true
