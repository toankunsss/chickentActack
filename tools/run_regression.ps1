param(
    [string]$Godot,
    [switch]$Visual
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
    $installed = Get-Command godot -ErrorAction SilentlyContinue
    if ($installed) { $Godot = $installed.Source }
}
if (-not $Godot) {
    $running = Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Godot*.exe' -and $_.ExecutablePath } | Select-Object -First 1
    if ($running) {
        $consolePath = $running.ExecutablePath -replace '\.exe$', '_console.exe'
        $Godot = if (Test-Path -LiteralPath $consolePath) { $consolePath } else { $running.ExecutablePath }
    }
}
if (-not $Godot -or -not (Test-Path -LiteralPath $Godot)) {
    throw 'Pass -Godot with the path to the Godot 4 console executable.'
}
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'qa') -Force | Out-Null
function Invoke-GameCheck([string]$Name, [string[]]$Extra, [string]$Marker, [switch]$Windowed) {
    $log = Join-Path $projectRoot "qa/$Name.log"
    $arguments = @('--path', $projectRoot, '--log-file', $log, '--quit-after', '3000') + $Extra
    # Start-Process provides a reliable native ExitCode in hosts where invoking
    # Godot directly leaves $LASTEXITCODE unset.
    $quoted = $arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }
    $process = Start-Process -FilePath $Godot -ArgumentList $quoted -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(60000)) { throw "$Name did not finish within 60 seconds (PID $($process.Id))." }
    $exitCode = $process.ExitCode
    $output = Get-Content -LiteralPath $log -Raw
    if ($exitCode -ne 0 -or $output -notmatch [regex]::Escape($Marker) -or $output -match '(?m)^(SCRIPT ERROR:|ERROR:)|Assertion failed') {
        throw "$Name failed. See $log"
    }
    Write-Host "$Name PASS"
}
Invoke-GameCheck 'farm-smoke' @('--headless', '--script', 'res://tests/save_map_regression.gd', '--', '--farm-smoke') 'FARM_SYSTEM_SMOKE_OK'
Invoke-GameCheck 'tutorial-progress-regression' @('--headless', '--script', 'res://tests/tutorial_progress_regression.gd') 'TUTORIAL_PROGRESS_REGRESSION_OK'
Invoke-GameCheck 'save-map-regression' @('--headless', '--script', 'res://tests/save_map_regression.gd') 'SAVE_MAP_REGRESSION_OK'
Invoke-GameCheck 'map-drag-regression' @('--headless', '--script', 'res://tests/map_drag_regression.gd') 'MAP_DRAG_REGRESSION_OK'
Invoke-GameCheck 'fusion-regression' @('--headless', '--script', 'res://tests/fusion_regression.gd') 'FUSION_REGRESSION_OK'
Invoke-GameCheck 'battle-skill-regression' @('--headless', '--script', 'res://tests/battle_skill_regression.gd') 'BATTLE_SKILL_REGRESSION_OK'
Invoke-GameCheck 'rewards-regression' @('--headless', '--script', 'res://tests/rewards_regression.gd') 'REWARDS_REGRESSION_OK'
if ($Visual) {
	Invoke-GameCheck 'battle-economy' @('--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--max-fps', '60', '--resolution', '720x1280', '--script', 'res://tests/battle_economy_qa.gd') 'BATTLE_ECONOMY_QA_OK' -Windowed
	Invoke-GameCheck 'daily-battle-polish' @('--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--max-fps', '60', '--resolution', '720x1280', '--script', 'res://tests/daily_battle_polish_qa.gd') 'DAILY_BATTLE_POLISH_QA_OK' -Windowed
	Invoke-GameCheck 'audio-settings' @('--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--max-fps', '60', '--resolution', '720x1280', '--script', 'res://tests/audio_settings_qa.gd') 'AUDIO_SETTINGS_QA_OK' -Windowed
    Invoke-GameCheck 'rewards-visual' @('--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--max-fps', '60', '--resolution', '720x1280', '--script', 'res://tests/rewards_visual_qa.gd') 'REWARDS_VISUAL_QA_OK' -Windowed
    Invoke-GameCheck 'tutorial-onboarding' @('--headless', '--script', 'res://tests/tutorial_onboarding_qa.gd') 'TUTORIAL_ONBOARDING_QA_OK'
    Invoke-GameCheck 'egg-upgrade-visual' @('--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--max-fps', '60', '--resolution', '720x1280', '--script', 'res://tests/egg_upgrade_visual_qa.gd') 'EGG_UPGRADE_VISUAL_QA_OK' -Windowed
    Invoke-GameCheck 'modal-visual' @('--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--max-fps', '60', '--resolution', '720x1280', '--script', 'res://tests/modal_visual_qa.gd') 'MODAL_VISUAL_QA_OK' -Windowed
    Invoke-GameCheck 'raid-visual' @('--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--max-fps', '60', '--resolution', '720x1280', '--script', 'res://tests/raid_visual_qa.gd') 'RAID_VISUAL_QA_OK' -Windowed
    Invoke-GameCheck 'fusion-layout' @('--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--max-fps', '60', '--resolution', '720x1280', '--script', 'res://tests/fusion_layout_qa.gd') 'FUSION_LAYOUT_QA_OK' -Windowed
    Invoke-GameCheck 'fusion-outcome' @('--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--max-fps', '60', '--resolution', '720x1280', '--script', 'res://tests/fusion_outcome_visual_qa.gd') 'FUSION_OUTCOME_QA_OK' -Windowed
    Invoke-GameCheck 'shop-visual' @('--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--max-fps', '60', '--resolution', '720x1280', '--script', 'res://tests/shop_visual_qa.gd') 'SHOP_VISUAL_QA_OK' -Windowed
    Invoke-GameCheck 'shop-redesign' @('--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--max-fps', '60', '--resolution', '720x1280', '--script', 'res://tests/shop_redesign_qa.gd') 'SHOP_REDESIGN_QA_OK' -Windowed
    Invoke-GameCheck 'battle-visual' @('--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--max-fps', '60', '--resolution', '720x1280', '--script', 'res://tests/battle_visual_qa.gd') 'BATTLE_VISUAL_QA_OK' -Windowed
}
