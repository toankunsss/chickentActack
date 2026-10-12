extends RefCounted
## Offline calendar uses a fixed UTC+7 boundary, not the device timezone setting.
const OFFSET := 7 * 3600
const DAYS := ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
const WEEK := [{"gold": 500, "gems": 0}, {"gold": 750, "gems": 0}, {"gold": 1000, "gems": 0}, {"gold": 0, "gems": 5}, {"gold": 1500, "gems": 0}, {"gold": 2000, "gems": 0}, {"gold": 0, "gems": 10}]
const AD_LIMIT := 5
const AD_COOLDOWN := 120
const AD_ENERGY := 20
const AD_MILESTONE_GEMS := 5
var state := {"week_start": -1, "claimed_mask": 0, "last_seen_day": -1, "ad_day": -1, "ads_today": 0, "last_ad_at": 0, "doubled_day": -1}

static func day_at(now: int) -> int:
	return floori(float(now + OFFSET) / 86400.0)

static func weekday(day: int) -> int:
	return posmod(day + 3, 7)

static func reward_text(reward: Dictionary) -> String:
	var pieces: Array[String] = []
	if int(reward.get("gold", 0)) > 0: pieces.append("%d GOLD" % int(reward.gold))
	if int(reward.get("gems", 0)) > 0: pieces.append("%d GEMS" % int(reward.gems))
	if int(reward.get("energy", 0)) > 0: pieces.append("%d ENERGY" % int(reward.energy))
	return " + ".join(pieces)

func snapshot() -> Dictionary:
	return state.duplicate(true)

func restore(data: Dictionary) -> void:
	var fresh: RefCounted = get_script().new()
	state = fresh.snapshot()
	if not data.is_empty(): state = data.duplicate(true)

static func valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	var limits := {"week_start": [-1, 1000000], "claimed_mask": [0, 127], "last_seen_day": [-1, 1000000], "ad_day": [-1, 1000000], "ads_today": [0, AD_LIMIT], "last_ad_at": [0, 86400000000], "doubled_day": [-1, 1000000]}
	for key in limits:
		var value: Variant = data.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)): return false
		if value < limits[key][0] or value > limits[key][1]: return false
	return true

func view(now: int) -> Dictionary:
	var day := day_at(now)
	var index := weekday(day)
	var week := day - index
	var mask: int = int(state.claimed_mask) if state.week_start == week else 0
	var ads: int = int(state.ads_today) if state.ad_day == day else 0
	var clock_ok := day >= int(state.last_seen_day) and now >= int(state.last_ad_at)
	return {"day": day, "index": index, "week": week, "mask": mask, "ads": ads, "clock_ok": clock_ok,
		"claimed": (mask & (1 << index)) != 0, "doubled": state.doubled_day == day,
		"cooldown": maxi(0, int(state.last_ad_at) + AD_COOLDOWN - now), "reset_in": (day + 1) * 86400 - OFFSET - now}

func _advance(now: int) -> void:
	var today := view(now)
	state.last_seen_day = today.day
	if state.week_start != today.week:
		state.week_start = today.week
		state.claimed_mask = 0
	if state.ad_day != today.day:
		state.ad_day = today.day
		state.ads_today = 0

func claim(now: int) -> Dictionary:
	var today := view(now)
	if not today.clock_ok: return {"ok": false, "reason": "clock"}
	if today.claimed: return {"ok": false, "reason": "claimed"}
	_advance(now)
	state.claimed_mask = int(state.claimed_mask) | (1 << int(today.index))
	return {"ok": true, "reward": WEEK[today.index].duplicate()}

func ad_offer(kind: String, now: int) -> Dictionary:
	var today := view(now)
	if kind not in ["gift", "daily_double"]: return {"ok": false, "reason": "invalid"}
	if not today.clock_ok: return {"ok": false, "reason": "clock"}
	if today.ads >= AD_LIMIT: return {"ok": false, "reason": "limit"}
	if today.reset_in < 180: return {"ok": false, "reason": "reset_soon"}
	if today.cooldown > 0: return {"ok": false, "reason": "cooldown"}
	if kind == "daily_double" and (not today.claimed or today.doubled): return {"ok": false, "reason": "claim_first" if not today.claimed else "claimed"}
	var reward: Dictionary = WEEK[today.index].duplicate() if kind == "daily_double" else {"gold": 0, "gems": 0, "energy": AD_ENERGY}
	if today.ads == AD_LIMIT - 1: reward.gems += AD_MILESTONE_GEMS
	return {"ok": true, "kind": kind, "day": today.day, "ad_index": today.ads, "reward": reward}

func complete_ad(quote: Dictionary, now: int) -> Dictionary:
	# Quotes are created before showing an ad; stale/duplicate callbacks cannot pay.
	var current := ad_offer(str(quote.get("kind", "")), now)
	if not current.ok: return current
	if current.day != quote.get("day") or current.ad_index != quote.get("ad_index") or current.reward != quote.get("reward"):
		return {"ok": false, "reason": "expired"}
	_advance(now)
	state.ads_today += 1
	state.last_ad_at = now
	if current.kind == "daily_double": state.doubled_day = current.day
	return {"ok": true, "reward": current.reward}
