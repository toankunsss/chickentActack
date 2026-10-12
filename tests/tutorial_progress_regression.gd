extends SceneTree

const TutorialState = preload("res://scripts/tutorial/TutorialProgress.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var tutorial = TutorialState.new()
	tutorial.reset_for_new_player()
	check(tutorial.is_active() and tutorial.current_step_id() == "welcome", "New player starts at welcome")
	check(not tutorial.accept_event("screen_shop"), "Out-of-order event is ignored")
	check(tutorial.accept_event("ack_welcome") and tutorial.current_step_id() == "open_shop", "Welcome advances once")
	check(not tutorial.accept_event("ack_welcome") and tutorial.current_step_id() == "open_shop", "Duplicate event is idempotent")

	var sequence := [
		["screen_shop", {}, "select_chickens"],
		["tab_chickens", {}, "acquire_pair"],
	]
	for row in sequence:
		check(tutorial.accept_event(row[0], row[1]) and tutorial.current_step_id() == row[2], "Advance on %s" % row[0])
	check(not tutorial.accept_event("pair_ready", {"success": false}), "Failed pair cannot advance")
	check(not tutorial.accept_event("pair_ready"), "Pair event requires explicit success")
	check(tutorial.accept_event("pair_ready", {"success": true}) and tutorial.current_step_id() == "return_farm", "Successful pair advances")
	check(tutorial.accept_event("screen_farm") and tutorial.current_step_id() == "merge", "Farm return advances")
	check(not tutorial.accept_event("merge_succeeded", {"success": false}), "Failed merge cannot advance")
	check(tutorial.accept_event("merge_succeeded", {"success": true}) and tutorial.current_step_id() == "hatch", "Successful merge advances")
	check(tutorial.accept_event("egg_hatched", {"success": true}) and tutorial.current_step_id() == "collection", "Successful hatch advances")
	check(not tutorial.collection_ready, "Collection is not ready before its screen is opened")
	check(tutorial.accept_event("screen_collection") and tutorial.current_step_id() == "collection", "Collection screen reveals final overlay without advancing")
	check(tutorial.collection_ready and tutorial.is_active(), "Final acknowledgement remains pending")
	check(not tutorial.accept_event("screen_collection"), "Duplicate collection event is ignored")
	check(tutorial.accept_event("ack_complete") and not tutorial.is_active() and tutorial.is_completed(), "Final acknowledgement completes tutorial")
	check(not tutorial.accept_event("ack_complete"), "Completed tutorial is terminal")

	var completed_snapshot: Dictionary = tutorial.snapshot()
	var restored = TutorialState.new()
	restored.restore(completed_snapshot, TutorialState.MISSING_NEW_PLAYER)
	check(restored.snapshot() == completed_snapshot, "Completed snapshot round trips exactly")

	for step_index in TutorialState.STEP_IDS.size():
		var snapshot := {
			"version": TutorialState.VERSION,
			"step_id": TutorialState.STEP_IDS[step_index],
			"completed": false,
			"skipped": false,
			"collection_ready": step_index == TutorialState.STEP_IDS.size() - 1,
		}
		restored.restore(snapshot, TutorialState.MISSING_VETERAN)
		check(restored.snapshot() == snapshot, "Step snapshot round trip: %s" % snapshot.step_id)

	restored.restore({}, TutorialState.MISSING_NEW_PLAYER)
	check(restored.is_active() and restored.current_step_id() == "welcome", "Missing fresh state starts onboarding")
	restored.restore({}, TutorialState.MISSING_VETERAN)
	check(not restored.is_active() and restored.is_completed(), "Missing veteran state migrates to completed")
	restored.restore({"version": 99, "step_id": "removed"}, TutorialState.MISSING_NEW_PLAYER)
	check(not restored.is_active(), "Unknown version or step fails open without soft-lock")

	restored.reset_for_replay()
	check(restored.is_active() and restored.current_step_id() == "welcome", "Replay resets deterministic state")
	check(restored.skip(), "Active tutorial can be skipped")
	check(not restored.is_active() and restored.is_completed() and restored.was_skipped(), "Skip is persisted as a terminal state")
	check(not restored.skip(), "Skip is idempotent")
	check(_steps_are_unique(), "Step IDs are unique")

	print("TUTORIAL_PROGRESS_REGRESSION_%s: %d checks; %d failures" % ["OK" if failures.is_empty() else "FAILED", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _steps_are_unique() -> bool:
	var seen := {}
	for step_id in TutorialState.STEP_IDS:
		if seen.has(step_id):
			return false
		seen[step_id] = true
	return true
