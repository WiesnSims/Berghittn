extends Node
## Run: godot --headless --fixed-fps 60 res://tests/title_slides.tscn
## Headless check of the title screen's slideshow (1.1.2): every scene's picture is there, they come
## in a shuffled order with each once, a picture holds still while the shaders are built, and when
## alive the next one fades in after SLIDE_TIME and takes over, round all of them and back to the first.

var failures: Array[String] = []


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _slides(backdrop: TeaserBackdrop) -> Array[Node]:
	return backdrop.get_children().filter(func(child: Node) -> bool: return child is TeaserBackdrop.Slide and not child.is_queued_for_deletion())


func _ready() -> void:
	var backdrop := TeaserBackdrop.new()
	backdrop.size = Vector2(1152, 648)
	add_child(backdrop)
	var scenes: Array = TeaserBackdrop.SCENES.keys()
	_check(scenes.size() == 7, "%d scenes" % scenes.size())
	for id: String in scenes:
		var picture := load(TeaserBackdrop.SCENES[id]["picture"]) as Texture2D
		_check(picture != null and picture.get_width() == 1920, "%s: its picture (%s)" % [id, TeaserBackdrop.SCENES[id]["picture"]])
		for effect: Array in TeaserBackdrop.SCENES[id]["effects"]:
			_check((effect[1] as Array).all(func(at: Vector2) -> bool: return Rect2(0, 0, 1, 1).has_point(at)), "%s: its %s is on the picture" % [id, effect[0]])
	var order: Array = backdrop.order.duplicate()
	order.sort()
	scenes.sort()
	_check(order == scenes, "each once, shuffled: %s" % ", ".join(backdrop.order))
	var first: String = backdrop.scene()
	_check(_slides(backdrop).size() == 1 and (_slides(backdrop)[0] as TeaserBackdrop.Slide).id == first, "one picture showing: %s" % first)
	# Still while the shaders are built.
	backdrop.set_animated(false)
	for i: int in 60:
		backdrop._process(1.0)
	_check(backdrop.scene() == first and _slides(backdrop).size() == 1, "held still: no change in a minute")
	backdrop.set_animated(true)
	backdrop._process(TeaserBackdrop.SLIDE_TIME - 1.0)
	_check(_slides(backdrop).size() == 1, "%.0f s: still the one" % (TeaserBackdrop.SLIDE_TIME - 1.0))
	# The change starts at SLIDE_TIME, the fade going on in the same frame.
	backdrop._process(1.0)
	backdrop._process(TeaserBackdrop.FADE_TIME * 0.5 - 1.0)
	var slides: Array[Node] = _slides(backdrop)
	var fading: bool = slides.size() == 2 and (slides[1] as Control).modulate.a > 0.1 and (slides[1] as Control).modulate.a < 0.9
	_check(fading and (slides[1] as TeaserBackdrop.Slide).id == backdrop.order[1], "then the next fades in over it: %s" % backdrop.order[1])
	_check(slides.size() == 2 and slides[1].get_index() < backdrop.get_child_count() - 2, "under the snow and the shade")
	backdrop._process(TeaserBackdrop.FADE_TIME)
	await get_tree().process_frame
	_check(backdrop.scene() == backdrop.order[1] and _slides(backdrop).size() == 1, "and takes over")
	var seen: Array[String] = [first, backdrop.scene()]
	for i: int in backdrop.order.size() - 1:
		for step: int in ceili((TeaserBackdrop.SLIDE_TIME + TeaserBackdrop.FADE_TIME) / 0.5) + 2:
			backdrop._process(0.5)
		await get_tree().process_frame
		if not seen.has(backdrop.scene()):
			seen.append(backdrop.scene())
	_check(seen.size() == 7 and backdrop.scene() == first, "round all %d and back to the first" % seen.size())
	var kinds: Array[String] = []
	for id: String in scenes:
		for effect: Array in TeaserBackdrop.SCENES[id]["effects"]:
			kinds.append(effect[0])
	for kind: String in ["shot", "lamp", "volley", "gold", "birds", "glint", "sparks", "lantern"]:
		_check(kind in kinds, "a picture with %s" % kind)
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)
