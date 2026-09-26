param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,
    [string]$EvidencePath = "Docs/Specs/AC9/Evidence/AC9.0/automated-test.log"
)

$ErrorActionPreference = "Stop"
$tests = @(
    "Tests/Battle/test_ac9_0_shared_mechanics.gd",
    "Tests/Battle/test_ac9_0_boss_party_catalog.gd",
    "Tests/Battle/test_ac9_1_orcs_integration.gd",
    "Tests/Battle/test_ac9_2_lizardmen_integration.gd",
    "Tests/Battle/test_ac9_3_werewolves_integration.gd",
    "Tests/Battle/test_ac9_4_harpies_integration.gd",
    "Tests/Battle/test_ac9_5_humans_integration.gd",
    "Tests/Battle/test_ac9_6_elves_integration.gd",
    "Tests/Battle/test_ac9_7_dwarves_integration.gd",
    "Tests/Save/test_ac9_0_roster_identity_round_trip.gd",
    "Tests/Battle/test_ac6_1_combat_foundation.gd",
    "Tests/Battle/test_ac6_2_keyword_reactions.gd",
    "Tests/Battle/test_ac6_3_goblin_wave_a.gd",
    "Tests/Battle/test_ac6_4_goblin_wave_b.gd",
    "Tests/Battle/test_ac6_5_brakka.gd",
    "Tests/Battle/test_goblin_encounter_integration.gd",
    "Tests/Run/test_ac8_economy.gd",
    "Tests/Run/test_ac8_2_battle_settlement_rules.gd",
    "Tests/Run/test_ac8_2_run_settlement_state.gd",
    "Tests/Run/test_ac8_3_reward_acknowledgement.gd",
    "Tests/Run/test_ac8_5_recruitment_rules.gd",
    "Tests/Run/test_ac8_6_roster_eligibility.gd",
    "Tests/UI/test_ac8_gold_reward.gd",
    "Tests/UI/test_ac8_5_town_recruitment_panel.gd",
    "Tests/UI/test_ac8_6_party_dismissal.gd",
    "Tests/WorldMap/test_ac8_1_gold_runtime.gd",
    "Tests/WorldMap/test_ac8_2_victory_settlement.gd",
    "Tests/WorldMap/test_ac8_2_defeat_ends_run.gd",
    "Tests/WorldMap/test_ac8_3_reward_presentation.gd",
    "Tests/WorldMap/test_ac8_4_habitat_rules.gd",
    "Tests/WorldMap/test_ac8_4_town_ownership.gd",
    "Tests/WorldMap/test_ac8_4_world_debug_integration.gd",
    "Tests/WorldMap/test_ac8_town_recruitment.gd",
    "Tests/WorldMap/test_cleared_battle_hex_revisit.gd",
    "Tests/Run/test_world_run_start_service.gd",
    "Tests/Run/test_world_production_launcher.gd",
    "Tests/UI/test_world_run_start_scene.gd",
    "Tests/Save/test_world_run_save_codec_v5.gd"
)

$evidenceDirectory = Split-Path -Parent $EvidencePath
New-Item -ItemType Directory -Force $evidenceDirectory | Out-Null
$godotVersion = (& $GodotPath --version 2>&1) -join " "
Set-Content -LiteralPath $EvidencePath -Value @(
    "AC9.0 CI job: ac9-0-roster-readiness"
    "Expected pass condition: every runner exits 0 and output contains no SCRIPT ERROR or Parse Error."
    "Godot: $godotVersion"
    "Runner count: $($tests.Count)"
)

$failures = @()
foreach ($test in $tests) {
    $resourcePath = "res://$test"
    Write-Host "=== $test ==="
    Add-Content -LiteralPath $EvidencePath -Value ([Environment]::NewLine + "=== $test ===")
    $standardOutput = New-TemporaryFile
    $standardError = New-TemporaryFile
    $process = Start-Process -FilePath $GodotPath -ArgumentList @("--headless", "--path", ".", "--script", $resourcePath) -NoNewWindow -PassThru -Wait -RedirectStandardOutput $standardOutput.FullName -RedirectStandardError $standardError.FullName
    $exitCode = $process.ExitCode
    $output = @(
        Get-Content -LiteralPath $standardOutput.FullName
        Get-Content -LiteralPath $standardError.FullName
    )
    Remove-Item -LiteralPath $standardOutput.FullName, $standardError.FullName -Force
    $text = $output -join [Environment]::NewLine
    $output | ForEach-Object { Write-Host $_ }
    Add-Content -LiteralPath $EvidencePath -Value $text
    Add-Content -LiteralPath $EvidencePath -Value "EXIT CODE: $exitCode"
    if ($exitCode -ne 0 -or $text -match "SCRIPT ERROR|Parse Error") {
        $failures += $test
    }
}

Add-Content -LiteralPath $EvidencePath -Value ([Environment]::NewLine + "SUMMARY: $($tests.Count - $failures.Count)/$($tests.Count) runners passed.")
if ($failures.Count -gt 0) {
    Add-Content -LiteralPath $EvidencePath -Value "FAILED: $($failures -join ', ')"
    Write-Error "AC9.0 runner matrix failed: $($failures -join ', ')"
    exit 1
}

Add-Content -LiteralPath $EvidencePath -Value "RESULT: PASS"
Write-Host "AC9.0 runner matrix: PASS ($($tests.Count)/$($tests.Count))"
