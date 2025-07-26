class_name UnitStatsBar
extends MarginContainer

@export var unit_stats_bar_content: PanelContainer

@export var unit_name_label: Label
@export var initiative_score_label: Label
@export var movement_points_label: Label
@export var health_text_label: Label
@export var health_bar: TextureProgressBar

@export var shadowed_stylebox: StyleBoxFlat

@export var red_shadowed_stylebox: StyleBoxFlat
@export var blue_shadowed_stylebox: StyleBoxFlat
@export var red_flat_stylebox: StyleBoxFlat
@export var blue_flat_stylebox: StyleBoxFlat

# Drift tweakable properties:
@export var drift_amount: float = 20.0   # Pixels to drift right.
@export var drift_duration: float = 2.0    # Duration (in seconds) for one half of the drift.

# Reference to the drift tween.
var drift_tween: Tween = null

# Store the original position.
var base_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Set initial stylebox override.
#	unit_stats_bar_content.add_theme_stylebox_override("panel", shadowed_stylebox)

	# Store the initial position so we can reset later.
	base_position = unit_stats_bar_content.get_position()

# Update the stats bar with the given unit's stats.
func update_stats(unit: Unit) -> void:
	if !TurnSystem.instance.is_combat_started:
		#return
		pass

	unit_name_label.text = unit.ui_name

	var lowest_score: int = TurnSystem.instance.lowest_initiative_score

	# Shows the initiative score of the unit. Resets at the start of the next round so the lowest unit has a 0 to keep numbers more readable.
	initiative_score_label.text = "Initiative Score: " + str(TurnSystem.instance.initiative_scores[unit] - lowest_score)
	#health_text_label.text = "Health: %d / %d" % [
	#	unit.attribute_map.get_attribute_by_name("health").current_value, 
	#	unit.attribute_map.get_attribute_by_name("health").maximum_value
	#]
	
	# Animate the health bar value.
	#var target_health_percentage := (float(unit.attribute_map.get_attribute_by_name("health").current_value) /
	#	unit.attribute_map.get_attribute_by_name("health").maximum_value * 100)
	#var tween := create_tween()
	#tween.tween_property(health_bar, "value", target_health_percentage, 0.4) \
	#	 .set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

	
	# Change the stylebox based on whether this unit has already acted.
	if unit.turn_state == unit.TurnState.TURN_ENDED:
		if unit.is_enemy:
			unit_stats_bar_content.add_theme_stylebox_override("panel", red_flat_stylebox)
		else:
			unit_stats_bar_content.add_theme_stylebox_override("panel", blue_flat_stylebox)
	else:
		if unit.is_enemy:
			
			unit_stats_bar_content.add_theme_stylebox_override("panel", red_shadowed_stylebox)
			
		else:
			unit_stats_bar_content.add_theme_stylebox_override("panel", blue_shadowed_stylebox)

# Call this function to start the drift animation.
func start_drift() -> void:
	# If already drifting, do nothing.
	if drift_tween:
		return
	base_position = unit_stats_bar_content.get_position()
	var final_position: Vector2 = Vector2(base_position.x + drift_amount, base_position.y)
	drift_tween = get_tree().create_tween()
	drift_tween.set_loops(50)  # Loop indefinitely.
	drift_tween.tween_property(unit_stats_bar_content, "position", final_position, drift_duration) \
			   .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift_tween.tween_property(unit_stats_bar_content, "position", base_position, drift_duration) \
			   .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# Call this function to stop the drift and reset the position.
func stop_drift() -> void:
	if abort_tween():
		unit_stats_bar_content.set_position(base_position)

func abort_tween() -> bool:
	if drift_tween:
		drift_tween.kill()
		drift_tween = null
		return true
	return false
