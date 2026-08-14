# AC3.2 Full-Roster Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep valid recruitment rewards available at six characters and require one atomic, cancellable party-member replacement before recruitment completes.

**Architecture:** Extend the existing AC3.3 `PartyManagement` scene with `Mode.REPLACEMENT`, keeping `MapController` as pending-transaction owner and `RunRoster` as the only roster mutator. Reuse `BattleArena`'s existing suspend/restore/complete API unchanged; route below-capacity recruits to placement mode and full rosters to replacement mode.

**Tech Stack:** Godot 4, typed GDScript, GodotIQ structured scene/script tools, headless `SceneTree` acceptance runners, PowerShell, Git.

---

## Preconditions and file map

Begin in the primary workspace; this repository forbids Git worktrees. Preserve the two unrelated untracked UID files and do not stage them:

```text
Tests/Battle/test_active_turn_skill_lock.gd.uid
Tests/Map/test_world_turn_counter.gd.uid
```

The design is committed on `feat/ac3-2-full-roster-replacement` at `8810ee7`. Before implementation, verify that this branch is current with `main`; do not create a second branch.

Files and responsibilities:

- Modify `Scripts/Run/run_roster.gd`: define typed atomic replacement results and mutation.
- Modify `Tests/Run/test_ac3_3_party_formation.gd`: prove replacement invariants and failure immutability.
- Modify `Scripts/Party/party_slot.gd`: permit explicitly configured pending-on-occupied drops and render destructive feedback.
- Modify `Scripts/Party/party_management.gd`: add `Mode.REPLACEMENT`, configuration, typed intent, selection, cancellation, and cleanup.
- Modify `Tests/UI/test_ac3_3_party_management.gd`: verify the shared scene's replacement-mode contract and AC3.3 regressions.
- Modify `Scripts/Map/map_controller.gd`: retain eligible recruits at capacity and route/commit/cancel the replacement transaction.
- Modify `Tests/Map/test_ac3_1_recruitment_integration.gd`: replace the superseded full-roster filtering expectation.
- Modify `Tests/Map/test_ac3_3_party_management_integration.gd`: verify full-roster reward, replacement, cancel, stale/repeated, exact-slot, and teardown behavior.
- Modify `Docs/TO_CONSIDER.md`: resolve TC-002 and keep TC-001's no-duplicate rule explicit.
- Modify `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`: check AC3.2 and install its final verification row only after all gates pass.
- Create `Docs/Specs/AC3/Evidence/AC3.2/2026-08-14/automated-test.log`: exact automated evidence.
- Create `Docs/Specs/AC3/Evidence/AC3.2/2026-08-14/manual-runtime-check.md`: binary pointer/visual/runtime evidence.
- Create `Docs/Specs/AC3/Evidence/AC3.2/2026-08-14/implementation-link.txt`: tested implementation commit.

Do not modify `Scripts/Battle/battle_arena.gd`. Its current `recruitment_placement_requested`, `restore_pending_recruitment()`, and `complete_pending_recruitment()` contract already supports both placement and replacement.

### Task 1: Add atomic full-roster replacement to `RunRoster`

**Files:**

- Modify: `Tests/Run/test_ac3_3_party_formation.gd`
- Modify: `Scripts/Run/run_roster.gd`

- [ ] **Step 1: Inspect the domain files and impact before editing**

Use GodotIQ:

```text
file_context(res://Scripts/Run/run_roster.gd, detail=brief)
file_context(res://Tests/Run/test_ac3_3_party_formation.gd, detail=brief)
impact_check(res://Scripts/Run/run_roster.gd, action=add_function, target=try_replace_at, change_description="add atomic full-roster replacement with typed rejection results")
```

Expected: `RunRoster` owns six semantic slots; no replacement API exists; callers depend on snapshots and exact battle slot conversion.

- [ ] **Step 2: Write failing replacement assertions**

Increase `EXPECTED_TEST_COUNT` from `24` to `36`. Immediately after the assertion that additions reach full capacity, append:

```gdscript
	var replacement := _character(&"replacement", "Replacement")
	_expect(
		roster.try_replace_at(replacement, 4, &"player_0") == RunRoster.ReplaceResult.REPLACED,
		"full roster replacement succeeds"
	)
	_expect(roster.size() == 6, "replacement preserves size six")
	_expect(roster.get_character_at(4) == replacement, "replacement preserves target slot")
	_expect(not roster.has_character(&"player_0") and roster.has_character(&"replacement"), "replacement updates membership")
	_expect(_unit_id_at(roster.create_battle_units(), 4) == &"replacement", "battle conversion uses replaced slot")

	var replaced_snapshot := roster.get_slot_snapshot()
	_expect(
		roster.try_replace_at(_character(&"invalid_slot", "Invalid"), -1, &"replacement") == RunRoster.ReplaceResult.INVALID_SLOT
		and _same_slots(replaced_snapshot, roster.get_slot_snapshot()),
		"invalid replacement slot is mutation-free"
	)
	_expect(
		roster.try_replace_at(null, 4, &"replacement") == RunRoster.ReplaceResult.INVALID_RECRUIT
		and _same_slots(replaced_snapshot, roster.get_slot_snapshot()),
		"invalid recruit is mutation-free"
	)
	_expect(
		roster.try_replace_at(_character(&"player_1", "Duplicate"), 4, &"replacement") == RunRoster.ReplaceResult.DUPLICATE
		and _same_slots(replaced_snapshot, roster.get_slot_snapshot()),
		"duplicate replacement is mutation-free"
	)
	_expect(
		roster.try_replace_at(_character(&"stale", "Stale"), 4, &"player_0") == RunRoster.ReplaceResult.STALE_TARGET
		and _same_slots(replaced_snapshot, roster.get_slot_snapshot()),
		"stale target is mutation-free"
	)
	_expect(
		roster.try_replace_at(replacement, 4, &"replacement") == RunRoster.ReplaceResult.DUPLICATE
		and _same_slots(replaced_snapshot, roster.get_slot_snapshot()),
		"repeated replacement is mutation-free"
	)

	var non_full := RunRoster.new()
	var non_full_before := non_full.get_slot_snapshot()
	_expect(
		non_full.try_replace_at(_character(&"early", "Early"), 0, &"player_0") == RunRoster.ReplaceResult.NOT_FULL
		and _same_slots(non_full_before, non_full.get_slot_snapshot()),
		"non-full roster replacement is rejected"
	)
	_expect(
		not roster.has_character(&"player_0"),
		"dismissed character is absent and may be eligible later"
	)
```

Add these helpers before `_expect()`:

```gdscript
func _unit_id_at(units: Array[BattleUnitState], slot_index: int) -> StringName:
	for unit: BattleUnitState in units:
		if unit.slot_index == slot_index:
			return unit.unit_id
	return &""


func _same_slots(left: Array[RunCharacter], right: Array[RunCharacter]) -> bool:
	if left.size() != right.size():
		return false
	for slot_index: int in left.size():
		if left[slot_index] != right[slot_index]:
			return false
	return true
```

- [ ] **Step 3: Run the focused test and verify failure**

Run:

```powershell
godot --headless --path . --script res://Tests/Run/test_ac3_3_party_formation.gd
```

Expected: FAIL with `Invalid call. Nonexistent function 'try_replace_at'` or missing `RunRoster.ReplaceResult`; the pre-existing assertions must not fail first.

- [ ] **Step 4: Implement the minimal atomic domain API**

Use GodotIQ `script_ops(op="patch")`, not a raw filesystem write. Add after `MoveResult`:

```gdscript
enum ReplaceResult {
	REPLACED,
	INVALID_RECRUIT,
	DUPLICATE,
	NOT_FULL,
	INVALID_SLOT,
	EMPTY_TARGET,
	STALE_TARGET,
}
```

Add after `try_add_at()`:

```gdscript
func try_replace_at(
	recruit: RunCharacter,
	slot_index: int,
	expected_character_id: StringName
) -> ReplaceResult:
	if not is_instance_valid(recruit) or recruit.character_id.is_empty():
		return ReplaceResult.INVALID_RECRUIT
	if not _is_valid_slot(slot_index):
		return ReplaceResult.INVALID_SLOT
	if not is_full():
		return ReplaceResult.NOT_FULL
	var target: RunCharacter = _slots[slot_index]
	if not is_instance_valid(target):
		return ReplaceResult.EMPTY_TARGET
	if target.character_id != expected_character_id:
		return ReplaceResult.STALE_TARGET
	if has_character(recruit.character_id):
		return ReplaceResult.DUPLICATE
	_slots[slot_index] = recruit
	return ReplaceResult.REPLACED
```

The validation order is part of the test contract: malformed recruit and slot are reported before full-state/target checks; no assignment occurs until all validation passes.

- [ ] **Step 5: Validate and run the focused test**

Use:

```text
validate(target=res://Scripts/Run/run_roster.gd, detail=brief)
check_errors(scope=res://Scripts/Run/run_roster.gd)
```

Then run:

```powershell
godot --headless --path . --script res://Tests/Run/test_ac3_3_party_formation.gd
```

Expected: `AC3.3 party formation tests: PASS (36/36)` and no parser/script errors.

- [ ] **Step 6: Commit the domain change**

```powershell
git add -- Scripts/Run/run_roster.gd Tests/Run/test_ac3_3_party_formation.gd
git diff --cached --check
git commit -m "feat: add atomic roster replacement"
```

### Task 2: Add replacement behavior to the shared party interface

**Files:**

- Modify: `Tests/UI/test_ac3_3_party_management.gd`
- Modify: `Scripts/Party/party_slot.gd`
- Modify: `Scripts/Party/party_management.gd`
- Modify through GodotIQ only if properties cannot be set from the script: `Scenes/party_management.tscn`

- [ ] **Step 1: Inspect scripts, scene, and signal impact**

Use:

```text
file_context(res://Scripts/Party/party_slot.gd, detail=brief)
file_context(res://Scripts/Party/party_management.gd, detail=brief)
file_context(res://Tests/UI/test_ac3_3_party_management.gd, detail=brief)
scene_map(res://Scenes/party_management.tscn, focus=Margin/VBox, radius=4, detail=brief)
impact_check(res://Scripts/Party/party_management.gd, action=add_signal, target=replacement_requested, change_description="add typed full-roster replacement intent")
```

Expected: the existing `InstructionLabel`, `PendingRecruitRegion`, pending card, six slots, details panel, and Cancel button can be reused without adding a parallel scene.

- [ ] **Step 2: Write failing scene-contract tests**

Increase `EXPECTED_TEST_COUNT` from `19` to `31`. Add a static enum assertion plus the replacement checks below:

```gdscript
var _replacement_events: Array[Variant] = []
```

Connect the new signal with the existing signal setup:

```gdscript
	party.connect("replacement_requested", _on_replacement_requested)
```

After the placement cancellation assertion, construct a full formation and add:

```gdscript
	var full_slots: Array[RunCharacter] = []
	for slot_index: int in 6:
		full_slots.append(_character(StringName("full_%d" % slot_index), "Full %d" % slot_index))
	party.call("configure_replacement", full_slots, scout)
	await process_frame
	_expect((party.get_node("%PendingRecruitRegion") as Control).visible, "replacement shows pending recruit")
	_expect((party.get_node("%CancelPlacementButton") as Button).text == "Cancel Replacement", "replacement labels cancel action")
	_expect((party.get_node("%InstructionLabel") as Label).text.contains("replace"), "replacement explains destructive drop")
	party.call("select_character", 0, full_slots[0].character_id)
	_expect((party.get_node("%DetailsPanel") as Control).visible, "replacement permits target inspection")
	party.call("request_move", 0, 1, full_slots[0].character_id)
	_expect(_move_events.size() == 1, "replacement blocks existing-member movement")
	party.call("request_placement", 0, scout.character_id)
	_expect(_placement_events.size() == 1, "replacement does not emit empty-slot placement")
	party.call("request_replacement", 0, full_slots[0].character_id, scout.character_id)
	_expect(
		_replacement_events.size() == 1
		and _replacement_events[0] == [0, full_slots[0].character_id, scout.character_id],
		"replacement emits exact target and recruit identities"
	)
	party.call("request_replacement", 0, &"stale", scout.character_id)
	party.call("request_replacement", 0, full_slots[0].character_id, &"wrong")
	party.call("request_replacement", -1, full_slots[0].character_id, scout.character_id)
	_expect(_replacement_events.size() == 1, "invalid and stale replacement requests are rejected")
	party.call("request_placement_cancel")
	_expect(_cancelled and not (party.get_node("%DetailsPanel") as Control).visible, "replacement cancel clears details and emits")
	party.call("configure_normal", slots)
	await process_frame
	_expect(not (party.get_node("%PendingRecruitRegion") as Control).visible, "normal reconfiguration clears replacement presentation")
	_expect((party.get_node("%ReturnToMapButton") as Control).visible, "normal mode retains Return to Map")
```

Add helpers:

```gdscript
func _on_replacement_requested(
	destination_slot: int,
	expected_character_id: StringName,
	expected_recruit_id: StringName
) -> void:
	_replacement_events.append([destination_slot, expected_character_id, expected_recruit_id])


func _character(id: StringName, display_name: String) -> RunCharacter:
	var skills: Array[CharacterSkill] = []
	return RunCharacter.new(id, display_name, 5, 20, skills)
```

Reset `_cancelled = false` immediately before configuring replacement so its cancellation assertion proves a new emission.

- [ ] **Step 3: Run the focused UI test and verify failure**

Run:

```powershell
godot --headless --path . --script res://Tests/UI/test_ac3_3_party_management.gd
```

Expected: FAIL because `replacement_requested`, `configure_replacement()`, and `request_replacement()` do not exist.

- [ ] **Step 4: Extend `PartySlot` for explicit destructive pending targets**

Use GodotIQ `script_ops(op="patch")`. Add:

```gdscript
const REPLACEMENT_DROP_COLOR := Color(0.88, 0.23, 0.23)

var pending_replaces: bool = false
```

Extend `configure()` with a final defaulted argument and assignment:

```gdscript
func configure(
	index: int,
	value: RunCharacter,
	can_drag: bool,
	can_accept_existing: bool,
	can_accept_pending: bool,
	pending_will_replace: bool = false
) -> void:
	# Preserve the existing assignments.
	pending_replaces = pending_will_replace
```

Replace the border-color selection with:

```gdscript
	var highlighted_color := REPLACEMENT_DROP_COLOR if pending_replaces else DROP_COLOR
	var border_color := highlighted_color if drop_highlighted else SELECTED_COLOR if selected else Color(0.29, 0.35, 0.44)
```

Remove this unconditional rejection from `_can_drop_data()`:

```gdscript
	if pending and is_instance_valid(character):
		accepted = false
```

Target validity must come only from the mode-specific `accepts_pending` value supplied by `PartyManagement`: placement sets it only for empty slots, replacement only for occupied slots.

- [ ] **Step 5: Extend `PartyManagement` with `Mode.REPLACEMENT`**

Use GodotIQ `script_ops(op="patch")`. Add:

```gdscript
signal replacement_requested(
	destination_slot: int,
	expected_character_id: StringName,
	expected_recruit_id: StringName
)
```

Add `REPLACEMENT` to `Mode`, add an on-ready reference to the existing label, and add configuration:

```gdscript
@onready var _instruction_label: Label = %InstructionLabel


func configure_replacement(slots: Array[RunCharacter], pending_recruit: RunCharacter) -> void:
	_mode = Mode.REPLACEMENT
	_pending_recruit = pending_recruit
	_set_slots(slots)
	_clear_transient_state()
	_refresh_presentation()
```

Allow selection in normal and replacement modes:

```gdscript
	if (_mode != Mode.NORMAL and _mode != Mode.REPLACEMENT) or slot_index < 0 or slot_index >= SLOT_COUNT:
		return
```

Add the guarded intent:

```gdscript
func request_replacement(
	destination_slot: int,
	expected_character_id: StringName,
	expected_recruit_id: StringName
) -> void:
	if (
		_mode != Mode.REPLACEMENT
		or not is_instance_valid(_pending_recruit)
		or _pending_recruit.character_id != expected_recruit_id
		or destination_slot < 0
		or destination_slot >= SLOT_COUNT
	):
		return
	var target: RunCharacter = _slots[destination_slot]
	if not is_instance_valid(target) or target.character_id != expected_character_id:
		return
	replacement_requested.emit(destination_slot, expected_character_id, expected_recruit_id)
```

In `_ready()`, route `pending_recruit_dropped` to a private mode-aware handler instead of directly to `request_placement`:

```gdscript
		slot.pending_recruit_dropped.connect(_on_pending_recruit_dropped)
```

Add:

```gdscript
func _on_pending_recruit_dropped(destination_slot: int, recruit_id: StringName) -> void:
	if _mode == Mode.PLACEMENT:
		request_placement(destination_slot, recruit_id)
		return
	if _mode != Mode.REPLACEMENT or destination_slot < 0 or destination_slot >= SLOT_COUNT:
		return
	var target: RunCharacter = _slots[destination_slot]
	if is_instance_valid(target):
		request_replacement(destination_slot, target.character_id, recruit_id)
```

Allow the existing cancel signal in both transactional modes:

```gdscript
func request_placement_cancel() -> void:
	if _mode != Mode.PLACEMENT and _mode != Mode.REPLACEMENT:
		return
	_clear_transient_state()
	placement_cancelled.emit()
```

In `_refresh_presentation()`, configure each slot with these exact booleans:

```gdscript
		var occupied := is_instance_valid(character)
		_slot_views[slot_index].configure(
			slot_index,
			character,
			_mode == Mode.NORMAL and occupied,
			_mode == Mode.NORMAL,
			(_mode == Mode.PLACEMENT and not occupied) or (_mode == Mode.REPLACEMENT and occupied),
			_mode == Mode.REPLACEMENT and occupied
		)
```

Then set shared presentation explicitly:

```gdscript
	var is_transaction := _mode == Mode.PLACEMENT or _mode == Mode.REPLACEMENT
	_pending_recruit_region.visible = is_transaction
	_return_button.visible = _mode == Mode.NORMAL
	_cancel_button.visible = is_transaction
	_cancel_button.text = "Cancel Replacement" if _mode == Mode.REPLACEMENT else "Cancel Placement"
	_instruction_label.text = (
		"Drag the recruit onto a character to replace them."
		if _mode == Mode.REPLACEMENT
		else "Drag the recruit into an empty slot."
		if _mode == Mode.PLACEMENT
		else "Drag characters to rearrange the party."
	)
	if is_transaction and is_instance_valid(_pending_recruit):
		_pending_recruit_card.configure(-1, _pending_recruit, true, false, false)
```

Change details visibility to:

```gdscript
	_details_panel.visible = (
		is_instance_valid(selected)
		and (_mode == Mode.NORMAL or _mode == Mode.REPLACEMENT)
	)
```

No `.tscn` mutation is expected because every required node already exists. If a scene property must change, use `node_ops(validate=true)`, `save_scene()`, and `explore`; never edit the `.tscn` with native file tools.

- [ ] **Step 6: Validate each script and run the UI test**

After changing `party_slot.gd`:

```text
validate(target=res://Scripts/Party/party_slot.gd, detail=brief)
check_errors(scope=res://Scripts/Party/party_slot.gd)
```

After changing `party_management.gd`:

```text
validate(target=res://Scripts/Party/party_management.gd, detail=brief)
check_errors(scope=res://Scripts/Party/party_management.gd)
signal_map(scope=file:res://Scripts/Party/party_management.gd, detail=brief)
```

Then run:

```powershell
godot --headless --path . --script res://Tests/UI/test_ac3_3_party_management.gd
```

Expected: `AC3.3 party management tests: PASS (31/31)` with normal, placement, and replacement assertions all passing.

- [ ] **Step 7: Commit the shared UI change**

```powershell
git add -- Scripts/Party/party_slot.gd Scripts/Party/party_management.gd Tests/UI/test_ac3_3_party_management.gd
git diff --cached --check
git commit -m "feat: add party replacement mode"
```

### Task 3: Route full-roster recruitment through replacement mode

**Files:**

- Modify: `Tests/Map/test_ac3_1_recruitment_integration.gd`
- Modify: `Tests/Map/test_ac3_3_party_management_integration.gd`
- Modify: `Scripts/Map/map_controller.gd`

- [ ] **Step 1: Inspect controller/test context and impact**

Use:

```text
file_context(res://Scripts/Map/map_controller.gd, detail=brief)
file_context(res://Tests/Map/test_ac3_1_recruitment_integration.gd, detail=brief)
file_context(res://Tests/Map/test_ac3_3_party_management_integration.gd, detail=brief)
impact_check(res://Scripts/Map/map_controller.gd, action=modify_function, target=_filter_eligible_reward_options, change_description="retain valid non-duplicate recruitment rewards when roster is full")
impact_check(res://Scripts/Map/map_controller.gd, action=modify_function, target=_on_recruitment_reward_placement_requested, change_description="route full roster to replacement mode and below capacity to placement mode")
impact_check(res://Scripts/Map/map_controller.gd, action=add_function, target=_on_recruitment_replacement_requested, change_description="commit atomic replacement through the existing pending reward transaction")
```

- [ ] **Step 2: Replace the superseded AC3.1 full-roster expectation**

In `Tests/Map/test_ac3_1_recruitment_integration.gd`, rename `_test_full_roster_filters_recruitment()` to `_test_full_roster_keeps_valid_recruitment()` and replace its assertion with:

```gdscript
	_assert(
		_reward_ids(options) == [&"boss_recruit_champion", &"boss_money_250", &"boss_rare_relic"],
		"Full roster recruitment eligibility",
		"valid Champion recruitment must remain beside other rewards at capacity"
	)
```

In the same function, add a second assertion that proves a dismissed catalog character becomes eligible again:

```gdscript
	var returning_members: Array[RunCharacter] = [
		RunCharacterCatalog.create_for_reward(&"boss_recruit_champion"),
		_character(&"return_1", "Return 1"),
		_character(&"return_2", "Return 2"),
		_character(&"return_3", "Return 3"),
		_character(&"return_4", "Return 4"),
		_character(&"return_5", "Return 5"),
	]
	var returning_roster := RunRoster.new(returning_members)
	var scout := RunCharacterCatalog.create_for_reward(&"combat_recruit_scout")
	var replaced := returning_roster.try_replace_at(scout, 0, &"champion")
	var returning_options := world.call(
		"_filter_eligible_reward_options",
		BattleRewardCatalog.get_options_for("boss"),
		returning_roster
	) as Array
	_assert(
		replaced == RunRoster.ReplaceResult.REPLACED
		and _reward_ids(returning_options).has(&"boss_recruit_champion"),
		"Dismissed character eligibility",
		"dismissed Champion must become eligible when no copy remains"
	)
```

Add the same typed `_character()` helper used by the other focused tests. Update the call in `_run()` to the renamed function and increase `EXPECTED_TEST_COUNT` from `7` to `8`.

- [ ] **Step 3: Add failing full transaction integration coverage**

Increase `Tests/Map/test_ac3_3_party_management_integration.gd` from `12` to `24` assertions. Before run reset, build capacity through the public pending-placement seam, then exercise full replacement and unexpected teardown cleanup:

```gdscript
	# Fill the three remaining slots with unique characters through the roster test seam.
	var roster: RunRoster = world.get("_run_roster") as RunRoster
	_expect(roster.try_add_at(_character(&"fourth", "Fourth"), 0) == RunRoster.AddResult.ADDED, "fixture fills empty slot 0")
	_expect(roster.try_add_at(_character(&"fifth", "Fifth"), 3) == RunRoster.AddResult.ADDED, "fixture fills empty slot 3")
	_expect(roster.try_add_at(_character(&"sixth", "Sixth"), 4) == RunRoster.AddResult.ADDED and roster.is_full(), "fixture reaches capacity")

	world.call("_open_encounter", Vector2i(1, 0), "boss")
	world.call("_on_battle_requested", Vector2i(1, 0), "boss")
	await process_frame
	var boss_options: Array[BattleRewardOption] = world.call("_get_eligible_reward_options", "boss")
	var champion_option := _find_reward(boss_options, &"boss_recruit_champion")
	_expect(is_instance_valid(champion_option), "full roster retains valid recruitment reward")
	world.call("_on_recruitment_reward_placement_requested", champion_option)
	await process_frame
	var replacement_party: PartyManagement = world.call("get_active_party_management")
	_expect(is_instance_valid(replacement_party) and replacement_party.get("_mode") == PartyManagement.Mode.REPLACEMENT, "capacity opens replacement mode")
	var before_replace: Array[RunCharacter] = world.call("get_run_formation_snapshot")
	replacement_party.call("request_placement_cancel")
	await process_frame
	_expect(not world.call("has_active_party_management") and _same_slots(before_replace, world.call("get_run_formation_snapshot")), "replacement cancel restores without mutation")

	world.call("_on_recruitment_reward_placement_requested", champion_option)
	await process_frame
	replacement_party = world.call("get_active_party_management")
	replacement_party.call("request_replacement", 1, before_replace[1].character_id, &"champion")
	await process_frame
	var after_replace: Array[RunCharacter] = world.call("get_run_formation_snapshot")
	_expect(after_replace[1].character_id == &"champion" and after_replace.size() == 6, "replacement commits at exact slot")
	_expect(not roster.has_character(before_replace[1].character_id), "dismissed character leaves membership")
	world.call("_on_recruitment_replacement_requested", 1, before_replace[1].character_id, &"champion")
	_expect(_same_slots(after_replace, world.call("get_run_formation_snapshot")), "repeated stale replacement cannot mutate")
	_expect(not world.call("has_active_party_management"), "successful replacement closes party management")
	world.call("_open_encounter", Vector2i(1, 0), "combat")
	world.call("_on_battle_requested", Vector2i(1, 0), "combat")
	await process_frame
	var next_battle := world.call("get_active_battle") as BattleArena
	var next_slot_id: StringName = &""
	for unit: BattleUnitState in next_battle.get_turn_queue():
		if unit.side == BattleUnitState.Side.PLAYER and unit.slot_index == 1:
			next_slot_id = unit.unit_id
	_expect(next_slot_id == &"champion", "next battle preserves the replaced semantic slot")
	world.exit_active_battle()
```

Add helpers:

```gdscript
func _character(id: StringName, display_name: String) -> RunCharacter:
	var skills: Array[CharacterSkill] = []
	return RunCharacter.new(id, display_name, 5, 20, skills)


func _find_reward(options: Array[BattleRewardOption], reward_id: StringName) -> BattleRewardOption:
	for option: BattleRewardOption in options:
		if option.reward_id == reward_id:
			return option
	return null


func _same_slots(left: Array[RunCharacter], right: Array[RunCharacter]) -> bool:
	if left.size() != right.size():
		return false
	for slot_index: int in left.size():
		if left[slot_index] != right[slot_index]:
			return false
	return true
```

If the existing formation sequence leaves slot `0` occupied, fill the actual empty slots reported by `get_run_formation_snapshot()` instead. The final fixture must have six occupied semantic slots without rearranging the earlier AC3.3 assertions.

- [ ] **Step 4: Run both integration tests and verify failure**

Run:

```powershell
godot --headless --path . --script res://Tests/Map/test_ac3_1_recruitment_integration.gd
godot --headless --path . --script res://Tests/Map/test_ac3_3_party_management_integration.gd
```

Expected: the AC3.1 runner fails because the controller still filters at capacity; the AC3.3 runner fails because capacity currently restores the reward and no replacement handler exists.

- [ ] **Step 5: Change reward eligibility without weakening duplicate validation**

In `_filter_eligible_reward_options()`, replace the recruitment condition with:

```gdscript
		var recruit: RunCharacter = RunCharacterCatalog.create_for_reward(option.reward_id)
		if (
			is_instance_valid(recruit)
			and not recruit.character_id.is_empty()
			and not roster.has_character(recruit.character_id)
		):
			eligible.append(option)
```

This intentionally removes capacity from catalog eligibility while preserving invalid and duplicate filtering. Do not change `RunRoster.can_add()`, which remains the below-capacity addition predicate.

- [ ] **Step 6: Route capacity to replacement mode**

In `_on_recruitment_reward_placement_requested()`, replace the current `can_add()` rejection with identity validation:

```gdscript
	if (
		not is_instance_valid(recruit)
		or recruit.character_id.is_empty()
		or _run_roster.has_character(recruit.character_id)
	):
		_active_battle.restore_pending_recruitment(option)
		return
```

After instantiating and adding the party scene, connect both transactional intents and configure by capacity:

```gdscript
	party.placement_requested.connect(_on_recruitment_placement_requested)
	party.replacement_requested.connect(_on_recruitment_replacement_requested)
	party.placement_cancelled.connect(_on_recruitment_placement_cancelled, CONNECT_ONE_SHOT)
	if _run_roster.is_full():
		party.configure_replacement(_run_roster.get_slot_snapshot(), recruit)
	else:
		party.configure_placement(_run_roster.get_slot_snapshot(), recruit)
```

Set `_active_party_management`, add the scene, and store pending option/recruit exactly once as in the current function. Do not restore or cancel solely because the roster is full.

- [ ] **Step 7: Add the authoritative replacement handler**

Add beside `_on_recruitment_placement_requested()`:

```gdscript
func _on_recruitment_replacement_requested(
	destination_slot: int,
	expected_character_id: StringName,
	expected_recruit_id: StringName
) -> void:
	if (
		not has_active_party_management()
		or not has_active_battle()
		or not is_instance_valid(_pending_recruit)
		or _pending_recruit.character_id != expected_recruit_id
	):
		return
	var result: RunRoster.ReplaceResult = _run_roster.try_replace_at(
		_pending_recruit,
		destination_slot,
		expected_character_id
	)
	if result != RunRoster.ReplaceResult.REPLACED:
		_active_party_management.refresh_slots(_run_roster.get_slot_snapshot())
		return
	var option: BattleRewardOption = _pending_recruitment_option
	close_party_management()
	_clear_pending_recruitment()
	if has_active_battle():
		_active_battle.complete_pending_recruitment(option)
```

Retain `_on_recruitment_placement_cancelled()` as the shared Cancel boundary for placement and replacement. Retain the existing `_clear_pending_recruitment()` calls in battle exit and run reset. Connect the transactional party instance to an explicit teardown guard:

```gdscript
	party.tree_exited.connect(_on_transaction_party_tree_exited.bind(party), CONNECT_ONE_SHOT)
```

Add:

```gdscript
func _on_transaction_party_tree_exited(party: PartyManagement) -> void:
	if _active_party_management != party:
		return
	_active_party_management = null
	_clear_pending_recruitment()
	_refresh_manage_party_button()
```

This unexpected-teardown path only clears controller state; it never restores or completes the reward. Normal success and Cancel set `_active_party_management = null` before removing the scene, so the guard becomes a no-op on those paths.

- [ ] **Step 8: Validate the controller and run focused/regression tests**

Use:

```text
validate(target=res://Scripts/Map/map_controller.gd, detail=brief)
check_errors(scope=res://Scripts/Map/map_controller.gd)
signal_map(scope=file:res://Scripts/Map/map_controller.gd, detail=brief)
```

Run:

```powershell
godot --headless --path . --script res://Tests/Map/test_ac3_1_recruitment_integration.gd
godot --headless --path . --script res://Tests/Map/test_ac3_3_party_management_integration.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_5_reward_selection.gd
godot --headless --path . --script res://Tests/UI/test_ac3_3_party_management.gd
godot --headless --path . --script res://Tests/Run/test_ac3_3_party_formation.gd
```

Expected: AC3.1 `PASS (8/8)`, AC3.3 integration `PASS (24/24)`, and all three regression runners PASS with their updated exact counts.

- [ ] **Step 9: Commit the integration change**

```powershell
git add -- Scripts/Map/map_controller.gd Tests/Map/test_ac3_1_recruitment_integration.gd Tests/Map/test_ac3_3_party_management_integration.gd
git diff --cached --check
git commit -m "feat: require replacement for full roster recruits"
```

### Task 4: Verify runtime, resolve governance, and record AC3.2 completion

**Files:**

- Modify: `Docs/TO_CONSIDER.md`
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
- Create: `Docs/Specs/AC3/Evidence/AC3.2/2026-08-14/automated-test.log`
- Create: `Docs/Specs/AC3/Evidence/AC3.2/2026-08-14/manual-runtime-check.md`
- Create: `Docs/Specs/AC3/Evidence/AC3.2/2026-08-14/implementation-link.txt`

- [ ] **Step 1: Run the full automated corpus**

Run every `Tests/**/*.gd` runner without writing a helper file:

```powershell
$testFiles = Get-ChildItem -Path Tests -Recurse -Filter '*.gd' | Sort-Object FullName
$failed = @()
foreach ($testFile in $testFiles) {
  $relative = [IO.Path]::GetRelativePath((Get-Location).Path, $testFile.FullName) -replace '\\','/'
  & godot --headless --path . --script ("res://" + $relative)
  if ($LASTEXITCODE -ne 0) { $failed += $relative }
}
if ($failed.Count -gt 0) { throw "Failed runners: $($failed -join ', ')" }
```

Expected: every discovered runner exits `0`; no parser, assertion, or script-error marker appears. Record the discovered count and each focused PASS signature.

- [ ] **Step 2: Run GodotIQ project and signal gates**

Use:

```text
validate(target=project, detail=brief)
check_errors(scope=project)
signal_map(find=orphans, detail=brief)
verify_project_runs(scene=main, check_scope=project, stop_after=true)
```

Expected: zero new errors, zero parser failures, no new orphan signal involving replacement, and main-scene startup PASS. Existing unrelated warnings/informational findings must be identified as pre-existing rather than silently omitted.

- [ ] **Step 3: Perform real-pointer runtime and visual QA**

Start Play and use the existing debug/test seams to reach a full six-character roster. Win a supported battle and verify:

1. Recruitment remains visible beside money and item rewards.
2. Confirming recruitment opens party management in replacement mode without changing the roster or exiting battle.
3. All six occupied cards and the pending recruit fit at 1152×648.
4. Clicking an existing member shows details but cannot drag that member.
5. Dragging the recruit over a target produces red/destructive feedback and identifies the member to be dismissed.
6. Cancel returns to the same selected reward with the same formation.
7. Reopening and dropping onto an occupied slot replaces exactly that character and completes once.
8. The next battle places the recruit at the exact replaced slot.
9. No runtime/debug-console errors occur.

Use the mandatory GodotIQ sequence:

```text
run(action=play)
verify_project_runs(scene=current, check_scope=project, stop_after=false)
explore(mode=tour)
read_debug_console()
run(action=stop)
```

If visual issues appear, inspect `party_management.tscn` with `scene_map`, use `node_ops(validate=true)` for changes, `save_scene()`, and repeat the tour. Describe every screenshot in the evidence record.

- [ ] **Step 4: Resolve TC-002 without over-resolving duplicate identity**

Move TC-002 from `Open questions` to `Resolved questions` and record:

```markdown
### TC-002 — Full-roster recruitment uses atomic replacement

- **Resolved:** 2026-08-14 for AC3.2.
- Valid recruitment remains in the normal reward catalog at roster size six.
- Confirm opens `PartyManagement.Mode.REPLACEMENT`; Cancel restores the unchanged reward choices.
- Any occupied member may be replaced through one atomic roster mutation.
- The dismissed character may be recruited again later when no copy is currently owned.
- Equipment/progression cleanup remains deferred until those systems own authoritative run state.
- **Authority:** `Docs/superpowers/specs/2026-08-14-ac3-2-full-roster-replacement-design.md`.
```

Keep TC-001 open, but its current no-duplicate rule remains authoritative for AC3.2.

- [ ] **Step 5: Write evidence against the tested implementation commit**

First commit any runtime-tested scene correction if one was required. Capture:

```powershell
$implementationCommit = git rev-parse HEAD
```

Write `automated-test.log` with the commit, exact focused counts, full-corpus discovered/pass counts, GodotIQ results, and runtime gate. Write `manual-runtime-check.md` with dated PASS/FAIL/BLOCKED entries for all nine checks above. Write `implementation-link.txt` with the same full SHA and the branch name.

Do not mark AC3.2 complete if any entry is FAIL or BLOCKED.

- [ ] **Step 6: Update the canonical acceptance criterion only after every gate passes**

Change:

```markdown
- [ ] AC3.2 — If the roster is already full at 6 characters, the player must dismiss one character before acquiring a new one
```

to:

```markdown
- [x] AC3.2 — If the roster is already full at 6 characters, the player must dismiss one character before acquiring a new one
```

Replace its manual-only verification row with:

```markdown
| `AC3.2` | Automated and manual runtime check | Run `Tests/Run/test_ac3_3_party_formation.gd`, `Tests/UI/test_ac3_3_party_management.gd`, `Tests/Map/test_ac3_1_recruitment_integration.gd`, and `Tests/Map/test_ac3_3_party_management_integration.gd` to verify atomic six-member replacement, full-roster reward eligibility, replacement-mode interaction, exact-slot preservation, cancellation restoration, dismissed-character eligibility, and stale/repeated/teardown rejection. Then fill the roster, win a supported battle, confirm recruitment remains available, inspect and cancel replacement once without mutation, reopen and replace any occupied member with real pointer input, and confirm the next battle uses the recruit in the exact replaced slot without runtime errors. |
```

Leave AC3.1 and AC3.3 checked only because their full regression suites passed. Do not change AC3.4 or later criteria.

- [ ] **Step 7: Self-audit evidence consistency and commit completion records**

Run:

```powershell
rg -n "AC3\.2|Implementation commit|Result:" Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC3/Evidence/AC3.2/2026-08-14 Docs/TO_CONSIDER.md
git diff --check
git status --short
```

Expected: exactly one checked AC3.2 criterion, exactly one AC3.2 verification row, all three evidence files name the same full tested SHA, TC-002 is resolved once, and only the two unrelated UID files remain outside the planned change.

Commit:

```powershell
git add -- Docs/TO_CONSIDER.md Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC3/Evidence/AC3.2/2026-08-14
git diff --cached --check
git commit -m "docs: record AC3.2 completion evidence"
```

### Task 5: Final branch verification and handoff

**Files:** No new files; verify committed scope only.

- [ ] **Step 1: Re-run completion verification from committed HEAD**

Use the `superpowers:verification-before-completion` skill. Re-run the three focused runners, AC3.1 integration runner, AC2.5 reward regression, full corpus, GodotIQ project validation/error/signal gates, and main-scene startup from committed HEAD.

Expected: all results match the recorded evidence. If any result differs, fix it, refresh evidence to the newly tested implementation SHA, recommit, and repeat.

- [ ] **Step 2: Confirm branch scope**

Run:

```powershell
git status --short --branch
git log --oneline main..HEAD
git diff --stat main...HEAD
```

Expected: the branch contains the approved design plus focused AC3.2 implementation/evidence commits. The two pre-existing untracked UID files remain untracked and unchanged. No unrelated file is staged or committed.

- [ ] **Step 3: Prepare integration options**

Use `superpowers:finishing-a-development-branch` only after all verification passes. Do not push unless the user requests remote handoff or review.
