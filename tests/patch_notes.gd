extends Node
## Run: godot --headless --fixed-fps 60 res://tests/patch_notes.tscn
## The patch notes (user request 2026-10-24): the newest entry is the game's version, every entry has
## as many lines in English as in German, the title screen shows the version and marks unread notes
## until they are opened, and the panel lists every version.

var failures: Array[String] = []


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _ready() -> void:
	var saved: String = Settings.seen_version
	_check(PatchNotes.ENTRIES[0]["version"] == PatchNotes.current(), "the newest notes are for this version (%s)" % PatchNotes.current())
	for entry: Dictionary in PatchNotes.ENTRIES:
		_check((entry["en"] as Array).size() == (entry["de"] as Array).size() and not (entry["en"] as Array).is_empty(), "%s: %d lines in both languages" % [entry["version"], (entry["en"] as Array).size()])
	Settings.seen_version = ""
	var screen := (load("res://scenes/ui/start_screen.tscn") as PackedScene).instantiate() as StartScreen
	add_child(screen)
	await get_tree().process_frame
	var button := screen.get_node("%PatchNotesButton") as Button
	_check(button.text == tr("UI_PATCH_NOTES_NEW"), "unread: \"%s\"" % button.text)
	_check(screen._version.text == tr("UI_VERSION") % PatchNotes.current(), "the version shows: %s" % screen._version.text)
	button.pressed.emit()
	await get_tree().process_frame
	var shown: String = screen._notes._text.get_parsed_text()
	_check(screen._notes.visible and shown.contains("1.0.1") and shown.contains("1.0 "), "the panel lists every version")
	_check(button.text == tr("UI_PATCH_NOTES") and Settings.seen_version == PatchNotes.current(), "read once, the mark goes")
	Settings.seen_version = saved
	Settings.save()
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)
