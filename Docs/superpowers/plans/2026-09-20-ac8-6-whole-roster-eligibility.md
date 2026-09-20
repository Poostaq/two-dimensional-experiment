# AC8.6 Whole-Roster Recruitment Eligibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkboxes for tracking. Follow GodotIQ workflows and use a dedicated branch in the primary workspace; never a worktree.

**Goal:** Prove and complete base AC8.6 whole-roster town eligibility, refresh after roster changes/reload, empty offers and stale-request rejection; additionally deliver the user-requested minimal standalone dismissal extension.

**Architecture:** Keep `TownRecruitmentRules` as the pure eligibility authority and `WorldRuntimeController.get_town_recruitment_context()` as the service authority. Add removal to `RunRoster` and a minimal dismissal intent to normal `PartyManagement`; the controller persists a detached candidate through the existing save coordinator before publishing it. Derive offers from the current roster rather than storing an offer list.

**Tech Stack:** Godot 4, typed GDScript, authored Control scenes, standalone SceneTree runners, V5 saves, GodotIQ.

**Status:** Implemented and verified on 2026-09-20 on `feat/ac8-6-roster-eligibility`, based on `776c0ef`. Base AC8.6 and the separately requested D1 dismissal extension pass; see [verification evidence](../../Specs/AC8/Evidence/AC8.6/verification.md). Runtime changes are committed in `dfc8c2d`, `a8538c0`, `06da651` and `540c0f9`.

---

## Base AC8.6 contract

Sources: [MVP AC8.6](../../Specs/GAME_DESIGN_SPEC_MVP.md), [parent AC8 plan](2026-09-18-ac8-town-recruitment-and-gold.md), [AC8.5 plan](2026-09-20-ac8-5-town-recruitment.md), [AC8.5 evidence](../../Specs/AC8/Evidence/AC8.5/verification.md).

Base AC8.6 requires eligibility to refresh when members leave through dismissal/replacement. It does not independently require creating a standalone dismiss-member command, confirmation dialog or minimum-party/refund policy. Those are the **user-requested extension** included in this delivery. Keep base-criterion evidence and extension evidence separately identified, including when one test covers both.

1. Eligible classes equal the town clan's recruitable classes minus canonical `class_id` values of **every** roster member. Slot, character instance ID, HP and battle activity cannot alter membership. Preserve catalog ordering.
2. A class remains excluded while any member has that class. Removing its last member makes it eligible. Starter aliases (`player_0..2`) and their canonical regular-class identities must behave identically.
3. Refresh after committed recruitment, dismissal or replacement. Continue reconstructs class identity and derives offers again. No offers are serialized. The extension below supplies a new standalone dismissal path for exercising this existing eligibility obligation.
4. With all six Goblin classes present, the town remains browsable but has zero purchase buttons and a visible empty message. Closing/reopening/reloading cannot introduce a fallback recruit.
5. Revalidate class absence on both selection and confirmation against the roster **before** replacement. Selecting an occupied class and replacing its own member is forbidden. Stale UI and old-session callbacks cannot charge, write or mutate roster state.

## User-requested extension: minimal standalone dismissal

### D1 — Minimum-one-member/no-refund policy (single source of truth)

This policy governs all dismissal UX, domain validation, persistence and tests in this plan. Task details and code examples implement D1; they do not introduce independent policy variants.

- **Minimum one member:** Reject removal when it would leave zero members. The domain returns `LAST_MEMBER` / `last_member`; UX disables the action and explains `Keep at least one party member.` UI checks never replace domain enforcement.
- **No refund or charge:** Dismissal leaves gold exactly unchanged. Confirmation reads `Dismiss <name>? No gold is refunded.` Cancellation also leaves all state unchanged.
- **Bounded action:** Dismiss one selected member from normal world party management, outside battles, encounters, reward/placement modals and blocked saves. Confirm the captured slot and character ID. Success empties only that slot and removes its HP entry, preserves other members and slots, and costs no world turn. Cancel/Escape is a no-op.
- **Durable publication:** Persist the detached removal candidate before publishing it. Failed-save retry uses the exact staged bytes; discard preserves the original roster and eligibility. Repeated confirmation, stale target, stale panel and old session are harmless.
- **Scope boundary:** No selling, refund calculation, bulk dismissal, empty-party support, commander-specific protection, dismissal during placement/battle, or broader party-management redesign. Changing D1 requires an explicit scope decision; do not infer more behavior from AC8.6.

The chosen approach extends existing rules and transaction ownership. A second recruitment manager would duplicate state; a test-only removal fixture would leave the requested dismissal action unavailable. Neither alternative is planned.

## What already exists and what remains

- `TownRecruitmentRules.eligible_class_ids()` already enumerates `RunRoster.get_characters()` and filters canonical classes. `purchase_error()` already rejects present classes. Characterization tests may pass immediately; do not rewrite working filtering simply to create a red test.
- `_commit_town_purchase()` checks the live roster before candidate publication. `_finish_town_placement()` rebuilds the panel and rotates callback generation. Expand coverage before changing these paths.
- `RunRoster` supports add, move and replacement, but has no removal operation. Its empty constructor creates starters, so empty-roster test fixtures must use a typed six-slot array containing nulls.
- `PartyManagement` has normal, placement and replacement modes, but no dismiss action.
- `_on_party_move_requested()` currently mutates the live roster before saving. Do not copy that pattern into dismissal; use detached candidates as town purchasing does. A broad movement refactor is outside scope.
- Passed-out status lives in `BattleUnitState`; run-state HP and `_reconcile_health_for_roster()` reject values below 1. Victory recovery restores passed-out members. Test battle-state exclusion and recovered/reloaded exclusion separately; do not weaken V5 HP validation or manufacture a zero-HP world save.
- Current six-class eligibility can become completely empty at capacity. Test replacement with a full valid roster containing a legacy Scout or Champion so an absent class actually remains purchasable.

## File responsibilities

| Action | File | Responsibility |
|---|---|---|
| Modify | `Scripts/Run/run_roster.gd` | Guarded exact-slot removal |
| Modify | `Scripts/Party/party_management.gd` | Normal-mode dismissal intent and confirmation lifecycle |
| Modify | `Scenes/party_management.tscn` | Authored Dismiss button and confirmation dialog |
| Modify | `Scripts/WorldMap/world_runtime_controller.gd` | Authoritative dismissal transaction, publication and callback guards |
| Inspect; modify only for a reproduced failure | `Scripts/Run/town_recruitment_rules.gd` | Whole-roster canonical filtering |
| Inspect; modify only for a reproduced failure | `Scripts/UI/town_recruitment_panel.gd` | Rebuilt offers, empty state, obsolete button rejection |
| Create | `Tests/Run/test_ac8_6_roster_eligibility.gd` | Canonical identity, removal, duplicate-class and passed-out matrix |
| Create | `Tests/UI/test_ac8_6_party_dismissal.gd` | Confirmation, mode restrictions and stale selection |
| Extend | `Tests/WorldMap/test_ac8_town_recruitment.gd` | Durable dismissal, replacement refresh and stale purchase integration |
| Extend | `Tests/UI/test_ac8_5_town_recruitment_panel.gd` | Real transition to empty offers and obsolete controls |
| Extend | `Tests/WorldMap/test_ac3_5_recovery_integration.gd` | Passed-out member remains in roster through recovery |
| Create | `Tests/Run/test_ac8_6_eligibility_restart.gd` | Independent writer/reader eligibility verification |
| Create | `Docs/Specs/AC8/Evidence/AC8.6/.gdignore`, `verification.md`, `run_gate.py` | Isolated evidence and reproducible gate |
| Update after acceptance | `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`, parent AC8 plan | Evidence links and scoped completion |

Retain the existing catalog, save coordinator and V5 format. No new autoload, campaign state, habitat generation, pricing policy or battle-reward recruitment path.

## Task 1: Establish implementation branch and baseline

- [x] Preserve this plan and any unrelated changes. Fetch origin, switch to `main`, fast-forward with `git pull --ff-only origin main`, then create `feat/ac8-6-roster-eligibility`. Do not reset divergent history. Restore unrelated changes without staging them with this work.
- [x] Run GodotIQ project summary and project validation. Use `file_context` for each target and `impact_check` before public API/signal changes; use dependency/signal tools to inspect connections. Read current files through `script_ops` before applying this plan.
- [x] Create the AC8.6 evidence directory with `.gdignore`. Copy the AC8.5 `run_gate.py` into it: its relative project-root calculation remains correct at the same directory depth. Keep old AC8.5 evidence unchanged.
- [x] Run the existing AC8.5 rules, town integration, panel, roster, formation, party UI, recovery, save-coordinator and V5 codec suites using the recipe below. Record failures separately from new tests.

## Task 2: Lock the eligibility invariant and add removal

**Scope:** Eligibility assertions belong to base AC8.6. The new removal API and its minimum-member guard belong to the user-requested extension and implement D1.

**Files:** `Scripts/Run/run_roster.gd`, `Tests/Run/test_ac8_6_roster_eligibility.gd`.

- [x] Create a standalone deferred SceneTree runner with `_expect(condition, message)`, a failure count, explicit `PASS test_ac8_6_roster_eligibility` on success and `quit(1)` on failure. Assert ordered offers for starters are `[scrapbroker, shivrunner, mobcaller]`, sparse slots give the same result, unknown clans return none, and query snapshots remain unchanged.
- [x] Add a passed-out fixture using `roster.create_battle_units()`, set a starter unit's `current_hp = 0`, and assert its class remains excluded. Do not remove the member or pass an active-unit list to eligibility.
- [x] Add two distinct character IDs with the same canonical class: use `player_0` and the factory-created `scrapshield_bruiser`. Removing one must keep that class excluded; removing the last representative while other members remain must make it eligible.
- [x] Write failing removal assertions before adding the API. Invalid slot, empty slot, wrong expected ID and last-member requests preserve the entire slot snapshot. Success changes only the selected slot; repeated removal is rejected. Use the following exact method contract:

```gdscript
# RunRoster additions; use the existing _is_valid_slot() helper.
enum RemoveResult {
    REMOVED,
    INVALID_SLOT,
    EMPTY_TARGET,
    STALE_TARGET,
    LAST_MEMBER,
}

func try_remove_at(slot_index: int, expected_character_id: StringName) -> RemoveResult:
    if not _is_valid_slot(slot_index):
        return RemoveResult.INVALID_SLOT
    var target: RunCharacter = _slots[slot_index]
    if not is_instance_valid(target):
        return RemoveResult.EMPTY_TARGET
    if target.character_id != expected_character_id:
        return RemoveResult.STALE_TARGET
    if size() <= 1:
        return RemoveResult.LAST_MEMBER
    _slots[slot_index] = null
    return RemoveResult.REMOVED
```

- [x] Add these assertions to the runner after constructing a default roster; use `_expect` so release configurations cannot skip the check:

```gdscript
var roster := RunRoster.new()
var candidate := RunRoster.new(roster.get_slot_snapshot())
_expect(candidate.try_remove_at(0, &"wrong") == RunRoster.RemoveResult.STALE_TARGET, "stale removal rejects")
_expect(candidate.try_remove_at(0, &"player_0") == RunRoster.RemoveResult.REMOVED, "remove exact member")
_expect(roster.has_character(&"player_0"), "candidate removal preserves live roster")
_expect(TownRecruitmentRules.eligible_class_ids(&"goblin", candidate).has(&"scrapshield_bruiser"), "last class representative enables offer")
_expect(not TownRecruitmentRules.eligible_class_ids(&"goblin", roster).has(&"scrapshield_bruiser"), "live offer remains excluded before publication")
```

- [x] Validate/check each changed script, run the new runner and retained roster/formation suites, then commit `feat: add guarded roster dismissal primitive`.

## Task 3: Persist dismissal through the production controller

**Scope:** User-requested extension implementing D1. Offer refresh after its committed roster change also provides base AC8.6 evidence.

**Files:** controller and existing town integration runner. Extend its existing `Repository`, `_session`, `_open`, `_expect` helpers instead of adding a parallel harness.

- [x] Write a failing integration case: open normal party management at a town with 750g, dismiss `player_0` from slot 0, close party management and open recruitment. Expect 750g, slot 0 empty, only `player_0` removed from HP, exactly one save, and `scrapshield_bruiser` offered. All coordinates, move/boss/cache/encounter/reward fields remain byte-for-byte equivalent in the durable dictionary.
- [x] Define `request_party_dismissal(slot_index: int, expected_character_id: StringName) -> Dictionary` returning `{ok: bool, error: StringName}`. Require an applied playable session, valid save coordinator, normal active party, no town-placement selection, battle, encounter, pending reward, terminal transition or autosave block. Return `service_blocked` before mutation for those guards; map removal failures to `invalid_slot`, `empty_target`, `stale_target`, `last_member`.
- [x] Implement the transaction in that method in this order: capture `_session_generation` and `_active_party`; clone `RunRoster.new(_roster.get_slot_snapshot())`; call `try_remove_at`; build `_build_candidate_state(_model, false, candidate)`; reject a null/invalid state as `invalid_candidate`; call `commit_candidate` with reason `party_dismissal` and a publication callback bound to that candidate, session and source. On failure, use the existing autosave overlay/error signal and block input. Return `save_failed` without installing the candidate.
- [x] Add `_publish_party_dismissal(state: RefCounted, candidate: RunRoster, session: int, source: PartyManagement) -> void`. Reject stale session/source, then install `_roster` and `_durable_run_state` together, clear dismissal confirmation, refresh the party slots, queue diagnostics refresh, and apply the current model snapshot to update HUD. Preserve the normal party modal's movement lock. It must neither deduct gold nor resolve an encounter.
- [x] Bind the party's new dismissal signal to a handler that validates session and source before calling the domain method. Closing/reopening party management and `apply_session()` invalidate old callbacks. The confirmation captures slot and character ID; current slot selection must not silently change its target.
- [x] Add integration cases for rejected last-member dismissal, invalid/stale IDs, duplicate confirm, old-panel and old-session callbacks, each with zero writes and unchanged durable/live state. A pending confirmation followed by a member moving to another slot must reject its old target.
- [x] Inject one failed write: live roster, HP and gold remain unchanged; retry publishes once with identical bytes; discard retains old eligibility and invalidates the abandoned UI action. The domain method rejects further dismissal and purchase while blocked. Do not claim all AC8.8 coverage from these targeted checks.
- [x] Validate/check controller and tests individually, run focused integration plus save-coordinator tests, then commit `feat: persist party dismissal before roster publication`.

## Task 4: Add minimal dismissal controls

**Scope:** User-requested extension implementing D1. Use D1's exact confirmation and rejection copy; add no further party-management policy.

**Files:** party script/scene and new dismissal UI runner.

- [x] Author a `DismissButton` in the existing character-details area and a `DismissConfirmation` ConfirmationDialog in `Scenes/party_management.tscn` with GodotIQ scene operations. Use unique names for script references. Keep layout in the scene, then save it.
- [x] Add `signal dismissal_requested(slot_index: int, expected_character_id: StringName)` and a typed `request_dismissal(slot_index: int, expected_character_id: StringName) -> void` entry point to the party script. This method only opens confirmation when `_mode == Mode.NORMAL`, the slot still has that ID, and more than one member remains. It emits no domain mutation itself.
- [x] Connect Dismiss to the currently selected member, retain a separate pending slot/ID, and display the name plus no-refund message. On confirmation, recheck normal mode and the same target before emitting. Clear pending identity before emitting so duplicate confirmation cannot emit twice. Cancel, Escape, close, refresh/reconfigure and mode changes clear pending identity without emission.
- [x] Hide the action in placement/replacement mode. Disable it for no selection or the final member, with the specified explanation. Confirmation must trap keyboard focus, keep map input blocked, and restore focus to a valid party control on cancel or success. Use Godot's dialog controls rather than another custom modal framework.
- [x] UI assertions: request opens confirmation with zero emissions; cancel emits zero; confirmation emits exact slot/ID once; changed target, closed panel or changed mode emits zero; last-member action is disabled; placement/replacement cannot invoke it even through the method. Integrate actual controller signal wiring in the production scene tests.
- [x] Validate/check scripts, run party UI and town suites, inspect the scene through GodotIQ, then commit `feat: expose confirmed dismissal in party management`.

## Task 5: Complete refresh, empty-state and stale-request matrix

**Files:** existing town integration/panel/recovery runners; production filtering/panel code only if a test exposes a defect.

- [x] Recruitment: purchase Scrapbroker with 1500g into slot 5. Verify it disappears from the actual panel and domain context; repeat its class request and old placement signal and assert no additional save or charge.
- [x] Replacement: use the existing six-member fixture `[player_0, player_1, player_2, scout, champion, shivrunner]`. Buy Scrapbroker into slot 0 replacing `player_0`. Assert Scrapbroker disappears, Scrapshield Bruiser appears, and other occupied-class exclusions remain. Confirm filtering used the original roster: requesting an already-present class to replace its own member must fail.
- [x] Multiple representatives: use a valid roster containing both `player_0` and `scrapshield_bruiser` plus another class. Dismiss each representative in turn through the production API; only the final removal enables the offer. Verify slot stability and exact HP-key reconciliation after each save.
- [x] Stale class eligibility at confirmation: start selection of an absent class, then use a clearly labelled test fixture to install another roster member of that class before emitting the retained confirmation. Compare state immediately before and after that callback: zero purchase writes and no charge. This fixture tests revalidation; it is not a claimed gameplay path. Cover both add and replacement callbacks.
- [x] Empty eligibility: start from valid saved formation containing each of the six regular classes and sufficient gold. Open/reopen the actual panel and assert context `ok`, an empty class list, visible empty label, zero offer buttons and usable Close. Directly request every class and expect rejection without writes. Then dismiss one member via normal party management and reopen: exactly its class returns.
- [x] Panel refresh: retain a reference to an old offer button, reconfigure with that class absent, and emit its old pressed signal before deferred deletion. Expect no recruit intent. If the current `_request_recruit()` allows it, extend its existing guard with `offer.get_parent() == _offers` and `offer.name == String(class_id)`; retain controller revalidation as the authority.
- [x] Recovery integration: in the existing victory/recovery fixture make a starter pass out, prove it remains a roster member, complete recovery, acknowledge the reward and return to a town. Its class is absent from offers both before and after Continue. Record separately that recruitment is unavailable during the active battle itself.
- [x] Validate/check affected scripts; run focused suites. Preserve existing passing code where tests confirm correctness. Commit `test: cover whole-roster recruitment eligibility transitions` together with any minimal fixes justified by those tests.

## Task 6: Independent-process Continue and rendered acceptance

**Evidence labels:** Offer identity/refresh/reload checks are base AC8.6 evidence. Dismissal controls, confirmation, D1 enforcement and dismissal-transaction safety are extension evidence. Record both labels for shared scenarios.

- [x] Create `Tests/Run/test_ac8_6_eligibility_restart.gd`, following the existing AC8.5 restart harness. Accept `-- --mode=writer|reader --case=dismissal|replacement|empty`; use only `user://ac8-6-eligibility-<case>.json`. Writer commits the actual production action (or writes the valid all-six roster for the empty case), reader starts independently and restores through the production session path.
- [x] For dismissal/replacement readers assert the exact expected formation, HP keys, gold and ordered offers; open/reopen must produce zero further saves. Empty reader must render no purchasable offer. Add a duplicate-class dismissal case before acceptance if the V5-backed integration case cannot prove restoration of both canonical identities.
- [x] Run GodotIQ play, verify-project-runs, console inspection and state inspection on a disposable production-launcher run. Exercise actual pointer and keyboard input for dismiss/cancel/confirm, closing party management, reopening recruitment, purchasing the newly eligible class, replacing a member and Continue.
- [x] Inspect 1280x720 and 1920x1080: selected-member details, confirmation name/no-refund text, disabled last-member state, changed offer list, and an actual all-six-roster empty state. Check focus, Escape, no camera movement/input leakage and no clipped labels. Use one screenshot per verification point; describe captures. Tour the scene after UI scene changes, then stop the game.
- [x] Run the final targeted/regression gate; require explicit PASS, process exit 0 and no script/runtime ERROR for every runner. Record exact commands, tested revision, red/green evidence where behavior changed, and restart/rendered results. Tests already passing at baseline are characterization evidence, not fabricated red/green evidence.
- [x] Complete project validation, parser checks and orphan-signal review; separate pre-existing warnings from attributable problems. Commit relevant scripts, scene, UIDs, tests and evidence only.

## Reproducible automated commands

Copying the established gate runner to AC8.6 keeps its logs separate. From repository root, run this baseline, then rerun it after implementation:

```powershell
python Docs/Specs/AC8/Evidence/AC8.6/run_gate.py --prefix baseline Run/test_ac8_5_recruitment_rules WorldMap/test_ac8_town_recruitment UI/test_ac8_5_town_recruitment_panel Run/test_ac3_1_run_roster Run/test_ac3_3_party_formation UI/test_ac3_3_party_management Run/test_ac3_5_post_battle_recovery WorldMap/test_ac3_5_recovery_integration WorldMap/test_world_runtime_save_coordinator Save/test_world_run_save_codec_v5
```

Final focused gate:

```powershell
python Docs/Specs/AC8/Evidence/AC8.6/run_gate.py --prefix gate Run/test_ac8_6_roster_eligibility UI/test_ac8_6_party_dismissal WorldMap/test_ac8_town_recruitment UI/test_ac8_5_town_recruitment_panel WorldMap/test_ac3_5_recovery_integration
```

Also run `WorldMap/test_ac8_4_town_ownership_reload`, `WorldMap/test_ac8_4_world_debug_integration`, `WorldMap/test_ac8_3_reward_presentation`, `WorldMap/test_cleared_battle_hex_revisit`, `WorldMap/test_world_production_scene`, and `Save/test_goblin_starter_save_migration` through that gate. Use prefix `regression` and record all results. No game tests need to run for preparation of this document alone.

For the separate-process harness, use the engine path from `run_gate.py` with `--headless --path . --script res://Tests/Run/test_ac8_6_eligibility_restart.gd -- --mode=writer --case=dismissal`, then run a new process with `--mode=reader`. Repeat for replacement and empty. Capture with Python `subprocess.run(..., capture_output=True, text=True, timeout=120)` as the established gate does. A timeout, forced quit, missing PASS, nonzero exit or ERROR is a failed gate.

## Acceptance traceability and documentation handoff

| AC8.6 obligation | Required evidence |
|---|---|
| Entire roster, canonical classes and passed-out members | Task 2 rules/duplicate-ID matrix plus Task 5 battle/recovery integration |
| Refresh after recruitment | Task 5 purchase and actual panel assertions |
| Refresh after dismissal | Task 5 reopened offers after the extension's committed removal; acceptance concerns eligibility, not creation of its controls |
| Refresh after replacement | Task 5 canonical starter replacement |
| Class returns only after final member leaves | Tasks 2 and 5 duplicate-class fixtures |
| Reload | Task 6 independent writer/reader cases |
| Empty set has no purchasable offer | Task 5 actual six-class roster and Task 6 rendered/restart checks |
| Stale requests cannot bypass eligibility | Task 5 stale purchase/old-button/old-session checks |

Separate extension acceptance:

| User-requested extension obligation | Required evidence |
|---|---|
| D1 minimum-one-member/no-refund policy | Tasks 2-4 domain rejection, unchanged gold, exact UX copy and disabled last-member control |
| D1 confirmed, bounded dismissal | Tasks 3-4 exact target, cancel/no-op, mode restrictions and stale dismissal checks |
| D1 durable publication | Task 3 failure/retry/discard and Task 6 dismissal restart evidence |

Delivery of this plan requires both tables to pass. The extension table is not an addition to the base AC8.6 definition; report its completion separately.

- [x] Only after every base AC8.6 row passes, record AC8.6 complete in MVP and the parent plan, linking `Docs/Specs/AC8/Evidence/AC8.6/verification.md`. Record the user-requested extension and its D1 results separately in that evidence; do not rewrite the base criterion to require standalone dismissal controls.
- [x] Reassess broad AC8.4 using its ownership/reload/topology evidence together with the full filtered-offer evidence. Mark it complete only if those combined requirements pass for every existing v1 town; generated habitat ownership remains AC9.
- [x] Keep AC8.7 and AC8.8 unchecked: this plan supplies supporting capacity/persistence checks, not their full acceptance matrices. Burned/hostile town behavior remains AC9/AC10 integration work.
- [x] Commit the scoped documentation and restore unrelated local work unstaged. Push only when remote handoff is requested.

## Planning self-review

The plan separates base AC8.6 obligations from the user-requested minimal dismissal extension. It preserves canonical catalog identity, the current positive-HP save contract, six-slot formation shape and the existing transaction owner. D1 is the single source of truth for dismissal policy across UX, domain state and verification. Implementation must verify fresh branch context before applying changes; no planned test or acceptance checkbox here is evidence of a completed feature.

## Execution notes

The production starter fixture includes Brakka in slot 1, so dismissal integration uses its authoritative ID. Roster RED tests used dynamic method lookup to fail cleanly before the new API existed. Rendered QA found and fixed early keyboard/wheel camera leakage. Confirmation input is routed through the root viewport for embedded Window handling. All seven towns now have explicit filtered-offer assertions before and after Continue. Final verification covers 23 distinct automated suites, eight independent restart processes, two rendered production runs, 16 inspected captures and GodotIQ smoke/tour checks. Base AC8.6 and the D1 extension are reported separately; AC8.7/AC8.8 remain unchecked.
