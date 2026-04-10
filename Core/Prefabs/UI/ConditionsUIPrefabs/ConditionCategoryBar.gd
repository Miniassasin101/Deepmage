## [b]Class:[/b] ConditionCategoryBar
## [i]A selectable/highlightable row used in the left column of [Class ConditionsLibraryUI] to represent a single condition category.[/i]
##
## [b]Responsibilities[/b][br]
## • Displays a category name in [member category_label].[br]
## • Manages hover/highlight/selected visuals by swapping styleboxes on [member highlight_container].[br]
## • Notifies its owning [Class ConditionsLibraryUI] indirectly (the UI binds to row input).[br]
##
## [b]Visuals[/b][br]
## • Un/Highlighted/Selected states are driven by [Class StyleBoxTexture] overrides on the [code]"panel"[/code] style of [member highlight_container].[br]
## • Hovering calls [method set_highlight]; selecting calls [method set_selected]. Selection takes precedence over highlight.[br]
##
## [b]Notes[/b][br]
## • Logic unchanged; documentation comments only.[br]
## • Rows should be created via [method ConditionsLibraryUI._build_category_row], which wires input and metadata.

class_name ConditionCategoryBar
extends PanelContainer


## Label that displays the category’s readable name (e.g., “Position”, “Targeting”, “Movement”).
@export var category_label: Label

## Container whose [code]"panel"[/code] stylebox is swapped to represent highlight/selection.
@export var highlight_container: PanelContainer
## Style for the default (unhighlighted) state.
@export var style_box_unhighlighted_texture: StyleBoxTexture = null
## Style for the hover-highlight state.
@export var style_box_highlighted_texture: StyleBoxTexture = null
## Style for the selected/active state.
@export var style_box_selected_texture: StyleBoxTexture = null

## True if this row is the currently selected category.
var is_selected: bool = false

## True if this row is visually highlighted (hover) and not selected.
var is_highlighted: bool = false

## True while the pointer is inside this row (tracked by mouse-enter/exit).
var is_hovered: bool = false

## Back-reference to the owning [Class ConditionsLibraryUI] (set in [method setup]).
var cond_lib_ui: ConditionsLibraryUI = null


## Initializes this row with its owner UI and display text. Also applies the default style.
## Parameters:[br]
## • [param in_cond_lib_ui]: [Class ConditionsLibraryUI] — owner that created this row.[br]
## • [param in_text]: [code]String[/code] — visible category label text.
func setup(in_cond_lib_ui: ConditionsLibraryUI, in_text: String) -> void:
	if in_cond_lib_ui:
		cond_lib_ui = in_cond_lib_ui
	
	highlight_container.add_theme_stylebox_override("panel", style_box_unhighlighted_texture)
	
	if is_highlighted:
		set_highlight(true)
	
	category_label.set_text(in_text)


## Turns hover highlight on or off. Does nothing if the row is currently selected.
## Parameters: [param turn_highlight_on] — [code]true[/code] to apply [member style_box_highlighted_texture], [code]false[/code] to restore unhighlighted.
func set_highlight(turn_highlight_on: bool) -> void:
	if is_selected:
		return
	
	if turn_highlight_on:
		highlight_container.add_theme_stylebox_override("panel", style_box_highlighted_texture)
		is_highlighted = true
	else:
		highlight_container.add_theme_stylebox_override("panel", style_box_unhighlighted_texture)
		is_highlighted = false


## Sets or clears the selected state. Selection overrides highlight visuals.
## Parameters: [param in_is_selected] — [code]true[/code] to mark selected and apply [member style_box_selected_texture].
func set_selected(in_is_selected: bool) -> void:
	if !in_is_selected:
		is_selected = false
		set_highlight(is_hovered)
	else:
		is_selected = true
		is_highlighted = false
		highlight_container.add_theme_stylebox_override("panel", style_box_selected_texture)


## Pointer entered: track hover and apply highlight (unless selected).
func _on_mouse_entered() -> void:
	is_hovered = true
	set_highlight(true)


## Pointer exited: if not selected, remove highlight.
func _on_mouse_exited() -> void:
	if !is_selected:
		set_highlight(false)
