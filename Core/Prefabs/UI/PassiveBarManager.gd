class_name PassiveBarManager
extends CanvasLayer   # or Control; both work with this logic


@export_category("References")
@export var bar_scene: PackedScene
@export var bar_parent: Control  # assign a right-anchored container in the Inspector

@export_category("Layout")
@export var max_visible: int = 6
@export var base_offset: Vector2 = Vector2(0.0, 0.0)
@export var spacing_y: float = 8.0
@export var slide_in_dx: float = 220.0
@export var exit_up_dy: float = 28.0

var _items: Array[PassiveBarItem] = []
var _pool: Array[PassiveBarItem] = []

var _layout_dirty: bool = false
var _reflow_in_progress: bool = false

var _bars_by_key: Dictionary = {}   # String -> Array[PassiveBarItem]

func _ready() -> void:
	if bar_parent == null:
		push_error("PassiveBarManager: bar_parent is not assigned.")
		return
	_schedule_reflow()
	get_tree().root.size_changed.connect(_schedule_reflow)

func _schedule_reflow() -> void:
	if _layout_dirty:
		return
	_layout_dirty = true
	call_deferred("_reflow")

func _reflow() -> void:
	_layout_dirty = false
	if _reflow_in_progress:
		_layout_dirty = true
		return
	_reflow_in_progress = true

	# Trim beyond capacity; mark exit so we don't move them this pass.
	while _items.size() > max_visible:
		var tail_index: int = _items.size() - 1
		var tail_item: PassiveBarItem = _items[tail_index]
		_items.remove_at(tail_index)
		await _play_exit_and_recycle(tail_item)

	var current_y: float = base_offset.y
	for index in range(_items.size()):
		var bar_item: PassiveBarItem = _items[index]
		if !is_instance_valid(bar_item) or bar_item.is_exiting:
			continue
		var target_pos: Vector2 = Vector2(base_offset.x, current_y)
		bar_item.play_move(target_pos)

		var h: float = bar_item.size.y
		if h <= 0.0:
			h = 28.0
		current_y += h + spacing_y

	_reflow_in_progress = false
	if _layout_dirty:
		_layout_dirty = false
		call_deferred("_reflow")

func _play_exit_and_recycle(item: PassiveBarItem) -> void:
	if !is_instance_valid(item):
		return
	var exit_to: Vector2 = item.position + Vector2(0.0, -exit_up_dy)
	await item.play_exit(exit_to)
	_recycle(item)

func _spawn_item() -> PassiveBarItem:
	var item: PassiveBarItem
	if _pool.is_empty():
		item = bar_scene.instantiate() as PassiveBarItem
	else:
		item = _pool.pop_back()
	bar_parent.add_child(item)
	item.is_in_use = true
	item.is_exiting = false
	item._reset_visuals()
	return item

func _recycle(item: PassiveBarItem) -> void:
	if !is_instance_valid(item):
		return
	item.is_in_use = false
	item.is_exiting = false
	item.visible = false
	#item.modulate.a = 0.0
	item.position = Vector2.ZERO
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	_pool.append(item)

func add_passive(text_value: String, key: String = "") -> PassiveBarItem:
	var item: PassiveBarItem = _spawn_item()
	item.set_text(text_value)

	_items.insert(0, item)

	var target_y: float = base_offset.y
	var enter_from: Vector2 = Vector2(base_offset.x + slide_in_dx, target_y)
	var enter_to: Vector2 = Vector2(base_offset.x, target_y)
	item.play_enter(enter_from, enter_to)

	if key != "":
		if !_bars_by_key.has(key):
			_bars_by_key[key] = []
		var list_for_key: Array = _bars_by_key[key]
		list_for_key.push_front(item)
		_bars_by_key[key] = list_for_key

	_schedule_reflow()
	return item

func end_passive(item: PassiveBarItem) -> void:
	if item == null or !is_instance_valid(item):
		return
	if item.is_exiting or !item.is_in_use:
		return  # already on the way out or already pooled

	for i in range(_items.size()):
		if _items[i] == item:
			_items.remove_at(i)
			break

	for key in _bars_by_key.keys():
		var list_for_key: Array = _bars_by_key[key]
		for j in range(list_for_key.size()):
			if list_for_key[j] == item:
				list_for_key.remove_at(j)
				_bars_by_key[key] = list_for_key
				break

	await _play_exit_and_recycle(item)
	_schedule_reflow()

func end_oldest_for_key(key: String) -> void:
	if key == "" or !_bars_by_key.has(key):
		return
	var list_for_key: Array = _bars_by_key[key]
	if list_for_key.is_empty():
		return
	var item: PassiveBarItem = list_for_key.back()
	list_for_key.pop_back()
	_bars_by_key[key] = list_for_key
	await end_passive(item)
