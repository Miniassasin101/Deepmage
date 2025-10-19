class_name SkillActivationUI
## SkillActivationUI.gd
extends Control

@export_category("References")
@export var active_skill_bar: ActiveSkillBar
@export var active_end_timer: Timer
@export var passive_manager: PassiveBarManager
@export var passive_layer: Control
@export var passive_bar_scene: PackedScene


@export_category("Layout")
@export var passive_spacing: float = 8.0
@export var passive_right_margin: float = 36.0
@export var passive_bottom_margin: float = 120.0

static var instance: SkillActivationUI = null

# Runtime

var active_is_showing: bool = false
var active_is_fading: bool = false

func _ready() -> void:
	if instance != null:
		push_error("There's more than one SkillActivationUI! - " + str(instance))
		queue_free()
		return
	instance = self

	if active_end_timer == null:
		active_end_timer = Timer.new()
		active_end_timer.one_shot = true
		add_child(active_end_timer)

	active_end_timer.timeout.connect(_on_active_timeout)
	





# ─────────────────────────────────────────────────────────────────────────────
# ACTIVE (red bar)
# ─────────────────────────────────────────────────────────────────────────────
func on_active_declared(skill_name: String, priority_number: int = -1) -> void:
	if active_skill_bar == null:
		return
	
	if priority_number == -1:
		active_skill_bar.set_text(skill_name)
	else:
		active_skill_bar.set_text(skill_name + " (" + str(priority_number) + ")")

	# If a fade-out is pending, cancel it and flash+swap instead
	if active_end_timer.time_left > 0.0 or active_is_fading:
		active_end_timer.stop()
		active_is_fading = false
		#active_skill_bar.flash_and_swap(skill_name)
		active_skill_bar.open()
	else:
		# fresh in
		active_skill_bar.open()
	active_is_showing = true

func schedule_active_end(delay_seconds: float) -> void:
	if !active_is_showing:
		return
	active_is_fading = true
	active_end_timer.start(delay_seconds)

func _on_active_timeout() -> void:
	if active_skill_bar == null:
		return
	active_skill_bar.close()
	active_is_showing = false
	active_is_fading = false

# ─────────────────────────────────────────────────────────────────────────────
# PASSIVE (blue stack on the right)
# ─────────────────────────────────────────────────────────────────────────────






func on_passive_declared(skill_name: String, key: String) -> PassiveBarItem:
	if passive_manager == null:
		return null
	var bar_item: PassiveBarItem = passive_manager.add_passive(skill_name, key)
	return bar_item

func on_passive_ended(bar_item: PassiveBarItem) -> void:
	if passive_manager == null or bar_item == null:
		return
	await passive_manager.end_passive(bar_item)
