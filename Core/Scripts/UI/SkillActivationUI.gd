class_name SkillActivationUI
## SkillActivationUI.gd
extends Control

@export_category("References")
@export var active_skill_bar: ActiveSkillBar
@export var active_end_timer: Timer
@export var passive_layer: Control
@export var passive_bar_scene: PackedScene
@export var passive_vbox: VBoxContainer

@export_category("Layout")
@export var passive_spacing: float = 8.0
@export var passive_right_margin: float = 36.0
@export var passive_bottom_margin: float = 120.0

static var instance: SkillActivationUI = null

# Runtime
var passive_slots: Array[PassiveSkillActivationSlot] = []
var first_passive_slot: PassiveSkillActivationSlot = null
var passive_bars: Array[PassiveSkillBar] = []
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
	
	SignalBus.on_combat_started.connect(setup_passive_slots)




# ─────────────────────────────────────────────────────────────────────────────
# ACTIVE (red bar)
# ─────────────────────────────────────────────────────────────────────────────
func on_active_declared(skill_name: String) -> void:
	if active_skill_bar == null:
		return
	
	active_skill_bar.set_text(skill_name)

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
	active_end_timer.start(1.0)

func _on_active_timeout() -> void:
	if active_skill_bar == null:
		return
	active_skill_bar.close()
	active_is_showing = false
	active_is_fading = false

# ─────────────────────────────────────────────────────────────────────────────
# PASSIVE (blue stack on the right)
# ─────────────────────────────────────────────────────────────────────────────
func setup_passive_slots() -> void:
	if !passive_vbox:
		return
	
	var p_slots: Array[PassiveSkillActivationSlot] = []
	
	p_slots.assign(passive_vbox.get_children())
	
	if p_slots.is_empty():
		return
	
	p_slots.reverse()
	var p_size: int = p_slots.size()
	var prev_slot: PassiveSkillActivationSlot = null
	for i in range(p_size):
		var curr_slot: PassiveSkillActivationSlot = p_slots.get(i)
		if prev_slot:
			prev_slot.next_slot = curr_slot
		curr_slot.setup(i)
		prev_slot = curr_slot
	
	passive_slots = p_slots
	first_passive_slot = p_slots.front()






func on_passive_declared(skill_name: String) -> PassiveSkillBar:
	if passive_bar_scene == null or first_passive_slot == null:
		return null

	var new_bar_node: PassiveSkillBar = passive_bar_scene.instantiate() as PassiveSkillBar
	
	await get_tree().create_timer(0.3).timeout
	new_bar_node.set_text(skill_name)
	first_passive_slot.add_skill_bar(new_bar_node)

	
	# Track then reposition all bars (newest stacks *above* previous)
	passive_bars.append(new_bar_node)

	return new_bar_node

func on_passive_ended(bar_to_remove: PassiveSkillBar) -> void:
	if bar_to_remove == null:
		return

	for idx in passive_bars.size():
		if passive_bars[idx] == bar_to_remove:
			passive_bars.remove_at(idx)
			break

	for slot in passive_slots:
		if slot.passive_skill_bar == bar_to_remove:
			await slot.remove_skill_bar(bar_to_remove)  # ← pass the target
			return

	# If it’s no longer the slot’s current bar, still hunt it down up the chain.
	for slot in passive_slots:
		await slot.remove_skill_bar(bar_to_remove)
