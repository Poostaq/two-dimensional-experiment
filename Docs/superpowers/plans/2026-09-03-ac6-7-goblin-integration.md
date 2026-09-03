# AC6.7 Goblin Integration Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove the complete Goblin combat slice through production world, battle, reward, persistence, party-management, and next-battle entry points, then close AC6 only when every focused and aggregate gate passes.

**Architecture:** AC6.7 adds no compensating gameplay subsystem. A single waited `SceneTree` integration runner drives the production world scene across two Combat encounters and a save/reload boundary, while existing focused runners remain the authority for exhaustive per-class mechanics; evidence and specification ledgers are updated only after the combined gate is green.

**Tech Stack:** Godot 4, typed GDScript, production `.tscn` entry points, SceneTree test runners, JSON V2 run saves, GodotIQ validation/runtime inspection, Markdown evidence ledgers.

---

## Preconditions and Scope Guard

- Update `main` from origin, then create `feat/ac6-7-goblin-integration` in the primary workspace. Do not use a worktree.
- Preserve and do not stage the existing unrelated `.tmp/`, screenshot `.import`, and test `.uid` files.
- The approved design is `Docs/superpowers/specs/2026-08-29-ac6-goblin-combat-vertical-slice-design.md`, especially AC6.7 and AC6-AC08 through AC6-AC11.
- AC6.7 is an integration/evidence gate. Do not add gameplay behavior to make this runner pass. If the RED runner exposes a production defect, stop, document the failing invariant, and create a separately reviewed fix plan.
- Before editing any `.gd`, call `file_context(file, detail="brief")`; use `script_ops` for the edit; then run `validate(target=<file>, detail="brief")` and `check_errors(scope=<file>)`.
- Every headless runner must be awaited, exit zero, and print its explicit PASS line. A timeout or missing PASS line is a failure.

## File and Responsibility Map

- Create `Tests/WorldMap/test_ac6_7_goblin_integration.gd` — one deterministic two-battle production-path runner covering roster/catalog identity, real targeting and movement, logs, formation changes, victory/reward, Cache save/reload/preparation, and fresh battle isolation.
- Create `Docs/Specs/AC6/Evidence/AC6.7/2026-09-03/manual-runtime-check.md` — commands, commit SHA, state observations, screenshots, debug-console result, and the AC6 acceptance ledger.
- Create `Docs/Specs/AC6/Evidence/AC6.7/2026-09-03/implementation-link.txt` — final implementation commit SHA and branch.
- Create `Docs/Specs/AC6/Evidence/AC6.7/2026-09-03/automated-test.log` — combined focused and aggregate runner output.
- Modify `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` — mark AC6.7 complete only after all gates pass.
- Modify `Docs/superpowers/specs/2026-08-29-ac6-goblin-combat-vertical-slice-design.md` — update AC6-AC01 and AC6-AC06 through AC6-AC11 with current evidence; do not rewrite historical evidence entries.
- Modify `Docs/Races/Goblins/Classes.md` and `Docs/Races/Goblins/Commanders.md` — replace stale “unimplemented” status language with evidence-backed implementation status while retaining the progression deferral.

## Risk Invariants

| Risk | Required proof |
|---|---|
| Focused tests are mistaken for integration | The new runner must instantiate `Scenes/world_map_runtime.tscn` and traverse world → battle → reward → world → reload → preparation → next battle. |
| Battle-local state leaks | Before ending battle one, dirty HP, Armor, Advantage, Snared, Bleed, temporary Speed, cooldowns, history, and Brakka’s once-per-round guard; battle two must reconstruct clean units from the persistent roster. |
| Reward or party flow mutates world movement incorrectly | Reward completion and formation rearrangement consume zero extra world moves; only accepted map moves advance the run. |
| Cache duplicates or disappears | Save/reload preserves exact progress/readiness; one committed preparation consumes exactly one ready Cache and applies exactly once. |
| Broad milestone is closed on partial evidence | AC6.7 and aggregate AC6 remain unchecked unless focused runners, full retained suite, GodotIQ project gate, production walkthrough, and progression-exclusion search all pass. |

### Task 1: Add the RED production integration runner

**Files:**

- Create: `Tests/WorldMap/test_ac6_7_goblin_integration.gd`

- [ ] **Step 1: Inspect the production seams before authoring the runner**

Use GodotIQ `file_context(detail="brief")` on:

```text
Tests/WorldMap/test_ac6_6_runtime_integration.gd
Tests/WorldMap/test_world_runtime_migrated_flows.gd
Scripts/WorldMap/world_runtime_controller.gd
Scripts/Battle/battle_arena.gd
Scripts/Run/world_run_state.gd
```

Then use `dependency_graph` on `world_runtime_controller.gd` and `signal_map(scope="file:Scripts/WorldMap/world_runtime_controller.gd")` to confirm the battle/reward/party callbacks used below still match production wiring.

- [ ] **Step 2: Create the waited test runner**

Create the runner through `script_ops(op="create")`. Its orchestration and assertion groups must be exactly:

```gdscript
class_name AC67GoblinIntegrationTests
extends SceneTree

const WORLD_SCENE := "res://Scenes/world_map_runtime.tscn"
const BRAKKA_ID := &"brakka_rustbanner"
const REGULAR_CLASS_IDS: Array[StringName] = [
	&"scrapshield_bruiser", &"wirefang_skirmisher", &"snarewright",
	&"scrapbroker", &"shivrunner", &"mobcaller",
]

var _failures: Array[String] = []
var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_verify_catalog_and_loadouts()
	var fixture: Dictionary = await _create_production_world("ac6-7-integration")
	if fixture.is_empty():
		_finish()
		return
	await _verify_first_battle(fixture)
	await _verify_reward_and_rearrangement(fixture)
	await _verify_reload_preparation_and_second_battle(fixture)
	_finish()
```

Implement the helpers in the same file with typed locals and these concrete assertions:

```gdscript
func _verify_catalog_and_loadouts() -> void:
	for class_id: StringName in REGULAR_CLASS_IDS:
		var character := RunCharacterCatalog.create_by_class_id(class_id)
		_expect(is_instance_valid(character), "%s resolves" % class_id)
		_expect(character.race_id == &"goblin", "%s is Goblin" % class_id)
		_expect(character.get_skills().size() == 3, "%s has three skills" % class_id)
	var brakka := RunCharacterCatalog.create_by_class_id(BRAKKA_ID)
	_expect(is_instance_valid(brakka), "Brakka resolves")
	_expect(brakka.get_skills().size() == 4, "Brakka has three-plus-one loadout")
	_expect(brakka.get_skills()[3].skill_id == &"banner_holder", "Banner Holder is fourth")
```

`_create_production_world()` must generate a deterministic `WorldPlan`, instantiate the production world scene, apply a run state whose six slots contain Brakka plus five regular Goblins, and return the world, plan, fake atomic repository, initial move count, and omitted sixth-class ID. Fail closed if generation, scene instantiation, or `apply_session()` fails.

`_verify_first_battle()` must open a real Combat through the controller, obtain the production `BattleArena`, and assert all of the following before forcing victory with the existing debug damage seam:

- production units retain roster IDs, Goblin race identity, authored skills, and Power/Defense conversion;
- Brakka begins in slot 1 with four skills and Banner Holder applies Advantage to the formation-rule closest active enemy with the exact authored log;
- one Active skill is previewed and confirmed with a real selected target;
- one legal formation path is previewed and confirmed, changing the actor’s slot;
- the skill tooltip names its keyword/effect and the battle log records the committed action;
- deliberately dirty battle-one state includes reduced HP, Armor, Advantage, Snared, Bleed, temporary Speed, a cooldown entry, action history, and Brakka’s reaction guard;
- victory exposes the three production Combat rewards.

`_verify_reward_and_rearrangement()` must select `combat_recruit_scout`, drive the production recruitment placement, place the scout into a chosen slot, close battle, open ordinary party management, move one Goblin before the next battle, and assert roster/HUD formation persistence plus no extra world move consumption. This proves the mixed-party seam; exhaustive `Louder Together` mechanics remain owned by `test_ac6_4_goblin_wave_b.gd`.

`_verify_reload_preparation_and_second_battle()` must make accepted moves until Cache is ready, save the resulting authoritative state, free the first world, recreate the world from that state, enter a second Combat, commit `SPARE_PLATING`, and assert:

```gdscript
_expect(not bool(state.get("cache_ready")), "one committed preparation consumes Cache once")
_expect(arena.get_action_records().is_empty(), "new battle has no action history")
_expect(arena.get_battle_action_log_entries().is_empty(), "new battle has no action log")
_expect(arena.round_number == 1, "new battle starts at round one")
```

For every active unit in battle two, compare against its `RunCharacter` definition and require full HP, base Speed, zero non-preparation Armor, no Advantage/Snared/Bleed, no cooldowns, and no carried reaction guard. Then require exactly `+2 Armor` on active player frontline units and zero preparation Armor on backline/enemy units. Confirm Brakka’s Banner Holder can trigger in round one again. Verify the previously rearranged persistent slot layout is used to construct the fresh battle.

Finish with the repository-standard explicit counter and PASS output:

```gdscript
func _finish() -> void:
	if _failures.is_empty():
		print("PASS test_ac6_7_goblin_integration (%d/%d)" % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
```

- [ ] **Step 3: Run the runner and preserve RED evidence**

```powershell
godot --headless --path . --script res://Tests/WorldMap/test_ac6_7_goblin_integration.gd
```

Expected before any remediation: either PASS because AC6.1–AC6.6 already satisfy the integration contract, or a precise FAIL naming an existing production invariant. Do not weaken assertions and do not modify production code in this task.

- [ ] **Step 4: Validate the new runner**

```text
validate(target="Tests/WorldMap/test_ac6_7_goblin_integration.gd", detail="brief")
check_errors(scope="Tests/WorldMap/test_ac6_7_goblin_integration.gd")
```

Expected: zero convention and parser errors.

- [ ] **Step 5: Commit the integration runner**

```powershell
git add Tests/WorldMap/test_ac6_7_goblin_integration.gd
git commit -m "test: add AC6.7 Goblin integration gate"
```

### Task 2: Run focused and retained automated gates

**Files:**

- Create: `Docs/Specs/AC6/Evidence/AC6.7/2026-09-03/automated-test.log`

- [ ] **Step 1: Run every AC6 focused runner**

Run and append complete stdout, stderr, command, and exit code for:

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac6_1_combat_foundation.gd
godot --headless --path . --script res://Tests/Battle/test_ac6_2_keyword_reactions.gd
godot --headless --path . --script res://Tests/Battle/test_ac6_3_goblin_wave_a.gd
godot --headless --path . --script res://Tests/Battle/test_ac6_4_goblin_wave_b.gd
godot --headless --path . --script res://Tests/Battle/test_ac6_5_brakka.gd
godot --headless --path . --script res://Tests/Run/test_ac6_6_quartermaster_state.gd
godot --headless --path . --script res://Tests/Battle/test_ac6_6_battle_preparation.gd
godot --headless --path . --script res://Tests/WorldMap/test_ac6_6_runtime_integration.gd
godot --headless --path . --script res://Tests/WorldMap/test_ac6_7_goblin_integration.gd
```

Expected: all exit 0 with their PASS lines.

- [ ] **Step 2: Run affected cross-system regressions**

Run the existing Battle result/reward, active-turn lock, party formation, migrated world flow, battle entry, runtime model/save coordinator, save codec/store, HUD, and cutover runners. Use `rg --files Tests | Sort-Object` to enumerate the current paths rather than relying on a stale copied suite list. Expected: every runner exits 0.

- [ ] **Step 3: Run the full retained headless suite**

Use the repository’s existing full-suite command or loop over every `Tests/**/test_*.gd` waited runner in sorted order. Record runner count, assertion/PASS totals when printed, exit codes, and elapsed time. Expected: no failure, timeout, crash, or missing PASS result.

- [ ] **Step 4: Verify deterministic replay**

Run `test_ac6_7_goblin_integration.gd` a second time with the same seed and compare its normalized PASS/state summary with the first run. Expected: identical selected targets, formation transitions, reward choice, Cache checkpoints, and next-battle state.

- [ ] **Step 5: Commit automated evidence**

```powershell
git add Docs/Specs/AC6/Evidence/AC6.7/2026-09-03/automated-test.log
git commit -m "test: record AC6.7 automated evidence"
```

### Task 3: Execute the production runtime and GodotIQ gate

**Files:**

- Create: `Docs/Specs/AC6/Evidence/AC6.7/2026-09-03/manual-runtime-check.md`
- Create: `Docs/Specs/AC6/Evidence/AC6.7/2026-09-03/screenshots/` artifacts only when each named verification point is reached.

- [ ] **Step 1: Run the static project gate**

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(find="orphans", detail="brief")
```

Expected: zero new convention errors, zero parser/script errors, and no orphan signals introduced by AC6.

- [ ] **Step 2: Verify clean production startup**

```text
verify_project_runs(scene="main", check_scope="project", stop_after=false)
read_debug_console()
```

Expected: Play starts and the console contains no new error or warning attributable to AC6.

- [ ] **Step 3: Perform the production walkthrough**

Through normal UI entry points:

1. Select Brakka, start a seeded run, and inspect the six-slot formation and `Cache 0/4` HUD.
2. Enter Combat, inspect all visible Goblin skill names/tooltips and Brakka’s fourth Passive.
3. Use a real target-selecting Active skill, use a real movement path, and capture the resulting keyword/log presentation.
4. Rearrange formation, win, choose Recruit Scout, place the mixed-race recruit, return to world, and rearrange again.
5. Accrue Cache, save/reload before the next Combat, and verify exact progress/readiness.
6. Enter the next Combat, verify actions are locked, commit one preparation choice, and inspect exact target/Armor application.
7. Confirm fresh HP/status/cooldown/history/reaction state and the persisted formation; confirm Brakka’s Passive triggers again.
8. Read the debug console and stop Play.

Capture at most one screenshot for each materially different verification point: first-battle Goblin UI/log, post-reward mixed formation, reloaded Cache HUD, preparation lock/application, and clean second-battle state. Use `state_inspect` for scalar/state evidence.

- [ ] **Step 4: Write the evidence record**

Record date, branch, exact commit SHA, commands, PASS lines, GodotIQ results, screenshot paths, inspected state values, deterministic seed, reward choice, formation before/after, Cache before/after reload, preparation result, fresh-state comparison, and debug-console result. Explicitly state that leveling/evolution/mechanical progression was not added.

### Task 4: Close AC6 documentation and perform final verification

**Files:**

- Create: `Docs/Specs/AC6/Evidence/AC6.7/2026-09-03/implementation-link.txt`
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
- Modify: `Docs/superpowers/specs/2026-08-29-ac6-goblin-combat-vertical-slice-design.md`
- Modify: `Docs/Races/Goblins/Classes.md`
- Modify: `Docs/Races/Goblins/Commanders.md`

- [ ] **Step 1: Verify progression exclusion before changing status**

```powershell
rg -n -i "goblin.*(level|evolution|upgrade)|(?:level|evolution|upgrade).*goblin" Scripts Scenes Tests
rg -n -i "leveling|evolution|mechanical.*progression" Docs/TO_CONSIDER.md Docs/Races/Goblins
```

Expected: no implemented Goblin leveling/evolution/mechanical progression; the deferral is explicitly documented. Any unrelated textual matches must be classified in the evidence record.

- [ ] **Step 2: Update the active specification and design ledger narrowly**

Change AC6.7 to `[x]` only if Tasks 1–3 are fully green. In the AC6 design ledger:

- AC6-AC01 cites the active spec and implementation plans;
- AC6-AC06 and AC6-AC07 cite AC6.6 final evidence;
- AC6-AC08 cites the two-battle fresh-state runner and production walkthrough;
- AC6-AC09 cites Cache save/reload and exactly-once preparation evidence;
- AC6-AC10 cites the exclusion search and deferral documents;
- AC6-AC11 cites focused runners, full suite, deterministic rerun, GodotIQ checks, startup, walkthrough, and console result;
- the overall coverage result becomes PASS only if all eleven rows are PASS.

Update Goblin class/commander status prose to distinguish implemented/evidenced combat behavior from intentionally deferred progression.

- [ ] **Step 3: Write the implementation link**

Write the branch and the final relevant commit SHA to `implementation-link.txt`. If documentation is not yet committed, write the runner/evidence commit first, then amend the record after the final documentation commit without claiming a nonexistent SHA.

- [ ] **Step 4: Run final integrity checks**

```powershell
git diff --check
git status --short
godot --headless --path . --script res://Tests/WorldMap/test_ac6_7_goblin_integration.gd
```

Then rerun:

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(find="orphans", detail="brief")
verify_project_runs(scene="main", check_scope="project", stop_after=true)
```

Expected: clean diff, only AC6.7 files staged, focused runner PASS, project gate clean, production starts, and Play stops normally.

- [ ] **Step 5: Commit the milestone closure**

```powershell
git add Docs/Specs/AC6/Evidence/AC6.7 Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/superpowers/specs/2026-08-29-ac6-goblin-combat-vertical-slice-design.md Docs/Races/Goblins/Classes.md Docs/Races/Goblins/Commanders.md
git commit -m "docs: evidence AC6 Goblin vertical slice"
```

## Plan Self-Review Results

- **Spec coverage:** All AC6.7 bullets map to the new runner, retained focused suites, or production walkthrough; AC6-AC08 through AC6-AC11 each have explicit evidence gates.
- **No compensating feature code:** The plan creates only a test runner and evidence/docs. Production defects trigger a separate fix plan.
- **Battle isolation:** The first battle deliberately dirties every named battle-local category; the second compares fresh units to persistent definitions and independently checks preparation Armor.
- **Durability:** Cache is inspected before save, after reload, and after exactly one preparation commit.
- **Mixed party and formation:** Recruitment plus two formation transitions are verified without extra world movement.
- **Progression boundary:** Repository search and preserved deferral text prevent AC6.7 from silently adding leveling/evolution mechanics.
- **Status safety:** No checkbox or aggregate ledger changes until automated, deterministic, GodotIQ, runtime, and console gates all pass.
