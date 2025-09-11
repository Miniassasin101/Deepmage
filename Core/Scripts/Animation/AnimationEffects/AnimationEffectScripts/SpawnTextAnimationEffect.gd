class_name SpawnTextAnimationEffect
extends AnimationEffect

@export var text_line: String = "Text Here"

@export var color: Color = Color.ALICE_BLUE


func play_effect(unit: Unit = null) -> void:
	if !unit:
		return
	
	Utilities.spawn_text_line(unit, text_line)
