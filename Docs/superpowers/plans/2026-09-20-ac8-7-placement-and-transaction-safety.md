# AC8.7 Placement and Transaction Safety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Follow GodotIQ inspection and validation workflows. Use a dedicated branch in the primary workspace; never a worktree. Steps use checkboxes for tracking.

**Goal:** Complete AC8.7 by proving six-member capacity, exact chosen-slot placement/replacement, and unchanged wallet/roster on insufficient funds, cancellation, invalid/stale input and failed saves.

**Architecture:** Retain `RunRoster` slot validation, `PartyManagement` intent signals, and controller-owned town selection. Build a detached roster/state candidate, revalidate live town eligibility and funds, then persist through `WorldRuntimeSaveCoordinator` before publishing wallet and roster together. Expand acceptance tests first; change production behavior only for a reproduced failure.

**Tech Stack:** Godot 4, typed GDScript, authored Control scenes, standalone SceneTree runners, existing V5 saves, GodotIQ.

**Status:** Implemented and verified on 2026-09-20 on `feat/ac8-7-placement-safety`, based on `c567422`; final tested revision `015c35d`. [Acceptance evidence](../../Specs/AC8/Evidence/AC8.7/verification.md): 14 regression suites, 1,000 controller checks, 16 restart processes and two rendered runs. The existing implementation passed; changes are tests and evidence only. AC8.8 remains pending.

## Requirements and scope

Sources: [MVP AC8.7](../../Specs/GAME_DESIGN_SPEC_MVP.md), [AC8 parent plan](2026-09-18-ac8-town-recruitment-and-gold.md), [AC8.6 plan](2026-09-20-ac8-6-whole-roster-eligibility.md), [AC8.6 evidence](../../Specs/AC8/Evidence/AC8.6/verification.md).

1. Formation always has six slots and at most six occupied members. With room, recruit into the chosen empty slot, preserving holes and every other occupant. At capacity, replace exactly the chosen member after checking their captured character ID. Never auto-fill a different slot, compact formation, or append a seventh member.
2. Selection and placement preview perform no save or charge. Commit costs exactly 500g; 500g becomes 0g. Preserve every unrelated run-state field and surviving member's HP. New recruit HP starts at its maximum; replacement removes only the displaced member's HP entry.
3. Insufficient funds, invalid destination/recruit/target, class already present, obsolete panel/session/generation and cancellation leave live roster, wallet and durable checkpoint unchanged, with zero write attempts.
4. Commit rechecks current town/availability, class absence and funds. Selection-time validation alone is insufficient. Existing full-roster replacement must not bypass canonical class eligibility.
5. A failed write leaves both live and durable state unchanged and blocks further actions. Retry uses identical staged bytes and publishes once. Discard keeps the original state and invalidates abandoned callbacks. Ordinary Cancel while a save is pending cannot silently discard it.
6. Recruitment and cancellation consume no world move. Town/party/error surfaces retain input isolation; map interaction resumes only after the relevant modal closes.

AC8.8 retains the comprehensive cross-flow wallet/reward/recruitment durability matrix and burned-town UI/domain acceptance. AC8.7 includes targeted retry/reload checks needed to prove its own failed-save guarantee, but does not mark AC8.8 complete. No new save version, economy policy, replacement confirmation dialog, generated habitat, town destruction, standalone dismissal policy or broad controller refactor is planned.

## Approach and existing implementation

Recommended: characterize existing paths and repair demonstrated gaps. Rebuilding a recruitment service would duplicate working transaction ownership; introducing a new persisted purchase ledger would expand into AC8.8 without evidence that AC8.7 needs one.

Inspected implementation:

- `RunRoster.try_add_at()` rejects occupied/out-of-range slots and full rosters. `try_replace_at()` requires capacity, a matching target ID and a nonduplicate recruit. `get_slot_snapshot()` creates a separate slot array, but shares character objects: the transaction must not mutate those objects.
- `request_town_recruitment()` captures coordinate/class/recruit and binds session, town generation and source panel to callbacks. It selects placement or replacement mode based on capacity.
- `_on_town_add()` / `_on_town_replace()` mutate a detached candidate. `_commit_town_purchase()` rechecks availability, coordinate, eligibility and funds, builds the state and deducts 500g on the candidate only.
- `_publish_town_purchase()` installs roster and state together. `_finish_town_placement()` rotates generation and refreshes offers. Save coordinator clears its blocked flag before calling publication, allowing `_valid_town_selection()` to succeed on retry.
- Existing town tests cover 499/500/750g, add to slot 5, basic cancellation, one replacement target, add-save retry/discard and stale eligibility. AC8.6 evidence explicitly leaves the complete AC8.7 matrix pending.

## File responsibilities

| Action | Path | Responsibility |
|---|---|---|
| Extend | `Tests/WorldMap/test_ac8_town_recruitment.gd` | Capacity, all destinations, invalid/stale intents, add/replacement rollback and revalidation; reuse `Repository`, `_session`, `_open`, `_expect` |
| Extend | `Tests/Run/test_ac3_1_run_roster.gd` | Direct add/replace capacity and exact-slot invariants |
| Extend | `Tests/UI/test_ac3_3_party_management.gd` | Placement/replacement mode, cancel, wrong-mode and stale-target intents |
| Inspect; change only for failing regression | `Scripts/Run/run_roster.gd` | Slot/capacity primitives |
| Inspect; change only for failing regression | `Scripts/WorldMap/world_runtime_controller.gd` | Selection guards, candidate commit, publication and cancellation |
| Inspect; change only for failing regression | `Scripts/Party/party_management.gd` | Input and intent lifecycle |
| Inspect; change only for failing regression | `Scripts/WorldMap/world_runtime_save_coordinator.gd` | Frozen retry candidate and publication ordering |
| Inspect; change only for demonstrated UI defect | `Scenes/party_management.tscn` | Existing authored placement/replacement surface |
| Create | `Tests/Run/test_ac8_7_placement_restart.gd` | Separate-process add/replacement/retry/discard checkpoint verification |
| Create | `Tests/WorldMap/capture_ac8_7_placement.gd` | Production-launcher pointer/keyboard verification using disposable saves |
| Create | `Docs/Specs/AC8/Evidence/AC8.7/.gdignore`, `run_gate.py`, `verification.md` | Isolated logs, commands, inspected captures and acceptance matrix |
| Update after passing gates | `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`, `Docs/superpowers/plans/2026-09-18-ac8-town-recruitment-and-gold.md`, this plan | Scoped AC8.7 status and evidence links |

## Task 1: Prepare branch and baseline

- [x] Record status and HEAD. Preserve unrelated edits, fetch origin, update `main` with fast-forward only, then create `feat/ac8-7-placement-safety`. Follow repository stash/restore rules; never reset divergent history or use a worktree. Preserve this planning file if uncommitted.

```powershell
git status --short --branch
git fetch origin
git switch main
git pull --ff-only origin main
git switch -c feat/ac8-7-placement-safety
```

- [x] Call GodotIQ project summary and project validation. Inspect each target with `file_context(detail="brief")`, then `script_ops(op="read")`; use `impact_check` before API/signal changes and dependency/signal tools for wiring. Record baseline warnings separately.
- [x] Create the AC8.7 evidence directory with `.gdignore`; copy AC8.6's `run_gate.py` unchanged initially. Its project-root calculation works at the same directory depth. Run the existing regression command in Task 7 before editing gameplay code.
- [x] Record characterization passes as passes. Only require a red test when a new assertion exposes a real defect; do not alter working behavior merely to force a failure.

## Task 2: Cover six slots and capacity

- [x] Extend the direct roster tests with sparse formations, all six destination indices, invalid indices -1/6, occupied destinations, duplicate recruit IDs, add-at-capacity, replace-below-capacity and wrong replacement target. Assert full slot identity snapshots, not just `size()`.
- [x] Parameterize controller add cases over destination 0 through 5. Build a valid session with that slot empty and other members in noncontiguous slots. Use typed six-slot arrays: an empty `RunRoster.new()` creates starters, not an empty party. Decode each fixture through `world_run_state.gd.from_dictionary()` and require success.
- [x] Parameterize full-roster replacement over destination 0 through 5. Reuse the existing valid legacy fixture `[player_0, player_1, player_2, scout, champion, shivrunner]` and purchase absent Scrapbroker. Resolve Scout/Champion through the existing reward catalog methods as `_replacement_case()` does. Six regular Goblin classes would have zero offers and cannot serve as a purchasable full-roster fixture.
- [x] For each success, compare the entire state against exactly these permitted changes, using the existing integration harness variables:

```gdscript
var before: Dictionary = world.get_durable_run_state().to_dictionary()
var expected: Dictionary = before.duplicate(true)
var previous_id: String = String(expected.formation[slot])
expected.gold = int(before.gold) - RunEconomyRules.RECRUITMENT_COST
expected.formation[slot] = "scrapbroker"
if not previous_id.is_empty():
    expected.character_hp.erase(previous_id)
expected.character_hp["scrapbroker"] = RunCharacterCatalog.create_by_class_id(&"scrapbroker").max_hp
var party: PartyManagement = world.get("_active_party")
if previous_id.is_empty():
    party.request_placement(slot, &"scrapbroker")
else:
    party.request_replacement(slot, StringName(previous_id), &"scrapbroker")
_expect(world.get_durable_run_state().to_dictionary() == expected, "only chosen slot, HP and gold change")
_expect((world.get("_roster") as RunRoster).get_slot_snapshot().size() == 6, "six fixed slots")
_expect(repo.writes.size() == 1, "one purchase write")
```

- [x] Verify survivors with deliberately reduced positive HP retain those values. Verify formation/gold in decoded written bytes match live publication; add with five members becomes exactly six.
- [x] Validate/check each changed script individually, run roster/formation/town suites, then commit `test: cover AC8.7 chosen slots and capacity` (include a targeted production fix only if required by a failing test).

## Task 3: Complete cancellation and stale-input matrix

- [x] For both placement and replacement, capture live slot IDs, HP, durable dictionary and write-attempt count before selection. Selection, cancel button, Escape, repeated cancel and close callbacks must leave all four unchanged. Reopen and make a fresh purchase successfully, proving cancellation does not poison the next selection.
- [x] Assert `PartyManagement.request_close()` remains unavailable in placement/replacement; their cancel action returns to the town. Injecting the controller-bound `close_requested` signal may cancel, but never commit.
- [x] Exercise invalid indices -1/6, occupied add slot, wrong recruit ID, wrong replacement target, add signal against a full roster and replacement signal against a nonfull roster. Test public UI methods and directly emitted intents so UI checks cannot hide missing domain checks.
- [x] Retain old callback Callables before cancel/reopen, successful purchase and `apply_session()`. Invoke those captured callbacks with the original arguments after the transition; no write or state change is allowed. Do not emit against a freed Node after a frame. Also deliver duplicate confirmation synchronously before queued deletion and verify one write/charge.
- [x] Assert repeated offer requests while placement is open do not change the selected recruit or open a second party. Wrong-mode rearrangement/dismissal cannot mutate the transaction roster.
- [x] Run party/town tests, fix only reproduced guard/lifecycle defects with a focused red-to-green regression, validate/check each modified script, then commit `test: verify recruitment cancellation and stale intents`.

## Task 4: Verify commit-time funds and availability

- [x] Run gold 0, 499, 500 and 750 for add and replacement. Low balances reject with `insufficient_gold` and zero writes; exact price succeeds with 0g. Full roster alone must not reject an otherwise eligible replacement.
- [x] After selecting at 500g, use an explicitly labelled adversarial fixture to lower the controller's current state balance to 499g before the placement intent. Snapshot after fixture mutation; assert rejection does not alter that state or live roster and attempts no save. This tests revalidation, not a supported concurrent gameplay path.
- [x] Separately change selected town context or activate a service-blocking state after selection. Commit must reject unchanged. Retain the AC8.6 stale-class tests for both add and replacement, including trying to replace the existing representative of the requested class.
- [x] Keep all mutation authority in `_commit_town_purchase()`: current availability/coordinate -> `purchase_error()` against live roster and gold -> candidate validity -> coordinator commit -> publication. If a new test fails, patch the failed guard at its existing owner; do not duplicate pricing or eligibility in the panel.
- [x] Validate/check changed scripts and run town/rules/panel suites; commit `test: verify recruitment commit-time revalidation`.

## Task 5: Prove failed-save rollback for add and replacement

- [x] Extend the fake repository to distinguish write attempts from successfully stored bytes. Add a successful-checkpoint field updated only after a successful `replace_atomic`; preserve `writes` as the attempt log used by existing tests. Seed the successful bytes from the pre-purchase V5 checkpoint without counting a purchase attempt.
- [x] Generalize `_retry_case()` to cover add and full replacement independently, with retry and discard branches. Assert original roster reference, character identities/HP, durable dictionary, HUD gold and successful repository bytes remain unchanged after failure. Attempted candidate bytes must contain the complete post-purchase roster and gold, never a partial update.
- [x] Fail twice before success: after each failed attempt all live/checkpoint assertions remain unchanged. Every attempted byte array must equal the first. After success, compare the entire expected dictionary from Task 2, exact destination, exact 500g deduction and refreshed offers. Another retry/old placement intent makes no write.
- [x] While blocked, attempt purchase, add/replacement callback, cancel, town close, normal party/dismissal and map movement. They must neither publish nor replace the pending candidate. Verify session replacement cannot orphan an outstanding purchase; inspect existing `apply_session()` behavior before constructing that assertion.
- [x] Discard: unchanged checkpoint/roster/gold, no recruit, no charge, pending placement removed, old callbacks invalid and retry unavailable. Freshly open the town and complete a new selection to prove recovery.
- [x] If rollback fails, fix only the existing candidate/publication boundary responsible. Never mutate live roster then attempt to undo it; never recompute a pending purchase from current UI state during retry. Validate/check per file, run town and save-coordinator suites, then commit `test: prove add and replacement save rollback`.

## Task 6: Independent restart and rendered input

- [x] Create `test_ac8_7_placement_restart.gd` using the AC8.5/AC8.6 restart runner's repository/path isolation pattern. Define writer/reader modes for `add`, `replace`, `failed_add`, `failed_replace`, `retry_add`, `retry_replace`, `discard_add`, `discard_replace`. Each reader runs in a fresh process against the writer's disposable save.
- [x] Successful/retried readers require the exact purchased slot, six-slot formation, expected HP and one 500g deduction. Failed/discard readers require the original formation, HP and gold. Persist a baseline checkpoint before injecting failure. Reopening town after Continue must not write or charge. Failed in-memory UI intents are not required to resume after application exit.
- [x] Create `capture_ac8_7_placement.gd` by adapting the production launcher/input harness in `capture_ac8_6_eligibility.gd`. Use disposable fixtures with 499g, 500g, sparse formation and the eligible full legacy roster. At 1280x720 and 1920x1080 exercise actual offer click, drag to a nondefault empty slot, replacement drag, Cancel/Escape, error-overlay retry/discard and fresh-launcher Continue.
- [x] Verify disabled unaffordable offers, exact wallet display, unchanged target after cancellation/failure, exact chosen target after success, visible cancellation/error controls, and keyboard/wheel/pointer isolation from the map. Signal emission alone is not rendered input evidence. Capture each distinct state once per resolution and inspect every image for clipping/readability.
- [x] Run GodotIQ `run(play)` -> `verify_project_runs()` -> console -> state inspection -> required visual capture -> `run(stop)`. Use `explore(mode="tour")` after any scene change, describe findings and correct demonstrated defects.
- [x] Commit new restart/rendered runners and necessary UIDs as `test: verify AC8.7 restart and production input`.

## Task 7: Regression gate and acceptance record

Run the existing suites before implementation and again after the final change using the copied evidence gate:

```powershell
python Docs/Specs/AC8/Evidence/AC8.7/run_gate.py --prefix gate Run/test_ac3_1_run_roster Run/test_ac3_3_party_formation UI/test_ac3_3_party_management Run/test_ac8_5_recruitment_rules Run/test_ac8_6_roster_eligibility UI/test_ac8_5_town_recruitment_panel UI/test_ac8_6_party_dismissal WorldMap/test_ac8_town_recruitment WorldMap/test_world_runtime_save_coordinator Save/test_world_run_save_codec_v5 WorldMap/test_ac3_5_recovery_integration WorldMap/test_ac8_2_victory_settlement WorldMap/test_ac8_2_defeat_ends_run WorldMap/test_ac8_3_reward_presentation
```

For the baseline, replace `--prefix gate` with `--prefix baseline`. Expected: every named runner exits 0, prints its PASS marker and contains no script/runtime ERROR; the wrapper exits 0. A timeout or a missing PASS is failure, even if Godot exits 0. Run the separate-process matrix with its explicit modes and record every exact command; the generic gate does not supply restart-mode arguments. Run rendered captures with the harness's resolution arguments and `--rendered` where applicable.

- [x] Complete final project validation, parser/error checks and orphan-signal inspection. Distinguish pre-existing warnings and static built-in-signal false positives from actual regressions.
- [x] Record the tested implementation revision, baseline/final commands/results, any red-to-green fixes, independent restart logs, actual-input observations, inspected screenshots and tool limitations in `Docs/Specs/AC8/Evidence/AC8.7/verification.md`.
- [x] Use this acceptance table; no row can be inferred solely from AC8.5/AC8.6 historical evidence:

| AC8.7 obligation | Required fresh evidence |
|---|---|
| Six-member limit | Primitive rejection of seventh add; five-to-six success; replacement remains six |
| Chosen placement/replacement | All six destination indices; unchanged other slots/HP; written bytes and Continue agree |
| Insufficient funds | 0/499 rejection and 500 success for both modes; funds rechecked at commit |
| Cancellation | Button/Escape and stale callbacks; no write, charge, roster change or world move |
| Invalid/stale requests | Bad indices/IDs/modes; old generation/panel/session; duplicates; changed class/town/context |
| Failed saves | Add and replacement; repeated failure, exact-byte retry and discard; unchanged live/durable state until success |
| Usable production flow | Actual pointer/keyboard at both resolutions; readable controls; map input isolated |

- [x] Mark only AC8.7 complete after every row passes; keep AC8.8 unchecked. Update the MVP, parent AC8 plan and this plan with the evidence link. Commit only relevant files as `test: record AC8.7 placement acceptance`; restore unrelated edits unstaged. Push only on user request.

## Planning review

The plan covers each clause of AC8.7 and retains its existing six-slot/500g contract. The code inspection establishes existing behavior and coverage gaps, not fresh test success. Production changes are conditional on reproduced failures; a tests-and-evidence-only implementation is valid if the complete matrix already passes. AC8.8 and generated/burned-town integration remain separate.

## Execution notes

All acceptance gates passed. The approved tests-and-evidence-only outcome applied: no gameplay/scene fixes were needed. Independent review strengthened wrong-mode assertions, the five-to-six boundary, live-roster publication, decoded retry bytes and actual map input isolation. Related task commits were grouped by file ownership rather than creating an empty production commit for each passing characterization step. Full details and existing presentation limitations are in the acceptance evidence.
