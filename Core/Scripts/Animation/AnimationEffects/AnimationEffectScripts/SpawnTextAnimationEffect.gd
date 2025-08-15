class_name SpawnTextAnimationEffect
extends AnimationEffect

@export var text_line: String = "Text Here"

@export var color: Color = Color.ALICE_BLUE


func play_effect(owner: Unit = null) -> void:
	if !owner:
		return
	
	Utilities.spawn_text_line(owner, text_line)
