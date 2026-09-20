# AC8.5 Town Recruitment Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkboxes for tracking. Follow repository GodotIQ workflows; use a dedicated branch in the primary workspace, never a worktree.

**Goal:** Let the player recruit an eligible character from an intact allied town's clan for exactly 500g, using existing party placement and an atomic save.

**Architecture:** A pure recruitment rule module derives offers from authoritative town ownership and canonical roster classes. WorldRuntimeController coordinates a dedicated town panel and the existing PartyManagement placement UI. WorldRuntimeSaveCoordinator persists one candidate containing both the new formation and deducted gold before publishing either.

**Tech Stack:** Godot 4, typed GDScript, authored Control scenes, standalone SceneTree tests, V5 run saves, GodotIQ.

**Status:** Implemented and verified on 2026-09-20 in `6b21ec6` (rules) and `7e51140` (production flow/UI). [Verification evidence](../../Specs/AC8/Evidence/AC8.5/verification.md). Current-world AC8.5 passes; AC8.6?AC8.8 acceptance remains pending.

---

## Requirements and scope

Sources: [MVP AC8](../../Specs/GAME_DESIGN_SPEC_MVP.md#AC8--Town-Recruitment-and-Gold), [parent implementation plan](2026-09-18-ac8-town-recruitment-and-gold.md), and [ownership prerequisite](2026-09-20-ac8-4-town-ownership.md).

AC8.5 requires recruitment in intact allied towns at exactly 500g, restricted to recruitable classes of the town's habitat clan. Current world version 1 explicitly treats existing towns as allied Goblin towns. Implement against those towns; do not wait for generated habitats, add towns, alter roads, or change world time.

The production purchase must include basic whole-roster filtering, chosen-slot placement/replacement, cancellation and save-failure safety now. These are dependencies of a usable purchase, even though their exhaustive acceptance matrices belong to AC8.6–AC8.8. Do not mark those criteria complete merely because this slice includes supporting behavior.

Generated ownership/alliance and durable burning remain AC9/AC10 work. The current model has no burned-town or alliance-state field. Centralize recruitment availability so those systems can extend it later; do not invent campaign persistence here or claim actual ruins integration was verified. Unknown world versions fail closed through TownOwnershipRules.

## Findings that affect implementation

- Towns are identified by ownership resolution / `town_index`, not by encounter type. Non-town hexes can also be `safe`.
- `RunCharacterCatalog.get_goblin_class_ids()` lists six regular classes: `scrapshield_bruiser`, `wirefang_skirmisher`, `snarewright`, `scrapbroker`, `shivrunner`, `mobcaller`. Commander factories and legacy Scout/Champion rewards must not become town offers.
- `RunCharacter` currently has `character_id` and `race_id`, but no canonical `class_id`. Starter creation rewrites character IDs to `player_0`, `player_1`, `player_2`.
- `_restore_roster()` already reconstructs starters, all six regular Goblin characters, commanders and legacy rewards from saved formation IDs. A catalog-created regular recruit can use its existing canonical character ID and round-trip through V5 without a new instance-ID scheme.
- Existing reward placement callbacks explicitly return when `_session_applied` is true. They are preview/legacy paths, not a production purchase API. Reuse PartyManagement and RunRoster, not BattleRewardOption as a town transaction.
- `_build_candidate_state()` already copies gold and reconciles formation HP. SaveCoordinator stores exact pending bytes and publishes only after `replace_atomic()` succeeds.
- Existing encounter close consumes the current encounter. Town-panel dismissal should be its own close path and should not consume a town or move the boss.

## Chosen approach

Use a small pure rule module plus dedicated production callbacks in the existing controller. This preserves save ownership and avoids coupling a paid transaction to historical battle rewards. A second recruitment manager would duplicate lifecycle state; extending BattleRewardOption would retain the wrong reward semantics.

Proposed UI: automatically open a town recruitment panel when a committed move enters a currently available town. Show clan, wallet, class names and `500g` on each recruit action. Selecting an offer opens existing placement; no charge occurs until the slot is confirmed. Cancel returns to town browsing; successful purchase returns to refreshed offers. Close returns to the map. A HUD `Recruit` action is visible while standing in an available town, allowing reopening after closing or Continue without an extra move.

## Single-source available-town API contract

`WorldRuntimeController.get_town_recruitment_context() -> Dictionary` is the sole authority for service availability. Arrival routing, HUD visibility/reopen, offer selection and placement confirmation must call it afresh; none may reconstruct availability from cell tags or UI state. It accepts no arguments and reads the committed player coordinate, active session, runtime model and durable run state. Its result always contains:

| Field | Type | Contract |
|---|---|---|
| `ok` | `bool` | True only when the current town service is available under all rules below |
| `error` | `StringName` | Empty on success; a specific rejection reason on failure |
| `coord` | `Vector2i` | Committed player coordinate; `Vector2i.ZERO` only when no valid session coordinate exists, never usable unless `ok` is true |
| `clan_id` | `StringName` | Resolved owner on success; empty on failure |
| `gold` | `int` | Durable balance on success; zero on failure |
| `class_ids` | `Array[StringName]` | Fresh eligible offers on success; empty on failure |

Evaluate these rules in order, without mutations or persistence writes:

1. Require an applied, playable session with valid model, durable state and persistence coordinator; otherwise return `invalid_session`.
2. Call `_model.get_town_ownership(coord)`, which delegates to `TownOwnershipRules.resolve()`. A valid town requires a validated plan cell with integer `town_index >= 0`. Propagate ownership errors, including `unsupported_world_version`, `invalid_coordinate` and `not_a_town`; never fall back to Goblin ownership. A generic `safe` cell is insufficient, and `safe` encounter status is never a substitute for ownership resolution.
3. For supported world version 1, a successfully resolved Goblin town is **intact and allied by the explicit legacy world-v1 rule**. That rule is the entire current compatibility policy, not an inference from missing burning/alliance fields. Reject an unexpected clan as `unsupported_town_owner`. No other world version is available until this API explicitly supports its authoritative ownership, intact-state and alliance data. Future support must reject missing/unknown state and deny destroyed or non-allied towns; adding ownership support alone must not enable recruitment for a new version.
4. Reject a terminal transition, pending reward, active battle, boss collision/encounter, ordinary encounter, unrelated party modal or blocked autosave as `service_blocked`. The controller's current town panel and its matching placement modal may remain open for offer refresh and commit revalidation; they do not bypass any other guard. Request/callback handlers separately validate their session/selection/source identities and reject repeated or stale actions.
5. Return success with the resolved clan, durable wallet and freshly derived offers. Insufficient funds or an empty offer list does **not** make the town unavailable: browsing remains possible, with purchase actions disabled as appropriate.

`TownRecruitmentRules.purchase_error()` receives `town_available = context.ok` and `clan_id = context.clan_id` only from a fresh call to this API. UI code may display the result but cannot supply or override either value. This contract is also the sole extension point for AC9/AC10 intact/allied service policy.

## Close, cancel and dismissal no-op contract

Closing/dismissing the town panel (including its keyboard close path), cancelling unconfirmed placement, or dismissing the placement UI must perform **zero domain mutations and zero persistence writes**. Compare state immediately before and after each action: wallet, roster/formation/HP, town ownership and intact/allied status, player coordinate, move count, boss position/activation/engagement, consumed encounters, battle preparation/settlements, cache progression and world-time progression must be identical. These actions cannot resolve or consume an encounter, tick the world, award gold or charge for a recruit. The movement that originally entered the town is a separate, already committed transaction.

Only transient UI state may change: selection/callback invalidation, focus, panel visibility and modal input blocking. Cancel returns to browsing; Close returns to the map. Clearing the modal input block is not encounter resolution. Repeated or stale close/cancel callbacks are harmless no-ops. During an in-flight or failed purchase save these actions are blocked; only the existing explicit save Retry/Return flow may settle or discard that pending transaction. Closing a panel after a successful purchase preserves the already committed purchase. Here, “dismissal” means dismissing UI, not removing a roster member, whose eligibility effects belong to AC8.6.

## File ownership

| Action | Path | Responsibility |
|---|---|---|
| Modify | `Scripts/Run/run_character.gd` | Explicit runtime canonical class identity, default empty for legacy content |
| Modify | `Scripts/Run/run_character_catalog.gd` | Assign regular-class identity before starter IDs are rewritten; clan recruit allowlist |
| Modify | `Scripts/Run/run_economy_rules.gd` | Single `RECRUITMENT_COST: int = 500` constant |
| Create | `Scripts/Run/town_recruitment_rules.gd` | Pure class eligibility and purchase validation |
| Modify | `Scripts/WorldMap/world_runtime_controller.gd` | Authoritative town context, panel/placement lifecycle, durable transaction |
| Create | `Scripts/UI/town_recruitment_panel.gd` | Render offers and emit selection/close intent |
| Create | `Scenes/UI/town_recruitment_panel.tscn` | Authored, scrollable modal panel |
| Modify | `Scripts/UI/world_map_hud.gd`, `Scenes/world_map_hud.tscn` | Reopen recruitment at the current town |
| Create | `Tests/Run/test_ac8_5_recruitment_rules.gd` | Catalog identity, allowlist, price and filtering |
| Create | `Tests/WorldMap/test_ac8_town_recruitment.gd` | Production entry, placement, atomicity and rejection |
| Create | `Tests/UI/test_ac8_5_town_recruitment_panel.gd` | Offer rendering, empty/poor states and signals |
| Create | `Tests/Run/test_ac8_5_recruitment_restart.gd` | Separate-process purchase/Continue verification |
| Create | `Docs/Specs/AC8/Evidence/AC8.5/verification.md`, `.gdignore` | Reproducible evidence and acceptance limits |

Reuse unchanged unless a demonstrated regression requires adjustment: `Scripts/Party/party_management.gd`, `Scripts/Run/run_roster.gd`, `Scripts/WorldMap/town_ownership_rules.gd`, `Scripts/WorldMap/world_runtime_save_coordinator.gd`, `Scripts/Save/world_run_save_codec_v5.gd`. No new autoload or save version is planned.

## Task 1: Establish branch and baseline

- [x] Record working-tree state; preserve unrelated changes. Fetch origin, fast-forward `main`, then create `feat/ac8-5-town-recruitment`. Resolve divergent history explicitly instead of resetting it. Keep this plan available on the task branch.
- [x] Call GodotIQ `project_summary(detail="brief")`; inspect each target with `file_context` before edits. Run `impact_check` before signature/signal changes and project validation before multi-file changes.
- [x] Run ownership/reload, economy, roster, party formation, save-coordinator, V5 codec, reward presentation and cleared-battle-revisit regressions using the command recipe below. Record existing failures separately.

## Task 2: Canonical class identity and pure rules

**Files:** RunCharacter, RunCharacterCatalog, RunEconomyRules, new TownRecruitmentRules and `Tests/Run/test_ac8_5_recruitment_rules.gd`.

- [x] Write a failing identity test first: starters retain IDs `player_0..2` but expose the first three canonical Goblin class IDs. Every regular factory result exposes its requested class. Legacy rewards have no recruitable class. Require explicit PASS and exit 0 from the runner.
- [x] Add `var class_id: StringName = &""` to RunCharacter without changing its constructor. In `RunCharacterCatalog.create_by_class_id()`, assign `character.class_id = class_id` on each successful regular Wave A/B return. The starter path then retains that property when it changes `character_id`. Do not add commanders to the recruit allowlist.
- [x] Add the following catalog/economy contracts:

```gdscript
# RunEconomyRules
const RECRUITMENT_COST: int = 500

# RunCharacterCatalog
static func get_recruitable_class_ids(clan_id: StringName) -> Array[StringName]:
    if clan_id == &"goblin":
        return get_goblin_class_ids()
    return []
```

- [x] Implement `TownRecruitmentRules` with the following pure offer core. Availability comes exclusively from the single-source `get_town_recruitment_context()` contract above, never from a UI argument:

```gdscript
class_name TownRecruitmentRules
extends RefCounted

static func eligible_class_ids(clan_id: StringName, roster: RunRoster) -> Array[StringName]:
    var result: Array[StringName] = []
    if not is_instance_valid(roster):
        return result
    var occupied: Dictionary[StringName, bool] = {}
    for character: RunCharacter in roster.get_characters():
        occupied[character.class_id] = true
    for class_id: StringName in RunCharacterCatalog.get_recruitable_class_ids(clan_id):
        if not occupied.has(class_id):
            result.append(class_id)
    return result

static func purchase_error(
    clan_id: StringName, roster: RunRoster, class_id: StringName,
    gold: int, town_available: bool
) -> StringName:
    if not town_available:
        return &"town_unavailable"
    if not is_instance_valid(roster):
        return &"invalid_roster"
    if not RunCharacterCatalog.get_recruitable_class_ids(clan_id).has(class_id):
        return &"class_not_recruitable"
    if not eligible_class_ids(clan_id, roster).has(class_id):
        return &"class_already_present"
    if gold < RunEconomyRules.RECRUITMENT_COST:
        return &"insufficient_gold"
    return &""
```

- [x] Test the core with these concrete assertions, within the standalone runner:

```gdscript
var rules: Script = load("res://Scripts/Run/town_recruitment_rules.gd")
var roster := RunRoster.new(RunCharacterCatalog.create_starters())
var expected: Array[StringName] = [&"scrapbroker", &"shivrunner", &"mobcaller"]
assert(rules.eligible_class_ids(&"goblin", roster) == expected)
assert(rules.purchase_error(&"goblin", roster, &"scrapbroker", 499, true) == &"insufficient_gold")
assert(rules.purchase_error(&"goblin", roster, &"scrapbroker", 500, true) == &"")
assert(rules.purchase_error(&"goblin", roster, &"scrapbroker", 500, false) == &"town_unavailable")
assert(rules.purchase_error(&"goblin", roster, &"scrapshield_bruiser", 500, true) == &"class_already_present")
assert(rules.eligible_class_ids(&"unknown", roster).is_empty())
```

- [x] Add commander/Scout/Champion rejection, all-six-classes empty eligibility and roster snapshots proving queries do not mutate data. Filtering must not inspect HP or battle-active units. Do not relax persisted HP validation to manufacture passed-out world saves; the dedicated AC8.6 matrix owns that broader integration.
- [x] Validate/check each changed script immediately, run the focused runner and existing roster/catalog regressions, then commit `feat: define town recruitment eligibility and price`.

## Task 3: Authoritative purchase and placement lifecycle

**Files:** WorldRuntimeController and `Tests/WorldMap/test_ac8_town_recruitment.gd`.

- [x] Add integration tests using a production `apply_session()` fixture and an isolated repository double following `Tests/WorldMap/test_ac8_2_victory_settlement.gd`. Count writes and decode their bytes. First prove no production town purchase entry point exists; do not use legacy preview reward callbacks as the test subject.
- [x] Add these controller entry points: `get_town_recruitment_context() -> Dictionary`, `open_town_recruitment() -> bool`, and `request_town_recruitment(class_id: StringName) -> Dictionary`. Context returns `{ok, error, coord, clan_id, gold, class_ids}`. Requests take no client-supplied price, clan, availability or roster.
- [x] Implement `get_town_recruitment_context()` exactly as the single-source API contract above. Test valid v1 towns, non-town safe cells, invalid coordinates, unsupported versions, boss/ordinary encounters, blocked saves and matching versus unrelated modals. Assert failure results expose no clan or offers and produce no writes. Test that 499g and empty eligibility still permit browsing.
- [x] Make arrival routing, HUD reopen/visibility, offer selection and placement confirmation consume this API; do not add parallel availability predicates. Future ownership support must not implicitly broaden the explicit v1 intact/allied compatibility policy.
- [x] Create a pending town selection containing session generation, town-panel generation, coordinate, class ID and the catalog recruit. Connect PartyManagement placement/replacement/cancel signals to dedicated town callbacks bound to that selection and source panel. Verify those identities before processing callbacks. Invalidate on close, successful publication, discard, session replacement and exit.
- [x] On confirmation, re-resolve town availability, class eligibility and funds against the current roster **before** replacement. Construct `RunRoster.new(_roster.get_slot_snapshot())`; use `try_add_at()` or `try_replace_at()` with the exact expected target ID from the UI. Reject occupied/invalid slots, stale target IDs and mismatched recruit IDs with no write.
- [x] Build the candidate with `_build_candidate_state(_model, false, candidate_roster)`. Set its gold to durable gold minus `RunEconomyRules.RECRUITMENT_COST`; validate it, then call `commit_candidate(candidate_state, bound_publish_callback, "town_recruitment")`. Retain the exact candidate roster for publication. Never charge when selecting an offer, opening placement or writing a separate wallet save.
- [x] Publication installs the candidate roster and committed state together, reconciles HUD/modal state, clears the pending selection, and derives offers again. Preserve surviving members' HP, initialize the recruit to max HP, and remove a replaced member's HP entry. Do not change movement, boss position, cache progression, consumed encounters or battle settlements.
- [x] On save failure, retain SaveCoordinator's exact pending candidate/bytes and existing retry/return overlay. Freeze purchase, cancel and map input. Retry publishes once; discard clears pending town state and uses the existing return-to-launcher behavior. An old callback cannot execute in the resumed/new session.
- [x] Test 499g unchanged; 500g to 0g; 750g to 250g; double confirm produces one write/recruit/charge; cancellation produces none; failed write leaves live state unchanged; retry publishes exactly once; unavailable town and stale session/class/target reject. Confirm chosen slots and a full-roster replacement using a fixture with an eligible class still absent. Six regular Goblin classes all present should yield no offer, not a replacement loophole.
- [x] Validate/check per script, run focused integration plus save-coordinator/formation regressions, and commit `feat: commit paid town recruitment atomically`.

## Task 4: Town panel and map routing

**Files:** New town panel scene/script, HUD script/scene, WorldRuntimeController, new UI test runner.

- [x] Author the panel with GodotIQ scene operations: full-rect modal Control, input-blocking backdrop, centered PanelContainer, title/wallet labels, ScrollContainer with offer rows, status/empty label and Close button. Use container layout, keyboard focus and the existing UI styling. Each offer button emits `recruit_requested(class_id: StringName)`; Close emits `close_requested`.
- [x] Add `configure(clan_id: StringName, gold: int, class_ids: Array[StringName]) -> void`. Render names from the catalog and the shared 500g constant. Below 500g disable selection and display `Requires 500g`; with no classes show `No eligible recruits available.` Clear old rows/connections on refresh. Never let the panel mutate roster or wallet.
- [x] Route committed town arrival to this panel before opening the generic safe encounter. Preserve active boss/battle precedence. Town Close frees the panel, invalidates callbacks, unblocks the world and refreshes the HUD without marking a town consumed or advancing world time.
- [x] Add a HUD recruitment signal/action visible only in the current available town; recompute it on session restore, movement and modal transitions. Continue can reopen recruitment at the saved current town. Closing the world debug drawer when recruitment opens and blocking pointer/keyboard input follow existing modal behavior.
- [x] Hide town browsing while PartyManagement is open. Cancel returns to browsing; success refreshes wallet/offers; save failure shows existing autosave UI above placement. Disable repeated offer input as soon as a selection begins.
- [x] UI tests assert exact price text, three missing-class offers for starters, disabled 499g buttons, enabled 500g buttons, empty-state behavior, one signal per click after refresh, and no underlying map/debug/party action from modal input. Integration tests cover non-town safe cells and reopening at the same coordinate after Continue.
- [x] Exercise every Close/cancel/dismissal path against the no-op contract above, including keyboard input and repeated/stale callbacks. Assert identical before/after domain snapshots and repository write counts; separately confirm permitted panel/focus/input-block changes. Confirm save-pending close/cancel cannot discard or publish a purchase.
- [x] Validate/check changed scripts and save scenes through GodotIQ. Run UI, runtime-scene, HUD and debug-drawer regressions; commit `feat: expose recruitment in allied towns`.

## Task 5: Persistence and regression gate

**Files:** New restart runner and the integration runner; production adjustments only if these checks reveal a defect.

- [x] Create writer/reader modes using an isolated `user://ac8-5-recruitment-verification.json` slot. Writer buys `scrapbroker` into a chosen empty slot at 500g, saves and exits. A separate reader process continues that run and asserts balance 0g, the same slot/character/class/HP and no offer for Scrapbroker. Reopening/closing the panel performs no purchase write.
- [x] Add a failure/discard/restart case proving the old wallet/formation survive, and a failure/retry/restart case proving exactly one complete purchase survives. Never point fixtures at the user's active run slot.
- [x] Round-trip a purchased regular class through V5 and the existing load service. Verify canonical world-plan bytes before/after and retain legacy starter/reward compatibility. No codec migration is expected because formation already supports catalog IDs and gold is already persisted.
- [x] Run new tests plus the regression list below. A timeout, missing PASS, nonzero exit or script/runtime ERROR fails the gate even if other output appears successful. Record baseline-only warnings separately.

Run from repository root, substituting each test path:

```powershell
& 'D:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --quit-after 1800 --script res://Tests/Run/test_ac8_5_recruitment_rules.gd
```

Use an external 120-second process timeout in the evidence runner. Expected: explicit PASS marker, exit 0, no script/runtime ERROR. Capture stdout/stderr and exact arguments per run.

**No AC8.5 acceptance claim may be recorded unless the command output includes explicit PASS, the process exits 0, and there is no script/runtime ERROR for every targeted AC8.5 suite.** The targeted suites are `Tests/Run/test_ac8_5_recruitment_rules.gd`, `Tests/WorldMap/test_ac8_town_recruitment.gd`, and `Tests/UI/test_ac8_5_town_recruitment_panel.gd`. Record their exact commands, complete output and exit codes against the tested revision. The restart suite and required regressions remain implementation safety checks; they do not confer AC8.6–AC8.8 acceptance. A completed plan, passing static checks, or a screenshot alone cannot satisfy this gate.

Required existing regressions:

- `Tests/Run/test_ac8_economy.gd`
- `Tests/Run/test_ac3_1_run_roster.gd`
- `Tests/Run/test_ac3_3_party_formation.gd`
- `Tests/UI/test_ac3_3_party_management.gd`
- `Tests/UI/test_world_map_hud.gd`
- `Tests/WorldMap/test_world_runtime_save_coordinator.gd`
- `Tests/WorldMap/test_world_production_scene.gd`
- `Tests/WorldMap/test_world_runtime_scene.gd`
- `Tests/WorldMap/test_scout_recruitment_flow.gd`
- `Tests/WorldMap/test_ac8_1_gold_runtime.gd`
- `Tests/WorldMap/test_ac8_2_defeat_ends_run.gd`
- `Tests/WorldMap/test_ac8_3_reward_presentation.gd`
- `Tests/WorldMap/test_ac8_4_town_ownership.gd`
- `Tests/WorldMap/test_ac8_4_town_ownership_reload.gd`
- `Tests/WorldMap/test_ac8_4_world_debug_integration.gd`
- `Tests/WorldMap/test_cleared_battle_hex_revisit.gd`
- `Tests/Save/test_goblin_starter_save_migration.gd`
- `Tests/Save/test_world_run_save_codec_v5.gd`

## Task 6: Rendered QA and acceptance evidence

- [x] Use GodotIQ play → verify_project_runs → debug console → state inspection on the production launcher with a disposable run. Exercise actual pointer and keyboard input for arrival, reopen, offer selection, chosen-slot placement, cancel, purchase and Continue. A callable-only check is insufficient for UI acceptance.
- [x] Inspect 1280×720 and 1920×1080 town screens, poor/empty states and placement. Use explore tour after scene work, describe inspected captures, and fix clipped labels, unreadable prices, focus loss or modal input leaks. Capture at most one screenshot per verification point.
- [x] Inspect before/after gold, formation, HP, current coordinate, move count, boss coordinate and cache progress. Confirm a purchase costs exactly 500g and only map movement changes world time. Verify town service cannot bypass a boss encounter.
- [x] Run final project validation, error check and scoped signal inspection; investigate new orphan connections. Record tested commit, exact runner commands/results, failure/retry evidence and rendered captures in the evidence directory.
- [x] Update MVP AC8.5 and parent-plan progress only after the explicit AC8.5 gate and targeted-suite output gate pass, with rendered open/reopen and no-op evidence. Keep AC8.6–AC8.8 unchecked pending their full matrices; state the current-world limitation on intact/allied status and the AC9/AC10 integration obligation. Do not mark full AC8.4 filtered-offer acceptance without the corresponding evidence.
- [x] Commit only relevant code, scenes, generated UIDs, tests and evidence. Restore unrelated work unstaged. Push only if remote handoff is requested.

## Acceptance traceability

**AC8.5 passes only when the 500g, clan-filter, and open/reopen flow are proven without claiming whole-roster replacement or save-retry durability.** Its gate additionally requires the available-town API, close/cancel no-op evidence and targeted-suite output gate defined above. Supporting safety checks remain required for implementation handoff, but their presence or success must not be reported as completion of AC8.6, AC8.7 or AC8.8.

| Acceptance owner | Requirement | Evidence |
|---|---|---|
| **AC8.5 gate** | Current-world intact allied town service and open/reopen | Single-source API tests; production arrival, HUD reopen and reopen after Continue; non-town safe/unsupported-version/boss rejection |
| **AC8.5 gate** | Exactly 500g per regular character | 499/500/750 purchase boundaries, exact balance change and rendered price |
| **AC8.5 gate** | Only town-clan recruitable classes | Explicit six-class allowlist; commander/legacy/unknown rejection |
| **AC8.5 gate** | Close/cancel/dismissal are domain no-ops | All dismissal paths preserve the full contract snapshot and write count; only transient UI changes |
| **AC8.5 gate** | Verified execution, not planning completion | Each targeted AC8.5 suite: explicit PASS, exit 0, no script/runtime ERROR; tested revision and rendered flow evidence |
| AC8.6 supporting work; acceptance pending | Canonical identity and whole-roster eligibility | `player_0..2` assertions and basic filtering; full passed-out/refresh/dismissal matrix remains separate |
| AC8.7 supporting work; acceptance pending | Whole-roster placement/replacement and rejected mutations | Chosen-slot/replacement, cancellation and stale-target checks do not establish full AC8.7 acceptance |
| AC8.8 supporting work; acceptance pending | Save-retry durability and idempotence | Independent writer/reader and retry/discard checks do not establish full AC8.8 acceptance |
| Regression safety | No topology/time/reward regression | Canonical bytes, movement snapshots, retained battle/ownership suites |
| AC9/AC10 deferred | Generated ownership and burned/hostile-town service denial | Explicit availability API extension obligation; actual campaign-state integration remains unclaimed |

## Self-review

The plan covers current-world AC8.5, records the necessary overlap with later recruitment criteria, preserves ownership and V5 contracts, and supplies explicit rejection/publication behavior. It does not add habitat generation, siege state, a parallel roster system or historical reward recruitment to production. The implementation must rerun context/impact checks against its updated branch before applying these steps.
