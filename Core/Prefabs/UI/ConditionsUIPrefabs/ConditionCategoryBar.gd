class_name ConditionCategoryBar
extends PanelContainer


@export var category_label: Label

@export var highlight_container: PanelContainer
@export var style_box_unhighlighted_texture: StyleBoxTexture = null
@export var style_box_highlighted_texture: StyleBoxTexture = null
@export var style_box_selected_texture: StyleBoxTexture = null

var is_selected: bool = false

var is_highlighted: bool = false

var is_hovered: bool = false

var cond_lib_ui: ConditionsLibraryUI = null




func setup(in_cond_lib_ui: ConditionsLibraryUI, in_text: String) -> void:
	if in_cond_lib_ui:
		cond_lib_ui = in_cond_lib_ui
	
	highlight_container.add_theme_stylebox_override("panel", style_box_unhighlighted_texture)
	
	if is_highlighted:
		set_highlight(true)
	
	category_label.set_text(in_text)


func set_highlight(turn_highlight_on: bool) -> void:
	if is_selected:
		return
	
	if turn_highlight_on:
		highlight_container.add_theme_stylebox_override("panel", style_box_highlighted_texture)
		is_highlighted = true
	else:
		highlight_container.add_theme_stylebox_override("panel", style_box_unhighlighted_texture)
		is_highlighted = false


func set_selected(in_is_selected: bool) -> void:
	if !in_is_selected:
		is_selected = false
		set_highlight(is_hovered)
	else:
		is_selected = true
		is_highlighted = false
		highlight_container.add_theme_stylebox_override("panel", style_box_selected_texture)


func _on_mouse_entered() -> void:

	is_hovered = true
	
	set_highlight(true)





func _on_mouse_exited() -> void:
	if !is_selected:
		set_highlight(false)
