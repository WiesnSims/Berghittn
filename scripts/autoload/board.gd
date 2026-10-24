extends Node
## Das Gipfelbuch (GAME_DESIGN section 12): the global leaderboard on berghittn.pages.dev/api/board
## (board/board.js). Wave 1 asks for a run ticket (start_run), the end of the run sends the result
## with it (submit), and the title screen's panel lists the boards (fetch). Without a connection
## nothing happens: the signals just say so, the game goes on.

## Our result was saved: its place on the board, all time and this week, and its id (co-op: the
## group's, from the host).
signal ranked(rank: int, week_rank: int, id: int)
## The result could not be saved (no connection, refused): the death screen hides its line.
signal not_ranked
## The board asked for by fetch(): `entries` as the server sends them (an empty Array if it failed),
## `ok` false if it could not be reached.
signal listed(mode: String, period: String, entries: Array, ok: bool)

const MODES: Array[String] = ["solo", "coop"]
const PERIODS: Array[String] = ["all", "week"]

# The ticket of the run going on, and the mode it was opened for ("" without one).
var _ticket: String = ""
var _mode: String = ""
# A ticket asked for and not answered yet: a quick death waits for it.
var _asking: bool = false
## False once this round's run no longer counts (forfeit): also a co-op guest's, for the host's entry.
var clean: bool = true


## A new scene, a new run: no ticket yet, and nothing forfeited.
func new_round() -> void:
	_ticket = ""
	_mode = ""
	clean = true


## Wave 1 began: a fresh ticket for this run (only with the Settings switch on).
func start_run(mode: String) -> void:
	_ticket = ""
	_mode = mode
	if not Settings.board or base_url() == "":
		return
	_asking = true
	var reply: Dictionary = await _request("ticket", HTTPClient.METHOD_POST, {"mode": mode})
	_asking = false
	if _mode == mode and reply.has("ticket"):
		_ticket = str(reply["ticket"])


## This run can go into the Gipfelbuch (a ticket is there or on its way).
func has_run(mode: String) -> bool:
	return Settings.board and clean and _mode == mode and (_ticket != "" or _asking)


## The run no longer counts (the F4 debug points): nothing is sent for it.
func forfeit() -> void:
	_ticket = ""
	clean = false


## Sends the run (keys as board/board.js takes them, the ticket added here); emits ranked or
## not_ranked. The ticket counts once.
func submit(entry: Dictionary) -> void:
	while _asking:
		await get_tree().process_frame
	if _ticket == "" or not Settings.board or not clean:
		not_ranked.emit()
		return
	var body: Dictionary = entry.duplicate()
	body["ticket"] = _ticket
	body["version"] = PatchNotes.current()
	_ticket = ""
	var reply: Dictionary = await _request("entry", HTTPClient.METHOD_POST, body)
	if not reply.has("rank"):
		not_ranked.emit()
		return
	remember(int(reply["id"]))
	ranked.emit(int(reply["rank"]), int(reply["week_rank"]), int(reply["id"]))


## An entry of ours (also the group's, told by the host): the panel highlights it.
func remember(id: int) -> void:
	if id > 0 and not id in Settings.board_ids:
		Settings.board_ids.append(id)
		while Settings.board_ids.size() > Constants.BOARD_REMEMBERED:
			Settings.board_ids.remove_at(0)
		Settings.save()


## One board: `mode` solo or coop, `period` all or week; answered by `listed`.
func fetch(mode: String, period: String) -> void:
	if base_url() == "":
		listed.emit.call_deferred(mode, period, [], false)
		return
	var reply: Dictionary = await _request("list?mode=%s&range=%s" % [mode, period], HTTPClient.METHOD_GET, {})
	listed.emit(mode, period, reply.get("entries", []) if reply.get("entries") is Array else [], reply.has("entries"))


## Where the Gipfelbuch is: the page's own origin in the browser (previews have their own board),
## else --board=<url>; "" on the desktop without it, so test runs never write to the real one.
func base_url() -> String:
	if has_meta("test_url"):
		return get_meta("test_url")
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("location.origin", true))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--board="):
			return arg.get_slice("=", 1)
	return ""


# The server's JSON answer, or {} if there was none (no connection, an error status, a timeout).
func _request(path: String, method: HTTPClient.Method, body: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = Constants.BOARD_TIMEOUT
	# The death screen pauses the game; the request must still finish.
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http)
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var data: String = JSON.stringify(body) if method == HTTPClient.METHOD_POST else ""
	if http.request("%s/api/board/%s" % [base_url(), path], headers, method, data) != OK:
		http.queue_free()
		return {}
	var result: Array = await http.request_completed
	http.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 200:
		return {}
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	return parsed if parsed is Dictionary else {}
