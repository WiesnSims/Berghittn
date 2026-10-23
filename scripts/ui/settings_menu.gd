class_name SettingsMenu
extends Control
## Sensitivity, volume, language and picture options, reachable from the start screen and the pause
## menu. Every change applies at once (so a slider can be judged while it moves) and is saved on close.

signal closed

## Language names stay in their own language, so a player stuck in the wrong one can still find theirs.
const LOCALE_NAMES: Dictionary = {"en": "English", "de": "Deutsch"}
const VOLUME_KEYS: Dictionary = {
	&"Master": "UI_SET_VOLUME_MASTER",
	&"Music": "UI_SET_VOLUME_MUSIC",
	&"Effects": "UI_SET_VOLUME_EFFECTS",
	&"Ambience": "UI_SET_VOLUME_AMBIENCE",
}
const ROW_HEIGHT: float = 40.0
const FONT_SIZE: int = 20

@onready var _rows: VBoxContainer = %Rows
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_back_button.pressed.connect(close)
	_build()
	hide()


func open() -> void:
	show()
	_back_button.grab_focus()


func close() -> void:
	Settings.save()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _build() -> void:
	_add_slider("UI_SET_SENSITIVITY", Constants.MOUSE_SENSITIVITY_MIN, Constants.MOUSE_SENSITIVITY_MAX,
			Settings.mouse_sensitivity, func(v: float) -> void: Settings.mouse_sensitivity = v,
			# Shown relative to the play-tested default, which reads better than radians per pixel.
			func(v: float) -> String: return "%.2f" % (v / Constants.DEFAULT_MOUSE_SENSITIVITY))
	_add_slider("UI_SET_AIM_SENSITIVITY", Constants.AIM_SENSITIVITY_MIN, Constants.AIM_SENSITIVITY_MAX,
			Settings.aim_sensitivity, func(v: float) -> void: Settings.aim_sensitivity = v, _percent)
	_add_toggle("UI_SET_INVERT_Y", Settings.invert_y, func(on: bool) -> void: Settings.invert_y = on)
	_add_toggle("UI_SET_DAMAGE_NUMBERS", Settings.damage_numbers, func(on: bool) -> void: Settings.damage_numbers = on)
	_add_toggle("UI_SET_CHATTER", Settings.chatter, func(on: bool) -> void: Settings.chatter = on)
	for bus: StringName in Settings.BUSES:
		_add_slider(VOLUME_KEYS[bus], 0.0, 1.0, Settings.volume(bus),
				func(v: float) -> void: Settings.set_volume(bus, v), _percent)
	_add_language()
	_add_slider("UI_SET_RENDER_SCALE", Constants.RENDER_SCALE_MIN, 1.0, Settings.render_scale,
			func(v: float) -> void: Settings.render_scale = v, _percent)


func _percent(value: float) -> String:
	return "%d %%" % roundi(value * 100.0)


func _add_row(key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.text = key
	label.custom_minimum_size = Vector2(260.0, 0.0)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	_rows.add_child(row)
	return row


func _add_slider(key: String, low: float, high: float, value: float, assign: Callable, format: Callable) -> void:
	var row: HBoxContainer = _add_row(key)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = (high - low) / 100.0
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(260.0, 0.0)
	var readout := Label.new()
	readout.custom_minimum_size = Vector2(80.0, 0.0)
	readout.add_theme_font_size_override("font_size", FONT_SIZE)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	readout.text = format.call(value)
	slider.value_changed.connect(func(v: float) -> void:
		assign.call(v)
		readout.text = format.call(v)
		Settings.apply(false))
	row.add_child(slider)
	row.add_child(readout)


func _add_toggle(key: String, value: bool, assign: Callable) -> void:
	var row: HBoxContainer = _add_row(key)
	var toggle := CheckButton.new()
	toggle.button_pressed = value
	toggle.toggled.connect(func(on: bool) -> void:
		assign.call(on)
		Settings.apply(false))
	row.add_child(toggle)


func _add_language() -> void:
	var row: HBoxContainer = _add_row("UI_SET_LANGUAGE")
	var picker := OptionButton.new()
	picker.add_theme_font_size_override("font_size", FONT_SIZE)
	for locale: String in Settings.LOCALES:
		picker.add_item(LOCALE_NAMES[locale])
	picker.selected = Settings.LOCALES.find(Settings.locale)
	picker.item_selected.connect(func(index: int) -> void:
		Settings.locale = Settings.LOCALES[index]
		Settings.apply(false))
	row.add_child(picker)
