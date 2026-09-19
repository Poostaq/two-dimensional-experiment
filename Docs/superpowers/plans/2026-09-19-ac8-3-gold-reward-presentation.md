# AC8.3 Gold Reward Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox syntax. Follow repository AGENTS.md; use a dedicated branch in the primary workspace, never a worktree.

**Goal:** Replace production victory choices with a money icon, the exact committed gold award and a durable Continue action, preserving recovery and encounter completion.

**Architecture:** AC8.2 remains the sole authority for gold, recovery and battle settlement. Run state gains one pending reward receipt reference; V5 persists it atomically with settlement. A world-controller-owned panel presents that receipt both immediately and after reload; Continue saves an acknowledgement before dismissing it.

**Tech Stack:** Godot 4, typed GDScript, authored Control scenes, SVG icon, existing atomic save coordinator, headless SceneTree tests and GodotIQ runtime verification.

**Status:** Approved and implemented on `feat/ac8-3-gold-reward-presentation` in `3abd28f`, `d3ab8c0` and `3d1319a`. All 35 required process runs pass; six rendered restart runs and twelve inspected images verify presentation and persistence. [Execution evidence and tool limitations](../../Specs/AC8/Evidence/AC8.3/verification.md) are authoritative; the task recipes below retain the approved design. Based on AC8.2 `8fff747`.

Sources: [MVP AC8.3](../../Specs/GAME_DESIGN_SPEC_MVP.md), [AC8 parent plan](2026-09-18-ac8-town-recruitment-and-gold.md), [AC8.2 plan](2026-09-19-ac8-2-battle-gold-and-terminal-defeat.md), [AC8.2 evidence](../../Specs/AC8/Evidence/AC8.2/verification.md).

## Scope and decisions

- Display `Gold received: 150g` after victory over three distinct enemies. The amount comes from the committed receipt, never from the current wallet or a fresh enemy count.
- Preserve automatic AC8.2 recovery, formation, consumed encounters, cleared preparation, boss deactivation and zero-gold terminal defeat.
- Remove item/rest/recruitment choices from production, including direct calls that could still grant the Scout. Keep isolated legacy preview/catalog tests where they remain useful; they do not establish production acceptance. Town recruitment belongs to AC8.4–AC8.7.
- Include durable pending presentation and acknowledgement now, as required by the AC8.2 handoff. AC8.8 still owns cross-flow recruitment/transaction verification.
- Use one pending battle ID, not a second copy of the award or a queue: the world cannot start another battle while its reward is pending.
- Introduce V5 instead of changing V4's strict schema. Older saves normalize to no pending reward, including V4 saves containing previously paid receipts. Do not reopen historical awards or infer missing acknowledgement history.
- Retain the existing boss post-battle destination. There is no campaign-completion screen in the inspected baseline. Boss reward acknowledgement must finish before any existing/future completion routing; building a new completion screen is outside this slice.
- On failed acknowledgement, keep the reward visible and world input blocked. Retry uses the same candidate bytes. Existing Return-to-menu behavior may discard only the failed acknowledgement candidate: the committed pending reward remains and reopens on Continue. Terminal-defeat retry-only behavior is unchanged.

Alternatives considered: placing the panel inside `BattleArena` would require reconstructing a completed arena on reload; an in-memory-only panel would lose pending presentation on restart. Controller ownership reuses the existing durable session and avoids both costs.

## Authoritative state transitions and modal rule

These transitions govern Tasks 2–6. State names describe controller phases; only `pending_reward_battle_id` is newly persisted. `P` means the committed victory's battle ID. A candidate with an empty pending ID is not an acknowledgement until its atomic write succeeds.

**Modal requirement:** While its world session is mounted, the durable pending reward remains presented and blocks gameplay until a valid acknowledgement is successfully persisted, either on the initial save or a successful retry; no discard path may clear the durable pending reward.

The save-failure overlay may cover the panel and take focus, but the reward stays mounted beneath it. Starting a retry does not dismiss it. Return to the launcher may unmount the world UI; that is not acknowledgement, and reloading must restore the pending panel before enabling any gameplay.

| Current state | Event / guard | Durable state and write | Next state / presentation |
|---|---|---|---|
| Settlement saving | Victory settlement write succeeds | Award, recovery, receipt and pending `P` commit atomically | Settlement committed; input remains blocked until publication presents the panel |
| Settlement committed | Current-session publication callback | No additional write | Reward visible with amount from receipt `P`; Continue enabled, gameplay blocked |
| Settlement saving | Write fails / Retry fails again | Prior checkpoint unchanged; retain frozen settlement candidate | Settlement save failed; no reward panel yet, battle/world blocked |
| Settlement save failed | Retry succeeds | Same candidate bytes commit once | Settlement committed, then reward visible |
| Settlement save failed | Permitted AC8.2 discard / Return | Discard only uncommitted settlement candidate; prior checkpoint retained | Existing AC8.2 return/restore behavior; never claim reward acknowledgement or show an uncommitted award |
| Session loading | Valid save contains pending `P` | No write and no second settlement | Reward visible before input is enabled; no arena reconstruction or encounter reopening |
| Reward visible | Continue for current session and `P` | Stage candidate clearing only pending ID; durable pending remains `P` during write | Acknowledgement saving; panel remains, Continue disabled, gameplay blocked |
| Acknowledgement saving | Write fails | Keep durable `P` and frozen acknowledgement candidate | Acknowledgement save failed; failure overlay owns focus, reward remains beneath it |
| Acknowledgement save failed | Retry starts / fails again | Retry identical bytes; durable `P` unchanged on failure | Panel remains blocking; no dismissal merely because Retry was pressed |
| Acknowledgement saving or failed | Initial write / retry succeeds, current callback identity matches | Persist empty pending ID; award, recovery and receipt unchanged | Controller publishes acknowledged state, dismisses panel once and restores existing post-battle route/input locks |
| Acknowledgement save failed | Discard and remain in world | Drop only failed candidate; restore committed `P`; no write clearing `P` | Reward visible again, Continue re-enabled; gameplay still blocked |
| Acknowledgement save failed | Discard and Return to launcher | Drop only failed candidate; committed `P` remains on disk | World UI unmounted; next load restores reward visible |
| Saving / save failed | Duplicate Continue or acknowledgement | Reject while coordinator blocks input; no extra write | Current panel, candidate and state unchanged |
| Acknowledged, no pending reward | Duplicate acknowledgement of a known victory in current session | Successful no-op; no write | No panel reopened, no repeated routing or recovery |
| Any current-session reward state | Unknown ID, or older ID while a different reward is pending | Reject; no write | Current presentation and durable state unchanged |
| Session replaced / controller disposed | Queued UI or publication callback from old session generation, panel or transaction | Ignore before applying state or starting a write; never redirect an old callback into a new session | Replacement session and its UI unchanged |
| Session loading | Save has empty pending ID | No acknowledgement write | Existing ordinary/boss post-battle behavior; no reward panel |

Direct session replacement is rejected while a reward or save is pending. Valid launcher teardown invalidates the old callback generation and disconnects its panel. A coordinator with an outstanding write cannot be rebound to a replacement session. Every table row requires a domain, coordinator or controller test; restart rows additionally require the separate-process runner.

## Save-format compatibility contract

1. **V4 is immutable:** retain its exact envelope, run-state key set, field meanings and validation rules. Shared implementation helpers may change only if V4 fixtures retain the same acceptance/rejection behavior.
2. **V5 adds exactly one run-state field:** `world.run_state.pending_reward_battle_id: String`. Apart from `save_version = 5`, the V4 structure and existing field meanings remain unchanged. Do not add a duplicate amount, acknowledgement flag, queue or new lifecycle field.
3. **Empty and nonempty values:** `""` means no pending presentation. A nonempty value must exactly identify the final committed victory receipt in an active run, with no active preparation. The amount is read from that receipt.
4. **Legacy normalization:** successfully validated V2/V3/V4 saves normalize to an empty pending ID in memory, even if they contain historical paid receipts. Existing wallet and lifecycle migration rules remain intact. Never infer a pending reward from an old receipt.
5. **Malformed input rejects:** a V5 field that is missing, null, non-string or semantically invalid rejects the save. Never strip it, coerce it, substitute empty or fall back to an older codec after V5 validation fails. V2/V3/V4 payloads containing the new field also reject.
6. **Version dispatch:** accept only explicitly supported versions through their existing readers; unsupported future versions and malformed version values return the normal structured save-validation failure, without attempting a best-effort load or crashing.
7. **Encoding and downgrade:** production writes V5. Older encoders reject any state with a nonempty pending ID; for an empty ID they omit the field and preserve their existing contracts. Internal `from_dictionary()` defaults do not relax these wire-format rules.

## Acknowledgement ownership and publication order

**The save coordinator owns the durable acknowledgement commit; the world controller owns acknowledgement orchestration and is the sole owner of reward-panel dismissal after a successful commit.** The panel emits intent only, and the pure acknowledgement rule constructs a candidate only. Neither changes durable state or decides that saving succeeded.

The controller validates session generation, panel identity and battle ID before requesting a write. It passes the candidate to the session's coordinator, which freezes bytes, performs atomic replacement, retains failed candidates for retry, and invokes publication only after success. The controller's publication callback validates the captured session generation and expected battle ID before applying the acknowledged state, dismissing the panel, cleaning up the completed arena, restoring the model, recalculating input locks and refreshing the HUD, in that order. The published pending ID must be empty and the expected victory receipt must still exist. A mismatched callback is ignored, without state publication, dismissal or routing.

Retries use the original candidate and bound callback. Discard has no acknowledgement publication callback: it restores the durable pending state and either re-presents it or tears down the world for the launcher. HUD refresh, arena exit and UI visibility never constitute acknowledgement. Initial hidden setup and launcher teardown may hide/unmount a panel without clearing pending state.

## Observed integration points

- `BattleSettlementRules.build_candidate()` already stages gold, recovery, encounter completion and an immutable receipt together.
- `WorldRunState.to_dictionary()` is the copy boundary used by settlement, ordinary mutations and the save coordinator.
- `WorldRuntimeController._publish_battle_settlement()` currently calls `BattleArena.set_settlement_committed()`, which opens legacy choices. `apply_session()` restores preparation but has no pending reward restore path.
- `retry_autosave()` currently blocks the restored model only when an arena exists. A reward restored without an arena must also block it.
- `_on_battle_closed()` and arena debug exit can currently bypass post-settlement presentation. They need production pending-reward guards.
- V4's envelope uses an exact run-state key set. Production codec consumers are `world_single_slot_repository.gd`, `world_production_launcher.gd` and `world_runtime_save_coordinator.gd`.
- `test_ac8_2_victory_settlement.gd` currently expects legacy choices after save and an immediately usable world on reload. Those assertions must change with AC8.3.

## Task 1: Establish the baseline and isolate implementation

**Files:** inspect `AGENTS.md`, `GODOTIQ_RULES.md` and the source/test files listed below. No gameplay changes in this task.

- [x] Record `git status --short --branch` and `git log -3 --oneline`. The planning workspace contains unrelated tracked edits and untracked AC8–AC10 plans; preserve them. Stash unrelated work, update `main` from origin with fast-forward only, then create `feat/ac8-3-gold-reward-presentation`. Do not automatically merge divergent history. If updated main lacks AC8.2, integrate that prerequisite explicitly before implementing this dependent slice.
- [x] Use GodotIQ `file_context(detail="brief")` before each edited file, `impact_check` for changed signatures/signals and project validation before the multi-file change. Reinspect current source if it differs from the baseline above.
- [x] Run the existing victory, defeat, V4, reward-selection, Scout and recovery suites using the command recipe below. Record baseline failures separately. The previously recorded migrated-preview-flow stall is not evidence against or for AC8.3.

## Task 2: Model pending reward and acknowledgement

**Modify:** `Scripts/Run/world_run_state.gd`, `Scripts/Run/battle_settlement_rules.gd`.
**Create:** `Scripts/Run/battle_reward_acknowledgement_rules.gd`, `Tests/Run/test_ac8_3_reward_acknowledgement.gd`.
**Extend:** `Tests/Run/test_ac8_2_battle_settlement_rules.gd`, `Tests/Run/test_ac8_2_run_settlement_state.gd`.

- [x] Add failing cases using the existing settlement fixtures: victory stages pending ID with gold/recovery; loss stages none; unknown ID, defeat receipt, non-string ID and pending plus active preparation are invalid; copying round-trips the ID without aliasing receipts. Pending must reference the final receipt, which must be a victory in an active run. No new settlement may replace an unacknowledged one; an identical duplicate of the existing receipt remains an idempotent no-op.
- [x] Add a trailing optional `new_pending_reward_battle_id: String = ""` argument to `WorldRunState.create()`, the corresponding typed property and dictionary entry. `from_dictionary()` accepts a missing key as the internal/legacy empty default but rejects a present non-string value; V5 decoding separately requires the key. Include pending validation in `is_valid()` and preserve it in all candidate copies.

```gdscript
var pending_reward_battle_id: String = ""
# create(): copy the new trailing argument into this property.
# to_dictionary(): include this exact key/value.
# from_dictionary(): pass the validated string into create().
```

- [x] Extend settlement after the existing duplicate check and before accepting a new result:

```gdscript
if not state.pending_reward_battle_id.is_empty():
    return _failure("reward_pending")
# In the victory branch, before STATE.from_dictionary(data, plan):
data["pending_reward_battle_id"] = String(receipt.battle_id)
```

- [x] Implement the pure acknowledgement rule. It clears presentation only; it neither changes the receipt nor reapplies recovery/gold. Unknown or stale IDs reject. Repeated acknowledgement of a known victory after pending has cleared is a successful no-op.

```gdscript
class_name BattleRewardAcknowledgementRules
extends RefCounted

static func build_candidate(state: RefCounted, plan: WorldPlan, battle_id: String) -> Dictionary:
    if not is_instance_valid(state) or not state.is_valid(plan) or not state.is_playable() or battle_id.is_empty():
        return {"ok": false, "value": null, "error": "invalid_acknowledgement"}
    var known_victory: bool = false
    for receipt: Dictionary in state.battle_settlements:
        if receipt.battle_id == battle_id and receipt.outcome == "victory":
            known_victory = true
    if not known_victory:
        return {"ok": false, "value": null, "error": "unknown_reward"}
    if state.pending_reward_battle_id.is_empty():
        return {"ok": true, "duplicate": true, "value": null, "error": null}
    if state.pending_reward_battle_id != battle_id:
        return {"ok": false, "value": null, "error": "stale_reward"}
    var data: Dictionary = state.to_dictionary()
    data["pending_reward_battle_id"] = ""
    var decoded: Dictionary = load("res://Scripts/Run/world_run_state.gd").from_dictionary(data, plan)
    if not decoded.get("ok", false):
        return {"ok": false, "value": null, "error": "invalid_candidate"}
    return {"ok": true, "duplicate": false, "value": decoded.value, "error": null}
```

- [x] Assert the acknowledgement dictionary equals the settled dictionary with only `pending_reward_battle_id` cleared; replaying the result after acknowledgement never restores it. Run the new runner red before implementation and green afterward. Validate/check each changed script before proceeding to another. Commit the domain slice.

## Task 3: Version and wire persistence

**Create:** `Scripts/Save/world_run_save_codec_v5.gd`, `Tests/Save/test_world_run_save_codec_v5.gd`.
**Modify:** `Scripts/Save/world_run_save_envelope.gd`, `Scripts/Run/world_single_slot_repository.gd`, `Scripts/Run/world_production_launcher.gd`, `Scripts/WorldMap/world_runtime_save_coordinator.gd`.
**Extend:** V2/V3/V4 codec tests, `Tests/Run/test_world_single_slot_repository.gd`, `Tests/Run/test_world_production_launcher.gd`, `Tests/WorldMap/test_world_runtime_save_coordinator.gd`.

- [x] Write failing V5 tests for pending and acknowledged round trips, malformed/missing/wrong-type pending field, unknown receipt reference, pending defeat, and pending preparation. Exercise a fresh state, an ordinary settled state, a boss settled state and lost state. Test V2/V3/V4 migration with no pending presentation and unchanged wallet/receipt semantics.
- [x] Add V5 using V4's `encode`/`decode_any` pattern with `SAVE_VERSION = 5` and V4 delegation. A declared V5 payload must return its own validation failure without legacy fallback. Unsupported future versions must reject.
- [x] Extend the envelope's allowed versions. Share shape validation while retaining V4's exact old key set; V5 requires that set plus `pending_reward_battle_id`. Validate the field as a string and let domain validation check the receipt relationship. V2/V3/V4 inputs containing this new field reject instead of silently becoming V5.
- [x] Normalize old decoded state with an empty pending ID. Older encoders must refuse to serialize a state with a nonempty pending ID; when empty, strip the field before writing the unchanged old schema. Do not silently discard pending acknowledgement on downgrade.

```gdscript
# encode(), after obtaining state_data:
if save_version < 5:
    if not run_state.pending_reward_battle_id.is_empty():
        return PackedByteArray()
    state_data.erase("pending_reward_battle_id")
# decode(), after strict validation and copying world.run_state:
if expected_version < 5:
    if state_data.has("pending_reward_battle_id"):
        return _save_failure("legacy_reward_field")
    state_data["pending_reward_battle_id"] = ""
```

- [x] Point all three production codec consumers at V5. Update tests which decode production output through V4 to use V5; retain fixtures testing actual old versions. Re-run dependency_graph for V4 so no production writer is missed.
- [x] Test coordinator publication ordering, failed-write byte-for-byte retry, and discard restoring the durable pending reward. Run V2–V5, repository, launcher and coordinator suites; validate/check per script and commit.

## Task 4: Author the reward panel

**Create:** `Scripts/UI/battle_gold_reward_panel.gd`, `Scenes/UI/battle_gold_reward_panel.tscn`, `Assets/UI/gold_coin.svg`, `Tests/UI/test_ac8_gold_reward.gd`.
**Modify:** `Scenes/world_map_runtime.tscn` to instance the panel hidden under its UI layer, above the battle surface and below the autosave failure overlay.

- [x] Write failing panel tests for hidden initial state, exact receipt amount (0, 50, 150 and maximum supported integer), keyboard activation, one signal per presentation, reset on a different battle, and blocking while saving.
- [x] Author a full-rect input-blocking overlay with a centered container: heading `Victory`, a TextureRect coin, unique-name `%AmountLabel` and `%ContinueButton`. Use container sizing/wrapping at 1280×720 and 1920×1080. Escape and click-outside must not dismiss it. A simple authored SVG coin avoids font-dependent emoji rendering.
- [x] Give the panel this interface and behavior; populate the icon texture from the authored SVG in the scene:

```gdscript
extends Control
signal acknowledgement_requested(battle_id: String)

var _battle_id: String = ""
var _submitted: bool = false
@onready var _amount: Label = %AmountLabel
@onready var _continue: Button = %ContinueButton

func _ready() -> void:
    _continue.pressed.connect(_on_continue_pressed)
    dismiss()

func present(battle_id: String, earned_gold: int) -> void:
    _battle_id = battle_id
    _submitted = false
    _amount.text = "Gold received: %dg" % earned_gold
    _continue.disabled = false
    show()
    _continue.grab_focus()

func set_saving(saving: bool) -> void:
    _continue.disabled = saving or _submitted

func dismiss() -> void:
    hide()
    _battle_id = ""
    _submitted = false

func _on_continue_pressed() -> void:
    if not visible or _submitted or _continue.disabled or _battle_id.is_empty():
        return
    _submitted = true
    _continue.disabled = true
    acknowledgement_requested.emit(_battle_id)
```

- [x] Ensure the controller only calls `present()` when opening/restoring a presentation, not every HUD refresh, so duplicate publication cannot reset the submission latch. Saving failure retains the latch; Retry belongs to the autosave overlay. Discard-and-restore explicitly re-presents the durable receipt if remaining in-world.
- [x] Use GodotIQ node/build operations for the scene, save it, validate/check its script and run the panel tests. Commit the UI slice. Rendered verification follows after integration.

## Task 5: Coordinate settlement, restore and acknowledgement

**Modify:** `Scripts/WorldMap/world_runtime_controller.gd`, `Scripts/Battle/battle_arena.gd`.
**Create:** `Tests/WorldMap/test_ac8_3_reward_presentation.gd`.
**Extend:** `Tests/WorldMap/test_ac8_2_victory_settlement.gd`, `Tests/WorldMap/test_ac3_5_recovery_integration.gd`.

- [x] Start from the real combat fixture and failure-injecting Repository in `test_ac8_2_victory_settlement.gd`. Damage three 1-HP enemies to victory; do not fake a gold total. Fail settlement, retry, fail acknowledgement, retry and reload at both durable boundaries. Capture wallet, health, receipt count, move count, roster and writes at each step.
- [x] Add public `has_pending_gold_reward() -> bool` and `acknowledge_gold_reward(battle_id: String) -> Dictionary` on the controller. The first derives from durable state. The second rejects while integration-failed, non-playing or autosave-blocked, invokes the pure rule, returns duplicates without a write, and commits through the coordinator:

```gdscript
# For a nonduplicate acknowledgement candidate from Task 2:
var saved: Dictionary = _save_coordinator.commit_candidate(
    built.value, Callable(self, "_publish_reward_acknowledgement").bind(_session_generation, battle_id),
    "battle_reward_acknowledgement", true
)
# Failure: retain panel/input lock and emit autosave_failed(saved.error).
# Success: only the publication callback may dismiss/unlock.
```

- [x] Implement `_present_pending_gold_reward() -> void`: find the receipt matching durable pending ID, close character-info/debug overlays on the active arena, mark its settlement committed, block the world and present `receipt.earned_gold`. Missing receipt is an integration failure, never a reason to skip the screen.
- [x] In `_publish_battle_settlement()`, preserve the defeat branch. On victory restore the model/HUD, then present the pending reward. In `BattleArena.set_settlement_committed()` and `_show_victory_rewards()`, prevent legacy reward presentation when `_production_settlement` is true. Keep the completed arena frozen behind the reward until acknowledgement; a restored pending reward needs no arena.
- [x] At the end of `apply_session()`, restore a pending reward before preparation restoration or allowing world input. If pending exists, do not reopen its consumed encounter or instantiate enemies. Both fresh and restored paths must display the same amount and leave the wallet unchanged.
- [x] Implement `_publish_reward_acknowledgement(state: RefCounted, session_generation: int, battle_id: String) -> void`: first enforce the callback identity and published-state checks in the ownership contract, then publish state, dismiss the panel, free any completed arena exactly once, clear transient battle/recruitment state, restore the model from durable state, recalculate legitimate input locks and refresh HUD. Do not call the ordinary encounter-resolution save path or reapply recovery. This same method must work with no arena after reload.
- [x] Gate movement, party entry/mutation, encounter/battle opening, direct battle close/debug exit and `apply_session()` replacement while pending. Bind UI acknowledgement to the current session generation as well as battle ID; stale callbacks after a replacement must be ignored. Acknowledged/unknown IDs cannot dismiss a newer panel. Recalculate surface blocking after retry/discard with both active battle and pending reward considered.
- [x] Remove production reward-option configuration and legacy reward/recruitment signal connections from `_on_battle_requested()`. Guard production calls to arena selection/confirmation and controller reward-selected/reward-confirmed/recruitment-placement handlers as well. Reuse existing roster placement code for its remaining consumers; do not remove the six-slot infrastructure needed by towns.
- [x] Keep failed settlement behavior at the existing AC8.2 durability boundary: no reward is visible before a successful write. Failed acknowledgement may return to the launcher through the existing discard path, but cannot expose a playable world or clear the durable pending ID. Test Retry, Return and restart separately; defeat must still disallow discard.
- [x] Update the AC8.2 regression assertions: successful settlement shows the gold panel, reload stays blocked until acknowledgement, and direct battle close cannot bypass it. Assert no additional settlement, recovery or encounter-consumption write during acknowledgement. Validate/check each script, run focused suites and commit.

Required integration assertions (use existing `_expect` helper and actual fixture values):

```gdscript
_expect(world.get_durable_run_state().gold == 250, "three enemies award 150 once")
_expect(world.has_pending_gold_reward(), "committed award awaits acknowledgement")
_expect(world.get_valid_destinations().is_empty(), "reward blocks movement")
var before: Dictionary = world.get_durable_run_state().to_dictionary()
var battle_id: String = before.pending_reward_battle_id
repo.fail_next = true
_expect(not world.acknowledge_gold_reward(battle_id).get("ok", false), "ack save failure retained")
_expect(world.get_durable_run_state().to_dictionary() == before, "failed ack changes nothing durable")
var retry_bytes: PackedByteArray = repo.writes.back()
_expect(world.retry_autosave().get("ok", false), "ack retry succeeds")
_expect(repo.writes.back() == retry_bytes, "ack retries frozen bytes")
var expected: Dictionary = before.duplicate(true)
expected.pending_reward_battle_id = ""
_expect(world.get_durable_run_state().to_dictionary() == expected, "ack only clears pending")
var writes_before: int = repo.writes.size()
world.acknowledge_gold_reward(battle_id)
_expect(repo.writes.size() == writes_before, "duplicate ack has no write")
```

## Task 6: Replace superseded expectations and verify acceptance

**Modify:** `Tests/Battle/test_ac2_5_reward_selection.gd`, `Tests/WorldMap/test_scout_recruitment_flow.gd`.
**Create:** `Tests/Run/test_ac8_3_reward_restart.gd`, `Docs/Specs/AC8/Evidence/AC8.3/.gdignore`, `Docs/Specs/AC8/Evidence/AC8.3/verification.md`.
**Update after evidence passes:** this plan, `Docs/superpowers/plans/2026-09-18-ac8-town-recruitment-and-gold.md`, `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`.

- [x] In AC2.5 tests retain explicitly named preview/catalog checks and add production tests: no choices before/after settlement, no selection/confirmation/recruitment signals from stale direct calls, no escape/debug dismissal of pending gold. Production panel behavior belongs to the new UI/controller suites.
- [x] In the Scout flow runner add a production-session regression proving victory plus stale Scout requests leave roster identities, formation and wallet unchanged except for the committed gold award. Preserve full-roster placement/replacement coverage as isolated legacy/domain coverage; town tests will later exercise that infrastructure in the new flow.
- [x] Add writer/reader/acknowledged-reader process modes using only `user://ac83-reward-restart-test.json`. Writer wins and saves pending; a new process loads through the production launcher/repository, verifies the panel and no second award, then acknowledges; a third process verifies no panel and identical gold/recovery. Repeat for combat and boss. Do not touch the user's normal slot.
- [x] Run focused tests and relevant regressions listed below. Capture failures and unexpected parser/runtime errors even if process exit is zero. Reproduce the known preview stall separately if encountered; do not delete assertions or claim it passes.
- [x] Through GodotIQ play → verify_project_runs → debug console → state inspection, verify ordinary/boss victory and loss, pending reload, failed settlement Retry, failed acknowledgement Retry/Return, duplicate keyboard/pointer input and restored world input. Inspect panel, autosave overlay and debug/character-info layering. Use explore tour after scene changes and one screenshot per visual checkpoint; repeat affected checkpoints after fixes. Stop the game afterward.
- [x] Record rendered 1280×720 and 1920×1080 checks: visible money icon, exact amount, readable Continue with keyboard focus, no recruitment/item/rest controls, no clipped text and no modal input leakage. The world HUD total is 250g while the reward amount is 150g in the three-enemy fixture.
- [x] Run final project validation, project error check and orphan-signal inspection. Record existing warnings separately. Update AC8.3 status only after passing automated and runtime evidence. Reconcile stale AC8.1/AC8.2 summaries against their existing evidence without overwriting unrelated user edits; keep AC8.4–AC8.8 unchecked. Commit only relevant files and restore unrelated changes unstaged. Push only if requested.

## Test commands and acceptance matrix

Run from repository root; substitute each exact runner below. Require the runner's PASS output, exit 0 and no script/runtime errors. Use a 120-second external process timeout as well as the frame limit; timeout is a failed/incomplete run, not success.

```powershell
& 'D:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --quit-after 1800 --script res://Tests/Run/test_ac8_3_reward_acknowledgement.gd
```

Focused runners:

- `Tests/Run/test_ac8_3_reward_acknowledgement.gd`
- `Tests/Save/test_world_run_save_codec_v5.gd`
- `Tests/UI/test_ac8_gold_reward.gd`
- `Tests/WorldMap/test_ac8_3_reward_presentation.gd`
- `Tests/Run/test_ac8_3_reward_restart.gd` with `-- writer combat`, `-- reader combat`, `-- acknowledged-reader combat`, then the same three modes with `boss`.

Regression runners:

- `Tests/Run/test_ac8_economy.gd`, `Tests/Run/test_ac8_2_battle_settlement_rules.gd`, `Tests/Run/test_ac8_2_run_settlement_state.gd`
- `Tests/WorldMap/test_ac8_2_victory_settlement.gd`, `Tests/WorldMap/test_ac8_2_defeat_ends_run.gd`, `Tests/WorldMap/test_ac8_1_gold_runtime.gd`
- `Tests/Save/test_world_run_save_codec_v2.gd`, `Tests/Save/test_world_run_save_codec_v3.gd`, `Tests/Save/test_world_run_save_codec_v4.gd`
- `Tests/Run/test_world_single_slot_repository.gd`, `Tests/Run/test_world_production_launcher.gd`, `Tests/Run/test_world_run_start_service.gd`, `Tests/WorldMap/test_world_runtime_save_coordinator.gd`
- `Tests/Run/test_ac8_2_terminal_launcher.gd` in separate `-- writer` / `-- reader` processes
- `Tests/Battle/test_ac2_5_reward_selection.gd`, `Tests/WorldMap/test_scout_recruitment_flow.gd`, `Tests/WorldMap/test_ac3_5_recovery_integration.gd`
- `Tests/Run/test_ac3_1_run_roster.gd`, `Tests/Run/test_ac3_3_party_formation.gd`, `Tests/UI/test_world_autosave_failure_overlay.gd`, `Tests/UI/test_ac6_6_preparation_ui.gd`
- `Tests/Battle/test_ac7_4_debug_drawer.gd`, `Tests/Battle/test_battle_character_inspection.gd`, `Tests/WorldMap/test_world_production_scene.gd`

| Acceptance case | Required result / evidence |
|---|---|
| Ordinary or boss victory, 3 distinct enemies | 150g displayed with icon, wallet 250g, one receipt, recovery applied once; domain + integration + rendered |
| Failed settlement / repeated result | No panel or partial live mutation; retry same bytes, then one panel and one award |
| Continue / duplicate Continue | One acknowledgement save; no wallet, HP, formation, move or receipt change |
| Failed acknowledgement / Retry | Panel and input block retained; durable pending remains on every failed retry; only a successful persisted acknowledgement dismisses once |
| Failed acknowledgement / Return / restart | Return preserves pending checkpoint; next Continue restores panel without another award |
| Reload before / after acknowledgement | Same amount and blocked world / no panel and normal existing post-battle route |
| Boss pending reward | No rematch or new preparation; reward precedes downstream routing |
| Old V2–V4 save | Existing compatibility retained, no retroactive reward panel |
| Corrupt V5 or attempted downgrade with pending reward | Explicit rejection, never silent loss of pending state |
| Defeat after partial enemy kills | No reward panel; unchanged terminal loss and Continue rejection |
| Legacy reward/Scout calls in production | No rewards, recruit placement, roster change or acknowledgement bypass |
| Escape, debug exit, direct close, stale session callback | Cannot bypass current pending presentation or mutate a replacement session |

## Design exit criteria

AC8.3 is not accepted until **all** of these gates pass on the implementation revision recorded in `Docs/Specs/AC8/Evidence/AC8.3/verification.md`:

- [x] **Automated gate:** all five focused runners and every runner in the Regression runners list above pass with exit 0, explicit PASS output and no script/runtime errors. Run all six combat/boss restart modes and both terminal-launcher modes. A failure or timeout in this required set keeps the gate open; a historical PASS or an unrelated preview-runner limitation does not waive it.
- [x] **Transition gate:** map every row in the authoritative transition table to a named test and passing result. Include repeated failed retries, discard-in-world, Return/reload, duplicate/stale acknowledgement and old UI/publication callbacks after session replacement. Prove only a successful persisted acknowledgement clears pending state.
- [x] **Compatibility gate:** V2–V4 fixtures preserve their contracts; V5 round-trips its one added field; malformed pending fields, unsupported future versions and pending-state downgrade attempts reject. Record pending and acknowledged restart results without a second award or recovery.
- [x] **Presentation gate:** rendered evidence at both specified resolutions verifies icon, exact receipt amount, keyboard/pointer Continue, correct layering and blocking, reload restoration and the absence of production reward choices. Verify ordinary and boss wins and losses through the production session path.
- [x] **Scope and routing gate:** implementation review confirms that no new campaign-completion screen, completion scene or replacement completion flow was added. Boss rewards use the existing post-battle destination only after acknowledgement; town recruitment and AC8.4–AC8.8 remain outside this acceptance claim.
- [x] **Project and evidence gate:** final GodotIQ validation, error and orphan-signal checks identify no new attributable issues; pre-existing warnings are documented. Evidence names the tested revision, exact commands, outcomes, transition-test mapping and inspected screenshots. Only then update AC8.3 acceptance status.

Execution self-review: all six tasks and exit gates are satisfied by the linked verification record. Scene inspection used rendered process captures after the GodotIQ 3D tour/screenshot bridge timed out; the bridge was used successfully for launch, state and error checks. No campaign-completion screen was added.
