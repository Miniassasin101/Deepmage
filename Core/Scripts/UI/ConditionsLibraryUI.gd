class_name ConditionsLibraryUI
extends PanelContainer

@export var chip_prefab: PackedScene
@export var cat_bar_prefab: PackedScene
@export var search_line_edit: LineEdit

# New: left and right columns
@export var categories_vbox_container: VBoxContainer
@export var conditions_vbox_container: VBoxContainer

var prev_selected_row: ConditionCategoryBar = null


const ALL_CATEGORIES_TEXT: String = "All"
var selected_category_text: String = ""   # "" means All

func _ready() -> void:
	# Search ↔ refresh
	if search_line_edit != null and not search_line_edit.text_changed.is_connected(_on_search_changed):
		search_line_edit.text_changed.connect(_on_search_changed)


	_refresh_categories_column()
	_refresh_conditions_column()

# ----------------------------------------------------------
# Categories VBox (left)
# ----------------------------------------------------------
func _refresh_categories_column() -> void:
	if categories_vbox_container == null:
		return

	# Clear
	for child_node in categories_vbox_container.get_children():
		child_node.queue_free()

	# Build: "All" + actual categories
	var lib: ConditionLibrary = CombatSystem.instance.get_condition_library() if CombatSystem.instance else null
	if lib == null:
		return
	var categories_list: Array[String] = lib.get_unique_categories_sorted()
	var built_list: Array[String] = []
	built_list.append(ALL_CATEGORIES_TEXT)
	built_list.append_array(categories_list)

	for category_name in built_list:
		var row: PanelContainer = _build_category_row(category_name)
		categories_vbox_container.add_child(row)
		_style_category_row(row, _is_row_selected(category_name))

func _build_category_row(category_name: String) -> PanelContainer:
	var row: ConditionCategoryBar = cat_bar_prefab.instantiate() as ConditionCategoryBar
	
	row.setup(self, category_name)
	
	row.name = "CategoryRow_" + category_name
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.set_meta("category_name", category_name)
	
	
	# Click to select
	if not row.gui_input.is_connected(_on_category_row_gui_input):
		row.gui_input.connect(_on_category_row_gui_input.bind(row))

	return row



func _on_category_row_gui_input(event: InputEvent, row: PanelContainer) -> void:
	if !Input.is_action_just_pressed("left_mouse"):
		return
	
	if row is ConditionCategoryBar:
		if prev_selected_row:
			prev_selected_row.set_selected(false)
			prev_selected_row.set_highlight(false)
		
		row.set_selected(true)
		prev_selected_row = row
	
	var clicked_name: String = String(row.get_meta("category_name"))
	if clicked_name == ALL_CATEGORIES_TEXT:
		selected_category_text = ""
	else:
		selected_category_text = clicked_name

	#_restyle_all_category_rows()
	_refresh_conditions_column()

func _restyle_all_category_rows() -> void:
	if categories_vbox_container == null:
		return
	for row_node in categories_vbox_container.get_children():
		var row_pc: PanelContainer = row_node as PanelContainer
		if row_pc == null:
			continue
		var cat_name: String = String(row_pc.get_meta("category_name"))
		_style_category_row(row_pc, _is_row_selected(cat_name))

func _style_category_row(row: PanelContainer, is_selected: bool) -> void:
	# Minimal visual: modulate + border width. Replace with theme/styleboxes if you prefer.
	if is_selected:
		row.self_modulate = Color(1, 1, 1, 1)
		row.add_theme_constant_override("margin_left", 0) # noop, but left here if you want indents
	else:
		row.self_modulate = Color(1, 1, 1, 0.85)

func _is_row_selected(category_name: String) -> bool:
	if category_name == ALL_CATEGORIES_TEXT and selected_category_text == "":
		return true
	return category_name == selected_category_text

# ----------------------------------------------------------
# Conditions VBox (right)
# ----------------------------------------------------------
func _refresh_conditions_column() -> void:
	if conditions_vbox_container == null:
		return

	# Clear
	for c in conditions_vbox_container.get_children():
		c.queue_free()

	var lib: ConditionLibrary = CombatSystem.instance.get_condition_library() if CombatSystem.instance else null
	if lib == null:
		return

	var query_text: String = ""
	if search_line_edit != null:
		query_text = search_line_edit.text

	# Use selected_category_text ("" means All)
	var results: Array[ConditionBlueprint] = lib.search(query_text, selected_category_text)
	lib.sort_by_category_then_name(results)

	for bp in results:
		if bp == null:
			continue
		var chip: ConditionChip = chip_prefab.instantiate() as ConditionChip
		conditions_vbox_container.add_child(chip)
		chip.populate_from_blueprint(bp)

# ----------------------------------------------------------
# Search / legacy OB glue
# ----------------------------------------------------------
func _on_search_changed(_t: String) -> void:
	_refresh_conditions_column()
