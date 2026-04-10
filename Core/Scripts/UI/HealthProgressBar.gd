class_name HealthProgressBar
extends PanelContainer

@export var top_health_bar: TextureProgressBar      # white  (rest after max dmg)
@export var middle_health_bar: TextureProgressBar   # pink   (rest after min dmg)
@export var bottom_health_bar: TextureProgressBar   # red    (current)

@export var animation_duration: float = 0.25
var _tween: Tween

func _ready() -> void:
	_show_current_percent(100.0, false) # layout-safe default

func reset() -> void:
	_abort_tween()
	if top_health_bar: top_health_bar.value = 0.0
	if middle_health_bar: middle_health_bar.value = 0.0
	if bottom_health_bar: bottom_health_bar.value = 0.0

# ---------- PUBLIC: normal mode ----------
func show_current(cur_hp: int, max_hp: int, animated: bool = true) -> void:
	_show_current_percent(_pct(cur_hp, max_hp), animated)

func set_to_percent(in_percent: float = 100.0) -> void:  # backward compat
	_show_current_percent(in_percent, false)

func animate_to_percent(in_percent: float = 100.0) -> void:  # backward compat
	_show_current_percent(in_percent, true)

# ---------- PUBLIC: preview mode ----------
func show_preview(cur_hp: int, max_hp: int, min_damage: int, max_damage: int, anim_dur: float = animation_duration, animated: bool = false) -> void:
	min_damage = max(min_damage, 0)
	max_damage = max(max_damage, 0)
	if max_damage < min_damage:
		var t = max_damage; max_damage = min_damage; min_damage = t

	var hp_after_max := maxi(cur_hp - max_damage, 0)
	var hp_after_min := maxi(cur_hp - min_damage, 0)

	var p_top    := _pct(hp_after_max, max_hp)   # white
	var p_middle := _pct(hp_after_min, max_hp)   # pink
	var p_bottom := _pct(cur_hp,      max_hp)    # red

	if top_health_bar: top_health_bar.visible = true
	if middle_health_bar: middle_health_bar.visible = true
	if bottom_health_bar: bottom_health_bar.visible = true

	_set_three(p_top, p_middle, p_bottom, anim_dur, animated)

# ---------- internals ----------
func _show_current_percent(p: float, animated: bool) -> void:
	p = clampf(p, 0.0, 100.0)
	# hide lower layers when not previewing
	if middle_health_bar: middle_health_bar.visible = false; middle_health_bar.value = 0.0
	if bottom_health_bar: bottom_health_bar.visible = false; bottom_health_bar.value = 0.0
	if top_health_bar:    top_health_bar.visible = true

	_abort_tween()
	if animated:
		_tween = get_tree().create_tween()
		_tween.tween_property(top_health_bar, "value", p, animation_duration)\
			.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	else:
		top_health_bar.value = p

func _set_three(p_top: float, p_middle: float, p_bottom: float, anim_dur: float = animation_duration, animated = false) -> void:
	p_top = clampf(p_top, 0.0, 100.0)
	p_middle = clampf(p_middle, 0.0, 100.0)
	p_bottom = clampf(p_bottom, 0.0, 100.0)
	
	_abort_tween()
	if animated:
		var top_curr_val: float = top_health_bar.get_value()
		middle_health_bar.set_value(top_curr_val)
		bottom_health_bar.set_value(top_curr_val)
		
		_tween = get_tree().create_tween()
		_tween.tween_property(top_health_bar, "value", p_top, anim_dur).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		_tween.parallel().tween_property(middle_health_bar, "value", p_middle, anim_dur).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		_tween.parallel().tween_property(bottom_health_bar, "value", p_bottom, anim_dur).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	else:
		top_health_bar.value = p_top
		middle_health_bar.value = p_middle
		bottom_health_bar.value = p_bottom

func _pct(num: int, den: int) -> float:
	return float(num) / float(den) * 100.0 if den > 0 else 0.0

func _abort_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null
