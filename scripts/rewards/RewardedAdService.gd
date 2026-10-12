extends Node
## No production mock ads. Register a native SDK adapter through install_provider.
## Adapter contract: is_rewarded_ready(), show_rewarded(request_id), and signals
## reward_earned(id), ad_closed(id), ad_failed(id), availability_changed().
signal changed
signal finished(result: Dictionary)
const PLAY = preload("res://scripts/config/PlayProgress.gd")
var provider: Node
var pending: Dictionary = {}
var sequence := 0

func install_provider(adapter: Node) -> bool:
	if is_instance_valid(provider) or not pending.is_empty(): return false
	for method in ["is_rewarded_ready", "show_rewarded"]:
		if not adapter.has_method(method): return false
	for event in ["reward_earned", "ad_closed", "ad_failed", "availability_changed"]:
		if not adapter.has_signal(event): return false
	provider = adapter
	provider.reward_earned.connect(_earned)
	provider.ad_closed.connect(_cancel)
	provider.ad_failed.connect(_cancel)
	provider.availability_changed.connect(func(): changed.emit())
	changed.emit()
	return true

func available() -> bool:
	return is_instance_valid(provider) and provider.is_rewarded_ready() and pending.is_empty()

func begin(kind: String) -> Dictionary:
	if not pending.is_empty(): return {"ok": false, "reason": "busy"}
	if not available(): return {"ok": false, "reason": "unavailable"}
	if kind == "gift" and get_node("/root/Game").energy_balance() >= PLAY.ENERGY_CAP:
		return {"ok": false, "reason": "energy_full"}
	var quote: Dictionary = get_node("/root/Game").reward_progress.ad_offer(kind, int(Time.get_unix_time_from_system()))
	if not quote.ok: return quote
	sequence += 1
	var id := "%d:%d" % [Time.get_ticks_usec(), sequence]
	pending = {"id": id, "quote": quote, "earned": false, "deadline": Time.get_ticks_msec() + 180000}
	changed.emit()
	provider.show_rewarded(id)
	return {"ok": true}

func _earned(id: String) -> void:
	if pending.is_empty() or pending.id != id or pending.earned: return
	pending.earned = true
	retry_save()

func retry_save() -> void:
	if pending.is_empty() or not pending.earned: return
	var result: Dictionary = get_node("/root/Game").complete_ad_reward(pending.quote)
	if result.ok or result.get("reason") != "save_failed": pending.clear()
	changed.emit()
	finished.emit(result)

func _cancel(id: String) -> void:
	if pending.is_empty() or pending.id != id or pending.earned: return
	pending.clear()
	changed.emit()
	finished.emit({"ok": false, "reason": "cancelled"})

func _process(_delta: float) -> void:
	if not pending.is_empty() and not pending.earned and Time.get_ticks_msec() >= pending.deadline:
		_cancel(pending.id)
