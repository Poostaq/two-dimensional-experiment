# AC6.1 Goblin Combat Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the tested combat-stat, default-action, formation, movement, and history foundation required by later Goblin criteria, including correction of the world-map party preview.

**Architecture:** Keep `BattleUnitState` authoritative for mutable battle stats and slots. Extract pure damage and formation rules into focused `RefCounted` helpers, extend typed skill effect plans rather than branching on Goblin IDs, and leave `BattleArena` as the transaction coordinator. Preserve stable run-character definitions when `RunRoster` creates fresh battle units.

**Tech Stack:** Godot 4, typed GDScript, SceneTree test runners, GodotIQ structured editing/validation/runtime verification, Git.

---

## Scope and file ownership

**Create**

- `Scripts/Battle/battle_damage_rules.gd` — pure Power/Defense physical-damage calculation.
- `Scripts/Battle/battle_formation_rules.gd` — six-slot row/lane validation and legal allied Move 1 swap planning.
- `Scripts/Battle/battle_action_record.gd` — typed authoritative record for default and movement actions.
- `Tests/Battle/test_ac6_1_combat_foundation.gd` — focused AC6.1 logic and transaction runner.

**Modify**

- `Scripts/Battle/battle_unit_state.gd` — base Power/Defense and battle-local slot mutation.
- `Scripts/Run/run_character.gd` — stable base Power/Defense definition fields.
- `Scripts/Run/run_roster.gd` — copy persistent stats into fresh battle units.
- `Scripts/Battle/battle_arena.gd` — Default Attack, Default Swap, movement confirmation, history, and queue rebuild coordination.
- `Scripts/UI/world_map_hud.gd` — correct formation-to-label mapping.
- `Tests/UI/test_world_map_hud.gd` — reverse the currently incorrect assertions.
- `Tests/Run/test_ac3_3_party_formation.gd` — assert Power/Defense and slot preservation into battle state.
- `Docs/superpowers/specs/2026-08-29-ac6-goblin-combat-vertical-slice-design.md` — fill AC6-AC02/AC6.1 evidence links only after verification.

**Do not modify**

- Goblin keywords or class catalogs; those begin in AC6.2/AC6.3.
- World-run save schema; Cache begins in AC6.6.
- Leveling, evolution, or mechanical-unit systems.

## Mandatory execution rules

Before every `.gd` or `.tscn` edit, call GodotIQ `file_context(detail="brief")`. Before changing constructor signatures, call `impact_check` for the affected file and target. Make GDScript edits through `script_ops`; do not write Godot files with native filesystem tools. After each script change, call `validate(target=<file>, detail="brief")` and `check_errors(scope=<file>)`.

### Task 1: Lock the current baseline and failing formation regression

**Files:**

- Modify: `Tests/UI/test_world_map_hud.gd`
- Test: `Tests/UI/test_world_map_hud.gd`

- [ ] **Step 1: Run the retained baseline before edits**

Use GodotIQ project validation, project error check, and the existing WorldMapHud test runner. Record its current PASS and note that its occupant assertions encode the defect.

Expected baseline assertions:

```gdscript
_expect((hud.get_node("%BackSlot0") as Label).text == starters[0].display_name, "back slot shows occupant")
_expect((hud.get_node("%FrontSlot0") as Label).text == starters[1].display_name, "front slot shows occupant")
```

- [ ] **Step 2: Change the test to the canonical contract**

Keep `slots[0] = starters[0]` and `slots[3] = starters[1]`, but replace the four occupant assertions with:

```gdscript
_expect(
    (hud.get_node("%FrontSlot0") as Label).text == starters[0].display_name,
    "formation slot 0 appears in front slot 0"
)
_expect(
    (hud.get_node("%FrontSlot1") as Label).text == "Empty",
    "empty front slot is explicit"
)
_expect(
    (hud.get_node("%BackSlot0") as Label).text == starters[1].display_name,
    "formation slot 3 appears in back slot 0"
)
_expect(
    (hud.get_node("%BackSlot1") as Label).text == "Empty",
    "empty back slot is explicit"
)
```

- [ ] **Step 3: Run the HUD test and prove RED**

Expected: FAIL on the slot 0/slot 3 occupant assertions because `WorldMapHud.set_formation()` still maps `0..2` to back labels.

- [ ] **Step 4: Commit the test-only RED state**

```powershell
git add Tests/UI/test_world_map_hud.gd
git commit -m "test: expose reversed world preview formation"
```

### Task 2: Correct the world-map preview mapping

**Files:**

- Modify: `Scripts/UI/world_map_hud.gd`
- Test: `Tests/UI/test_world_map_hud.gd`

- [ ] **Step 1: Patch only `set_formation()`**

Use the canonical mapping:

```gdscript
func set_formation(slots: Array[RunCharacter]) -> void:
    for lane_index: int in 3:
        _front_slots[lane_index].text = _slot_text(slots, lane_index)
        _back_slots[lane_index].text = _slot_text(slots, lane_index + 3)
```

- [ ] **Step 2: Validate and compile the changed script**

GodotIQ:

```text
validate(target="res://Scripts/UI/world_map_hud.gd", detail="brief")
check_errors(scope="res://Scripts/UI/world_map_hud.gd")
```

Expected: no new convention or parser errors.

- [ ] **Step 3: Run the HUD runner and prove GREEN**

Expected: `World map HUD tests: PASS (25/25)`.

- [ ] **Step 4: Inspect production HUD**

Start the production project with GodotIQ, reach the world map, and use one `explore(mode="inspect")` capture of the party preview. Verify roster slots `0..2` appear beneath FRONT LINE and `3..5` beneath BACK LINE. Stop Play afterward.

- [ ] **Step 5: Commit**

```powershell
git add Scripts/UI/world_map_hud.gd Tests/UI/test_world_map_hud.gd
git commit -m "fix: align world preview formation rows"
```

### Task 3: Add Power and Defense to fresh battle state

**Files:**

- Modify: `Scripts/Battle/battle_unit_state.gd`
- Modify: `Scripts/Run/run_character.gd`
- Modify: `Scripts/Run/run_roster.gd`
- Modify: `Tests/Run/test_ac3_3_party_formation.gd`
- Test: `Tests/Battle/test_ac6_1_combat_foundation.gd`

- [ ] **Step 1: Create the focused test runner with stat-isolation cases**

The runner must construct a persistent character with Power 7 and Defense 2, convert it twice, mutate the first battle unit, and assert the second conversion and source definition remain unchanged:

```gdscript
func _test_fresh_battle_stats() -> void:
    var character := RunCharacter.new(&"goblin", "Goblin", 9, 20, [], 7, 2)
    var roster := RunRoster.new([character])
    var first: BattleUnitState = roster.create_battle_units()[0]
    _expect(first.power == 7 and first.defense == 2, "base combat stats copy into battle")
    first.power = 1
    first.defense = 0
    var second: BattleUnitState = roster.create_battle_units()[0]
    _expect(second.power == 7 and second.defense == 2, "battle stat mutation does not leak")
    _expect(character.power == 7 and character.defense == 2, "run definition stays immutable")
```

`RunRoster._init(starters: Array[RunCharacter])` already accepts the one-character array used above.

- [ ] **Step 2: Run the focused test and prove RED**

Expected: parser or assertion failure because Power/Defense fields and constructor parameters do not exist.

- [ ] **Step 3: Extend stable and battle constructors**

Add typed fields with safe defaults preserving old call sites:

```gdscript
var power: int = 1
var defense: int = 0
```

Constructor validation:

```gdscript
if candidate_power < 1 or candidate_defense < 0:
    return false
```

`RunRoster.create_battle_units()` must pass `character.power` and `character.defense` into each new `BattleUnitState`; it must never retain a battle-state object.

- [ ] **Step 4: Validate each changed script immediately**

For each of `run_character.gd`, `battle_unit_state.gd`, and `run_roster.gd`: GodotIQ file validation followed by file error check. Resolve all constructor impact findings before continuing.

- [ ] **Step 5: Run focused and retained formation tests**

Expected:

```text
AC6.1 combat foundation: PASS
AC3.3 party formation tests: PASS (updated assertion count)
```

- [ ] **Step 6: Commit**

```powershell
git add Scripts/Battle/battle_unit_state.gd Scripts/Run/run_character.gd Scripts/Run/run_roster.gd Tests/Battle/test_ac6_1_combat_foundation.gd Tests/Run/test_ac3_3_party_formation.gd
git commit -m "feat: carry combat stats into fresh battle units"
```

### Task 4: Add deterministic physical damage rules

**Files:**

- Create: `Scripts/Battle/battle_damage_rules.gd`
- Modify: `Tests/Battle/test_ac6_1_combat_foundation.gd`

- [ ] **Step 1: Add failing formula cases**

```gdscript
func _test_physical_damage_formula() -> void:
    _expect(BattleDamageRules.physical_damage(4, 0.85, 2) == 2, "85% rounds before Defense")
    _expect(BattleDamageRules.physical_damage(6, 1.20, 2) == 6, "ordinary damage uses ceil")
    _expect(BattleDamageRules.physical_damage(1, 0.60, 99) == 1, "direct damage minimum is one")
    _expect(BattleDamageRules.physical_damage(0, 1.0, 0) == -1, "invalid Power is rejected")
```

- [ ] **Step 2: Run and prove RED**

Expected: `BattleDamageRules` is undefined.

- [ ] **Step 3: Create the pure rule**

```gdscript
class_name BattleDamageRules
extends RefCounted


static func physical_damage(power: int, multiplier: float, defense: int) -> int:
    if power < 1 or multiplier <= 0.0 or defense < 0:
        return -1
    return max(1, ceili(float(power) * multiplier) - defense)
```

- [ ] **Step 4: Validate, compile, and rerun**

Expected: focused AC6.1 runner PASS and no validation/parser errors.

- [ ] **Step 5: Commit**

```powershell
git add Scripts/Battle/battle_damage_rules.gd Tests/Battle/test_ac6_1_combat_foundation.gd
git commit -m "feat: add physical combat damage rule"
```

### Task 5: Centralize six-slot formation semantics

**Files:**

- Create: `Scripts/Battle/battle_formation_rules.gd`
- Modify: `Scripts/Battle/battle_skill_rules.gd`
- Modify: `Tests/Battle/test_ac6_1_combat_foundation.gd`
- Modify: `Tests/Battle/test_ac2_8_skill_targeting.gd`

- [ ] **Step 1: Add failing row/lane/distance tests**

```gdscript
func _test_formation_contract() -> void:
    _expect(BattleFormationRules.is_front_slot(0), "slot 0 is front")
    _expect(BattleFormationRules.is_front_slot(2), "slot 2 is front")
    _expect(not BattleFormationRules.is_front_slot(3), "slot 3 is back")
    _expect(BattleFormationRules.is_back_slot(5), "slot 5 is back")
    _expect(BattleFormationRules.lane_of(4) == 1, "slot 4 is lane 1")
    _expect(BattleFormationRules.lane_distance(0, 5) == 2, "distance compares lanes")
    _expect(BattleFormationRules.lane_of(-1) == -1, "invalid slots are rejected")
```

- [ ] **Step 2: Prove RED**

Expected: missing `BattleFormationRules`.

- [ ] **Step 3: Create the shared rule**

```gdscript
class_name BattleFormationRules
extends RefCounted

const SLOT_COUNT: int = 6
const ROW_SIZE: int = 3


static func is_valid_slot(slot_index: int) -> bool:
    return slot_index >= 0 and slot_index < SLOT_COUNT


static func is_front_slot(slot_index: int) -> bool:
    return is_valid_slot(slot_index) and slot_index < ROW_SIZE


static func is_back_slot(slot_index: int) -> bool:
    return is_valid_slot(slot_index) and slot_index >= ROW_SIZE


static func lane_of(slot_index: int) -> int:
    return slot_index % ROW_SIZE if is_valid_slot(slot_index) else -1


static func lane_distance(first_slot: int, second_slot: int) -> int:
    if not is_valid_slot(first_slot) or not is_valid_slot(second_slot):
        return -1
    return absi(lane_of(first_slot) - lane_of(second_slot))
```

- [ ] **Step 4: Replace duplicated row checks in `BattleSkillRules`**

Use `BattleFormationRules.is_front_slot(actor.slot_index)` and `is_back_slot`; remove `FRONT_ROW_END`. Preserve all rejection codes/messages.

- [ ] **Step 5: Validate and run focused plus AC2.8 tests**

Expected: both PASS with unchanged AC2.8 behavior.

- [ ] **Step 6: Commit**

```powershell
git add Scripts/Battle/battle_formation_rules.gd Scripts/Battle/battle_skill_rules.gd Tests/Battle/test_ac6_1_combat_foundation.gd Tests/Battle/test_ac2_8_skill_targeting.gd
git commit -m "refactor: centralize battle formation rules"
```

### Task 6: Add Default Attack and typed action history

**Files:**

- Create: `Scripts/Battle/battle_action_record.gd`
- Modify: `Scripts/Battle/battle_arena.gd`
- Modify: `Tests/Battle/test_ac6_1_combat_foundation.gd`

- [ ] **Step 1: Add failing default-attack transaction cases**

Configure an active actor with Power 6 and an enemy with Defense 2. Confirm Default Attack and assert:

```gdscript
_expect(target.current_hp == target.max_hp - 4, "default attack deals 100% Power through Defense")
_expect(arena.get_battle_revision() == before_revision + 1, "default attack commits one revision")
var record: BattleActionRecord = arena.get_action_records().back()
_expect(record.kind == BattleActionRecord.Kind.DEFAULT_ATTACK, "history types default attack")
_expect(record.actor_id == actor.unit_id and record.target_ids == [target.unit_id], "history locks identities")
_expect(record.damage_by_target[target.unit_id] == 4, "history records applied damage")
```

Add rejection cases for defeated actor, ally target, defeated target, stale revision, and battle complete; compare HP, queue, revision, cooldown snapshots, and record count before/after.

- [ ] **Step 2: Prove RED**

Expected: missing record type and arena default-attack API.

- [ ] **Step 3: Create the immutable action record**

```gdscript
class_name BattleActionRecord
extends RefCounted

enum Kind { DEFAULT_ATTACK, DEFAULT_SWAP, FORMATION_MOVE, SKILL }

var kind: Kind
var actor_id: StringName
var target_ids: Array[StringName]
var damage_by_target: Dictionary[StringName, int]
var slot_before_by_unit: Dictionary[StringName, int]
var slot_after_by_unit: Dictionary[StringName, int]
var round_number: int
var revision: int
```

Its constructor must defensively duplicate all arrays/dictionaries and reject empty actor IDs, invalid round numbers, and invalid revisions.

- [ ] **Step 4: Add `preview_default_attack()` and `confirm_default_attack()`**

The preview returns target IDs and current revision without mutation. Confirmation revalidates actor/target/revision, calculates `BattleDamageRules.physical_damage(actor.power, 1.0, target.defense)`, applies HP damage, writes one record/log entry, increments revision once, evaluates defeat, and advances the queue. No class ID branching is allowed.

- [ ] **Step 5: Validate, compile, and run**

Run focused AC6.1, AC2.3 damage/log, AC2.8 transaction, and active-turn lock runners. Expected: all PASS.

- [ ] **Step 6: Commit**

```powershell
git add Scripts/Battle/battle_action_record.gd Scripts/Battle/battle_arena.gd Tests/Battle/test_ac6_1_combat_foundation.gd
git commit -m "feat: add default attack transaction history"
```

### Task 7: Add allied Move 1 and Default Swap

**Files:**

- Modify: `Scripts/Battle/battle_formation_rules.gd`
- Modify: `Scripts/Battle/battle_unit_state.gd`
- Modify: `Scripts/Battle/battle_arena.gd`
- Modify: `Tests/Battle/test_ac6_1_combat_foundation.gd`

- [ ] **Step 1: Add failing legal/stale movement cases**

Define Move 1 as swapping the actor with one active allied unit in the same lane's opposite row or an adjacent lane in the same row. Empty destinations are legal; occupied allied destinations swap. Enemy destinations and non-neighbor destinations reject.

```gdscript
_expect(BattleFormationRules.is_move_one(0, 1), "adjacent front lane is Move 1")
_expect(BattleFormationRules.is_move_one(0, 3), "same-lane row change is Move 1")
_expect(not BattleFormationRules.is_move_one(0, 2), "two lanes is not Move 1")
_expect(not BattleFormationRules.is_move_one(0, 4), "diagonal row-and-lane change is not Move 1")
```

Arena cases must prove previewed before/after slots, occupied swap, empty move, stale occupancy rejection, enemy-side rejection, one revision, one record, and queue rebuild preserving already-resolved entries.

- [ ] **Step 2: Prove RED**

Expected: movement predicate and arena APIs are absent.

- [ ] **Step 3: Implement the pure predicate**

```gdscript
static func is_move_one(from_slot: int, to_slot: int) -> bool:
    if not is_valid_slot(from_slot) or not is_valid_slot(to_slot) or from_slot == to_slot:
        return false
    var lane_delta: int = absi(lane_of(from_slot) - lane_of(to_slot))
    var row_changed: bool = is_front_slot(from_slot) != is_front_slot(to_slot)
    return (lane_delta == 1 and not row_changed) or (lane_delta == 0 and row_changed)
```

- [ ] **Step 4: Implement atomic arena confirmation**

Lock actor ID, optional allied occupant ID, source/destination slots, and revision during preview. Confirmation revalidates all five values before mutation. On success, update `slot_index` values atomically, append a `FORMATION_MOVE` record with complete before/after maps, increment revision once, rebuild only unresolved queue entries using existing deterministic Speed ordering, then advance.

Default Swap uses the same transaction with `BattleActionRecord.Kind.DEFAULT_SWAP` and requires an occupied active ally; ordinary formation move permits an empty destination.

- [ ] **Step 5: Validate and run**

Run focused AC6.1, AC2.2 speed-order, AC2.8 transaction/lifecycle, and AC3.3 formation tests. Expected: all PASS.

- [ ] **Step 6: Commit**

```powershell
git add Scripts/Battle/battle_formation_rules.gd Scripts/Battle/battle_unit_state.gd Scripts/Battle/battle_arena.gd Tests/Battle/test_ac6_1_combat_foundation.gd
git commit -m "feat: add atomic battle formation movement"
```

### Task 8: AC6.1 evidence gate

**Files:**

- Modify: `Docs/superpowers/specs/2026-08-29-ac6-goblin-combat-vertical-slice-design.md`
- Test: all retained Battle, UI, Run, and Save runners

- [ ] **Step 1: Run focused and retained automated suites**

Run every `Tests/Battle/test_*.gd`, `Tests/UI/test_world_map_hud.gd`, `Tests/UI/test_ac3_3_party_management.gd`, `Tests/Run/test_ac3_3_party_formation.gd`, and the reward/next-battle transition runners. Record exact PASS counts and date.

- [ ] **Step 2: Run the mandatory GodotIQ project gate**

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(find="orphans")
verify_project_runs(scene="main", check_scope="project", stop_after=true)
```

Expected: no new errors, parser failures, or orphan signals; startup PASS.

- [ ] **Step 3: Perform production formation verification**

In production entry points:

1. Put distinct units in slots 0 and 3.
2. Verify world preview labels slot 0 as front and slot 3 as back.
3. Open party management and verify the same mapping.
4. Enter battle and verify the same unit-slot placement.
5. Execute Default Attack, an empty formation move, and Default Swap.
6. Inspect action records and the debug console.

Expected: exact slot agreement, correct damage, atomic movement, deterministic queue, and no runtime errors.

- [ ] **Step 4: Update only earned evidence**

In the AC6 traceability table:

- mark AC6-AC02 PASS only if the automated and production formation checks passed;
- add implementation commit links for AC6.1;
- leave AC6-AC03 and later criteria FAIL because keywords and Goblin content are not implemented;
- record the exact test commands/results and GodotIQ evidence location.

- [ ] **Step 5: Commit the evidence record**

```powershell
git add Docs/superpowers/specs/2026-08-29-ac6-goblin-combat-vertical-slice-design.md
git commit -m "docs: record AC6.1 verification evidence"
```

## Self-review

- Spec coverage: AC6.1 foundation, AC6-AC02 formation semantics, and the AC6.1 portions of AC6-AC03/07/08 are assigned concrete tasks. Keywords, Goblin classes, Brakka, Cache, and integration completion remain correctly outside this plan.
- Placeholder scan: no TBD/TODO or undefined “appropriate” work remains.
- Type consistency: `BattleDamageRules.physical_damage`, `BattleFormationRules`, `BattleActionRecord`, and arena preview/confirmation responsibilities are used consistently.
- Governance: no criterion is marked complete until focused tests, retained regressions, implementation links, and GodotIQ runtime evidence exist.
