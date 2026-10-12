extends SceneTree
const RULES = preload("res://scripts/rewards/RewardProgress.gd")
const SERVICE = preload("res://scripts/rewards/RewardedAdService.gd")
var checks := 0
var failures: Array[String] = []
class FakeProvider extends Node:
	signal reward_earned(id: String)
	signal ad_closed(id: String)
	signal ad_failed(id: String)
	signal availability_changed
	var last_id := ""
	func is_rewarded_ready() -> bool: return true
	func show_rewarded(id: String) -> void: last_id = id

func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "MutationFarmRewardsQA/%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)

func run() -> void:
	var monday := int(Time.get_unix_time_from_datetime_string("2026-10-05T05:00:00"))
	var progress := RULES.new()
	check(progress.view(monday).index == 0, "Monday starts weekly calendar")
	for index in 14:
		var now := monday + index * 86400
		var result := progress.claim(now)
		check(result.ok and result.reward == RULES.WEEK[index % 7], "Correct daily reward %d" % index)
		check(not progress.claim(now).ok, "Cannot claim same day twice")
		check(not progress.claim(now - 86400).ok, "Clock rollback cannot reopen previous day")
		check(RULES.valid(progress.snapshot()), "Saved state passes strict validation")
		var restored := RULES.new()
		restored.restore(JSON.parse_string(JSON.stringify(progress.snapshot())))
		check(not restored.claim(now).ok, "Restart preserves claimed state")
	progress.restore({})
	progress.claim(monday)
	check(progress.claim(monday + 3 * 86400).ok and progress.state.claimed_mask == 9, "Missing days keeps earlier claims without granting missed days")
	var midnight := monday - 12 * 3600
	check(progress.view(midnight).index == 0 and progress.view(midnight - 1).index == 6, "Midnight UTC+7 changes weekday exactly")
	progress.restore({})
	for index in 5:
		var now := monday + index * 121
		var offer := progress.ad_offer("gift", now)
		check(offer.ok and offer.reward.energy == 20 and offer.reward.gold == 0 and offer.reward.gems == (5 if index == 4 else 0), "Energy ad and fifth-view bonus explicit")
		check(progress.complete_ad(offer, now).ok, "Verified completion consumes one slot")
		check(not progress.complete_ad(offer, now).ok, "Duplicate quote cannot grant again")
		check(not progress.ad_offer("gift", now + 119).ok, "Cooldown enforced")
	check(progress.ad_offer("gift", monday + 1000).reason == "limit", "Five-ad daily cap")
	check(progress.ad_offer("gift", monday + 86400).ok, "Ad limit resets next day")
	progress.restore({})
	check(not progress.ad_offer("daily_double", monday).ok, "Free claim required before optional double")
	progress.claim(monday)
	var double_offer := progress.ad_offer("daily_double", monday)
	check(progress.complete_ad(double_offer, monday).ok and progress.state.ads_today == 1, "Double counts against shared daily ad limit")
	check(not progress.ad_offer("daily_double", monday + 121).ok, "Daily reward doubled at most once")
	check(progress.ad_offer("gift", midnight + 86400 - 60).reason == "reset_soon", "Do not offer an ad just before reward expires at midnight")
	for key in progress.snapshot():
		var corrupt := progress.snapshot()
		corrupt[key] = "oops"
		check(not RULES.valid(corrupt), "Reject malformed field " + key)
	var game := root.get_node("Game")
	game.reward_progress.restore({})
	var initial_coins: float = game.coins
	var initial_gems: int = game.gems
	game._save_blocked = true
	check(game.claim_daily_reward().reason == "save_failed" and game.coins == initial_coins and game.gems == initial_gems, "Failed save rolls back wallet and check-in")
	game._save_blocked = false
	check(game.claim_daily_reward().ok, "Daily claim persists successfully")
	var paid_coins: float = game.coins
	var paid_gems: int = game.gems
	game.current_planet = "ice"
	check(not game.claim_daily_reward().ok, "Switching planet does not reset global claim")
	check(game.load_game() and not game.claim_daily_reward().ok and game.coins == paid_coins and game.gems == paid_gems, "Actual save/load retains claim and wallet")
	var service := SERVICE.new()
	root.add_child(service)
	check(service.begin("gift").reason == "unavailable" and game.coins == paid_coins, "No SDK never pretends to show an ad")
	var fake := FakeProvider.new()
	root.add_child(fake)
	check(service.install_provider(fake), "SDK adapter contract accepted")
	game.play_progress.state.energy = game.PlayProgress.ENERGY_CAP
	check(service.begin("gift").reason == "energy_full", "Full Energy blocks a wasteful ad before playback")
	game.play_progress.state.energy = 0
	var first_begin: Dictionary = service.begin("gift")
	check(first_begin.ok, "Ready provider begins ad: %s" % first_begin)
	if not first_begin.ok:
		var failed_file := FileAccess.open("res://qa/rewards-report.json", FileAccess.WRITE)
		failed_file.store_string(JSON.stringify({"checks": checks, "failures": failures, "begin": first_begin}, "\t"))
		failed_file.close()
		quit(1)
		return
	check(not service.begin("gift").ok, "No parallel ad requests")
	fake.reward_earned.emit("wrong-id")
	check(game.coins == paid_coins, "Unmatched callback ignored")
	fake.ad_closed.emit(fake.last_id)
	check(service.pending.is_empty() and game.coins == paid_coins and game.reward_progress.state.ads_today == 0, "Closing without earned signal gives no reward or quota usage")
	service.begin("gift")
	var id := fake.last_id
	fake.reward_earned.emit(id)
	check(game.energy_balance() == 20 and game.coins == paid_coins and game.reward_progress.state.ads_today == 1, "Only earned callback grants advertised Energy")
	fake.reward_earned.emit(id)
	fake.ad_closed.emit(id)
	check(game.energy_balance() == 20 and game.coins == paid_coins, "Duplicate/closed callback cannot pay twice")
	game.reward_progress.state.last_ad_at = 0
	service.begin("gift")
	game._save_blocked = true
	fake.reward_earned.emit(fake.last_id)
	check(not service.pending.is_empty() and service.pending.earned and game.energy_balance() == 20, "Failed ad save retains earned entitlement without paying")
	game._save_blocked = false
	service.retry_save()
	check(service.pending.is_empty() and game.energy_balance() == 40, "Save retry grants Energy once without replaying ad")
	game.reward_progress.state.last_ad_at = 0
	service.begin("gift")
	fake.ad_failed.emit(fake.last_id)
	check(service.pending.is_empty() and game.energy_balance() == 40, "Provider failure gives no reward")
	service.begin("gift")
	service.pending.deadline = 0
	service._process(0.1)
	fake.reward_earned.emit(fake.last_id)
	check(service.pending.is_empty() and game.energy_balance() == 40, "Timed-out and late callbacks cannot pay")
	var file := FileAccess.open("res://qa/rewards-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "scope": "Offline calendar, saved wallet, ad callback contract using test-only provider; no real ads"}, "\t"))
	file.close()
	if failures.is_empty(): print("REWARDS_REGRESSION_OK: %d checks, 0 failures" % checks)
	quit(0 if failures.is_empty() else 1)
