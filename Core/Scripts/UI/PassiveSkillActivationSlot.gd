class_name PassiveSkillActivationSlot
extends PanelContainer



var slot_number: int = 0

var passive_skill_bar: PassiveSkillBar = null

var next_slot: PassiveSkillActivationSlot = null


var starting_x_offset: float = 200.0



func setup(in_slot_num: int) -> void:
	slot_number = in_slot_num
	



func add_skill_bar(in_bar: PassiveSkillBar, is_passed_up: bool = false) -> void:
	if passive_skill_bar != null:
		await pass_bar_up()  # ← ensure this slot is free first

	if !is_passed_up:
		add_child(in_bar)
		passive_skill_bar = in_bar
		passive_skill_bar.global_position = global_position
		passive_skill_bar.open()
	else:
		in_bar.abort_tween()
		in_bar.reparent(self, true)
		passive_skill_bar = in_bar
		await in_bar.slide_up_to()






func remove_skill_bar(in_bar: PassiveSkillBar) -> void:
	# If this slot owns the bar, close *that exact bar*, not whatever is current.
	if in_bar == passive_skill_bar:
		# Detach our reference first so a new incoming bar won't get closed by mistake.
		passive_skill_bar = null
		if is_instance_valid(in_bar):
			await in_bar.close()
	elif next_slot != null:
		await next_slot.remove_skill_bar(in_bar)



func pass_bar_up() -> void:
	if passive_skill_bar == null:
		return

	if next_slot == null:
		var old_bar: PassiveSkillBar = passive_skill_bar
		passive_skill_bar = null
		if is_instance_valid(old_bar):
			await old_bar.close()  # ← wait for its exit; no ghost nodes
		return

	var bar_to_bubble: PassiveSkillBar = passive_skill_bar
	passive_skill_bar = null

	# Ensure the bar stops its current tween before we reuse it
	bar_to_bubble.abort_tween()
	# Keep global when reparenting because we animate using global_position
	bar_to_bubble.reparent(next_slot, true)
	await next_slot.add_skill_bar(bar_to_bubble, true)
	
	
