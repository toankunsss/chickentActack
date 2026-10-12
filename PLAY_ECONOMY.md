# Offline energy and daily shop — 2026-10-05

## Current defaults

- Battle costs 5 Energy per match/rematch. Energy does not regenerate with time; optional rewarded ads restore 20 Energy up to the 240 cap. Farm, browsing and previews are free.
- These are provisional tuning defaults, not a separately confirmed balance decision. Adjust `scripts/config/PlayProgress.gd` centrally.
- Charge once at the first combat update after loading/countdown. Cancelling preparation/countdown is free; abandoning combat does not refund. Insufficient energy or save failure prevents combat advancing.
- The lightning HUD now reads energy. Legacy saves migrate the previous `dna` display balance without deleting legacy fields or touching other resources. Balances above cap are preserved but do not regenerate until below cap.
- Elapsed/offline time does not grant Energy. Rewarded-ad completion and the resulting Energy transaction are saved together; this is still not server-backed anti-cheat.

## Victory rewards

- Win: **150 Gold + 10 Gold per player-controlled tile at the end**, plus **20 XP**. Defeat, draw and abandoned matches give no reward. Spending Energy does not guarantee a prize.
- The Battle lobby previews this formula. Result popup shows the amount actually saved; rematch costs another 5 Energy after its countdown.
- Reward values live in `PlayProgress.gd`; `Game.save_battle_reward()` rolls back both Gold and XP if saving fails. The arena claims once per completed, paid match and prevents duplicate finish callbacks from paying twice.
- Failed payout shows `PENDING` with `RETRY SAVE`; leaving/rematching is blocked until the prize saves. Retry does not charge Energy again. Pending state is in memory only: force-closing before a successful retry loses that unsaved prize. This is not a crash-recovery ledger or online anti-cheat.

## Daily stock

- 00:00 UTC+7 boundary, matching check-in. First access on a new day saves one seed; planets derive stable offers from it. Restart, tab/map changes and purchases cannot reroll that day.
- Four eggs: Lv.1 plus three distinct random levels from Lv.2–10. Existing prices and hatch probabilities remain unchanged.
- Four chickens per planet: two fixed Tier-1 starters, plus one random Tier-2–4 offer per local lineage. Starters preserve onboarding and merge pairs.
- Direct chicken purchases give the pictured tier, normal rarity, fixed price `500 × 3^(tier−1)` Gold. Feed/Gem pouch remain permanent items. No quantity cap was introduced.
- Transactions validate displayed day, planet context, actual stock, wallet and farm capacity. Old-day quotes require review/retry. Failed save restores Gold, roster, discovery list, stats and ID counter.
- Optional validated `play_progress` section in v3 saves; JSON counters normalized to integers. Older saves remain compatible.

## Verification

- Battle economy follow-up: **62 checks, zero failures** at 360×640, 390×844 and 720×1280 (`tests/battle_economy_qa.gd`). Includes exact-five/zero balance, post-countdown recheck, cancellation, rematch, failed debit, failed prize save/retry, single payout, reload, and reward preview/popup layout. Result-button tests wait for the wall-clock opening guard before tapping.
- Focused polish/economy suite: 84 checks, zero failures at 360×640, 390×844 and 720×1280; daily stability, clock rollback, regeneration, stock, save rollback, header/footer placement, energy debit and movement interpolation.
- Shop regression: 664 checks, zero failures, including all five planets and actual GUI purchases/scrolling.
- Battle regression: 1815 checks, zero failures; seven headless gameplay groups also pass.
- Physical Android, subjective sound quality, frame pacing on low-end devices and final economy balance remain pending.
