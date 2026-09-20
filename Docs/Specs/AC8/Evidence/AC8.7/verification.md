# AC8.7 verification — 2026-09-20

**Verdict: PASS for AC8.7.** Verified on `feat/ac8-7-placement-safety`, based on `c567422`. The existing production implementation satisfies the complete placement/transaction matrix; this delivery adds tests and evidence without changing gameplay, pricing, save format or scenes. AC8.8 remains unchecked.

Final tested revision: `015c35d` (modal-input evidence). Earlier implementation/test commits: `54a6c36` (roster/UI), `209e9f5` (controller matrix), `4044412` (restart/rendered), `3739930` (review-driven assertion coverage). The subsequent acceptance commit adds documentation and captured evidence only.

## Acceptance matrix

| Requirement | Fresh evidence |
|---|---|
| Six-member limit | [Roster suite](gate-test_ac3_1_run_roster.log) rejects a seventh addition and preserves exact occupants; [1,000-check town suite](gate-test_ac8_town_recruitment.log) includes all six five-to-six boundary destinations |
| Chosen-slot placement/replacement | Town matrix tests six destinations in each mode at 0/499/500/750g, sparse holes, exact live formation/member count, wounded survivors and complete durable dictionaries; only gold, target and corresponding HP entries may change |
| Insufficient funds | Both modes reject 0/499g with no writes; 500g purchases leave 0g. Adversarial post-selection funds, town and blocking-state changes are revalidated at confirmation |
| Cancellation | UI/controller tests and actual Escape/Cancel input in both rendered runs preserve state and writes; refreshed selection remains usable |
| Invalid/stale requests | Invalid slots/IDs/modes, occupied targets, repeated selection, duplicate confirmation, old callbacks across cancellation/reopen/purchase/session replacement and stale eligibility reject without mutation |
| Failed saves | Add and replacement fail twice; immediate first/second failure preserves live identities, state, HP, HUD and successful checkpoint. Attempted bytes decode to the complete expected candidate; retries use identical bytes and publish the exact expected state once. Discard preserves original state and invalidates callbacks; a fresh purchase succeeds |
| Restart | [16 separate processes](restart-results.json) cover writer/reader pairs for add, replacement, failed add/replacement, retry and discard. Exact complete state restores; reopening town twice never charges or writes |
| Production interaction | [1280×720](rendered-1280.log) and [1920×1080](rendered-1920.log) pass actual launcher Continue, offer click, drag to slot 4, Escape/Cancel, Retry Save, Return to Launcher and Continue. Legal map-cell clicks, drag/wheel and held-key events preserve state/camera behind town, party and save-error modals |

## Automated reproduction

The [baseline](baseline-results.json) and [final gate](gate-results.json) each contain 14 passing suites. All final processes exit 0, print PASS, and contain no script/runtime ERROR. The wrappers reject a timeout, missing PASS or any ERROR even when Godot itself exits 0. The final town suite contains 1,000 checks, and the party UI suite contains 47 assertions.

Run from the repository root:

```powershell
python Docs/Specs/AC8/Evidence/AC8.7/run_gate.py --prefix gate Run/test_ac3_1_run_roster Run/test_ac3_3_party_formation UI/test_ac3_3_party_management Run/test_ac8_5_recruitment_rules Run/test_ac8_6_roster_eligibility UI/test_ac8_5_town_recruitment_panel UI/test_ac8_6_party_dismissal WorldMap/test_ac8_town_recruitment WorldMap/test_world_runtime_save_coordinator Save/test_world_run_save_codec_v5 WorldMap/test_ac3_5_recovery_integration WorldMap/test_ac8_2_victory_settlement WorldMap/test_ac8_2_defeat_ends_run WorldMap/test_ac8_3_reward_presentation
python Docs/Specs/AC8/Evidence/AC8.7/run_restart.py
python Docs/Specs/AC8/Evidence/AC8.7/run_rendered.py
```

Each log records its exact command. Restart tests write only `user://ac8-7-placement-<case>.json`; rendered tests use `user://ac8-7-rendered-<width>.json`. Readers/rendered runs remove their disposable files. Production save data is not used.

These are characterization passes, not a claimed red-to-green gameplay fix. Review strengthened tests that could previously miss wrong-mode calls, five-to-six capacity, incorrect live publication or incorrect staged bytes. No production defect was reproduced.

## Inspected captures

All 26 captures were inspected at both resolutions. Buttons, instructions, slot targets and wallet values are readable without clipping.

| State | Observation | 1280×720 | 1920×1080 |
|---|---|---|---|
| Insufficient funds | 499g; disabled 500g offers; Close usable | [image](rendered-insufficient-1280.png) | [image](rendered-insufficient-1920.png) |
| Placement preview | Sparse slots and Cancel Placement visible | [image](rendered-placement-1280.png) | [image](rendered-placement-1920.png) |
| Placement cancelled | Original offers and 500g restored | [image](rendered-placement-cancelled-1280.png) | [image](rendered-placement-cancelled-1920.png) |
| Placement failed | Original formation behind readable Retry/Return/Copy overlay | [image](rendered-placement-failed-1280.png) | [image](rendered-placement-failed-1920.png) |
| Placement retry | 0g, Scrapbroker in chosen back-middle HUD position | [image](rendered-placement-retry-1280.png) | [image](rendered-placement-retry-1920.png) |
| Placement Continue | Slot 4 contains Scrapbroker; other holes preserved | [image](rendered-placement-continued-1280.png) | [image](rendered-placement-continued-1920.png) |
| Placement discard/Continue | Original sparse formation and 500g | [image](rendered-placement-discard-continued-1280.png) | [image](rendered-placement-discard-continued-1920.png) |
| Replacement preview | Six targets; replacement instruction and cancellation visible | [image](rendered-replacement-1280.png) | [image](rendered-replacement-1920.png) |
| Replacement cancelled | Champion retained, 500g, Scrapbroker available | [image](rendered-replacement-cancelled-1280.png) | [image](rendered-replacement-cancelled-1920.png) |
| Replacement failed | Champion retained behind readable failure overlay | [image](rendered-replacement-failed-1280.png) | [image](rendered-replacement-failed-1920.png) |
| Replacement retry | 0g; Scrapbroker replaces Champion in HUD | [image](rendered-replacement-retry-1280.png) | [image](rendered-replacement-retry-1920.png) |
| Replacement Continue | Six members; Scrapbroker in slot 4 | [image](rendered-replacement-continued-1280.png) | [image](rendered-replacement-continued-1920.png) |
| Replacement discard/Continue | Original Champion, six members and 500g restored | [image](rendered-replacement-discard-continued-1280.png) | [image](rendered-replacement-discard-continued-1920.png) |

Existing presentation limits: party cards display maximum HP rather than the fixture's damaged current HP, pending recruit displays `Slot -1`, and save-error diagnostics have a compressed text area. These do not prevent recruitment or error recovery; surviving HP preservation is proven by state assertions, not inferred from screenshots.

During harness development, a map-isolation probe hit a legitimate offer button. The final helper chooses a legal underlying map-cell center outside visible buttons. One subsequent 1280 drag did not reach the commit; a standalone rerun passed, and the final helper waits for a drawn layout and explicitly verifies drag initiation and release. The final consolidated run passes both resolutions. These test-harness failures are not presented as fixed gameplay defects.

## GodotIQ and review

- Main-scene play, `verify_project_runs(check_scope="project")`, console inspection and runtime state attachment: PASS. Launcher smoke captured zero new runtime/script errors; game stopped afterward. Existing historical `SkillEffectPlan` console entries were cleared before this fresh smoke.
- [Final project checks](godotiq-checks.json): 231 scripts and 22 scenes, zero validation/parser errors. Baseline 229 scripts/22 scenes had the same 36 warnings and 5 informational findings. No new convention warnings.
- Controller and party scoped signal maps have no orphans. Static scanning reports built-in `Button.pressed` as missing a project definition; actual UI input tests pass.
- Independent spec/quality reviews approved roster/UI/controller coverage after the assertion improvements. Restart/rendered review checks separate-process state, real input and original screenshots.

## Acceptance boundary

This accepts AC8.7 against the current legacy-v1 Goblin-town implementation. AC8.8's cross-flow durability and actual burned-town rejection remain separate. No scene or gameplay script changed; no new schema, transaction ledger, habitat generation, dismissal policy or economy behavior was introduced. Work is committed on the task branch; push/merge was not requested.
