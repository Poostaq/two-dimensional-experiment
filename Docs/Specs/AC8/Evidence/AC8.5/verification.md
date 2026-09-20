# AC8.5 verification — 2026-09-20

**Verdict: PASS for current-world AC8.5.** Implemented on `feat/ac8-5-town-recruitment`, based on `4f7c9ca`, in `6b21ec6` (rules) and `7e51140` (production flow, UI and tests).

AC8.5 acceptance proves the exact 500g price, town-clan recruit allowlist and production open/reopen flow, with one availability API and no-op close/cancel semantics. It does **not** confer whole-roster replacement or save-retry durability acceptance under AC8.6–AC8.8. Their supporting safety checks pass here; their full matrices remain pending.

## Automated gate

All three targeted suites have explicit PASS output, exit 0 and no script/runtime ERROR:

| Targeted suite | Final log |
|---|---|
| `Tests/Run/test_ac8_5_recruitment_rules.gd` | [rules gate](gate-test_ac8_5_recruitment_rules.log) |
| `Tests/WorldMap/test_ac8_town_recruitment.gd` | [integration gate](final-ui-test_ac8_town_recruitment.log) |
| `Tests/UI/test_ac8_5_town_recruitment_panel.gd` | [UI gate: 36 assertions](final-ui-test_ac8_5_town_recruitment_panel.log) |

[Gate results](gate-results.json) record all 21 passing targeted/regression runners. After the HUD placement correction, the four affected UI/runtime suites passed again in [final UI results](final-ui-results.json). Ten baseline runners passed before changes. Each gate log includes its exact command and process exit code. The [gate runner](run_gate.py) captures stdout/stderr, enforces an external 120-second timeout, and rejects missing PASS, nonzero exit and any ERROR output.

Reproduce from repository root:

```powershell
python Docs/Specs/AC8/Evidence/AC8.5/run_gate.py --prefix gate Run/test_ac8_5_recruitment_rules WorldMap/test_ac8_town_recruitment UI/test_ac8_5_town_recruitment_panel Run/test_ac8_economy Run/test_ac3_1_run_roster Run/test_ac3_3_party_formation UI/test_ac3_3_party_management UI/test_world_map_hud WorldMap/test_world_runtime_save_coordinator WorldMap/test_world_production_scene WorldMap/test_world_runtime_scene WorldMap/test_scout_recruitment_flow WorldMap/test_ac8_1_gold_runtime WorldMap/test_ac8_2_defeat_ends_run WorldMap/test_ac8_3_reward_presentation WorldMap/test_ac8_4_town_ownership WorldMap/test_ac8_4_town_ownership_reload WorldMap/test_ac8_4_world_debug_integration WorldMap/test_cleared_battle_hex_revisit Save/test_goblin_starter_save_migration Save/test_world_run_save_codec_v5
```

Coverage includes all seven existing towns, generic safe-cell rejection, unknown world versions, invalid coordinates, terminal/reward/battle/boss/ordinary encounter/unrelated party guards, matching placement revalidation, starter class aliases, nonrecruitable classes, 499/500/750g boundaries, chosen slots, duplicate/stale callbacks, replacement and detached save candidates. Close/cancel/dismissal preserve the full durable-state dictionary and write count; all-town checks preserve canonical plan bytes. Separate rule queries exclude roster classes without consulting HP.

Rules and production entry tests were observed failing before implementation: [rules red](rules-red.stdout.log), [town API red](red-town.log). The intermediate controller-first log records the expected missing UI resource before the panel was built; it is not a final passing gate. Rendered testing later detected minimap occlusion of the initial Recruit placement. The scene was corrected and the new overlap regression plus full rendered flows passed.

## Supporting restart checks

[Restart results](restart-results.json) record six separate processes: writer and reader for each of success, failed-save retry, and failed-save discard. All report explicit PASS, exit 0 and no ERROR. Readers restore the chosen slot, exact gold, recruit HP and eligibility; browsing does not rewrite the save or charge again. Failed writes leave live state unchanged; retry uses the exact candidate bytes, and discard invalidates stale placement callbacks.

The runner uses only `user://ac8-5-recruitment-verification.json`. Exact commands are in `restart-<writer|reader>-<success|retry|discard>.log`. It uses V5 with existing formation IDs; no save migration was added.

## Rendered interaction and visual evidence

Both production-launcher runs at 1280x720 and 1920x1080 pass with explicit PASS, exit 0 and no ERROR. See [rendered report](rendered-qa.md), [1280 log](rendered-1280.log), and [1920 log](rendered-1920.log).

Real input exercises Continue, Recruit, Close, class selection, Tab/Enter/Escape, Cancel Placement and dragging Scrapbroker into Slot 5. The purchase changes only gold from 500 to 0, the chosen slot and recruit HP; movement, boss and other durable state remain equal. A fresh launcher Continues and reopens without charging again. Pointer/wheel/keyboard modal input leaves camera position and zoom unchanged.

Twelve captures were inspected. The HUD Recruit control is unobstructed and clear of minimap/Debug; rich and poor town cards are contained and readable; placement shows all six slots, pending recruit and cancellation control. Empty-state captures are explicitly presentation fixtures, not claims about naturally exhausted roster eligibility. Representative captures: [HUD](rendered-hud-1280.png), [offers](rendered-rich-1280.png), [placement](rendered-placement-1920.png), [poor state](rendered-poor-1280.png), [Continue](rendered-continued-1920.png), [empty fixture](rendered-empty-fixture-1280.png).

## GodotIQ smoke and review

- GodotIQ play and `verify_project_runs(scene="main", check_scope="project")`: PASS. Runtime and script console buffers contain no errors.
- Disposable `user://ac8-5-bridge-verification.json` was injected into the production launcher for bridge checks. Continue restored the town with 500g and move count 0; actual Recruit click opened it and Escape closed it without charging or advancing moves. No normal active-run slot was replaced.
- Explore tour inspected the recruitment card: visible Goblin title, 500g wallet, four regular-class buttons and Close; no clipping. The 2D screenshots are presentation evidence, not 3D spatial validation.
- Initial game-context exec attempts used unsupported `get_tree()` and timed out; using the documented `Engine.get_main_loop()` resolved this. Input coordinates were transformed from the logical 1152x648 UI through the runtime stretch transform for the 1920x1080 window. The final actual button click succeeded with unchanged gold/moves. Game stopped after QA.
- Per-script context/validation/parser cycles completed. Project baseline: 218 scripts, 0 validation errors, 33 warnings, 5 informational findings. Final: 225 scripts/22 scenes, 0 validation errors, 35 warnings, 5 informational findings; the two additional warnings are standalone SceneTree tests lacking `class_name`. Project parser check: 225 scripts, 0 errors.
- Scoped signal maps show no orphans in controller, panel or HUD. The panel's `pressed` emission is flagged by the static missing-definition scan because it is the built-in `Button.pressed` signal, not a missing project signal; UI tests exercise it successfully.
- Independent spec and code-quality review approved rules, controller and UI, followed by final AC8.5 approval. The review-requested guard cases and rendered HUD-overlap regression are included.

## Acceptance limits

Intact/allied status is the explicit legacy v1 Goblin-town policy. Unsupported versions fail closed even if ownership support is added later. Generated clan ownership, alliance changes and actual destroyed-town service denial remain AC9/AC10 integration work. AC8.6–AC8.8 and full AC8.4 remain unchecked. No topology, campaign clock, commander content or historical battle-reward recruitment was changed.

The dedicated branch remains local; remote push/merge was not requested.
