# AC6.3 Goblin Class Wave A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add catalog-owned Scrapshield Bruiser, Wirefang Skirmisher, and Snarewright definitions with all nine authored Active skills, using the AC6.1/AC6.2 battle foundations through generic typed targeting, conditions, and effects.

**Architecture:** Keep stable Goblin identity, stats, tooltips, cooldowns, targeting profiles, conditions, and ordered effects in a focused Wave A catalog. Add reusable immutable authoring value objects that resolve semantic targets (`ACTOR`, `PRIMARY`, `ALL_SELECTED`, and a history-derived ally) into a locked `SkillEffectPlan`; extend the existing rules and transaction pipeline for 1..2 target selection and optional self Move 1. `BattleArena` remains a generic coordinator and must not branch on Goblin class or skill IDs.

**Tech Stack:** Godot 4, typed GDScript, SceneTree test runners, GodotIQ structured inspection/editing/validation, Git.

---

## Scope and file ownership

**Create**

- `Scripts/Battle/battle_skill_target_profile.gd` — immutable selection count, side, adjacency, and optional self-movement contract.
- `Scripts/Battle/battle_skill_effect_definition.gd` — immutable authored operation using semantic target roles and Power percentages.
- `Scripts/Battle/battle_skill_condition.gd` — immutable Snared and round-history requirements.
- `Scripts/Battle/battle_skill_authoring_resolver.gd` — pure conversion from a validated skill definition and locked selection into damage, movement, and keyword operations.
- `Scripts/Run/goblin_wave_a_catalog.gd` — stable class/skill IDs and the three complete Wave A `RunCharacter` definitions.
- `Tests/Battle/test_ac6_3_goblin_wave_a.gd` — focused AC6.3 runner.

**Modify**

- `Scripts/Battle/character_skill.gd` — own defensive copies of the new optional target profile, conditions, and ordered authored effects.
- `Scripts/Battle/skill_target_evaluation.gd` — expose minimum/maximum selection count and whether a movement choice is available.
- `Scripts/Battle/battle_skill_transaction.gd` — accumulate a deterministic locked target list up to the profile maximum and carry an optional declared self-movement path.
- `Scripts/Battle/battle_skill_rules.gd` — evaluate profile candidates, revalidate complete selections/conditions, and delegate plan construction to the resolver.
- `Scripts/Battle/skill_effect_plan.gd` — carry an optional locked voluntary movement path alongside ordered effects.
- `Scripts/Battle/battle_arena.gd` — preview and commit a skill-owned movement path through the existing atomic action transaction.
- `Scripts/Run/run_character_catalog.gd` — expose Wave A entries by stable ID without changing existing starter/reward behavior.
- `Tests/Battle/test_ac6_2_keyword_reactions.gd` — retain generic AC6.2 mechanics after authoring extensions.
- `Tests/Battle/test_ac6_1_combat_foundation.gd` — retain damage and Move 1 semantics after skill-plan movement integration.
- `Tests/Battle/test_ac2_8_skill_targeting.gd` — retain single-target and stale-revision behavior.
- `Tests/Battle/test_ac2_8_skill_transaction.gd` — retain transaction cancellation/callback behavior.
- `Docs/superpowers/specs/2026-08-29-ac6-goblin-combat-vertical-slice-design.md` — record AC6.3 evidence only after every gate passes.

**Explicitly out of scope**

- Scrapbroker, Shivrunner, Mobcaller, Brakka Rustbanner, Cache, battle-preparation UI, and save changes.
- New keyword mechanics: AC6.3 must compose the implemented AC6.2 Armor, Advantage, Snared, temporary Speed, queue rebuild, and history APIs.
- Goblin-specific branches in `BattleArena`, `BattleSkillRules`, or UI code.
- Progression, levels, evolution, and mechanical-unit permanent upgrades.

## Mandatory execution rules

Before code work, stash unrelated changes if needed, update `main` from origin, and create a dedicated `feat/ac6-3-goblin-wave-a` branch in the primary workspace; this repository forbids worktrees. Preserve the existing untracked AC6.2 plan and `.uid` files. Before every `.gd` edit call GodotIQ `file_context(detail="brief")`; before constructor or public-signature changes call `impact_check`. Edit `.gd` files only through `script_ops`. After each changed script run `validate(target=<file>, detail="brief")` and `check_errors(scope=<file>)`. Commit only the files named by the active task.

### Task 1: Establish the RED runner and immutable authoring contracts

**Files:**

- Create: `Scripts/Battle/battle_skill_target_profile.gd`
- Create: `Scripts/Battle/battle_skill_effect_definition.gd`
- Create: `Scripts/Battle/battle_skill_condition.gd`
- Create: `Tests/Battle/test_ac6_3_goblin_wave_a.gd`

- [ ] **Step 1: Write failing value-object tests**

Define the intended public surface in the runner:

```gdscript
var one_enemy := BattleSkillTargetProfile.create(
	1, 1, BattleUnitState.Side.ENEMY, false, false
)
var one_or_two_enemies := BattleSkillTargetProfile.create(
	1, 2, BattleUnitState.Side.ENEMY, false, false
)
var adjacent_ally := BattleSkillTargetProfile.create(
	1, 1, BattleUnitState.Side.PLAYER, true, false
)
var optional_self_move := BattleSkillTargetProfile.create(
	0, 0, BattleUnitState.Side.PLAYER, false, true
)
var damage := BattleSkillEffectDefinition.damage(
	BattleSkillEffectDefinition.TargetRole.PRIMARY, 85
)
var armor := BattleSkillEffectDefinition.keyword(
	BattleSkillEffectDefinition.TargetRole.HISTORY_ALLY,
	BattleKeywordOperation.Kind.ADD_ARMOR,
	2
)
var snared := BattleSkillCondition.create(BattleSkillCondition.Kind.PRIMARY_SNARED)

_expect(one_enemy.is_valid(), "single enemy profile is valid")
_expect(one_or_two_enemies.maximum_targets == 2, "Ring Net can lock two enemies")
_expect(adjacent_ally.require_adjacent_lane, "Pack Brace requires adjacency")
_expect(optional_self_move.allows_optional_self_move, "Slipstep exposes optional Move 1")
_expect(damage.power_percent == 85, "damage stores integer Power percentage")
_expect(armor.target_role == BattleSkillEffectDefinition.TargetRole.HISTORY_ALLY, "history recipient is semantic")
_expect(snared.is_valid(), "Snared condition is valid")
```

Also reject empty profiles, minimum greater than maximum, maximum above two, self movement combined with selected targets, non-positive damage percentages, keyword effects without magnitude/duration, and unknown condition kinds.

- [ ] **Step 2: Run and prove RED**

```powershell
godot --headless --path . --script Tests/Battle/test_ac6_3_goblin_wave_a.gd
```

Expected: parser failure because the three authoring types do not exist.

- [ ] **Step 3: Implement immutable value objects**

Use these stable enums:

```gdscript
# battle_skill_effect_definition.gd
enum Kind { DAMAGE, KEYWORD, SPEED, OPTIONAL_SELF_MOVE }
enum TargetRole { ACTOR, PRIMARY, ALL_SELECTED, HISTORY_ALLY }

# battle_skill_condition.gd
enum Kind { PRIMARY_SNARED, PRIMARY_ATTACKED_ALLY_THIS_ROUND }
```

Each `create()` returns `null` for invalid input. Getters return copied arrays/value objects. Power percentage is an integer and is resolved with `ceili(actor.power * percent / 100.0)` before Defense. The target profile supports only the combinations required by AC6.3: no selection, one target, or one-to-two same-side targets.

- [ ] **Step 4: Validate each new script and rerun the focused runner**

Expected: value-object assertions PASS with no parser or convention errors.

- [ ] **Step 5: Commit**

```powershell
git add Scripts/Battle/battle_skill_target_profile.gd Scripts/Battle/battle_skill_effect_definition.gd Scripts/Battle/battle_skill_condition.gd Tests/Battle/test_ac6_3_goblin_wave_a.gd
git commit -m "test: define AC6.3 skill authoring contracts"
```

### Task 2: Extend CharacterSkill without breaking existing definitions

**Files:**

- Modify: `Scripts/Battle/character_skill.gd`
- Modify: `Tests/Battle/test_ac6_3_goblin_wave_a.gd`
- Modify: `Tests/Battle/test_ac6_2_keyword_reactions.gd`

- [ ] **Step 1: Add failing construction and defensive-copy tests**

Construct an authored skill with `target_profile_value`, `condition_values`, and `authored_effect_values`. Assert duplicate IDs/invalid values reject, returned arrays are defensive copies, `duplicate_skill()` retains every field, and an existing AC2-style `CharacterSkill.create(...)` remains valid with default empty authoring fields.

- [ ] **Step 2: Prove RED**

Expected: `CharacterSkill.create()` does not accept the three new trailing values.

- [ ] **Step 3: Add backward-compatible trailing parameters**

Append, in this exact order:

```gdscript
target_profile_value: RefCounted = null,
condition_values: Array[RefCounted] = [],
authored_effect_values: Array[RefCounted] = []
```

Require all three to be present together for an authored Active skill. Preserve the existing mechanical fields for legacy skills; authored skills use `Effect.NONE` only when a non-empty valid authored-effect list exists. Validate unique condition kinds and ordered effects, and deep-copy them in construction, getters, `mechanical_definition()`, and `duplicate_skill()`.

- [ ] **Step 4: Validate and run AC6.3 plus AC6.2**

Expected: new construction tests PASS and AC6.2 remains 113/113.

- [ ] **Step 5: Commit**

```powershell
git add Scripts/Battle/character_skill.gd Tests/Battle/test_ac6_3_goblin_wave_a.gd Tests/Battle/test_ac6_2_keyword_reactions.gd
git commit -m "feat: add typed authored skill definitions"
```

### Task 3: Resolve target profiles, conditions, and ordered effect plans

**Files:**

- Create: `Scripts/Battle/battle_skill_authoring_resolver.gd`
- Modify: `Scripts/Battle/skill_target_evaluation.gd`
- Modify: `Scripts/Battle/battle_skill_rules.gd`
- Modify: `Scripts/Battle/skill_effect_plan.gd`
- Modify: `Tests/Battle/test_ac6_3_goblin_wave_a.gd`
- Modify: `Tests/Battle/test_ac2_8_skill_targeting.gd`

- [ ] **Step 1: Add failing pure rule tests**

Cover candidate filtering and authoritative revalidation for one enemy, adjacent active ally (lane distance exactly one), self-only, and one-or-two enemies. Cover `PRIMARY_SNARED` and `PRIMARY_ATTACKED_ALLY_THIS_ROUND` using immutable action-history snapshots. Prove stale/dead/wrong-side/duplicate targets, three Ring Net targets, a non-adjacent Pack Brace ally, and a no-longer-Snared Holdfast target all reject before a plan is created.

- [ ] **Step 2: Add failing resolver tests**

Assert these exact plan results:

```gdscript
_expect(shield_tap_plan.damage_operations[0][&"base_damage"] == 4, "ceil(4 * 0.85) is 4")
_expect(cheap_finish_plan.damage_operations[0][&"base_damage"] == 8, "ceil(6 * 1.20) is 8")
_expect(cheap_finish_advantage_plan.damage_operations[0][&"base_damage"] == 10, "ceil(6 * 1.60) is 10")
_expect(ring_net_plan.keyword_operations.size() == 2, "Ring Net locks both Snared applications")
```

Shield Tap adds Armor only to the active ally identified by the latest qualifying direct attack from the primary enemy earlier in the same round. Quick Mark orders damage before Advantage. Tripline Tag and Ring Net create Snared sources with the acting unit/skill/Power snapshot. Holdfast Wire orders damage, then `-1` current-round Speed.

- [ ] **Step 3: Implement `BattleSkillAuthoringResolver`**

Expose one pure entry point:

```gdscript
static func build_plan(
	actor: BattleUnitState,
	skill: CharacterSkill,
	locked_targets: Array[BattleUnitState],
	units: Array[BattleUnitState],
	round_number: int,
	revision: int,
	history: Array[BattleActionLogEntry],
	declared_move_path: Array[int] = []
) -> SkillEffectPlan
```

Resolve semantic roles only after complete validation. Use `BattleDamageRules` for the authored Power-percentage request, `BattleHistoryQuery` for the history recipient, and existing `BattleKeywordOperation` objects for Armor/Advantage/Snared. Represent Holdfast's negative Speed as an ordered speed operation; add validation for signed Speed magnitude while preserving effective-Speed floor 1.

- [ ] **Step 4: Extend evaluation and plan snapshots**

Add `minimum_targets`, `maximum_targets`, and `allows_optional_self_move` to `SkillTargetEvaluation`. Add `movement_path` and `movement_unit_id` to `SkillEffectPlan`, requiring an empty path or a valid Move 1 path for the actor. Existing constructors receive backward-compatible defaults.

- [ ] **Step 5: Delegate authored skills from `BattleSkillRules`**

Legacy skill evaluation remains unchanged. Authored skills use the target profile for candidate filtering and exact selection-count checks, conditions re-run during confirmation, then delegate effect construction. No `skill_id` switch is allowed.

- [ ] **Step 6: Validate and run focused/retained target tests**

```powershell
godot --headless --path . --script Tests/Battle/test_ac6_3_goblin_wave_a.gd
godot --headless --path . --script Tests/Battle/test_ac2_8_skill_targeting.gd
```

Expected: authored rule/resolver cases PASS and all legacy target/revision cases remain PASS.

- [ ] **Step 7: Commit**

```powershell
git add Scripts/Battle/battle_skill_authoring_resolver.gd Scripts/Battle/skill_target_evaluation.gd Scripts/Battle/battle_skill_rules.gd Scripts/Battle/skill_effect_plan.gd Tests/Battle/test_ac6_3_goblin_wave_a.gd Tests/Battle/test_ac2_8_skill_targeting.gd
git commit -m "feat: resolve authored Goblin skill plans"
```

### Task 4: Support multi-target locking and optional Slipstep movement

**Files:**

- Modify: `Scripts/Battle/battle_skill_transaction.gd`
- Modify: `Scripts/Battle/battle_arena.gd`
- Modify: `Tests/Battle/test_ac6_3_goblin_wave_a.gd`
- Modify: `Tests/Battle/test_ac6_1_combat_foundation.gd`
- Modify: `Tests/Battle/test_ac2_8_skill_transaction.gd`

- [ ] **Step 1: Add failing transaction tests**

Prove Ring Net can select one target and confirm or select two distinct targets and confirm; a third/duplicate target rejects; cancellation clears all locks. Prove Slipstep can confirm with no movement and still grant Armor, or declare one current legal Move 1 path; a stale/illegal declared path rejects without movement, Armor, cooldown, history, or revision change.

- [ ] **Step 2: Prove RED**

Expected: the transaction replaces a single lock and cannot carry movement.

- [ ] **Step 3: Extend transaction state**

Add `minimum_targets`, `maximum_targets`, `selected_target_ids`, and `declared_move_path`. `select_target()` toggles distinct selections until maximum; `begin_confirmation()` succeeds once minimum is met. Add:

```gdscript
func set_declared_move_path(path: Array[int], callback_generation: int) -> bool
```

Reset/cancel/stale rejection must clear both selections and path. Preserve the single-target interaction exactly when min/max are both one.

- [ ] **Step 4: Commit movement atomically in `BattleArena`**

Reuse `BattleFormationRules.is_move_one()` and the existing occupancy/path application helpers. Validate the locked path before any damage/keyword/cooldown mutation, apply movement in the plan's ordered movement phase, and write before/after slots plus `voluntary_movement = true` to the same skill action record. Do not call a second action transaction.

- [ ] **Step 5: Validate and run transaction/movement regressions**

```powershell
godot --headless --path . --script Tests/Battle/test_ac6_3_goblin_wave_a.gd
godot --headless --path . --script Tests/Battle/test_ac6_1_combat_foundation.gd
godot --headless --path . --script Tests/Battle/test_ac2_8_skill_transaction.gd
```

Expected: multi-target/Slipstep cases PASS; Default Swap and formation Move 1 behavior remain unchanged.

- [ ] **Step 6: Commit**

```powershell
git add Scripts/Battle/battle_skill_transaction.gd Scripts/Battle/battle_arena.gd Tests/Battle/test_ac6_3_goblin_wave_a.gd Tests/Battle/test_ac6_1_combat_foundation.gd Tests/Battle/test_ac2_8_skill_transaction.gd
git commit -m "feat: add multi-target and skill movement transactions"
```

### Task 5: Author the three Wave A catalog definitions

**Files:**

- Create: `Scripts/Run/goblin_wave_a_catalog.gd`
- Modify: `Scripts/Run/run_character_catalog.gd`
- Modify: `Tests/Battle/test_ac6_3_goblin_wave_a.gd`

- [ ] **Step 1: Add failing catalog identity/loadout tests**

Assert stable IDs, exact names/stats, exactly three unique Active skills per class, valid definitions, defensive copies, and unknown-ID rejection:

| Class ID | Display name | HP | Power | Speed | Defense | Skill IDs |
|---|---|---:|---:|---:|---:|---|
| `scrapshield_bruiser` | Scrapshield Bruiser | 20 | 4 | 7 | 2 | `shield_tap`, `pack_brace`, `banner_nudge` |
| `wirefang_skirmisher` | Wirefang Skirmisher | 14 | 6 | 10 | 0 | `quick_mark`, `cheap_finish`, `slipstep` |
| `snarewright` | Snarewright | 16 | 4 | 9 | 1 | `tripline_tag`, `holdfast_wire`, `ring_net` |

- [ ] **Step 2: Prove RED**

Expected: the Wave A catalog does not exist and the root catalog cannot resolve these IDs.

- [ ] **Step 3: Implement exact skill definitions**

Encode the authority from `Docs/Races/Goblins/Classes.md`:

- Shield Tap: 85% Power; post-hit 2 Armor to the qualifying active ally; CD1.
- Pack Brace: self plus one active adjacent ally gain 3 Armor atomically; CD2.
- Banner Nudge: one enemy gains Advantage until round end; CD3.
- Quick Mark: 90% Power, then Advantage; CD1.
- Cheap Finish: 120% Power, or consume pre-existing Advantage for 160%; CD2.
- Slipstep: optional legal self Move 1, then 2 Armor whether moved or not; CD3.
- Tripline Tag: Snared until round end with the AC6.2 rearmed one-follow-up metadata; CD1.
- Holdfast Wire: requires Snared, 115% Power, then -1 Speed through round end and immediate unresolved-queue rebuild; CD2.
- Ring Net: lock one or two enemies and apply Snared atomically; CD4.

Use the exact tooltips in `Classes.md`. Catalog construction must return fresh `RunCharacter` and `CharacterSkill` instances and must fail closed on duplicate IDs or invalid definitions.

- [ ] **Step 4: Add root catalog lookup**

Add `RunCharacterCatalog.create_by_class_id(class_id: StringName) -> RunCharacter`. Delegate only the three Wave A IDs to `GoblinWaveACatalog`; return `null` for unknown IDs. Do not alter `create_starters()` or `create_for_reward()`.

- [ ] **Step 5: Validate and run catalog tests**

Expected: exact identity, stats, tooltip, cooldown, targeting, condition, and ordered-effect assertions PASS.

- [ ] **Step 6: Commit**

```powershell
git add Scripts/Run/goblin_wave_a_catalog.gd Scripts/Run/run_character_catalog.gd Tests/Battle/test_ac6_3_goblin_wave_a.gd
git commit -m "feat: author Goblin wave A catalog"
```

### Task 6: Prove every Wave A skill through the authoritative arena

**Files:**

- Modify: `Tests/Battle/test_ac6_3_goblin_wave_a.gd`
- Modify: `Tests/Battle/test_ac6_2_keyword_reactions.gd`

- [ ] **Step 1: Add arena success cases**

For each of the nine skills, configure fresh catalog units, preview, target/select path, confirm, and assert exact HP/Armor/Advantage/Snared/Speed/slot/cooldown/history/log outcomes. Explicitly prove:

- Shield Tap uses the enemy's earlier direct-hit record and does nothing extra when no qualifying active ally remains.
- Quick Mark's hit cannot consume its newly applied Advantage.
- Cheap Finish consumes a pre-existing Advantage and records the rider.
- Slipstep records zero movement or one legal voluntary movement in the same action.
- Tripline's first later allied direct hit applies Advantage after damage and does not remove Snared; reapplication rearms once.
- Holdfast Wire leaves Snared present and reorders only unresolved queue entries.
- Ring Net applies zero partial state if either locked target becomes stale.

- [ ] **Step 2: Add rejection and lifecycle cases**

For every skill cover wrong side, defeated/stale targets, cooldown, and revision mismatch. Add the specific Pack Brace no-adjacent-ally, Holdfast non-Snared, Ring Net duplicate/three-target, and Slipstep stale-path failures. Assert every rejection leaves HP, positions, keywords, cooldowns, queue, action history, log, and battle revision unchanged. End battle and prove fresh catalog units do not retain keywords, modifiers, guards, cooldowns, or history-derived state.

- [ ] **Step 3: Run the focused runner twice**

```powershell
godot --headless --path . --script Tests/Battle/test_ac6_3_goblin_wave_a.gd
godot --headless --path . --script Tests/Battle/test_ac6_3_goblin_wave_a.gd
```

Expected: identical PASS count and deterministic action/log order on both runs.

- [ ] **Step 4: Run AC6.1 and AC6.2 regressions**

```powershell
godot --headless --path . --script Tests/Battle/test_ac6_1_combat_foundation.gd
godot --headless --path . --script Tests/Battle/test_ac6_2_keyword_reactions.gd
```

Expected: AC6.1 remains fully passing and AC6.2 remains 113/113.

- [ ] **Step 5: Commit**

```powershell
git add Tests/Battle/test_ac6_3_goblin_wave_a.gd Tests/Battle/test_ac6_2_keyword_reactions.gd
git commit -m "test: verify Goblin wave A battle behavior"
```

### Task 7: AC6.3 verification and evidence gate

**Files:**

- Modify: `Docs/superpowers/specs/2026-08-29-ac6-goblin-combat-vertical-slice-design.md`
- Test: all `Tests/Battle/test_*.gd`

- [ ] **Step 1: Run the complete Battle suite**

```powershell
Get-ChildItem Tests/Battle/test_*.gd | ForEach-Object {
	& godot --headless --path . --script $_.FullName
	if ($LASTEXITCODE -ne 0) { throw "Failed: $($_.Name)" }
}
```

Expected: every runner exits 0 with its exact PASS count.

- [ ] **Step 2: Run deterministic focused evidence**

Run `test_ac6_3_goblin_wave_a.gd` twice and save the exact command, PASS count, and date. Diff normalized outputs; expected result is no behavioral difference.

- [ ] **Step 3: Run the GodotIQ project gate**

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(find="orphans", detail="brief")
run(action="play")
verify_project_runs(check_scope="project", stop_after=false)
read_debug_console()
run(action="stop")
```

Expected: no new validation errors, parser failures, orphan wiring, startup failures, or debug-console errors.

- [ ] **Step 4: Record only earned AC6.3 evidence**

Update the design ledger with implementation commit hashes, exact focused/full-suite commands, PASS counts, deterministic rerun result, GodotIQ results, and date. Mark AC6.3 satisfied only if every gate passed. Leave AC6.4–AC6.7 incomplete.

- [ ] **Step 5: Commit evidence**

```powershell
git add Docs/superpowers/specs/2026-08-29-ac6-goblin-combat-vertical-slice-design.md
git commit -m "docs: record AC6.3 verification evidence"
```

## Self-review

- **Spec coverage:** All three class identities, exact stats, nine skill contracts, cooldowns, target counts, Armor/Advantage/Snared timing, temporary Speed/queue rebuilding, optional movement, atomicity, history, logs, and cleanup map to explicit tasks.
- **Architecture:** Catalog files own authored content; generic immutable profiles/effects/conditions own reusable rules; the resolver builds locked plans; the arena coordinates without Goblin IDs.
- **Scope:** Wave B, Brakka, Cache/preparation, progression, and presentation polish remain outside AC6.3.
- **Atomicity:** Selection, condition, optional path, semantic recipients, and every locked target revalidate before the first mutation.
- **Type consistency:** `BattleSkillTargetProfile`, `BattleSkillEffectDefinition`, `BattleSkillCondition`, and `BattleSkillAuthoringResolver` names and signatures are consistent across all tasks.
- **Governance:** AC6.3 remains incomplete until the focused runner, full Battle suite, deterministic rerun, GodotIQ project/runtime gate, and evidence ledger all pass.
