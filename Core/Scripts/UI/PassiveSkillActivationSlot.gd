class_name PassiveSkillActivationSlot
extends PanelContainer



var slot_number: int = 0

var passive_skill_bar: PassiveSkillBar = null

var next_slot: PassiveSkillActivationSlot = null


func setup(in_slot_num: int) -> void:
	slot_number = in_slot_num
	



func add_skill_bar(in_bar: PassiveSkillBar, is_passed_up: bool = false) -> void:
	if passive_skill_bar != null:
		pass_bar_up()
	
	if !is_passed_up:
		add_child(in_bar)
	else:
		in_bar.reparent(self, false)
	
	passive_skill_bar = in_bar
	

	
	pass

func remove_skill_bar(in_bar: PassiveSkillBar) -> void:
	if in_bar == passive_skill_bar:
		await get_tree().create_timer(2.0).timeout
		if in_bar:
			await in_bar.close()
		
		passive_skill_bar = null
	elif next_slot:
		next_slot.remove_skill_bar(in_bar)


func pass_bar_up() -> void:
	if next_slot == null:
		passive_skill_bar.queue_free()
		passive_skill_bar = null
		return
	next_slot.add_skill_bar(passive_skill_bar, true)
	
	
