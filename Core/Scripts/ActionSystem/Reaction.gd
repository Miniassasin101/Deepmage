class_name Reaction
extends Action





func resolve_reaction() -> void:
	pass


func get_reaction_package() -> AnimationPackage:
	#push_error("Get reaction package called on base Action class")
	return null
