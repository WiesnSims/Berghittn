class_name Keys
extends RefCounted
## Key bindings (1.1.2): the actions a player may put on other keys or mouse buttons (the Settings
## menu), saved in Settings.bindings as each action's first binding, and texts that name a key
## ("Press {interact} to ...") filled in with whatever it is bound to now. An action's other default
## bindings (the arrow keys, the middle button for throwing) stay as they are.

## Rebindable actions with their name in the menu, in the menu's order.
const ACTIONS: Array[Array] = [
	["move_forward", "UI_KEY_MOVE_FORWARD"], ["move_back", "UI_KEY_MOVE_BACK"],
	["move_left", "UI_KEY_MOVE_LEFT"], ["move_right", "UI_KEY_MOVE_RIGHT"],
	["jump", "UI_KEY_JUMP"], ["sprint", "UI_KEY_SPRINT"], ["crouch", "UI_KEY_CROUCH"],
	["fire", "UI_KEY_FIRE"], ["secondary", "UI_KEY_SECONDARY"], ["reload", "UI_KEY_RELOAD"],
	["melee", "UI_KEY_MELEE"], ["throw", "UI_KEY_THROW"], ["interact", "UI_KEY_INTERACT"],
	["weapon_slot_1", "UI_KEY_SLOT_1"], ["weapon_slot_2", "UI_KEY_SLOT_2"], ["weapon_slot_3", "UI_KEY_SLOT_3"],
	["weapon_next", "UI_KEY_NEXT"], ["weapon_previous", "UI_KEY_PREVIOUS"],
]
## Kept for themselves: pause and the debug keys cannot be bound to anything else.
const RESERVED: Array[String] = ["pause", "toggle_debug", "debug_points"]
const MOUSE_KEYS: Dictionary = {
	MOUSE_BUTTON_LEFT: "UI_KEY_MOUSE_LEFT", MOUSE_BUTTON_RIGHT: "UI_KEY_MOUSE_RIGHT",
	MOUSE_BUTTON_MIDDLE: "UI_KEY_MOUSE_MIDDLE", MOUSE_BUTTON_WHEEL_UP: "UI_KEY_WHEEL_UP",
	MOUSE_BUTTON_WHEEL_DOWN: "UI_KEY_WHEEL_DOWN", MOUSE_BUTTON_XBUTTON1: "UI_KEY_MOUSE_4",
	MOUSE_BUTTON_XBUTTON2: "UI_KEY_MOUSE_5",
}


static func actions() -> Array[String]:
	var names: Array[String] = []
	for entry: Array in ACTIONS:
		names.append(entry[0])
	return names


## What the action's first binding is called, as a player reads it ("E", "Space", "LMB").
static func name_of(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	return event_name(events[0]) if not events.is_empty() else "–"


static func event_name(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key:
		var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		# The key's label on this keyboard's layout (a German Z where a US keyboard has Y), where the
		# display server knows it; the browser's and the headless one do not (they log an error on
		# every call).
		var label: Key = KEY_NONE
		if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
			label = DisplayServer.keyboard_get_keycode_from_physical(code)
		return OS.get_keycode_string(label if label != KEY_NONE else code)
	var button := event as InputEventMouseButton
	if button:
		return TranslationServer.translate(MOUSE_KEYS.get(button.button_index, "UI_KEY_MOUSE_OTHER"))
	return "?"


## `text` with every {action} replaced by that action's key.
static func fill(text: String) -> String:
	if not "{" in text:
		return text
	for action: String in actions():
		text = text.replace("{%s}" % action, name_of(action))
	return text


## The same key or button (a key by where it is on the keyboard).
static func same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return (a as InputEventKey).physical_keycode == (b as InputEventKey).physical_keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


## An event a player may bind: a key (not Escape) or a mouse button, not one kept for pause or debug.
static func can_bind(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key and (key.physical_keycode == KEY_NONE or key.physical_keycode == KEY_ESCAPE):
		return false
	if not (key or event is InputEventMouseButton):
		return false
	for action: String in RESERVED:
		if InputMap.has_action(action) and InputMap.action_get_events(action).any(func(e: InputEvent) -> bool: return same(e, event)):
			return false
	return true


## Puts `event` first on `action`. An action that had it as its first binding gets `action`'s old
## one instead (a swap); one that had it among its others loses it. Returns the bindings to save.
static func rebind(action: String, event: InputEvent) -> Dictionary:
	var bound := _plain(event)
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	var old: InputEvent = events[0] if not events.is_empty() else null
	for other: String in actions():
		if other == action:
			continue
		var theirs: Array[InputEvent] = InputMap.action_get_events(other)
		for i: int in theirs.size():
			if not same(theirs[i], bound):
				continue
			if i == 0 and old != null:
				_set_first(other, old)
			else:
				InputMap.action_erase_event(other, theirs[i])
			break
	# Our own second binding of the same key would show twice.
	for e: InputEvent in InputMap.action_get_events(action).slice(1):
		if same(e, bound):
			InputMap.action_erase_event(action, e)
	_set_first(action, bound)
	return saved()


## Every rebindable action's first binding as Settings keeps it.
static func saved() -> Dictionary:
	var out: Dictionary = {}
	for action: String in actions():
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		if not events.is_empty():
			out[action] = to_data(events[0])
	return out


## The project's default bindings, then `bindings` (from Settings) over them.
static func apply(bindings: Dictionary) -> void:
	InputMap.load_from_project_settings()
	for action: String in actions():
		var event: InputEvent = from_data(bindings.get(action))
		if event != null and can_bind(event):
			rebind(action, event)


static func to_data(event: InputEvent) -> Dictionary:
	var key := event as InputEventKey
	if key:
		return {"key": int(key.physical_keycode)}
	var button := event as InputEventMouseButton
	if button:
		return {"mouse": int(button.button_index)}
	return {}


## Null for anything that is not a saved key or button.
static func from_data(data: Variant) -> InputEvent:
	if not data is Dictionary:
		return null
	var d: Dictionary = data
	if d.get("key") is int and int(d["key"]) > 0:
		var key := InputEventKey.new()
		key.physical_keycode = int(d["key"]) as Key
		return key
	if d.get("mouse") is int and int(d["mouse"]) > 0:
		var button := InputEventMouseButton.new()
		button.button_index = int(d["mouse"]) as MouseButton
		return button
	return null


# Only which key or button: no modifiers, no pressed state from the moment it was caught.
static func _plain(event: InputEvent) -> InputEvent:
	return from_data(to_data(event))


static func _set_first(action: String, event: InputEvent) -> void:
	var rest: Array[InputEvent] = InputMap.action_get_events(action).slice(1)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	for e: InputEvent in rest:
		InputMap.action_add_event(action, e)
