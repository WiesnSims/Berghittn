class_name SteckbriefPanel
extends Control
## Steckbriefe & Wandernadln (1.2 extras, GAME_DESIGN section 12), over the title screen. Two tabs:
## a wanted poster for every enemy (its picture, name, what it does, one of its lines, our kills; a
## dark silhouette and "???" until it first turned up in one of our matches, Settings.met), and the
## 18 Wandernadln with what the next one takes. Built in code; the start screen opens it.

signal closed

## Every enemy with a poster, in the order they are shown: the plain ones, then the Bsundan.
const ENEMIES: Array[String] = [
	"wanderer", "tourist", "knappe", "perchte", "krampus", "venedigermandl", "wilderer", "bergdohle",
	"kassier", "bergfuehrer", "trailrunner", "influencer", "sprengmeister", "schoenperchte",
]
const PORTRAITS: String = "res://assets/ui/steckbriefe/%s.png"
const PAPER := Color(0.86, 0.78, 0.6)
const PAPER_BSUNDAN := Color(0.93, 0.84, 0.58)
const INK := Color(0.22, 0.14, 0.08)
const RED := Color(0.55, 0.12, 0.08)
const GOLD := Color(0.78, 0.58, 0.16)
const MUTED := Color(0.75, 0.7, 0.62)
const CARD_SIZE := Vector2(196, 388)
const PANEL_SIZE := Vector2(1120, 600)
## A poster of an enemy not met yet: only its shape, in ink.
const SILHOUETTE: String = """shader_type canvas_item;
uniform vec4 ink : source_color;
void fragment() {
	COLOR = vec4(ink.rgb, texture(TEXTURE, UV).a * ink.a);
}
"""

static var _silhouette: ShaderMaterial

var _posters: GridContainer
var _badges: VBoxContainer
var _pages: Array[Control] = []
var _tabs: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var board := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.06, 0.04, 0.94)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(22)
	board.add_theme_stylebox_override("panel", style)
	center.add_child(board)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	board.add_child(box)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 12)
	box.add_child(tabs)
	for key: String in ["UI_STECKBRIEFE", "UI_NADLN"]:
		var tab := Button.new()
		tab.text = key
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(260, 48)
		tab.add_theme_font_size_override("font_size", 26)
		tab.pressed.connect(show_page.bind(_tabs.size()))
		tabs.add_child(tab)
		_tabs.append(tab)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = PANEL_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_posters = GridContainer.new()
	_posters.columns = 5
	_posters.add_theme_constant_override("h_separation", 18)
	_posters.add_theme_constant_override("v_separation", 18)
	_posters.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	scroll.add_child(_posters)
	_pages.append(scroll)
	var badge_scroll := ScrollContainer.new()
	badge_scroll.custom_minimum_size = PANEL_SIZE
	badge_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(badge_scroll)
	_badges = VBoxContainer.new()
	_badges.add_theme_constant_override("separation", 12)
	_badges.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_scroll.add_child(_badges)
	_pages.append(badge_scroll)
	var back := Button.new()
	back.text = "UI_BACK"
	back.custom_minimum_size = Vector2(220, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(close)
	box.add_child(back)
	hide()


## Opens on page `page` (0 Steckbriefe, 1 Wandernadln), freshly filled from Settings.
func open(page: int = 0) -> void:
	_fill_posters()
	_fill_badges()
	show_page(page)
	show()


func show_page(page: int) -> void:
	for i: int in _pages.size():
		_pages[i].visible = i == page
		_tabs[i].set_pressed_no_signal(i == page)


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## The material that draws a picture as its shape only.
static func silhouette() -> ShaderMaterial:
	if _silhouette == null:
		var shader := Shader.new()
		shader.code = SILHOUETTE
		_silhouette = ShaderMaterial.new()
		_silhouette.shader = shader
		_silhouette.set_shader_parameter("ink", Color(0.2, 0.13, 0.07, 0.9))
	return _silhouette


## One of `id`'s lines for its poster ("" if it has none): when it spots a player, else any.
static func quote(id: String) -> String:
	var data: EnemyData = load("res://data/enemies/%s.tres" % id)
	for moment: Gredn.Moment in [Gredn.Moment.SPOT, Gredn.Moment.IDLE, Gredn.Moment.APPEAR, Gredn.Moment.DEATH]:
		var lines: Array[int] = Gredn.lines_for(data, moment)
		if not lines.is_empty():
			return "„%s“" % Gredn.LINES[lines[0]][2]
	return ""


## The poster of `id` (also for tests).
func poster(id: String) -> Control:
	var met: bool = id in Settings.met
	var bsundan: bool = id in Wandernadln.VARIANTS
	var card := PanelContainer.new()
	card.name = "Poster_" + id
	card.custom_minimum_size = CARD_SIZE
	var paper := StyleBoxFlat.new()
	paper.bg_color = PAPER_BSUNDAN if bsundan else PAPER
	paper.set_corner_radius_all(3)
	paper.set_content_margin_all(10)
	paper.set_border_width_all(3 if bsundan else 0)
	paper.border_color = GOLD
	card.add_theme_stylebox_override("panel", paper)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	column.add_child(_text("UI_GSUACHT", 28, RED, true))
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(128, 160)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if ResourceLoader.exists(PORTRAITS % id):
		picture.texture = load(PORTRAITS % id)
	if not met:
		picture.material = silhouette()
	column.add_child(picture)
	var title: Label = _text(tr("ENEMY_" + id.to_upper()) if met else "???", 22, INK, true)
	title.name = "Name"
	column.add_child(title)
	if bsundan:
		column.add_child(_text("UI_STECK_BSUNDAN", 14, GOLD, true))
	var about: Label = _text(tr("STECK_" + id.to_upper()) if met else tr("UI_STECK_UNKNOWN"), 14, INK)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size = Vector2(CARD_SIZE.x - 20, 0)
	about.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(about)
	if met:
		var line: Label = _text(quote(id), 14, RED)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(CARD_SIZE.x - 20, 0)
		line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		column.add_child(line)
	var kills: Label = _text(tr("UI_STECK_KILLS") % Wandernadln.kills_of(id), 16, INK, true)
	kills.name = "Kills"
	column.add_child(kills)
	return card


func _fill_posters() -> void:
	for child: Node in _posters.get_children():
		_posters.remove_child(child)
		child.queue_free()
	for id: String in ENEMIES:
		_posters.add_child(poster(id))


func _fill_badges() -> void:
	for child: Node in _badges.get_children():
		_badges.remove_child(child)
		child.queue_free()
	var count := _text(tr("UI_NADL_COUNT") % Wandernadln.earned(), 24, MUTED, true)
	_badges.add_child(count)
	for badge: StringName in Wandernadln.BADGES:
		_badges.add_child(_badge_row(badge))


func _badge_row(badge: StringName) -> Control:
	var row := HBoxContainer.new()
	row.name = "Badge_" + String(badge)
	row.add_theme_constant_override("separation", 16)
	var got: int = Wandernadln.tier(badge)
	var title := _text("UI_NADL_" + String(badge).to_upper(), 24, Color(0.95, 0.92, 0.85))
	title.custom_minimum_size = Vector2(230, 0)
	row.add_child(title)
	for which: int in range(1, 4):
		var pin := Pin.new()
		pin.color = Wandernadln.TIER_COLORS[which] if got >= which else Wandernadln.TIER_COLORS[0]
		pin.earned = got >= which
		pin.tooltip_text = "%s: %s" % [tr(Wandernadln.TIERS[which]), goal_text(badge, which)]
		row.add_child(pin)
	var next: String = tr("UI_NADL_ALL") if got >= 3 else "%s: %s" % [tr(Wandernadln.TIERS[got + 1]), goal_text(badge, got + 1, true)]
	var hint := _text(next, 18, MUTED)
	hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(hint)
	return row


## What `badge`'s tier `which` takes, as the panel says it; `progress` adds how far we are.
static func goal_text(badge: StringName, which: int, progress: bool = false) -> String:
	var goal: int = Wandernadln.goal(badge, which)
	var text: String
	if badge == &"bsundan" and which == 2:
		text = TranslationServer.translate("UI_NADL_GOAL_BSUNDAN_ALL")
	elif badge == &"huat" and which == 3:
		return TranslationServer.translate("UI_NADL_GOAL_HUAT_FULL")
	else:
		text = TranslationServer.translate("UI_NADL_GOAL_" + String(badge).to_upper()) % goal
	if progress:
		text += "  (%d/%d)" % [mini(Wandernadln.value(badge, which), goal), goal]
	return text


func _text(text: String, size: int, color: Color, centred: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if centred:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## A Wandernadl: a round badge with a mountain, in its metal once earned, grey until then.
class Pin:
	extends Control

	var color: Color = Color.GRAY
	var earned: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(44, 44)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var middle: Vector2 = size / 2.0
		var radius: float = minf(size.x, size.y) / 2.0 - 2.0
		draw_circle(middle, radius, color.darkened(0.35))
		draw_circle(middle, radius - 3.0, color)
		var ink: Color = color.darkened(0.55) if earned else Color(0.2, 0.19, 0.18)
		var peak := PackedVector2Array([
			middle + Vector2(-radius * 0.62, radius * 0.38), middle + Vector2(-radius * 0.12, -radius * 0.45),
			middle + Vector2(radius * 0.12, -radius * 0.1), middle + Vector2(radius * 0.3, -radius * 0.32),
			middle + Vector2(radius * 0.62, radius * 0.38),
		])
		draw_colored_polygon(peak, ink)
		# Snow on the top.
		draw_colored_polygon(PackedVector2Array([middle + Vector2(-radius * 0.12, -radius * 0.45),
				middle + Vector2(-radius * 0.26, -radius * 0.24), middle + Vector2(0.0, -radius * 0.24)]),
				Color(1, 1, 1, 0.85 if earned else 0.25))
