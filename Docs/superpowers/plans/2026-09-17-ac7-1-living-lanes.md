# AC7.1 Living Lanes Implementation Plan

**Execution status:** Completed inline on `feature/ac7-1-living-lanes`, implementation commit `671612c`. All five task groups are complete. See [verification and documented plan adjustments](../../Specs/AC7/Evidence/AC7.1/verification.md) for test results, screenshots, and the correction to the original slot-array ordering assumption below. The task checklists remain as the original execution instructions.

> **For agentic workers:** Use `superpowers:executing-plans` to implement this plan task by task, with `superpowers:test-driven-development` for behavior changes. Steps use checkboxes for tracking. Follow repository AGENTS.md; use the primary workspace and a dedicated branch, never a worktree.

**Goal:** Show both six-slot battle formations as four readable character lanes with identity, role, HP, and current status iconography visible in the battle screen.

**Architecture:** Keep BattleArena authoritative. Replace formation slot presentation with reusable BattleUnitView scenes, retain stable side/slot addressing, and derive presentation from existing BattleUnitState query methods. A small presentation catalog supplies role labels and figure variants without adding combat rules or save fields.

**Tech Stack:** Godot 4, typed GDScript, Control scenes, repository SceneTree test runners, GodotIQ scene/script operations.

**References:** `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` (AC7.1 and its verification row), `Docs/Mockups/AC7/battle-ui-oracle.html`, and `Docs/superpowers/plans/2026-09-17-ac7-battle-ui-presentation.md`.

## Scope and decisions

This is the executable breakdown of AC7.1 in the broader plan. The approved oracle already establishes the composition; do not redesign or edit it. Implement the four character lanes now. Keep the existing skill/default-action controls usable and visible. Turn-order ribbon, unified action bar, overlay debug drawer, and centralized interaction-state resolver remain AC7.2–AC7.5.

The broader plan's global BattleUiSnapshot prerequisite is unnecessary for this isolated slice: the arena already has `get_battle_revision()`, `get_skill_presentation_snapshot()`, and a single unit-rendering path. Use a unit-view render boundary now; do not introduce queue/action snapshot infrastructure solely for AC7.1. Preserve current actor, targeting, transaction, and damage-feedback overlays until AC7.5 replaces their resolution.

Approaches considered:

1. **Recommended: reusable slot scenes with explicit slot collection.** Small arena integration, reusable visuals, no combat-model migration.
2. Style existing flat grids in place. Lower initial cost, but fails the oracle's four distinct character lanes and leaves duplicated slot presentation.
3. Implement the complete AC7 snapshot/resolver/HUD first. Broader reusable architecture, but unnecessarily couples AC7.1 acceptance to four other criteria.

Planning baseline: inspected commit `574b800`; working tree was clean. Planning did not run runtime tests or establish a passing implementation baseline.

## Existing contracts and hazards

- `BattleFormationRules`: front slots are **0, 1, 2**, back slots **3, 4, 5**; logical lane is `slot_index % 3`. The new visual lane columns do not change adjacency or targeting geometry.
- `BattleArena._get_control_children()` currently enumerates direct GridContainer children. `_assign_slot_metadata()` parses `SlotN` names. Both must change together when slots become nested.
- `get_player_slots()` and `get_enemy_slots()` return six Controls each, ordered by numeric slot identity. Keep their signatures and ordering.
- `_get_slot_for_unit()` uses side and `slot_index`; unit IDs identify occupants and move when units swap. View instances belong to slots, not units.
- `_render_units()` currently writes `UnitInfo/UnitNameLabel`, `UnitInfo/SpeedLabel`, and `UnitInfo/HealthLabel`. Preserve these paths and existing HP/defeat wording for compatibility.
- `_on_slot_gui_input`, `_on_slot_mouse_entered`, and `_on_slot_mouse_exited` already route battle input. Keep these handlers and their authoritative checks.
- `BattleUnitState` exposes HP, race, skills, armor, Advantage, Snared, Bleed, and speed-modifier queries, but has no role or portrait field. Do not infer class from translated display names or generated unit IDs.
- Only `Assets/brakka.png` was found under Assets. Use scene-authored stylized figures as the default, matching the oracle's silhouette approach; AC7.1 must not depend on generating a complete portrait pack.

## File map

| File | Change and responsibility |
|---|---|
| `Scripts/UI/battle_unit_presentation.gd` | Create: pure role/figure lookup and detached status presentation data |
| `Scripts/UI/battle_unit_view.gd` | Create: render occupied, empty, and defeated slot contents |
| `Scenes/UI/battle_unit_view.tscn` | Create: reusable figure, identity, HP, role, status, and slot layout |
| `Scenes/battle_arena.tscn` | Modify: four lane containers and twelve authored slot instances |
| `Scripts/Battle/battle_arena.gd` | Modify: explicit slot discovery and view refresh integration |
| `Tests/Battle/test_ac7_1_living_lanes.gd` | Create: scene, presentation, refresh, and ordering tests |
| `Docs/Specs/AC7/Evidence/AC7.1/verification.md` | Create during implementation: commands, results, visual evidence, deviations |
| `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` | Mark AC7.1 only after automated and visual gates pass |

No planned changes to formation rules, damage rules, save schema, character constructors, or turn queue.

## Task 1: Establish branch and regression baseline

- [ ] Inspect status and preserve unrelated work separately. Save this plan if it is uncommitted before changing branches. Update main, then branch:

```powershell
git fetch origin
git switch main
git pull --ff-only origin main
git switch -c feature/ac7-1-living-lanes
```

- [ ] Use GodotIQ `file_context(detail="brief")` before every edited file and `impact_check` before changing arena signatures or slot discovery. Inspect consumers with `dependency_graph` and wiring with `signal_map`, not text searches for callers/connections.
- [ ] Capture `validate(target="project", detail="brief")` and `check_errors(scope="project")` baseline. Resolve the Godot executable used in this environment; `godot` was not found on PATH during planning. Record the actual executable path in verification evidence.
- [ ] Run all existing Battle runners using the resolved executable. Use the same runner after each integration milestone:

```powershell
# Set to the verified local Godot console executable before running.
$godotExe = (Get-Command godot -ErrorAction Stop).Source
$battleTests = Get-ChildItem -LiteralPath Tests/Battle -Filter 'test_*.gd' -File | Sort-Object Name
foreach ($battleTest in $battleTests) {
  $testPath = 'res://Tests/Battle/' + $battleTest.Name
  & $godotExe --headless --path . --script $testPath
  if ($LASTEXITCODE -ne 0) { throw "Battle test failed: $testPath" }
}
```

If PATH lacks Godot, assign the verified executable's absolute path to `$godotExe` instead. Do not treat a missing executable as a passed test. Record pre-existing failures separately.

## Task 2: Lock the slot and presentation contract with failing tests

**File:** `Tests/Battle/test_ac7_1_living_lanes.gd`.

- [ ] Follow the existing SceneTree runner pattern: deferred async `_run`, accumulated failure messages, free instantiated arenas, and exit nonzero on failure. Use `load()` for new scripts/scenes.
- [ ] Add a scene contract fixture with six distinct units on each side and assert:
  - Four named visual containers: PlayerBackline, PlayerFrontline, EnemyFrontline, EnemyBackline.
  - Each has three slot views; front contains 0–2, back 3–5.
  - Public slot arrays each return 0–5, independent of visual child order.
  - Every occupied view displays its own identity, role, figure, HP bar/value, and stable slot label.
- [ ] Add sparse formation and defeated-unit fixtures. Empty slots keep their label and show `Empty`; defeated occupants retain identity and show `Defeated`, zero HP, and a distinct non-color marker.
- [ ] Add a real swap regression using the existing Default Swap interaction fixture: view instances stay in their slots, while names, figures, HP, role, statuses, and unit metadata follow the new occupants.

Core assertions to embed in the runner (use its `_expect` failure accumulator):

```gdscript
func _assert_slot_order(slots: Array[Control], side: String) -> void:
	_expect(slots.size() == 6, "%s has six slots" % side)
	for index: int in range(slots.size()):
		_expect(int(slots[index].get_meta("slot_index", -1)) == index,
			"%s slot ordering at %d" % [side, index])
		_expect(String(slots[index].get_meta("side", "")) == side,
			"slot retains side identity")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
```

- [ ] Run the new test and record failure caused by missing lane/view presentation, not parser errors. Run GodotIQ validate/check after creating the test script.

## Task 3: Add presentation mapping and reusable character view

**Files:** `Scripts/UI/battle_unit_presentation.gd`, `Scripts/UI/battle_unit_view.gd`, `Scenes/UI/battle_unit_view.tscn`.

- [ ] Add catalog tests first. Resolve known characters through authored skill IDs from the existing catalogs, not mutable names or instance IDs. Use these presentation labels: Scrapshield Bruiser → Bruiser, Wirefang Skirmisher → Skirmisher, Snarewright → Controller, Scrapbroker → Support, Shivrunner → Striker, Mobcaller → Support, Brakka → Commander. Unknown/debug units use `Combatant` and a neutral figure. Verify the exact existing skill identifiers via GodotIQ before authoring the lookup table. This is presentation metadata, not a new gameplay class system.
- [ ] Define the catalog boundary:

```gdscript
# battle_unit_presentation.gd; static, read-only queries.
static func role_for(unit: BattleUnitState) -> String:
static func figure_for(unit: BattleUnitState) -> StringName:
static func statuses_for(unit: BattleUnitState, round_number: int) -> Array[Dictionary]:
```

Each returned status dictionary contains `id: StringName`, `label: String`, `value: String`, and `description: String`. Return newly allocated presentation values; never expose mutable combat dictionaries or status sources to the view.

- [ ] Populate a deterministic status order using existing read APIs:

| Visible badge | Source | Removal condition |
|---|---|---|
| Shield + `Armor N` | `get_armor()` | Value becomes zero |
| Mark + `Advantage` | `has_advantage(round_number)` | Consumed or expired |
| Net + `Snared` | `is_snared(round_number)` | Cleared or expired |
| Drop + `Bleed N` | `get_bleed_snapshot()` | No remaining bleed sources; N is source count, not damage |
| Up/down arrow + signed Speed delta | `get_speed_modifier_snapshot()` and effective/base speed | No speed modifiers; net-zero active modifiers show `Speed ±0` |

Do not expose passive guard bookkeeping as a status. Cooldown controls remain in the skill UI. Defeated units suppress active-status badges without mutating stored combat effects.

- [ ] Create a `PanelContainer`-root unit scene with this stable structure. Author visual nodes via GodotIQ scene operations, not runtime arena construction:

```text
BattleUnitView (PanelContainer)
  UnitInfo (VBoxContainer)
    SlotLabel (Label)
    CharacterRow (HBoxContainer)
      Figure (Control; scene-authored silhouette variants)
      Identity (VBoxContainer)
        RoleLabel (Label)
    UnitNameLabel (Label)
    SpeedLabel (Label)
    HealthBar (ProgressBar)
    HealthLabel (Label)
    StatusRow (HFlowContainer)
    StateLabel (Label; Empty / Defeated)
```

Existing highlight overlays remain children of the slot root. Share scene-local styles rather than creating divergent styles for twelve slots. Decorative descendants ignore mouse input so slot events continue to reach the root.

- [ ] Implement the render boundary:

```gdscript
func render_empty(side: String, slot_index: int) -> void:
func render_unit(unit: BattleUnitState, round_number: int) -> void:
```

`render_empty` clears occupant ID, name, role, figure, HP, speed, and statuses; preserves side/index; displays the slot label and Empty marker. `render_unit` overwrites every field, clamps bar display to valid HP bounds, preserves the existing HealthLabel text format, uses `is_active()` for the defeated marker, and rebuilds status badges without accumulation. Neither method resets arena-owned interaction overlays or mutates the unit.

- [ ] Use figure shape plus visible role text, not color alone. Badges include readable short text and icon shapes; details may appear in tooltips, but the active status must already be identifiable without hover. Wrap badges rather than silently hiding active effects behind an overflow count.
- [ ] Test repeated renders, long names, missing catalog entries, all five status categories, status consumption/expiry, defeat, and occupied→empty→different occupant reuse. Compare authoritative HP, slot, and statuses before/after rendering to prove the view is read-only.
- [ ] Validate/check each script immediately after editing; run the focused runner until component assertions pass. Commit the coherent presentation component and its tests, including generated UID files.

## Task 4: Recompose formations and integrate refresh

**Files:** `Scenes/battle_arena.tscn`, `Scripts/Battle/battle_arena.gd`.

- [ ] Inspect the arena with `scene_map` focused on formations and current HUD sizing. Replace formation grids with container-authored lane columns. Visual left-to-right order is player back, player front, enemy front, enemy back; each column has its heading and three vertically ordered slots.
- [ ] Keep unique names PlayerFormation and EnemyFormation as side roots, changing their arena annotations from GridContainer to Container. Instance six reusable views under each side's two lanes, named Slot0–Slot5 with explicit side/index metadata. Scene authoring sets identity; UI order never invents it.
- [ ] Replace direct-child enumeration with recursive collection of nodes carrying slot metadata, sorted by index. The existing helper name can remain to minimize callers; broaden its parameter type and use the following algorithm:

```gdscript
func _get_control_children(formation: Container) -> Array[Control]:
	var slots: Array[Control] = []
	var pending: Array[Node] = [formation]
	while not pending.is_empty():
		var candidate: Node = pending.pop_back()
		if candidate is Control and candidate.has_meta("slot_index"):
			slots.append(candidate as Control)
		else:
			for child: Node in candidate.get_children():
				pending.append(child)
	slots.sort_custom(func(a: Control, b: Control) -> bool:
		return int(a.get_meta("slot_index")) < int(b.get_meta("slot_index")))
	return slots
```

- [ ] Update `_assign_slot_metadata(formation: Container, side: String)` to retain authored indices and verify six unique indices in range 0–5. Keep the existing signal wiring and interaction metadata initialization. Do not connect additional view click signals on top of gui_input, which would dispatch twice.
- [ ] Replace `_render_units()` label assignments with one empty render per slot followed by occupied renders for valid units. Keep `_get_slot_for_unit()` as the side/index lookup. Reuse `_refresh_turn_ui()` and `notify_authoritative_battle_change()`; do not add a second status polling loop or a revision counter.
- [ ] Preserve all existing overlays, public getters, and original UnitInfo label paths. Validate old direct node-path expectations in regression tests; migrate only hierarchy assertions made obsolete by lane nesting. Never weaken combat assertions to make the new UI pass.
- [ ] Fit the four columns within the existing HUD at 1152×648 using container sizing and wrapping. Keep current skill and default-action controls accessible. If debug/log space constrains the battlefield, bound its existing scroll region; do not implement AC7.4's drawer as a hidden prerequisite.
- [ ] Save the scene. Validate/check arena immediately, then run the focused test and complete Battle regression suite. Specifically inspect damage/defeat/log, speed order, character skills, skill transaction lifecycle, Default Swap, default attacks, active-turn lock, keyword reactions, and preparation flows.
- [ ] Commit the integrated formation replacement with relevant scene/script/UID/test files only.

## Task 5: Acceptance evidence and completion

- [ ] Extend integration checks to render after actual authoritative events: damage, Armor spend, Advantage consumption, Snared expiry, Bleed ticks, speed expiry, swap, removal, and a new battle configuration. Assert stale occupant/status data clears each time.
- [ ] Run `Tests/Run/test_ac3_3_party_formation.gd` and `Tests/WorldMap/test_world_battle_entry.gd` in addition to the Battle suite. Expected: exit code 0 and each runner's own success report.
- [ ] Run project validation/checks and `signal_map(find="orphans")`; compare against baseline. Investigate new errors and orphan connections.
- [ ] Use GodotIQ play → verify_project_runs → read_debug_console → state_inspect. Run `explore(mode="tour")` for visual QA, describe each returned screenshot, fix issues, and tour again. Capture at most one screenshot per verification point and stop the game afterward.
- [ ] At **1152×648**, verify a fully occupied 12-unit formation, sparse formation, a defeated unit, long names, and the maximum supported active-status combination. All lane headings, character identities, HP, roles, and status badges must be legible without overlap or clipping; existing action controls remain readable. Repeat at **1280×720**. Headless geometry checks do not replace this visual gate.
- [ ] Exercise pointer selection and keyboard navigation through existing action controls; verify decorative children do not swallow slot clicks and no duplicate action is dispatched. Preserve existing slot input capability; expanded ribbon/target keyboard behavior belongs to later ACs.
- [ ] Record evidence in `Docs/Specs/AC7/Evidence/AC7.1/verification.md`: actual commands/executable, commit, viewport, fixture, result, screenshot locations, pre-existing failures, and oracle differences. The oracle's illustrative occupancy and names are not requirements for production roster changes.
- [ ] Mark AC7.1 complete only when every row below passes. Commit evidence and the spec status update. Leave AC7.2–AC7.5 unchecked; push only if remote handoff is requested.

| Acceptance obligation | Automated proof | Runtime proof |
|---|---|---|
| Two six-slot formations, front/back lanes | Four containers, 12 unique side/index pairs, ordered public arrays | Four distinct readable columns |
| Character identity and role | Catalog fallback, figure presence, correct occupant name/role after swap | Distinct figures and readable labels |
| HP visibility and refresh | Damage/heal/defeat render assertions; unchanged combat values | HP bar and numeric HP readable |
| Active status iconography | All five categories, deterministic order, consumption/expiry cleanup | Icons/text readable together without a separate screen |
| Empty and defeated states | Reuse/reset/removal fixtures | Distinguishable from occupied active slots without color alone |
| Unchanged battle behavior | Battle suite plus formation/world-entry runners | Selection, target, confirm/cancel, action controls still function |
| Reference viewport | Geometry bounds where practical | 1152×648 visual tour with 12 units and status stress case |

**Done means:** AC7.1 has passing automated and runtime evidence, unchanged formation semantics, no new parser/runtime errors, and a committed task branch containing only relevant implementation and verification files.
