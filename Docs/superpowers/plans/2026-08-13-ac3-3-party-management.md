# AC3.3 Party Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add fixed six-slot run formations, persistent drag-and-drop party management, character inspection, and cancellable chosen-slot recruitment.

**Architecture:** `RunRoster` becomes the single authoritative nullable six-slot formation while retaining occupied-snapshot compatibility. A scene-owned `PartyManagement` overlay reports typed drag/drop intent to `MapController`, which owns both run mutation and pending recruitment. `BattleArena` suspends recruitment confirmation until MapController either restores the reward after cancellation or completes it after exact-slot placement.

**Tech Stack:** Godot 4.7, typed GDScript, scene-owned Control UI, native Control drag/drop virtuals, GodotIQ structured scene/script operations, headless SceneTree tests, Markdown evidence.

---

## Scope and file map

- Modify `Scripts/Run/run_roster.gd`: fixed six-slot storage and explicit add/move APIs.
- Modify `Tests/Run/test_ac3_1_run_roster.gd`: migrate AC3.1 compatibility assertions to explicit slots.
- Create `Tests/Run/test_ac3_3_party_formation.gd`: fixed-slot domain contract.
- Create `Scripts/Party/party_slot.gd`: one scene-owned slot/card drag source and drop target.
- Create `Scripts/Party/party_management.gd`: normal/placement modes, selection, details, and typed intent signals.
- Create `Scenes/party_management.tscn`: full-screen approved layout with six slots, pending recruit, details, and controls.
- Create `Tests/UI/test_ac3_3_party_management.gd`: scene interaction/presentation contract.
- Modify `Scripts/Battle/battle_arena.gd`: suspend, restore, and complete recruitment reward transactions.
- Modify `Tests/Battle/test_ac2_5_reward_selection.gd`: preserve AC2.5 and prove suspended recruitment ordering.
- Modify `Scripts/Map/map_controller.gd`: overlay ownership, map button gating, formation moves, and pending recruitment ownership.
- Modify `Scenes/game_world.tscn`: persistent Manage Party button.
- Modify `Tests/Map/test_ac3_1_recruitment_integration.gd`: replace automatic append assertions with placement flow.
- Create `Tests/Map/test_ac3_3_party_management_integration.gd`: full map/party/battle transaction coverage.
- Modify `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` and create AC3.3/AC3.1 evidence artifacts only after all gates pass.

## Task 1: Establish the implementation branch and baseline

- [ ] **Step 1: Preserve unrelated work and create the feature branch**

From the approved design branch, keep the two unrelated UID files unstaged and create:

```powershell
git switch -c feat/ac3-3-party-management
git status --short --branch
```

Expected: the feature branch contains both approved design commits; only the two pre-existing UID files are untracked.

- [ ] **Step 2: Run the baseline corpus**

```powershell
$testScripts = rg --files Tests -g 'test_*.gd' | Sort-Object
foreach ($testScript in $testScripts) {
    & godot --headless --path . --script ("res://" + ($testScript -replace '\\','/'))
    if ($LASTEXITCODE -ne 0) { throw "FAILED: $testScript" }
}
```

Expected: every existing runner exits `0`. Record any pre-existing failure before changing code.

- [ ] **Step 3: Run the GodotIQ baseline**

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(scope="all", find="orphans", detail="brief")
```

Expected: no parser errors; record existing warnings/orphans verbatim.

## Task 2: Migrate RunRoster to fixed slots with TDD

**Files:** `Scripts/Run/run_roster.gd`, `Tests/Run/test_ac3_1_run_roster.gd`, `Tests/Run/test_ac3_3_party_formation.gd`

- [ ] **Step 1: Inspect impact before modification**

```text
file_context(file="res://Scripts/Run/run_roster.gd", detail="normal")
impact_check(file="res://Scripts/Run/run_roster.gd", action="change_public_api", target="try_add", change_description="Replace compact roster addition with explicit fixed-slot placement while preserving occupied snapshots and battle conversion", detail="normal")
dependency_graph(target="res://Scripts/Run/run_roster.gd", depth=4, detail="brief")
```

- [ ] **Step 2: Write the new failing domain runner**

Create `test_ac3_3_party_formation.gd` with cases that assert:

```gdscript
var roster := RunRoster.new()
var slots := roster.get_slot_snapshot()
_expect(slots.size() == 6, "snapshot exposes six slots")
_expect(slots[0].character_id == &"player_0", "starter 0 keeps slot 0")
_expect(slots[1].character_id == &"player_1", "starter 1 keeps slot 1")
_expect(slots[2].character_id == &"player_2", "starter 2 keeps slot 2")
_expect(slots[3] == null and slots[4] == null and slots[5] == null, "remaining slots are empty")

var scout := RunCharacterCatalog.create_for_reward(&"combat_recruit_scout")
_expect(roster.try_add_at(scout, 5) == RunRoster.AddResult.ADDED, "explicit empty placement succeeds")
_expect(roster.try_move(0, 5, &"player_0") == RunRoster.MoveResult.SWAPPED, "occupied drop swaps")
_expect(roster.try_move(5, 4, &"player_0") == RunRoster.MoveResult.MOVED, "empty drop moves")
```

Add independent assertions for invalid indices, occupied addition, duplicate addition, same-slot, empty source, stale source ID, defensive snapshot mutation, occupied `get_characters()` order, size/full invariants, and `create_battle_units()` preserving gaps.

- [ ] **Step 3: Run RED**

```powershell
godot --headless --path . --script res://Tests/Run/test_ac3_3_party_formation.gd
```

Expected: non-zero because slot APIs do not exist.

- [ ] **Step 4: Implement the fixed-slot domain through GodotIQ**

Use `script_ops` to replace compact storage with:

```gdscript
enum AddResult { ADDED, INVALID, DUPLICATE, FULL, INVALID_SLOT, OCCUPIED }
enum MoveResult { MOVED, SWAPPED, INVALID_SLOT, EMPTY_SOURCE, STALE_SOURCE, SAME_SLOT }

const MAX_ROSTER_SIZE := 6
var _slots: Array[RunCharacter] = [null, null, null, null, null, null]

func _init(starters: Array[RunCharacter] = []) -> void:
    var initial := RunCharacterCatalog.create_starters() if starters.is_empty() else starters.duplicate()
    for slot_index: int in min(initial.size(), MAX_ROSTER_SIZE):
        _slots[slot_index] = initial[slot_index]

func try_add_at(character: RunCharacter, slot_index: int) -> AddResult:
    if not is_instance_valid(character) or character.character_id.is_empty():
        return AddResult.INVALID
    if not _is_valid_slot(slot_index):
        return AddResult.INVALID_SLOT
    if has_character(character.character_id):
        return AddResult.DUPLICATE
    if is_full():
        return AddResult.FULL
    if is_instance_valid(_slots[slot_index]):
        return AddResult.OCCUPIED
    _slots[slot_index] = character
    return AddResult.ADDED

func try_move(source_slot: int, destination_slot: int, expected_character_id: StringName) -> MoveResult:
    if not _is_valid_slot(source_slot) or not _is_valid_slot(destination_slot):
        return MoveResult.INVALID_SLOT
    if source_slot == destination_slot:
        return MoveResult.SAME_SLOT
    var source := _slots[source_slot]
    if not is_instance_valid(source):
        return MoveResult.EMPTY_SOURCE
    if source.character_id != expected_character_id:
        return MoveResult.STALE_SOURCE
    var destination := _slots[destination_slot]
    _slots[destination_slot] = source
    _slots[source_slot] = destination
    return MoveResult.SWAPPED if is_instance_valid(destination) else MoveResult.MOVED
```

Implement the remaining approved API exactly. `get_slot_snapshot()` duplicates the six-entry array; `get_characters()` filters occupied slots in ascending index; battle conversion uses the actual loop index.

- [ ] **Step 5: Migrate AC3.1 tests and callers**

Replace direct `try_add(character)` calls with explicit `try_add_at(character, empty_slot)`. Preserve AC3.1 catalog, duplicate, capacity, reset, and defensive-copy assertions. Do not change production MapController yet; the integration runner remains RED until Task 6.

- [ ] **Step 6: Validate and run GREEN**

```text
validate(target="res://Scripts/Run/run_roster.gd", detail="brief")
check_errors(scope="res://Scripts/Run/run_roster.gd")
```

```powershell
godot --headless --path . --script res://Tests/Run/test_ac3_3_party_formation.gd
godot --headless --path . --script res://Tests/Run/test_ac3_1_run_roster.gd
```

Expected: both print documented PASS signatures and exit `0`.

- [ ] **Step 7: Commit the domain migration**

```powershell
git add -- Scripts/Run/run_roster.gd Tests/Run/test_ac3_1_run_roster.gd Tests/Run/test_ac3_3_party_formation.gd
git commit -m "feat: add fixed-slot run formations"
```

## Task 3: Build PartySlot and PartyManagement scene with TDD

**Files:** `Scripts/Party/party_slot.gd`, `Scripts/Party/party_management.gd`, `Scenes/party_management.tscn`, `Tests/UI/test_ac3_3_party_management.gd`

- [ ] **Step 1: Write the failing real-scene runner**

Create a runner that loads `res://Scenes/party_management.tscn` and expects unique nodes for six slots, two row labels, pending recruit region, hidden details panel, name/HP/speed/skills fields, Return, and Cancel. Configure `[player_0, null, player_1, null, null, player_2]` and assert exact occupied/empty rendering, `20 / 20 HP`-style text, green HP fill, hidden details before click, details after click, and four-or-fewer skill rows.

Connect all four approved signals and call the public interaction boundaries to assert move payloads, placement payloads, close cleanup, and placement cancellation. Add direct drag-data tests for occupied-only sources, same-slot rejection, empty-only placement targets, and failed-drop cleanup.

- [ ] **Step 2: Run RED**

```powershell
godot --headless --path . --script res://Tests/UI/test_ac3_3_party_management.gd
```

Expected: scene missing.

- [ ] **Step 3: Create PartySlot script**

After `file_context` for any existing pattern used, create through `script_ops`:

```gdscript
class_name PartySlot
extends PanelContainer

signal character_clicked(slot_index: int, character_id: StringName)
signal character_dropped(source_slot: int, destination_slot: int, character_id: StringName)
signal pending_recruit_dropped(destination_slot: int, character_id: StringName)

var slot_index: int = -1
var character: RunCharacter
var drag_enabled: bool = false
var accepts_existing: bool = false
var accepts_pending: bool = false

func _get_drag_data(_at_position: Vector2) -> Variant:
    if not drag_enabled or not is_instance_valid(character):
        return null
    return {"source_slot": slot_index, "character_id": character.character_id, "pending": slot_index < 0}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
    if not data is Dictionary or not data.has("character_id"):
        return false
    return (
        accepts_pending and bool(data.get("pending", false))
        or accepts_existing and not bool(data.get("pending", false))
    )

func _drop_data(_at_position: Vector2, data: Variant) -> void:
    if not _can_drop_data(Vector2.ZERO, data):
        return
    if bool(data.get("pending", false)):
        pending_recruit_dropped.emit(slot_index, StringName(data["character_id"]))
    else:
        character_dropped.emit(int(data["source_slot"]), slot_index, StringName(data["character_id"]))
```

Add typed configure/clear/presentation helpers and click handling. HP displays `max_hp / max_hp`; no battle HP is retained.

- [ ] **Step 4: Build the approved scene through GodotIQ**

Run `scene_map` for existing UI conventions, then use `node_ops(validate=true)`/`build_scene` to create a full-rect Control with:

- Header and `ReturnToMapButton`.
- Back and Front labeled columns with `Slot0` through `Slot5` as scene-owned `PartySlot` nodes.
- Hidden `PendingRecruitRegion` containing one `PendingRecruitCard` and `CancelPlacementButton`.
- Hidden `DetailsPanel` below the formation with name, max HP, base speed, and `SkillsContainer`.
- Card-bottom green `ProgressBar` plus centered numeric HP label for every occupied card.

Save with `save_scene()`, then verify structure with `scene_map(focus="PartyManagement", radius=4, detail="brief")`.

- [ ] **Step 5: Implement PartyManagement**

Create the approved signals and methods. Use an enum `Mode { NORMAL, PLACEMENT }`. `configure_normal()` enables existing-character drag/drop and hides pending/cancel. `configure_placement()` locks existing drags, shows the pending recruit, and makes only empty slots accept pending data. `refresh_slots()` duplicates the six-entry snapshot and rebuilds presentation.

Selection must be stable by character ID after a successful normal refresh, but `_clear_transient_state()` hides details and clears selection/drag highlights on close. Placement mode never selects existing cards. Skill rows are presentation-only and use `RunCharacter.get_skills()`.

- [ ] **Step 6: Validate and run GREEN**

Validate/check each new script separately, validate the scene, run the UI runner, then run one editor visual tour after Play. Expected: exact approved layout, no initial details, readable bottom HP bars, and no overlap at 1152x648.

- [ ] **Step 7: Commit party UI**

```powershell
git add -- Scripts/Party/party_slot.gd Scripts/Party/party_management.gd Scenes/party_management.tscn Tests/UI/test_ac3_3_party_management.gd
git commit -m "feat: add drag and drop party management"
```

## Task 4: Suspend recruitment completion in BattleArena with TDD

**Files:** `Scripts/Battle/battle_arena.gd`, `Tests/Battle/test_ac2_5_reward_selection.gd`

- [ ] **Step 1: Run impact checks**

Use `file_context` and `impact_check` on `confirm_reward_selection`; trace `reward_confirmed` and `exit_requested` before editing.

- [ ] **Step 2: Add RED cases**

Extend AC2.5 tests so recruitment confirmation emits only `recruitment_placement_requested`, preserves selection, does not latch, and does not emit reward/exit. Assert `restore_pending_recruitment()` restores the visible selectable reward. Assert `complete_pending_recruitment()` emits `reward_confirmed` then `exit_requested` exactly once. Non-recruitment ordering remains unchanged.

- [ ] **Step 3: Implement the seam**

Add the approved signal/methods. Track `_pending_recruitment_option` inside the arena only as reward-UI suspension state; it is not the authoritative fresh recruit. Exact option identity and current selection must match before restore/complete. Reset this field in `configure()` and cleanup.

- [ ] **Step 4: Validate and run GREEN**

Run per-file GodotIQ gates and AC2.5. Expected: all previous cases plus suspended recruitment cases pass.

- [ ] **Step 5: Commit**

```powershell
git add -- Scripts/Battle/battle_arena.gd Tests/Battle/test_ac2_5_reward_selection.gd
git commit -m "feat: suspend recruitment for slot placement"
```

## Task 5: Add persistent map access and normal rearrangement integration

**Files:** `Scenes/game_world.tscn`, `Scripts/Map/map_controller.gd`, `Tests/Map/test_ac3_3_party_management_integration.gd`

- [ ] **Step 1: Inspect scene and impact**

Run `scene_map` on `game_world.tscn`, `file_context` on `map_controller.gd`, and impact checks for overlay ownership and battle creation.

- [ ] **Step 2: Write RED normal-mode integration cases**

Load the real world scene and assert Manage Party button gating, one overlay only, six-slot snapshot, move signal routing, immediate roster refresh, close cleanup, no selection on reopen, exact battle units after a swap, and exact battle units after a move into an empty slot.

- [ ] **Step 3: Add scene-owned persistent button**

Use GodotIQ scene operations to add a minimum-48px `ManagePartyButton` under the existing UI layer without covering the turn counter. Save and visually verify.

- [ ] **Step 4: Implement normal overlay ownership**

Add `_party_management_scene`, `_active_party_management`, `has_active_party_management()`, `get_active_party_management()`, `open_party_management()`, and `close_party_management()`. Gate the button and map movement consistently with encounter/battle overlays. Connect `move_requested` to a handler that calls `try_move`, refreshes regardless of result, and never trusts the scene snapshot.

- [ ] **Step 5: Validate and run GREEN**

Run per-script/scene gates, the new integration runner's normal cases, AC3.1 domain/integration, and map runtime tests.

- [ ] **Step 6: Commit**

```powershell
git add -- Scenes/game_world.tscn Scripts/Map/map_controller.gd Tests/Map/test_ac3_3_party_management_integration.gd
git commit -m "feat: integrate persistent party management"
```

## Task 6: Integrate cancellable chosen-slot recruitment

**Files:** `Scripts/Map/map_controller.gd`, `Tests/Map/test_ac3_1_recruitment_integration.gd`, `Tests/Map/test_ac3_3_party_management_integration.gd`

- [ ] **Step 1: Add RED transaction cases**

Assert that confirming Scout below capacity opens placement without roster mutation or battle exit; occupied and stale drops fail; Cancel closes placement, clears MapController pending fields, and restores unchanged reward selection; reopening and placing at slot 5 adds once and exits; next battle uses slot 5; repeated completion is inert; run reset/battle exit/tree teardown clear pending state.

- [ ] **Step 2: Implement MapController transaction ownership**

Add typed pending fields and one idempotent `_clear_pending_recruitment()`. Connect the arena's placement signal during battle creation. Resolve reward IDs through `RunCharacterCatalog`, reject concurrent transactions, and open placement mode. On cancel, retain local option long enough to restore the live arena, then clear. On successful exact-slot add, clear party/pending state and call arena completion. Rejected placement refreshes slots and remains open.

- [ ] **Step 3: Remove automatic recruitment mutation**

Delete the old immediate `_run_roster.try_add(recruit)` behavior from `_on_reward_confirmed`. Keep the signal consumer compatible as an observation/no-op for recruitment completion; money/item remain roster no-ops. Change eligibility so valid non-owned recruitment remains available below capacity even when compact order contains gaps.

- [ ] **Step 4: Migrate AC3.1 integration expectations**

Replace “Scout automatically becomes fourth” with: pending placement leaves three members; cancel leaves three; placement in explicit slot adds once; next battle preserves that slot. Keep duplicate filtering, full filtering, run reset, and reward-alternative coverage.

- [ ] **Step 5: Validate and run GREEN**

Run MapController GodotIQ gates, AC3.1 integration, AC3.3 integration, AC2.5, and both roster runners. Expected: every runner exits `0` with documented signatures.

- [ ] **Step 6: Commit**

```powershell
git add -- Scripts/Map/map_controller.gd Tests/Map/test_ac3_1_recruitment_integration.gd Tests/Map/test_ac3_3_party_management_integration.gd
git commit -m "feat: place recruits into chosen party slots"
```

## Task 7: Full verification and visual QA

- [ ] **Step 1: Run the complete headless corpus**

Use the Task 1 discovery loop. Expected: every runner exits `0`.

- [ ] **Step 2: Run project-wide GodotIQ gates**

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(scope="all", find="missing", detail="brief")
signal_map(scope="all", find="orphans", detail="brief")
```

Expected: no new parser, convention, missing-signal, or orphan-signal defect.

- [ ] **Step 3: Run mandatory Play verification**

```text
run(action="play")
verify_project_runs(scene="main", check_scope="project", stop_after=false)
read_debug_console()
```

- [ ] **Step 4: Verify normal mode with real input**

Open Manage Party, confirm details hidden, click one card, inspect max HP/base speed/skills, drag occupied-to-occupied, drag occupied-to-empty, close, reopen, confirm details hidden and formation persisted, then enter battle and inspect exact semantic slots.

- [ ] **Step 5: Verify placement mode with real input**

Win Combat, select Scout, Confirm, verify no early roster mutation, Cancel, verify rewards restored, reopen placement, drag Scout to a chosen empty slot, and verify the following battle uses exactly that slot.

- [ ] **Step 6: Visual tour**

Run `explore(mode="tour")`; verify two labeled formation columns, readable cards, green numeric bottom HP bars, hidden/revealed details behavior, pending card, drop feedback, and 1152x648 fit. Fix any issue with a failing regression first, then repeat affected gates. Stop Play.

## Task 8: Record completion evidence and canonical status

**Files:** canonical spec and exact evidence paths from the approved design.

- [ ] **Step 1: Capture automated evidence**

Create `Docs/Specs/AC3/Evidence/AC3.3/2026-08-13/automated-test.log` with exact commands, exit codes, PASS signatures, GodotIQ results, runtime result, and tested implementation SHA.

- [ ] **Step 2: Record binary manual evidence**

Create `manual-runtime-check.md` with PASS/FAIL/BLOCKED lines for every approved manual gate. Any unavailable or failed gate makes Overall non-PASS.

- [ ] **Step 3: Amend AC3.1 evidence without rewriting history**

Create `Docs/Specs/AC3/Evidence/AC3.1/2026-08-13/ac3-3-placement-amendment.md`, identify the original evidence boundary, and record current chosen-slot/cancel regression results and implementation SHA.

- [ ] **Step 4: Update the canonical spec only after PASS**

Mark only AC3.3 checked, install the exact approved AC3.3 verification row, and update AC3.1's row to reference current pending-placement regression coverage. Leave AC3.2 unchecked.

- [ ] **Step 5: Record implementation link and self-review**

Write the full tested SHA to `implementation-link.txt`. Run placeholder scan, `git diff --check`, evidence/spec ID search, and confirm all evidence names the same SHA.

- [ ] **Step 6: Commit documentation**

```powershell
git add -- Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC3/Evidence/AC3.1/2026-08-13/ac3-3-placement-amendment.md Docs/Specs/AC3/Evidence/AC3.3/2026-08-13
git commit -m "docs: record AC3.3 completion evidence"
```

## Final completion boundary

Do not claim AC3.3 complete unless the same implementation commit has focused domain/UI/integration PASS, full-corpus PASS, GodotIQ project/signal PASS, live normal and recruitment flows PASS, visual QA PASS, exact-slot next-battle proof, and matching evidence. Any stale placement, early reward completion, missing cancellation restoration, incorrect semantic slot, visible details on reopen, parser/runtime error, or unavailable required capability keeps AC3.3 unchecked.
