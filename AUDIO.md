# Game audio and settings

Implemented 2026-10-04 in the active `Game.tscn` / `App.gd` runtime.

## Player controls

- Gear button at the upper right, beside Help, on Farm, Collection, team selection and Shop. The normal HUD stays hidden during fullscreen combat.
- Cream/wood-colour blocking Settings modal with Baloo typography, separate Music and Sound Effects sliders, global mute, Test Sound, How to Play and Done. Escape / Android back close the modal (Android hardware acceptance pending).
- Preferences stored separately from game progression in `user://audio_settings.cfg`. Values clamp to 0–100%; malformed values fall back safely. Slider saves are debounced and also flushed on close / background notifications.
- Settings cannot open over an existing modal, tutorial or active UFO raid. Map, tabs, eggs and drag handlers respect the settings blocker. No reset/delete-save action is included.

## Sound pack

`assets/audio/` contains 26 WAV files, approximately 3.22 MB total:

- Three original procedural instrumental loops, softened on 2026-10-05: Farm (84 BPM, sparse warm plucks), Battle (108 BPM) and UFO raid (116 BPM, minor motif). Lead/SFX shifted down an octave, higher harmonics reduced, slower attack/release and quieter percussion; Farm has no noise hi-hat.
- Twenty-three short synthesized cues: UI, egg drop/hatch, merge, success/failure, rewards, countdown, victory/defeat, warning/cannon, seven elemental motifs and generic energy.
- Generated from the repository's own notes/synthesis code, not downloaded recordings or third-party music. Generator: `tools/generate_game_audio.gd`; run with Godot `--headless --path . --script res://tools/generate_game_audio.gd`. Generated WAVs are included: generation is **not** performed on game launch.
- Mono 22.05 kHz PCM; `.wav.import` keeps compression off for predictable short assets and loop QA. Runtime loop frame count uses duration × sample rate.

`Audio` autoload creates Music/SFX buses without changing Master. Two players crossfade music; eight pooled SFX players cap concurrent sounds. Repeated cannon/egg cues and skill bursts have cooldowns. UI buttons connect automatically; result, egg, merge, purchase, upgrade, reward and battle/raid hooks live in their presentation controllers. Income ticks are intentionally silent.

Focus loss/background pauses music and stops transient voices; resume restores the chosen volume/mute state. Music switches only after screen navigation succeeds and returns to Farm after raids. No network or external service is needed.

## Verification / remaining work

- `tests/audio_settings_qa.gd`: three phone aspect ratios, actual GUI hit-testing, both sliders, mute, preview, Done/Escape, blocked background navigation, shop entry, save/reload, invalid config, waveform data/clipping/loop seams, voice cap, routing and suspend/resume.
- Report: `qa/audio-settings-report.json`; screenshots: `qa/screens/modal_settings_popup_*.png` and `modal_settings_hud_*.png`.
- Seven existing headless gameplay regression groups passed after audio integration. The settings test is also registered under `tools/run_regression.ps1 -Visual`.
- Latest desktop run: audio/settings **170 checks, 0 failures**; Battle visual regression **1815 checks, 0 failures**. Battle QA still logs the pre-existing TutorialController anchor warning; this is not an audio parser error.
- Desktop QA uses the Dummy audio driver. It validates data/playback state, **not subjective listening quality or a real Android speaker/headphones**. Listen and tune mix/loop repetition on devices before release.
- This is an initial synthesized sound pack, not bespoke recordings for all 100 chickens. Separate music for all five planets, individual basic-hit sounds, advanced music ducking, haptics, language selection and production audio mastering remain out of scope for this pass.
