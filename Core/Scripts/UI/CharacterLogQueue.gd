class_name CharacterLogQueue
extends Control

@export var max_messages: int = 5  # Max messages before oldest starts disappearing
@export var messages_offset: float = 15.0
var messages: Array[TextController] = []

func add_message(text_controller: TextController, _add_to_q: bool = true) -> void:
	# Add the new message at the bottom
	messages.append(text_controller)
	add_child(text_controller)
	text_controller.text_finished.connect(remove_message)

	# Ensure older messages shift up
	_update_positions()

	# If exceeding max messages, remove the oldest
	if messages.size() > max_messages:
		_remove_oldest_message()

# Used when just adding text anywhere in the world
func add_message_no_queue(text_controller: TextController) -> void:
	add_child(text_controller)
	text_controller.text_finished.connect(remove_message)

func _update_positions() -> void:
	# Iterate over messages and adjust their vertical position
	for msg in messages:
		msg.offset += messages_offset # Shift upward incrementally

func _remove_oldest_message() -> void:
	var oldest_message = messages.pop_front()
	if oldest_message:
		oldest_message.queue_free()

func remove_message(message: TextController) -> void:
	for text in messages:
		if message == text:
			messages.erase(text)
			text.queue_free()
			return
	
