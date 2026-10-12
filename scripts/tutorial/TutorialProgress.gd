class_name TutorialProgress
extends RefCounted
## Scene-independent onboarding state. UI adapters report semantic events only.

signal step_changed(step_id: String)
signal tutorial_completed
signal tutorial_skipped

const VERSION := 1
const MISSING_NEW_PLAYER := "new_player"
const MISSING_VETERAN := "veteran"
const STEP_IDS: Array[String] = [
	"welcome",
	"open_shop",
	"select_chickens",
	"acquire_pair",
	"return_farm",
	"merge",
	"hatch",
	"collection",
]
const EVENT_BY_STEP := {
	"welcome": "ack_welcome",
	"open_shop": "screen_shop",
	"select_chickens": "tab_chickens",
	"acquire_pair": "pair_ready",
	"return_farm": "screen_farm",
	"merge": "merge_succeeded",
	"hatch": "egg_hatched",
	"collection": "screen_collection",
}
const SUCCESS_EVENTS := ["pair_ready", "merge_succeeded", "egg_hatched"]

var _step_index := 0
var _completed := false
var _skipped := false
var collection_ready := false

func reset_for_new_player() -> void:
	_step_index = 0
	_completed = false
	_skipped = false
	collection_ready = false
	step_changed.emit(current_step_id())

func reset_for_replay() -> void:
	reset_for_new_player()

func restore(saved: Variant, missing_policy: String = MISSING_VETERAN) -> void:
	if not saved is Dictionary or saved.is_empty():
		if missing_policy == MISSING_NEW_PLAYER:
			reset_for_new_player()
		else:
			_mark_completed(false)
		return
	var data: Dictionary = saved
	if not is_valid_snapshot(data):
		# Unknown/corrupt tutorial-only state must never soft-lock the game.
		_mark_completed(false)
		return
	_completed = bool(data.completed)
	_skipped = bool(data.skipped)
	collection_ready = bool(data.collection_ready)
	_step_index = STEP_IDS.find(str(data.step_id))
	if _completed or _skipped:
		_step_index = STEP_IDS.size() - 1
		collection_ready = true
	step_changed.emit(current_step_id())

func snapshot() -> Dictionary:
	return {
		"version": VERSION,
		"step_id": current_step_id(),
		"completed": _completed,
		"skipped": _skipped,
		"collection_ready": collection_ready,
	}

func accept_event(event_id: String, payload: Dictionary = {}) -> bool:
	if not is_active():
		return false
	var step_id := current_step_id()
	if step_id == "collection" and collection_ready:
		if event_id != "ack_complete":
			return false
		_mark_completed(true)
		return true
	if event_id != str(EVENT_BY_STEP.get(step_id, "")):
		return false
	if SUCCESS_EVENTS.has(event_id) and payload.get("success", false) != true:
		return false
	if step_id == "collection":
		collection_ready = true
		step_changed.emit(step_id)
		return true
	_step_index += 1
	step_changed.emit(current_step_id())
	return true

func skip() -> bool:
	if not is_active():
		return false
	_skipped = true
	_completed = true
	collection_ready = true
	_step_index = STEP_IDS.size() - 1
	tutorial_skipped.emit()
	return true

func is_active() -> bool:
	return not _completed and not _skipped

func current_step_id() -> String:
	return STEP_IDS[clampi(_step_index, 0, STEP_IDS.size() - 1)]

func is_completed() -> bool:
	return _completed

func was_skipped() -> bool:
	return _skipped

static func is_valid_snapshot(data: Dictionary) -> bool:
	if data.get("version") != VERSION:
		return false
	if not data.get("step_id") is String or not STEP_IDS.has(str(data.step_id)):
		return false
	for key in ["completed", "skipped", "collection_ready"]:
		if not data.get(key) is bool:
			return false
	if bool(data.skipped) and not bool(data.completed):
		return false
	if bool(data.completed) and not bool(data.collection_ready):
		return false
	return true

func _mark_completed(emit_signal: bool) -> void:
	_step_index = STEP_IDS.size() - 1
	_completed = true
	_skipped = false
	collection_ready = true
	if emit_signal:
		tutorial_completed.emit()
