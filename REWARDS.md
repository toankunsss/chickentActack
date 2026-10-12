# Weekly check-in and voluntary ad gifts

Updated: 2026-10-04. Check-in works offline now. Real rewarded advertising is
**not integrated**: there is no ad SDK, network account or ad-unit configuration
in this project. Production does not simulate a successful view or give rewards
for pressing WATCH AD. The provider used by regression tests lives only in tests.

## Player flow

Two Farm shortcuts: a calendar icon with **ĐIỂM DANH** underneath (the user's
explicit caption choice) and video **AD GIFT**. Neither has a rectangular button
background; their transparent hit areas remain finger-sized. Both open a blocking,
closeable cartoon modal. They stay on Farm
and cannot open during a raid, tutorial or another modal. Check-in never requires
an ad. Rewards are global to the local save/shared wallet, not separately claimable
on each planet. Icons use code-native SVGs in `assets/ui/rewards/`.

The check-in popup uses a raised golden DAILY GOODIES banner, pastel sticker cards,
an orange TODAY highlight and an existing chicken sprite in the eighth decorative
slot (not an extra reward). The panel pops in, the mascot wobbles gently, and a
successful claim bounces the reward icon and bursts paper confetti. Closing clears
all motion. Rendering and animation never award currency; saved rules are unchanged.

The calendar shows Monday–Sunday with each reward and TODAY / UPCOMING / CLAIMED /
MISSED states. Claim only the current calendar day, once. Week resets Monday and
day resets at **00:00 UTC+7**, independent of the device timezone setting. Missing
a day does not erase previous claims; missed rewards cannot be collected later.
Starting on Sunday allows Sunday's gift immediately, not seven consecutive days.

| Day | Free reward |
|---|---|
| Monday | 500 Gold |
| Tuesday | 750 Gold |
| Wednesday | 1,000 Gold |
| Thursday | 5 Gems |
| Friday | 1,500 Gold |
| Saturday | 2,000 Gold |
| Sunday | 10 Gems |

## Initial rewarded-ad offer design (needs real SDK)

- Choose either an Energy refill (20 Energy, capped at 240) or another copy of today's already-claimed
  check-in reward (at most once per day). Free check-in is never withheld.
- Both placements share **five completed ads/day** and **120 seconds cooldown**.
- The fifth completed ad adds **5 Gems**, shown in its offer before watching.
- Closing/skipping/failing an ad uses no daily slot and grants no reward.
- Each subsequent ad requires another deliberate tap. No forced interstitial,
  auto-replay, false notification dot, or progression gate was introduced.
- Stop offering ads in the last 180 seconds before midnight so the current-day
  offer does not normally expire during a viewing session.
- These are initial economy parameters, **not a proven optimal revenue plan**.
  Tune retention, opt-in/completion rate and economy only after real-device tests
  and an appropriately disclosed analytics setup; no analytics is installed here.

Rules and amounts live in `scripts/rewards/RewardProgress.gd`.

## Persistence and provider integration

`Game` stores optional `reward_progress` with the existing version-3 save. Old
saves without the field start with no claims; malformed reward fields fail save
validation. Wallet + claim/quota are saved together through SaveStore. Failed
writes roll back memory as well as currency. Same-day duplicates, switching maps,
restart, duplicate callbacks, and simple backwards clock changes are guarded.

This is local offline state, **not anti-cheat security**. Advancing/editing device
time, modifying saves or restoring an older backup can bypass local limits. A
trusted server clock, authenticated entitlements and provider server-side reward
verification are release work, not implemented claims.

`RewardedAdService.install_provider(adapter)` accepts a native SDK adapter with:

- `is_rewarded_ready() -> bool` and `show_rewarded(request_id: String)`.
- Signals `reward_earned(id)`, `ad_closed(id)`, `ad_failed(id)`,
  `availability_changed()`; all callbacks must reach Godot on its main thread.
- Only emit `reward_earned` on the provider's genuine completion/reward callback,
  never on close. Forward it before close if the SDK combines these callbacks.
- Retain the request ID, propagate failure/no-fill/cancellation, and preload the
  next ad outside this service. Ads timeout after 180 seconds; stale IDs cannot pay.

The service checks the quoted amount/day/slot, consumes at most once, and keeps a
verified entitlement in memory for RETRY SAVE after a disk-write failure. This
pending entitlement does not survive process death and expires with its day's
offer; a backend transaction ledger is required for stronger crash recovery.

To activate real ads: choose network/plugin, provide public app and rewarded-unit
IDs, implement the adapter, then test with official test ads on Android. Consent,
age handling, privacy/store disclosures, no-fill, background/resume, connectivity
and server-side verification must be addressed before production release.

## Verification

- `tests/rewards_regression.gd`: calendar/reset/skip/rollback, save/load and shared
  wallet, failed-save rollback, caps, cooldown, doubling, fifth bonus; fake provider
  tests wrong/duplicate/closed/failed/timed-out callbacks and retry-save.
- `tests/rewards_visual_qa.gd`: rendered 360x640, 390x844, 720x1280; real GUI taps,
  icon placement, seven day cards, correct claim amount, modal navigation block,
  text/button bounds, and honest unavailable-ad state. Not Android acceptance.
- Reports: `qa/rewards-report.json`, `qa/rewards-visual-report.json`; screenshots
  `qa/screens/modal_daily_rewards_*`, `modal_ad_gifts_*`, `modal_rewards_farm_icons_*`.
