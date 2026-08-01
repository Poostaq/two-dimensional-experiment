# AC2.8 Skill Targeting and Execution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement all six AC2.8 active skills with typed rules, free/predefined targeting, explicit confirmation, stale-safe transactions, cooldowns, temporary Speed effects, and deterministic evidence.

**Architecture:** Extend `CharacterSkill` and `BattleUnitState` with typed immutable definition data and mutable per-unit battle state. Add pure result/rules objects and a transaction orchestrator that reports presentation snapshots; keep committed combat mutation, scene rendering, logging, and lifecycle integration in `BattleArena`. Use GodotIQ for every Godot file inspection/edit/validation and implement each behavior through a red-green TDD cycle.

**Tech Stack:** Godot 4.7, typed GDScript, Godot scene resources, headless `SceneTree` test runners, GodotIQ MCP validation/runtime tooling.

---

## File structure

- `Scripts/Battle/character_skill.gd`: immutable identity, description, typed targeting/effect/requirement/cooldown definition.
- `Scripts/Battle/battle_unit_state.gd`: base/effective Speed, cooldown counters, temporary modifiers, and defensive runtime-state APIs.
- `Scripts/Battle/skill_action_reason.gd`: typed rejection code and exact player message.
- `Scripts/Battle/skill_target_evaluation.gd`: immutable target-evaluation result.
- `Scripts/Battle/skill_effect_plan.gd`: immutable ordered operations produced by validation.
- `Scripts/Battle/skill_confirmation_validation.gd`: immutable confirmation result.
- `Scripts/Battle/battle_skill_rules.gd`: pure target, availability, stale, and effect-plan evaluation.
- `Scripts/Battle/battle_skill_transaction.gd`: explicit transaction state machine, generations, locks, confirmation latch, and presentation snapshot.
- `Scripts/Battle/battle_action_log_entry.gd`: one logical skill-action record supporting damage and Speed targets without breaking `BattleLogEntry` damage history.
- `Scripts/Battle/battle_arena.gd`: UI event forwarding, guarded effect-plan commit, revision ownership, turn/round integration, and rendering.
- `Scenes/battle_arena.tscn`: scene-owned contextual action region and per-slot targeting overlay nodes.
- `Tests/Battle/test_ac2_8_skill_targeting.gd`: focused model, rules, transaction, integration, UI, stale, and callback coverage.
- `Tests/Battle/test_ac2_6_character_skills.gd`: constructor updates for typed definitions while preserving AC2.6 assertions.
- `Tests/Battle/test_ac2_7_skill_preview.gd`: constructor/fixture updates while preserving AC2.7 tooltip assertions.
- `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`: AC2.8 verification contract and completion checkbox after evidence passes.
- `Docs/Specs/AC2/Evidence/AC2.8/2026-08-01/*`: automated log, manual runtime record, and implementation link.

### Task 1: Define the failing AC2.8 model and fixture contract

**Files:**
- Create: `Tests/Battle/test_ac2_8_skill_targeting.gd`
- Modify: `Scripts/Battle/character_skill.gd`
- Modify: `Tests/Battle/test_ac2_6_character_skills.gd`
- Modify: `Tests/Battle/test_ac2_7_skill_preview.gd`

- [ ] **Step 1: Inspect and baseline every affected script**

Run GodotIQ `file_context(detail="brief")` and `impact_check(action="modify")` for all four files, then run:

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_6_character_skills.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_7_skill_preview.gd
```

Expected: both exit `0` with their existing AC2.6/AC2.7 pass messages.

- [ ] **Step 2: Write failing typed-definition tests**

Create the focused runner with `_failures: Array[String]`, assertion helpers, and tests that construct these exact enums and fields:

```gdscript
CharacterSkill.TargetingMode.FREE
CharacterSkill.TargetingMode.PREDEFINED
CharacterSkill.TargetSide.SELF
CharacterSkill.TargetSide.ALLY
CharacterSkill.TargetSide.ENEMY
CharacterSkill.TargetRule.SELECT_ONE
CharacterSkill.TargetRule.SELF
CharacterSkill.TargetRule.ALL_ACTIVE_ALLIES
CharacterSkill.TargetRule.FARTHEST_ACTIVE_ENEMY
CharacterSkill.Requirement.NONE
CharacterSkill.Requirement.FRONT_ROW
CharacterSkill.Requirement.BACK_ROW
CharacterSkill.Requirement.ABOVE_HALF_HP
CharacterSkill.Effect.DAMAGE
CharacterSkill.Effect.SPEED_BOOST
CharacterSkill.CooldownMode.NONE
CharacterSkill.CooldownMode.POST_USE_ACTIONS
CharacterSkill.CooldownMode.ROUND_GATE
```

Assert that `mechanical_definition()` preserves all typed values, `duplicate_skill()` returns a distinct exact copy, and invalid combinations from the design return `null`: passive executable effect, free targeting with non-one target rule, enemy allegiance with all-allies, negative magnitude/duration, and negative cooldown.

- [ ] **Step 3: Run the focused runner to verify RED**

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_8_skill_targeting.gd
```

Expected: assertion failure because the typed enums/constructor fields do not exist; no parser failure in the test harness itself.

- [ ] **Step 4: Implement the minimal immutable typed contract**

Add the enums above and read-only backing fields:

```gdscript
var targeting_mode: TargetingMode: get: return _targeting_mode
var target_side: TargetSide: get: return _target_side
var target_rule: TargetRule: get: return _target_rule
var requirement: Requirement: get: return _requirement
var effect: Effect: get: return _effect
var effect_magnitude: int: get: return _effect_magnitude
var effect_duration: int: get: return _effect_duration
var cooldown_mode: CooldownMode: get: return _cooldown_mode
var cooldown_actions: int: get: return _cooldown_actions
var unavailable_through_round: int: get: return _unavailable_through_round
```

Extend `create`, `_init`, `is_valid_definition`, `is_valid`, `duplicate_skill`, and add `mechanical_definition() -> Dictionary`. Preserve the exact AC2.7 strings. Update every existing fixture constructor with a complete valid typed definition; passive fixtures use non-executable `Effect.NONE` and `TargetingMode.PREDEFINED` metadata matching their description but remain non-actionable.

- [ ] **Step 5: Verify GREEN and validate each changed script**

Run AC2.8, AC2.6, and AC2.7 runners. Expected: all exit `0`. Then run GodotIQ `validate(detail="brief")` and `check_errors` separately for each changed `.gd` file.

- [ ] **Step 6: Commit the model contract**

```powershell
git add -- Scripts/Battle/character_skill.gd Tests/Battle/test_ac2_6_character_skills.gd Tests/Battle/test_ac2_7_skill_preview.gd Tests/Battle/test_ac2_8_skill_targeting.gd
git commit -m "feat: define typed skill mechanics"
```

### Task 2: Add cooldown and temporary Speed state

**Files:**
- Modify: `Tests/Battle/test_ac2_8_skill_targeting.gd`
- Modify: `Scripts/Battle/battle_unit_state.gd`
- Modify: `Scripts/Battle/battle_turn_queue.gd`

- [ ] **Step 1: Inspect impact and write failing runtime-state tests**

After GodotIQ context/impact checks, add focused cases for:

```gdscript
assert(unit.get_skill_cooldown(&"shield_bash") == 0)
assert(unit.set_skill_cooldown(&"shield_bash", 2))
unit.tick_skill_cooldowns([&"shield_bash"])
assert(unit.get_skill_cooldown(&"shield_bash") == 2) # newly applied ID excluded
unit.tick_skill_cooldowns([])
assert(unit.get_skill_cooldown(&"shield_bash") == 1)
assert(unit.add_speed_modifier(&"quick_step", 2, BattleUnitState.ModifierExpiry.NEXT_ACTION, 1))
assert(unit.get_effective_speed() == unit.base_speed + 2)
unit.expire_speed_modifiers_after_action()
assert(unit.get_effective_speed() == unit.base_speed)
```

Also prove Rally expires by round, overlapping sources stack, invalid IDs/negative values reject, returned dictionaries/arrays are defensive copies, and `BattleTurnQueue` orders by effective Speed.

- [ ] **Step 2: Run AC2.8 to verify RED**

Expected: failures for missing cooldown/modifier/effective-Speed APIs.

- [ ] **Step 3: Implement minimal state APIs**

Add `base_speed`, effective `speed` compatibility, `ModifierExpiry`, a typed internal modifier record/dictionary, cooldown APIs, modifier APIs, and defensive snapshots. Keep `BattleTurnQueue.build()` validation and tie-breaking unchanged except reading `get_effective_speed()`.

- [ ] **Step 4: Verify GREEN, regress AC2.2, and validate**

Run AC2.8 and `Tests/Battle/test_ac2_2_speed_order.gd`; expected both pass. Validate/check each changed script.

- [ ] **Step 5: Commit**

```powershell
git add -- Scripts/Battle/battle_unit_state.gd Scripts/Battle/battle_turn_queue.gd Tests/Battle/test_ac2_8_skill_targeting.gd
git commit -m "feat: track skill cooldowns and speed modifiers"
```

### Task 3: Implement pure evaluation and immutable effect plans

**Files:**
- Create: `Scripts/Battle/skill_action_reason.gd`
- Create: `Scripts/Battle/skill_target_evaluation.gd`
- Create: `Scripts/Battle/skill_effect_plan.gd`
- Create: `Scripts/Battle/skill_confirmation_validation.gd`
- Create: `Scripts/Battle/battle_skill_rules.gd`
- Modify: `Tests/Battle/test_ac2_8_skill_targeting.gd`

- [ ] **Step 1: Write failing target and validation tests**

Build the exact six-unit fixture from the design and assert exact arrays/reasons for all six skills. Cover semantic front/back slots, strict `current_hp * 2 > max_hp`, round-1 Shadow Lunge, farthest ordering `(distance desc, back before front, slot desc)`, defeated/removal/ownership rejection, and exact reason messages.

Assert accepted confirmations return:

```gdscript
validation.accepted == true
validation.reason.code == SkillActionReason.Code.NONE
validation.actor_id == &"player_actor"
validation.skill_id == skill.skill_id
validation.target_ids == expected_ids
validation.evaluated_revision == revision
validation.effect_plan.advance_turn == true
```

Rejected confirmations must return `effect_plan == null`.

- [ ] **Step 2: Run AC2.8 to verify RED**

Expected: missing result/rules classes.

- [ ] **Step 3: Implement result types and pure rules**

Implement the exact fields/codes/messages from the design. `BattleSkillRules.evaluate_targets(...) -> SkillTargetEvaluation` and `validate_confirmation(...) -> SkillConfirmationValidation` receive actor, skill, units, round, revision, and proposed target IDs. They never mutate inputs. Accepted validation creates ordered `SkillEffectPlan.DamageOperation` or `SpeedOperation` values plus cooldown data.

- [ ] **Step 4: Verify GREEN and validate one script at a time**

Run AC2.8 after each result type/rules addition, then GodotIQ validate/check each file.

- [ ] **Step 5: Commit**

```powershell
git add -- Scripts/Battle/skill_action_reason.gd Scripts/Battle/skill_target_evaluation.gd Scripts/Battle/skill_effect_plan.gd Scripts/Battle/skill_confirmation_validation.gd Scripts/Battle/battle_skill_rules.gd Tests/Battle/test_ac2_8_skill_targeting.gd
git commit -m "feat: evaluate skill targets and effect plans"
```

### Task 4: Implement the transaction state machine and callback supersession

**Files:**
- Create: `Scripts/Battle/battle_skill_transaction.gd`
- Modify: `Tests/Battle/test_ac2_8_skill_targeting.gd`

- [ ] **Step 1: Write failing state-transition tests**

Cover every design transition using public ID-based commands:

```gdscript
transaction.preview_skill(actor, skill, units, round, revision)
transaction.begin_skill(actor, skill, units, round, revision)
transaction.hover_target(target_id, captured_generation)
transaction.select_target(target_id, captured_generation)
transaction.request_confirm(units, round, revision)
transaction.cancel()
transaction.observe_battle_change(units, round, revision)
```

Assert `IDLE`, `PREVIEWING`, `TARGETING`, `VALIDATING`, `RESOLVING`, transient `CANCELLED`, and `REJECTED_STALE`; new-skill rejection during targeting; exact presentation snapshots; last-event-wins hover; stale generation no-ops; immediate stale lock clearing; and exact stale messages.

- [ ] **Step 2: Run AC2.8 to verify RED**

Expected: missing transaction class/state APIs.

- [ ] **Step 3: Implement minimal orchestration**

Store actor/skill IDs, locked IDs, captured revision/round, generation, confirmation latch, and last result. Publish a defensive snapshot dictionary with state, generation, message, summary, confirm/cancel visibility/enabled state, and `indicator_roles: Dictionary[StringName, StringName]`. Do not reference scene nodes or mutate units.

- [ ] **Step 4: Verify GREEN and validate**

Run AC2.8, then validate/check the transaction and test scripts.

- [ ] **Step 5: Commit**

```powershell
git add -- Scripts/Battle/battle_skill_transaction.gd Tests/Battle/test_ac2_8_skill_targeting.gd
git commit -m "feat: orchestrate skill targeting transactions"
```

### Task 5: Build the scene-owned action region and slot overlays

**Files:**
- Modify: `Scenes/battle_arena.tscn`
- Modify: `Tests/Battle/test_ac2_8_skill_targeting.gd`

- [ ] **Step 1: Write failing scene-structure assertions**

Assert unique nodes `%SkillActionRegion`, `%SkillActionMessageLabel`, `%SkillActionSummaryLabel`, `%SkillConfirmButton`, and `%SkillCancelButton`; initial hidden state; Confirm initially disabled; and each populated formation slot owns a mouse-ignoring `TargetIndicatorOverlay` with border/tint presentation support.

- [ ] **Step 2: Run AC2.8 to verify RED**

Expected: assertion failure because action/indicator nodes do not exist.

- [ ] **Step 3: Modify the scene through GodotIQ**

Run `scene_map` on the skill panel and formations. Use validated `node_ops`/`build_scene` to add the action region inside the existing skill panel and overlay nodes inside all twelve scene-owned slots. Keep controls hidden by default, set overlays to ignore mouse input, and preserve existing node ordering/content. Save the scene.

- [ ] **Step 4: Verify scene GREEN and visually inspect structure**

Run AC2.8, GodotIQ validate/check the scene, then `scene_map` to confirm ownership and unique names.

- [ ] **Step 5: Commit**

```powershell
git add -- Scenes/battle_arena.tscn Tests/Battle/test_ac2_8_skill_targeting.gd
git commit -m "feat: add skill targeting controls and overlays"
```

### Task 6: Wire arena presentation and guarded resolution

**Files:**
- Create: `Scripts/Battle/battle_action_log_entry.gd`
- Modify: `Scripts/Battle/battle_arena.gd`
- Modify: `Tests/Battle/test_ac2_8_skill_targeting.gd`

- [ ] **Step 1: Write failing arena integration tests**

Instantiate the arena with the canonical test fixture and simulate real button/slot signals. Assert hover preview roles, targeting messages, valid/invalid hover visuals, lock/retarget, predefined immediate lock, Confirm/Cancel visibility, disabled unrelated skills, unusable click reasons, enemy/passive/non-current boundaries, and neutral cleanup.

For each skill, snapshot HP, Speed, cooldowns, queue, round, logs, outcome, and revision; confirm once; assert exact effect, one action-log entry, one turn advance, one atomic revision increment, cooldown semantics, modifier expiry, unresolved-queue rebuild, defeat/result handling, and return to `IDLE`.

- [ ] **Step 2: Run AC2.8 to verify RED**

Expected: arena remains inspection-only and lacks action wiring.

- [ ] **Step 3: Implement ID-based UI wiring and rendering**

Connect action buttons once in `_ready()`. Forward skill/slot hover, exit, press, Confirm, and Cancel to `BattleSkillTransaction`. Render only its snapshot: contextual visibility/text/buttons, skill disabling, and indicator roles. Use generation checks for every bound/deferred callback.

- [ ] **Step 4: Implement guarded effect-plan application**

Add one `_commit_skill_effect_plan(plan)` boundary guarded by `_action_in_progress`, transaction latch, and revision equality. Apply ordered damage through `BattleDamageResolver`, Speed modifiers through `BattleUnitState`, cooldown after the current tick, one logical `BattleActionLogEntry`, outcome evaluation, modifier/cooldown expiry, unresolved queue rebuild, turn advance, and one revision increment for the atomic commit. On any pre-commit failure, mutate nothing.

- [ ] **Step 5: Verify GREEN and validate after each script**

Run AC2.8 until all integration cases pass. Validate/check `battle_action_log_entry.gd`, then `battle_arena.gd`, then the test.

- [ ] **Step 6: Commit**

```powershell
git add -- Scripts/Battle/battle_action_log_entry.gd Scripts/Battle/battle_arena.gd Tests/Battle/test_ac2_8_skill_targeting.gd
git commit -m "feat: execute confirmed skill actions"
```

### Task 7: Prove stale rejection, re-entry safety, and lifecycle cleanup

**Files:**
- Modify: `Tests/Battle/test_ac2_8_skill_targeting.gd`
- Modify: `Scripts/Battle/battle_skill_transaction.gd`
- Modify: `Scripts/Battle/battle_arena.gd`

- [ ] **Step 1: Add the four named failing safety tests**

Implement the exact design cases:

```gdscript
_test_stale_target_rejection_clears_lock_without_mutation()
_test_failed_confirmation_has_no_partial_mutation()
_test_confirmation_reentry_resolves_once()
_test_callback_generation_supersedes_stale_events()
```

Snapshot all combat fields for every rejection. Deliver old hover/deferred/target/skill callbacks after newer generations. Trigger repeated Confirm in one frame. Cover inspection change, actor defeat, target defeat/removal/ownership change, battle completion, round/cooldown/Speed changes, reconfiguration, exit, and new battle.

- [ ] **Step 2: Run AC2.8 and verify each new test fails for its intended missing guard**

Expected: assertion failures demonstrating stale presentation or missing guard; never accept parser errors as RED.

- [ ] **Step 3: Add only the missing guards/cleanup hooks**

Use immediate `observe_battle_change`, revision/message mapping, confirmation latch, generation/state/ID checks, and one cleanup method called from all lifecycle boundaries.

- [ ] **Step 4: Verify GREEN and validate**

Run AC2.8, validate/check each changed script, and confirm no Godot debugger errors.

- [ ] **Step 5: Commit**

```powershell
git add -- Scripts/Battle/battle_skill_transaction.gd Scripts/Battle/battle_arena.gd Tests/Battle/test_ac2_8_skill_targeting.gd
git commit -m "fix: harden skill transaction lifecycle"
```

### Task 8: Full regression, visual QA, evidence, and closeout

**Files:**
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
- Create: `Docs/Specs/AC2/Evidence/AC2.8/2026-08-01/automated-test.log`
- Create: `Docs/Specs/AC2/Evidence/AC2.8/2026-08-01/manual-runtime-check.md`
- Create: `Docs/Specs/AC2/Evidence/AC2.8/2026-08-01/implementation-link.txt`

- [ ] **Step 1: Run project validation and all focused AC2 runners**

Run GodotIQ `validate(target="project", detail="brief")`, `check_errors(scope="project")`, and `signal_map(find="orphans")`. Then run AC2.1 through AC2.8 headless runners individually.

Expected: all eight exit `0`, no new validation/parser errors, and no new orphan signals.

- [ ] **Step 2: Run the runtime readiness gate**

Use GodotIQ `run(action="play")`, `verify_project_runs()`, `read_debug_console()`, and `state_inspect` for transaction/revision/cooldown values. Expected: Play starts and the debug console has no failing errors.

- [ ] **Step 3: Perform visual QA at 1152×648**

Use the approved manual sequence for all free/predefined hover, invalid, locked, Confirm/Cancel, blocking, and cleanup states. Run `explore(mode="tour")`, describe every screenshot, fix any clipping/overlap/stale indicators, and tour again. Use at most one screenshot per verification point.

- [ ] **Step 4: Record traceable evidence**

Write the exact eight command results and current implementation SHA to the three AC2.8 evidence files. The manual record must cover all thirteen design steps and explicitly record stale rejection, zero partial mutation, confirmation de-duplication, callback supersession, contextual visibility, and debugger status.

- [ ] **Step 5: Close the MVP criterion**

Change AC2.8 to `[x]` and replace its verification row with the automated/manual contract from the design. Confirm exactly one acceptance row and one verification row, while AC2.9 remains unchecked.

- [ ] **Step 6: Verify evidence consistency and commit**

```powershell
$sha=(Get-Content -Raw 'Docs/Specs/AC2/Evidence/AC2.8/2026-08-01/implementation-link.txt').Trim()
$auto=Get-Content -Raw 'Docs/Specs/AC2/Evidence/AC2.8/2026-08-01/automated-test.log'
$manual=Get-Content -Raw 'Docs/Specs/AC2/Evidence/AC2.8/2026-08-01/manual-runtime-check.md'
if (-not $auto.Contains($sha) -or -not $manual.Contains($sha)) { throw 'AC2.8 evidence SHA mismatch' }
```

Expected: exit `0`. Then:

```powershell
git add -- Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC2/Evidence/AC2.8/2026-08-01
git commit -m "docs: record AC2.8 verification"
```

- [ ] **Step 7: Run final verification before completion**

Repeat project validation, AC2.1–AC2.8, `verify_project_runs`, and `read_debug_console` against the final committed tree. Stop Play afterward. Do not claim completion unless every current command passes.
