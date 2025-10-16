## ActiveSkillBar.gd
class_name ActiveSkillBar
extends PanelContainer

@export var label_node: Label

var tween_in: Tween = null
var tween_out: Tween = null
var tween_flash: Tween = null

var hidden_y: float = 0.0
var shown_y: float = 0.0

func _ready() -> void:
	# Start hidden just off-screen
	var viewport_size: Vector2 = get_viewport_rect().size
	var bar_size: Vector2 = size
	shown_y = viewport_size.y - bar_size.y - 40.0  # 40px margin from bottom
	hidden_y = viewport_size.y + 12.0              # slightly below
	position = Vector2((viewport_size.x - bar_size.x) * 0.5, hidden_y)
	modulate.a = 0.0
	visible = true

func set_text(skill_text: String) -> void:
	if label_node != null:
		label_node.text = skill_text

func play_in() -> void:
	if tween_out != null:
		tween_out.kill()
	if tween_in != null:
		tween_in.kill()
	tween_in = create_tween()
	tween_in.tween_property(self, "position:y", shown_y, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_in.parallel().tween_property(self, "modulate:a", 1.0, 0.18)

func play_out_down() -> void:
	if tween_in != null:
		tween_in.kill()
	if tween_out != null:
		tween_out.kill()
	tween_out = create_tween()
	tween_out.tween_property(self, "position:y", hidden_y, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween_out.parallel().tween_property(self, "modulate:a", 0.0, 0.18)

func flash_and_swap(new_text: String) -> void:
	set_text(new_text)
	# quick white flash
	if tween_flash != null:
		tween_flash.kill()
	var original_modulate: Color = modulate
	var flash_color: Color = Color(1, 1, 1, 1)
	tween_flash = create_tween()
	tween_flash.tween_property(self, "self_modulate", flash_color, 0.06)
	tween_flash.tween_property(self, "self_modulate", original_modulate, 0.10)
