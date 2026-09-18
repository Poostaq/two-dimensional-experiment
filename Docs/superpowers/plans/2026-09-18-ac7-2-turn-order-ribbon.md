# AC7.2 Turn-Order Ribbon Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` to implement this plan task by task and `superpowers:test-driven-development` for behavior changes. Steps use checkboxes for tracking. Follow repository AGENTS.md: primary workspace, dedicated branch, no worktrees. Execute inline unless delegation is requested.

**Goal:** Give the current actor a persistent framed `NOW` ribbon entry and link pointer hover or keyboard focus on each entry to exactly one corresponding battlefield character.

**Architecture:** BattleArena remains authoritative for queue order, current actor, phases, and unit-to-slot mapping. A presentation-only BattleTurnOrderRibbon renders detached entry dictionaries and emits one resolved preview ID. BattleUnitView owns an independent preview overlay; existing current, target, effect, and damage layers retain their owners.

**Tech Stack:** Godot 4, typed GDScript, authored Control scenes, SceneTree test runners, GodotIQ scene/script tools.

**Status:** Completed inline on `feature/ac7-2-turn-order-ribbon`, implementation commit `0df1ee0`. All five task groups are complete. See [verification and documented layout adjustments](../../Specs/AC7/Evidence/AC7.2/verification.md) for automated tests, rendered-input evidence, screenshots, and structured runtime checks. The checklists below remain the original execution instructions. Planning baseline was `cf52969` on `feature/ac7-1-living-lanes` with a clean working tree.

**References:** [MVP criterion and verification contract](../../Specs/GAME_DESIGN_SPEC_MVP.md), [approved visual oracle](../../Mockups/AC7/battle-ui-oracle.html), [broader AC7 plan, Task 3](2026-09-17-ac7-battle-ui-presentation.md), [AC7.1 implementation evidence](../../Specs/AC7/Evidence/AC7.1/verification.md).

## Scope and design decisions

The approved AC7 composition is the design input. This plan specializes Task 3 against the completed AC7.1 code. **AC7.2 adds new UI components and presentation wiring.** The existing turn summary and target overlay do not implement a ribbon or turn-order preview. Do not redesign the oracle or implement AC7.3's action bar, AC7.4's drawer, or AC7.5's global visual-state resolver. Keep existing action controls, log, and debug controls usable.

### Hard constraint: preserve combat behavior

Implementation is limited to new presentation components, read-only presentation adapters, refresh wiring, and preview routing. **Do not change queue construction, turn sorting or tie-breaking, current-actor advancement, round rollover, defeat/removal semantics, formation rules, save data, action validation, targeting legality, action resolution, or transaction behavior.** Do not modify `BattleTurnQueue` or combat rule/transaction/save modules for AC7.2.

The existing arena lifecycle methods may gain presentation refresh/cleanup calls only; their authoritative state mutations and ordering must remain unchanged. Ribbon hover, focus, click, and keyboard activation must not mutate combat state or invoke combat actions. Filtering the visible queue is a detached display operation; it must not filter or rewrite `_turn_queue`, `_current_turn_index`, or the public queue query. A combat issue discovered during this work must be recorded separately rather than fixed as part of AC7.2. Review the final diff against this constraint even if all tests pass.

### Existing baseline and required additions

These source anchors describe the inspected AC7.1 baseline; line numbers may move during implementation.

| Existing baseline | Required AC7.2 addition |
|---|---|
| `Scenes/battle_arena.tscn:224`: existing turn-summary area | Create ribbon scene/script and instance the ribbon in this HUD area above the formations; retain the existing summary |
| `Scenes/UI/battle_unit_view.tscn:176`: existing target overlay | Add a separate `TurnOrderPreviewOverlay`; preserve the target overlay and its owner |
| `Scripts/Battle/battle_arena.gd:392`, `:396`: queue and current-actor queries | Read these existing authoritative queries for detached ribbon presentation |
| `Scripts/Battle/battle_arena.gd:881`, `:2032`: authoritative-change and turn-UI refresh paths | Wire ribbon refresh and reapply resolved preview after unit rendering, including early-return paths |
| `Scripts/UI/battle_unit_view.gd:23`, `:45`: empty/occupied lane presentation | Add the preview setter and empty/defeated cleanup; retain lane rendering responsibilities |

There is currently **no ribbon scene, ribbon script, or turn-order preview overlay**. Task 3 creates the ribbon, and Task 4 creates the overlay/setter and connects the ribbon preview signal to BattleArena. Task 5 supplies AC7.2 automated and rendered-input evidence, its `.gdignore`, and the spec status update only after the new behavior passes, as required by `Docs/Specs/GAME_DESIGN_SPEC_MVP.md:254`.

Approaches considered:

1. **Recommended: a reusable ribbon with a small arena adapter.** Gives queue rendering and interaction one owner, keeps model references outside the ribbon, and reuses the existing slot lookup.
2. Build all ribbon controls and callbacks in BattleArena. Fewer files, but adds presentation state to an already large controller and makes isolated focus tests harder.
3. Introduce the full AC7 snapshot and visual resolver first. Useful for AC7.5, but couples this criterion to unrelated action and debug work.

The ribbon shows the **remaining current-round queue**, starting at the current actor, labeled `NOW`, `2`, `3`, and so on. Do not rotate already-acted units into a predicted next round: round-end expiry can change speed and order. At the next round, render the newly authoritative queue. This is a presentation choice, not a change to `get_turn_queue()`.

Pointer hover takes precedence over keyboard focus while a pointer is over a ribbon entry. When the pointer leaves, a still-focused entry resumes its preview. Exits clear only their own source ID; a delayed exit from A must not clear a newer preview of B. This resolves mixed input to at most one preview without losing keyboard focus.

Current-turn framing is independent of hover and focus: an authored outer frame and visible `NOW` label stay visible through normal, hovered, pressed, and focused entry states. A focus outline remains separately recognizable. Battlefield preview uses an inner outline plus a small `ORDER` marker, with no pulse or scale animation. The existing current-actor frame and target indicators must remain readable when they overlap it.

## Existing contracts and implementation hazards

- `BattleArena.get_turn_queue()` returns a duplicate of the full round queue, including actors that already acted. `get_current_unit()` uses `_current_turn_index`.
- `advance_turn()` advances the index and rebuilds the queue only at round rollover. Never call `BattleTurnQueue.build()` from presentation code or sort entries by displayed speed.
- `remove_battle_unit()` currently rebuilds the queue and resets its index. Display the resulting authoritative state; do not correct or redesign this behavior here.
- `notify_authoritative_battle_change()` renders units and may return early after rendering the skill transaction. Add ribbon refresh before that early return so defeat/removal and presentation changes cannot leave stale entries.
- `_refresh_turn_ui()` has terminal and no-current early returns. Refresh ribbon state on all paths.
- `_render_units()` calls `render_empty()` on every slot before rendering occupants. A preview cleared by this pass must be reapplied by stable unit ID after the entire pass.
- Unit views belong to slots. `unit_id` follows the occupant on Swap; side/slot metadata and view identity stay fixed. Resolve via `get_unit_by_id()` and `_get_slot_for_unit()` each time, never cache a unit-to-Control association across swaps.
- `_refresh_highlights()` resets existing slot overlays and can return early for log feedback. Keep ribbon preview in its own overlay rather than inserting it into that precedence chain.
- The previous Control-scene GodotIQ tour timed out. Try the required tool flow, but retain a rendered real-input fixture as an evidence fallback; headless signal tests do not prove pointer hit testing or layout.

## File map

| File | Responsibility |
|---|---|
| Create `Scenes/UI/battle_turn_order_ribbon.tscn` | Named ribbon region, pinned current entry host, horizontal scroll region for remaining entries, empty-state label |
| Create `Scenes/UI/battle_turn_order_entry.tscn` | Reusable focusable entry with initial/icon, short name, ordinal, independent current frame and `NOW` label |
| Create `Scripts/UI/battle_turn_order_ribbon.gd` | Render keyed entry instances, retain focus on benign refresh, resolve hover/focus, emit preview ID |
| Modify `Scenes/battle_arena.tscn` | Instance ribbon above formations inside the existing HUD containers |
| Modify `Scripts/Battle/battle_arena.gd` | Detached queue adapter, refresh/reset boundaries, validated preview-to-slot routing |
| Modify `Scenes/UI/battle_unit_view.tscn` | Mouse-ignoring preview outline and `ORDER` marker |
| Modify `Scripts/UI/battle_unit_view.gd` | Preview setter and empty/defeated cleanup |
| Create `Tests/Battle/test_ac7_2_turn_order_ribbon.gd` | Queue, framing, interaction arbitration, lifecycle and non-mutation tests |
| Create `Tests/Battle/capture_ac7_2_turn_order_ribbon.gd` | Rendered viewport input, keyboard traversal, geometry and screenshot evidence |
| Create `Docs/Specs/AC7/Evidence/AC7.2/verification.md` and `.gdignore` | Actual commands, results, screenshots, deviations and limitations |
| Modify `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` | Mark AC7.2 only after automated and runtime evidence passes |

## Task 1: Establish implementation branch and baseline

- [ ] Preserve this plan and any unrelated work before switching branches. Update main and create the implementation branch; do not carry unrelated unstaged changes onto it.

```powershell
git status --short
git fetch origin
git switch main
git pull --ff-only origin main
git merge-base --is-ancestor cf52969 HEAD
git switch -c feature/ac7-2-turn-order-ribbon
```

The ancestry check must succeed before implementation: AC7.1 is a dependency. If it does not, inspect the branch graph and bring the completed AC7.1 work into the integration workflow before continuing. Do not silently implement against pre-AC7.1 scenes. Preserve the plan on the task branch if it is not yet on main.

- [ ] Call `file_context(detail="brief")` before editing each file, including new paths; a missing-file result is expected before creation. Use `dependency_graph` and `impact_check` before changing arena/view APIs, and `signal_map` to inspect wiring. Use GodotIQ writes for scripts and scenes.
- [ ] Record project `validate` and `check_errors` baseline. After each script edit, run that file's `validate` then `check_errors` before editing another script. Baseline warning counts from AC7.1 are historical evidence, not permission to ignore new warnings.
- [ ] Verify the prior executable exists, then run the Battle suite with bounded processes and captured output:

```powershell
@'
from pathlib import Path
import subprocess
exe = Path(r'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe')
assert exe.is_file(), 'Resolve an installed Godot executable before testing'
for test in sorted(Path('Tests/Battle').glob('test_*.gd')):
    result = subprocess.run([str(exe), '--headless', '--path', '.', '--script',
                             'res://' + test.as_posix()],
                            capture_output=True, text=True, timeout=60)
    print(test.name, result.returncode)
    print(result.stdout)
    print(result.stderr)
    assert result.returncode == 0, test
    assert 'SCRIPT ERROR' not in result.stdout + result.stderr, test
'@ | python -
```

Expected: all existing runners exit zero, with no script errors. Investigate baseline failures separately and retain their output.

## Task 2: Lock the ribbon contract with failing tests

**File:** `Tests/Battle/test_ac7_2_turn_order_ribbon.gd`.

- [ ] Use the existing deferred async SceneTree runner pattern, failure accumulation, arena cleanup and nonzero failure exit. Load new scenes with `load()`. Initially test for missing ribbon/preview methods without parser references to nonexistent global classes.
- [ ] Use an actor at player slot 0, speed 10; enemy slot 0, speed 8; ally slot 3, speed 6. Assert initial order actor/enemy/ally, then enemy/ally after one advancement and ally after two. After rollover assert the rebuilt authoritative order. Add equal-speed units to verify existing player-before-enemy and numeric slot tie order.
- [ ] Add a separate maximum-occupancy fixture with twelve active units, an empty fixture, a defeated occupant, and two units sharing a display name but having different IDs. Never key entries by display name.

Core assertions to embed in the runner after `_expect` and the arena fixture exist:

```gdscript
func _assert_queue(arena: BattleArena, expected: Array[StringName]) -> void:
	var ribbon: Node = arena.find_child("TurnOrderRibbon", true, false)
	_expect(is_instance_valid(ribbon), "ribbon exists")
	if not is_instance_valid(ribbon):
		return
	_expect(ribbon.has_method("get_entry_ids"), "ribbon exposes rendered order")
	if ribbon.has_method("get_entry_ids"):
		_expect(ribbon.call("get_entry_ids") == expected, "remaining queue order")


func _assert_preview(arena: BattleArena, expected: StringName) -> void:
	var count: int = 0
	for slot: Control in arena.get_player_slots() + arena.get_enemy_slots():
		var overlay: Control = slot.get_node_or_null("TurnOrderPreviewOverlay")
		_expect(is_instance_valid(overlay), "dedicated preview overlay exists")
		if is_instance_valid(overlay) and overlay.visible:
			count += 1
			_expect(slot.get_meta("unit_id", &"") == expected, "preview follows ID")
	_expect(count == (0 if expected.is_empty() else 1), "exactly one or zero previews")
```

- [ ] Assert one visible `NOW` label and current frame while combat has a valid current actor; zero for empty, preparation-blocked, or completed battle. Check the current frame stays visible when another entry is hovered/focused.
- [ ] Test hover A, hover B, delayed exit A, exit B; focus A, hover B, exit B, focus exit A. Expected previews are A/B/B/empty and A/B/A/empty respectively. Test entering and leaving the same entry with both sources active.
- [ ] Test a benign HP refresh while focused: same entry instance and keyboard focus remain; no duplicate signals or entries. Test turn change, round rollover, reset with reused IDs, preparation entry, completion, defeat and removal: old previews clear.
- [ ] Save selected skill, transaction snapshot, inspected unit ID, current actor, battle revision, round, HP and committed-history count; hover/focus/click/Enter on ribbon entries must not change them. Compare snapshots only across preview events, not across intentional battle mutations.
- [ ] Run the new test alone. Expected initial failure: ribbon/overlay or required method absent. Fix test syntax/setup failures before treating this as a valid red result.

## Task 3: Build the presentation-only ribbon

**Files:** the two new ribbon scenes and `Scripts/UI/battle_turn_order_ribbon.gd`.

- [ ] Author the entry as a Button with mouse-ignoring children `Identity/Icon`, `Identity/Name`, `OrderLabel`, `NowLabel`, and `CurrentFrame`. Use a readable initial as the icon fallback, full identity/team/position in tooltip text, and visible team distinction beyond color. Keep `CurrentFrame` independent of Button theme states.
- [ ] Author the ribbon with `CurrentEntryHost`, `UpcomingScroll/Entries` and `EmptyLabel`. Pin the current entry outside the horizontally scrollable upcoming region so `NOW` remains visible when later entries are explored. Set vertical scrolling off; all entries must be reachable by keyboard and pointer. Focused upcoming entries scroll into view.
- [ ] Implement these typed public contracts; dictionaries contain only detached presentation values:

```gdscript
signal unit_preview_changed(unit_id: StringName)

# render_entries(entries: Array[Dictionary], current_id: StringName) -> void
# clear_preview() -> void
# get_entry_ids() -> Array[StringName]
# get_preview_unit_id() -> StringName
# get_entry_control(unit_id: StringName) -> Control
```

Each row has `unit_id: StringName`, `display_name: String`, `side: int`, and `ordinal: int`. The arena supplies current ID separately. Create entries by instantiating the authored scene, connect each instance once, and update/reorder keyed instances on refresh. Free only removed entries. Do not rebuild every entry on HP or status changes. Set accessible description/name using properties supported by the installed engine, backed by visible name/ordinal and full tooltip text.

- [ ] Keep `_hovered_id`, `_focused_id`, `_preview_id` and `_entries_by_id` as ribbon-local state. Resolve through one method:

```gdscript
func _resolve_preview() -> void:
	var next_id: StringName = _hovered_id if not _hovered_id.is_empty() else _focused_id
	if not _entries_by_id.has(next_id):
		next_id = &""
	if next_id == _preview_id:
		return
	_preview_id = next_id
	unit_preview_changed.emit(_preview_id)
```

Entry enter handlers set their source ID and resolve; exit handlers clear only if the stored source equals that entry ID. `clear_preview()` clears both source IDs, releases focus only if owned by a ribbon entry, then resolves. Clear before freeing entries. An unchanged render must not synthesize new hover events or acquire focus. On an actor/round/reset boundary, require a fresh hover entry or focus event to resume preview.

- [ ] Do not connect `pressed` to inspection, skill selection, targeting or turn advancement. Button click may acquire focus and show the same informational preview; Enter has no gameplay effect. Explicitly wire previous/next focus order through current then upcoming entries and allow Tab/Shift-Tab to enter/leave the ribbon without trapping focus.
- [ ] Test the isolated ribbon arbitration and keyed-refresh cases, then validate/check the script. Commit the focused ribbon component and its tests when this milestone passes.

## Task 4: Link arena state and battlefield preview

**Files:** `Scripts/Battle/battle_arena.gd`, `Scenes/battle_arena.tscn`, `Scripts/UI/battle_unit_view.gd`, `Scenes/UI/battle_unit_view.tscn`.

- [ ] Add a scene-authored `TurnOrderPreviewOverlay` with an outline and `ORDER` child marker to the reusable unit scene. Use full-rect anchors and container-safe margins, `mouse_filter = IGNORE` for all overlay children, and no minimum-size contribution that expands the unit card. Keep it visually distinct from the outer current frame and existing target tint.
- [ ] Add the view setter below. Call it with `false` from `render_empty()` and for defeated occupants. After the arena's complete render pass, the arena reapplies the resolved live ID.

```gdscript
func set_turn_order_preview(active: bool) -> void:
	var overlay: Control = $TurnOrderPreviewOverlay
	overlay.visible = active
	set_meta("turn_order_preview", active)
```

- [ ] Instance the newly created ribbon as `%TurnOrderRibbon` in the existing turn-summary HUD area (`Scenes/battle_arena.tscn:224` at baseline), above formations, and connect `unit_preview_changed` once during arena readiness. Keep the existing current-unit summary for compatibility. Use containers and bounded horizontal scrolling to fit 1152×648; do not shrink away AC7.1 identity/HP/status content or hide action controls to make room.
- [ ] Add `_get_turn_order_entries() -> Array[Dictionary]` to BattleArena using this algorithm:

```gdscript
func _get_turn_order_entries() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var current: BattleUnitState = get_current_unit()
	if is_battle_complete() or is_preparation_required():
		return rows
	if not is_instance_valid(current) or not current.is_active():
		return rows
	var reached_current: bool = false
	for unit: BattleUnitState in get_turn_queue():
		if not is_instance_valid(unit):
			continue
		if unit.unit_id == current.unit_id:
			reached_current = true
		if not reached_current or not unit.is_active():
			continue
		if not is_instance_valid(get_unit_by_id(unit.unit_id)):
			continue
		rows.append({"unit_id": unit.unit_id, "display_name": unit.display_name,
			"side": unit.side, "ordinal": rows.size() + 1})
	return rows
```

- [ ] Add `_turn_order_preview_id: StringName`, `_refresh_turn_order_ribbon() -> void`, `_on_turn_order_preview_changed(unit_id: StringName) -> void`, `_apply_turn_order_preview() -> void`, and `_clear_turn_order_preview() -> void`. The event handler accepts an ID only if it occurs in the currently rendered rows and resolves to a living unit during active battle. Clear all twelve preview setters before setting the one resolved slot. Invalid IDs resolve to empty; no slot/action handlers are invoked.
- [ ] `_refresh_turn_order_ribbon()` supplies rows/current ID, prunes removed/dead sources, then reapplies preview after unit rendering. Call it in `_refresh_turn_ui()` before terminal/empty early returns and in `notify_authoritative_battle_change()` after `_render_units()` but before its transaction early return. Guard readiness for pre-tree configuration.
- [ ] Clear both ribbon source state and arena preview before `configure_units()` replaces units, before successful turn advancement, and when preparation/completion begins. Track current actor/round/phase changes in refresh as a second guard against mutation paths outside `advance_turn()`. Do not clear focus for ordinary HP/status refresh. When entries disappear, release only their focus; never steal focus from action controls or result/preparation UI.
- [ ] After actual Swap or relocation, resolve the preview ID against the new slot. If the operation advances the turn, the turn boundary clears preview instead. Defeated cards keep AC7.1 identity/HP/defeat presentation but cannot be previewed from the ribbon.
- [ ] Run the new test plus Living Lanes, active-turn skill locking, character skills, and default actions. Fix any selection, input passthrough or overlay regression before committing integration.

## Task 5: Verify real input, layout, and lifecycle

**Files:** `Tests/Battle/capture_ac7_2_turn_order_ribbon.gd`, AC7.2 evidence, MVP spec.

- [ ] Adapt the existing `Tests/Battle/capture_ac7_1_living_lanes.gd` fixture through GodotIQ reads. Use actual viewport mouse motion/button and keyboard events, not direct signal emission, for rendered interaction evidence. Include sparse and twelve-unit fixtures with a long name.
- [ ] At 1152×648 and 1280×720, verify ribbon and formations remain inside the viewport; all actions remain reachable; `NOW` stays visible while upcoming entries scroll; long names do not force width growth; tooltips expose full names. Keyboard traversal must reach every entry and leave the ribbon.
- [ ] Capture pointer preview of a player and enemy, keyboard preview, and current-plus-preview overlap. Add preview-plus-selected-target overlap and assert target/transaction snapshots are unchanged. Capture after turn advancement and after defeat/reset to show cleanup. Describe each inspected screenshot and fix clipping or ambiguous overlap before recapturing.
- [ ] Use GodotIQ `run(play)` → `verify_project_runs` → `read_debug_console` → `state_inspect`, plus `explore(mode="tour")` for visual QA. If capture fails, retry the documented runtime handshake once, then record the limitation and use rendered fixture screenshots with real input. Stop the game afterward.
- [ ] Run the complete Battle suite and the two adjacent regressions `Tests/Run/test_ac3_3_party_formation.gd` and `Tests/WorldMap/test_world_battle_entry.gd`, using the bounded runner from Task 1. Run the rendered fixture with `--rendering-method gl_compatibility` instead of `--headless`. Require process completion, zero exit, no script errors and inspected images.
- [ ] Run final `validate(target="project", detail="brief")`, `check_errors(scope="project")`, `signal_map(find="orphans")`, and the normal project-entry runtime smoke check. Review the final diff for only ribbon-related changes and generated UIDs. Verify explicitly that queue construction/sorting, authoritative turn and round transitions, save data, targeting legality, and action resolution are unchanged; arena lifecycle edits must be limited to presentation refresh/cleanup calls.
- [ ] Record actual executable/version, branch/commit, test commands/results, baseline differences, input cases, screenshots and any limitations in `Docs/Specs/AC7/Evidence/AC7.2/verification.md`. Add `.gdignore` to prevent evidence images/logs becoming game assets. Mark only AC7.2 complete when every acceptance row below passes.
- [ ] Commit only relevant source, scenes, tests, UIDs, evidence and spec update on the task branch. Push only if remote handoff/review is requested.

## Acceptance and evidence map

| Requirement | Automated proof | Runtime proof |
|---|---|---|
| Persistent current actor treatment | Exactly one current frame/`NOW`; unaffected by other previews | Inspect normal, hovered, focused, scrolled and overlapping states |
| Authoritative ordering | Current-round suffix, tie order, turn advance, round rebuild, duplicate names | Observe advance and round rollover |
| Pointer and keyboard linkage | Source arbitration, ID-to-slot mapping, exactly one overlay | Actual motion and Tab/Shift-Tab across both teams |
| Cleanup and safety | Exit, focus loss, removed/dead units, reset with reused IDs, phase/turn change, empty queue | Inspect defeat, reset and completion without stale emphasis |
| Preserve gameplay and existing visuals | Selection/transaction/state non-mutation; Swap mapping; Battle regressions | Target plus preview plus current remain distinct; input reaches cards/actions |
| Accessible constrained layout | Entry identity/ordinal/tooltip, focus order, geometry checks | Twelve entries and long names at both target viewport sizes |

**Done means:** AC7.2 has passing automated and real-input visual evidence, existing combat and AC7.1 contracts remain intact, the normal project entry runs without new errors, and relevant changes are committed on the dedicated branch. AC7.3–AC7.5 remain pending.
