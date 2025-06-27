class_name TextController extends Control


signal text_finished(text_line: TextController)

@export var animator: AnimationPlayer
@export var text_label: Label
@export var default_animation: String = "CharacterTextLogFadeAnim"

var world_pos: Vector3 = Vector3()  # Holds the world position of the text
var camera: Camera3D = null  # Reference to the camera
var offset: float = 0.0

func _ready() -> void:
	camera = get_viewport().get_camera_3d()  # Assume MouseWorld is the autoload managing the camera

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if camera:
		var screen_pos: Vector2 = camera.unproject_position(world_pos)
		screen_pos -= Vector2(0.0, offset)
		set_position(screen_pos)  # Update the screen position based on the world position

func play(text: String = "N/A", animation: String = default_animation) -> void:
	setup_text(text)
	play_anim(animation)

func setup_text(text: String = "N/A") -> void:
	text_label.set_text(text)

func set_text_color(color: Color) -> void:
	text_label.add_theme_color_override("font_color", color)

func play_anim(animation: String) -> void:
	if !animator.has_animation(animation):
		push_error("Animator does not have the animation: ", animation)
		on_text_finished()
		return
	animator.play(animation)
	await animator.animation_finished
	on_text_finished()

func on_text_finished() -> void:
	text_finished.emit(self)
