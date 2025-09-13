class_name UnitStatsBar
extends MarginContainer

@export var unit_stats_bar_content: PanelContainer

@export var unit_name_label: Label
@export var initiative_score_label: Label
@export var multiple_action_penalty_label: Label
@export var health_text_label: Label
@export var health_bar: SimpleAnimatableProgressBar

@export var shadowed_stylebox: StyleBoxFlat

@export var red_shadowed_stylebox: StyleBoxFlat
@export var blue_shadowed_stylebox: StyleBoxFlat
@export var red_flat_stylebox: StyleBoxFlat
@export var blue_flat_stylebox: StyleBoxFlat

# Drift tweakable properties:
@export var drift_amount: float = 20.0   # Pixels to drift right.
@export var drift_duration: float = 2.0    # Duration (in seconds) for one half of the drift.

# Pulse tweakable properties:
@export var pulse_amount: float = 0.8
@export var pulse_duration: float = 0.5
@export var pulse_border_width: int = 3



# Reference to the drift tween.
var drift_tween: Tween = null




var pulse_tween: Tween = null

# Store the original position.
var base_position: Vector2 = Vector2.ZERO

var stats_bar_unit: Unit = null

func _ready() -> void:
	# Set initial stylebox override.
#	unit_stats_bar_content.add_theme_stylebox_override("panel", shadowed_stylebox)

	# Store the initial position so we can reset later.
	base_position = unit_stats_bar_content.get_position()
	
	make_styleboxes_unique()
	


func make_styleboxes_unique() -> void:

	red_shadowed_stylebox = red_shadowed_stylebox.duplicate()
	blue_shadowed_stylebox = blue_shadowed_stylebox.duplicate()
	red_flat_stylebox = red_flat_stylebox.duplicate()
	blue_flat_stylebox = blue_flat_stylebox.duplicate()


# Update the stats bar with the given unit's stats.
func update_stats(unit: Unit) -> void:
	if !TurnSystem.instance.is_combat_started:
		#return
		pass
	
	
	stats_bar_unit = unit
	
	unit_name_label.text = unit.ui_name

	var lowest_score: int = TurnSystem.instance.lowest_initiative_score

	# Shows the initiative score of the unit. Resets at the start of the next round so the lowest unit has a 0 to keep numbers more readable.
	initiative_score_label.text = "Initiative Score: " + str(TurnSystem.instance.initiative_scores[unit] - lowest_score)
	var health_attribute: Attribute = unit.get_attributes_container().get_attribute("health")

	var current_modified_value: int = health_attribute.get_current_modified_value()
	health_text_label.text = "Health: %d / %d" % [
		maxi(current_modified_value, 0), 
		health_attribute.maximum_value
	]
	
	# Animate the health bar value.
	var target_health_percentage: float = (float(current_modified_value) / float(health_attribute.maximum_value) * 100)
	#print_debug("Current Value: " + str(current_modified_value))
	#print_debug("Target Percent: " + str(target_health_percentage))
	
	health_bar.animate_to_percent(target_health_percentage)

	
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
	
	if TurnSystem.instance.selected_unit == unit:
		start_pulse()
	else:
		stop_pulse()
	



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

## Pulses the color of the stylebox to indicate selected unit.
func start_pulse() -> void:
	if pulse_tween or !get_tree():
		return  # Already pulsing

	var current_stylebox := unit_stats_bar_content.get_theme_stylebox("panel") as StyleBoxFlat
	if current_stylebox == null:
		return

	# Duplicate to avoid modifying shared resource
	var pulsing_stylebox: StyleBoxFlat = current_stylebox.duplicate()
	unit_stats_bar_content.add_theme_stylebox_override("panel", pulsing_stylebox)

	var original_color: Color = pulsing_stylebox.border_color
	var lighter_color: Color = original_color.lightened(pulse_amount)
	
	pulsing_stylebox.set_border_width_all(pulse_border_width)

	pulse_tween = get_tree().create_tween()
	pulse_tween.set_loops()  # Infinite loop
	pulse_tween.tween_property(pulsing_stylebox, "border_color", lighter_color, pulse_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(pulsing_stylebox, "border_color", original_color, pulse_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func stop_pulse() -> void:
	if abort_pulse():

		# Restore original stylebox
		var current_unit := TurnSystem.instance.selected_unit
		if current_unit:
			update_stats(stats_bar_unit)  # Reapply correct stylebox based on current unit state

func abort_pulse() -> bool:
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null
		return true
	return false
