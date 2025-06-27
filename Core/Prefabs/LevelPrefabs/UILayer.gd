class_name UILayer extends CanvasLayer

static var instance: UILayer = null
@export var damage_number_scene: PackedScene
@export var text_controller_scene: PackedScene
@export var character_log_queue_scene: PackedScene



var character_log_queue

func _ready() -> void:
	if instance != null:
		push_error("There's more than one UILayer! - " + str(instance))
		queue_free()
		return
	instance = self

	# Instance and add CharacterLogQueue
	character_log_queue = character_log_queue_scene.instantiate() as CharacterLogQueue
	add_child(character_log_queue)
