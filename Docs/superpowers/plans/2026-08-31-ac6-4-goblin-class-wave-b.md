# AC6.4 Goblin Class Wave B Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add catalog-owned Scrapbroker, Shivrunner, and Mobcaller definitions with all nine authored Active skills, proving support targeting, health and Bleed requirements, Advantage-consumption history, allied-action timing, distinct-attacker scaling, and mixed-race coordination.

**Architecture:** Extend the AC6.3 immutable authoring model with generic race identity, condition kinds, and history-derived magnitude rules; keep authored names, stats, tooltips, cooldowns, target profiles, conditions, and ordered effects in a focused Wave B catalog. `BattleSkillAuthoringResolver` builds one locked `SkillEffectPlan` from the current unit snapshot and committed-action history, while `BattleArena` remains a class-agnostic transaction coordinator with no Goblin class or skill-ID branches.

**Tech Stack:** Godot 4, typed GDScript, SceneTree test runners, GodotIQ structured inspection/editing/validation, Git.

---

## Scope and file ownership

**Create**

- `Scripts/Run/goblin_wave_b_catalog.gd` — stable class/skill IDs and the three complete Wave B `RunCharacter` definitions.
- `Tests/Battle/test_ac6_4_goblin_wave_b.gd` — focused AC6.4 contract, catalog, resolver, arena, rejection, and lifecycle runner.

**Modify**

- `Scripts/Run/run_character.gd` — add immutable stable race identity with a backward-compatible constructor default.
- `Scripts/Run/run_roster.gd` — copy race identity into fresh battle units.
- `Scripts/Run/run_character_catalog.gd` — resolve Wave A and Wave B class IDs without changing starter/reward behavior.
- `Scripts/Battle/battle_unit_state.gd` — carry stable race identity for battle-local mixed-race evaluation.
- `Scripts/Battle/battle_skill_condition.gd` — add reusable Bleed, HP-threshold, Advantage-consumption-history, prior-allied-action, prior-allied-hit, and different-race conditions.
- `Scripts/Battle/battle_skill_effect_definition.gd` — add history-scaled damage and history-dependent Armor definitions.
- `Scripts/Battle/battle_history_query.gd` — add typed round-local queries for Advantage consumption, earlier allied actions, and direct hits.
- `Scripts/Battle/battle_skill_authoring_resolver.gd` — evaluate the new generic conditions and freeze history-derived damage/Armor/Speed values into the plan.
- `Scripts/Battle/skill_effect_plan.gd` — carry locked per-target Armor grants when a fixed keyword magnitude is insufficient.
- `Scripts/Battle/battle_arena.gd` — apply locked Armor grants through the existing atomic skill transaction and record their deltas.
- `Tests/Battle/test_ac6_1_combat_foundation.gd` — retain fresh run-to-battle conversion behavior after race propagation.
- `Tests/Battle/test_ac6_2_keyword_reactions.gd` — retain history, Bleed, Advantage, Speed, and cleanup foundations.
- `Tests/Battle/test_ac6_3_goblin_wave_a.gd` — retain every Wave A authored skill after resolver extensions.
- `Tests/Battle/test_ac2_8_skill_targeting.gd` — retain legacy target and stale-confirmation behavior.
- `Docs/superpowers/specs/2026-08-29-ac6-goblin-combat-vertical-slice-design.md` — record AC6.4 evidence only after every gate passes.

**Explicitly out of scope**

- Brakka Rustbanner, Banner Holder, closest-enemy selection, Cache, battle preparation, save schema changes, and AC6.7 production-flow evidence.
- New keyword state: AC6.4 composes implemented Armor, Advantage, Bleed, and temporary Speed APIs.
- Race-based bonuses beyond the exact `different-race ally` legality rule for Louder Together.
- Goblin-specific branches in `BattleArena`, `BattleSkillRules`, `BattleHistoryQuery`, or `BattleSkillAuthoringResolver`.
- Progression, equipment, non-Goblin authored catalogs, AI execution, and balance changes.

## Mandatory execution rules

At execution start, preserve the current unrelated untracked plan and `.uid` files, return to `main`, update it from origin, and create a dedicated `feat/ac6-4-goblin-wave-b` branch in the primary workspace; this repository forbids worktrees. Before every `.gd` edit call GodotIQ `file_context(file, detail="brief")`; before constructor, enum, or public-signature changes call `impact_check`. Edit `.gd` files only through `script_ops`. After each changed script run `validate(target=<file>, detail="brief")` and `check_errors(scope=<file>)`. Commit only files named by the active task.

### Task 1: Establish the AC6.4 RED runner and race identity contract

**Files:**

- Modify: `Scripts/Run/run_character.gd`
- Modify: `Scripts/Run/run_roster.gd`
- Modify: `Scripts/Battle/battle_unit_state.gd`
- Create: `Tests/Battle/test_ac6_4_goblin_wave_b.gd`
- Modify: `Tests/Battle/test_ac6_1_combat_foundation.gd`

- [ ] **Step 1: Write failing race propagation tests**

Add the focused runner with a waited `SceneTree` exit and assertions equivalent to:

```gdscript
var goblin := RunCharacter.new(
	&"scrapbroker", "Scrapbroker", 8, 18, [], 3, 1, &"goblin"
)
var roster := RunRoster.new([goblin])
var battle_units := roster.create_battle_units()

_expect(goblin.race_id == &"goblin", "run character stores stable race identity")
_expect(battle_units[0].race_id == &"goblin", "battle conversion preserves race identity")
_expect(battle_units[0].unit_id == goblin.character_id, "race propagation does not change identity")
```

Also prove an omitted race defaults to `&"unknown"`, an empty explicit race is rejected or normalized to `&"unknown"`, and two fresh battle conversions do not share mutable state.

- [ ] **Step 2: Prove RED**

Run:

```powershell
Start-Process -FilePath (Get-Command godot).Source -ArgumentList @('--headless', '--path', (Get-Location).Path, '--script', 'res://Tests/Battle/test_ac6_4_goblin_wave_b.gd') -NoNewWindow -Wait -PassThru
```

Expected: nonzero exit because `RunCharacter` and `BattleUnitState` do not expose `race_id`.

- [ ] **Step 3: Implement backward-compatible race identity**

Append `race_id_value: StringName = &"unknown"` to the existing `RunCharacter` constructor and `BattleUnitState` constructor. Store a non-empty `race_id`, and pass it through `RunRoster.create_battle_units()` without changing the ordering of existing arguments. Update direct test fixtures only where an explicit race is required.

- [ ] **Step 4: Validate and run retained conversion tests**

Run AC6.4 and `test_ac6_1_combat_foundation.gd`. Expected: race assertions pass, AC6.1 remains 40/40, and legacy constructors retain `&"unknown"`.

- [ ] **Step 5: Commit**

```powershell
git add Scripts/Run/run_character.gd Scripts/Run/run_roster.gd Scripts/Battle/battle_unit_state.gd Tests/Battle/test_ac6_4_goblin_wave_b.gd Tests/Battle/test_ac6_1_combat_foundation.gd
git commit -m "feat: propagate battle race identity"
```

### Task 2: Add reusable Wave B conditions

**Files:**

- Modify: `Scripts/Battle/battle_skill_condition.gd`
- Modify: `Tests/Battle/test_ac6_4_goblin_wave_b.gd`

- [ ] **Step 1: Write failing immutable-condition tests**

Extend `BattleSkillCondition.Kind` with these exact generic kinds:

```gdscript
PRIMARY_BLEEDING
PRIMARY_BELOW_HALF_HP
PRIMARY_HIT_BY_ALLY_THIS_ROUND
ALLY_CONSUMED_ADVANTAGE_THIS_ROUND
ALLY_ACTED_BEFORE_ACTOR_THIS_ROUND
PRIMARY_DIFFERENT_RACE_FROM_ACTOR
```

Use `PRIMARY_DIFFERENT_RACE_FROM_ACTOR` for Louder Together because its first selected target is the ally. Assert `create()`, `is_valid()`, and `duplicate_condition()` preserve every new kind, and unknown integers still return `null`.

- [ ] **Step 2: Prove RED**

Expected: the runner fails because the enum values are absent.

- [ ] **Step 3: Implement validation and duplication**

Add all six kinds to the constructor allowlist. Keep the object immutable and parameter-free; thresholds and timing are fixed by the authoritative AC6.4 contracts: below 50% means `current_hp * 2 < max_hp`, and all history predicates are current-round, strictly earlier committed actions.

- [ ] **Step 4: Validate and rerun the focused contract tests**

Expected: all condition value-object assertions pass with no convention or parser errors.

- [ ] **Step 5: Commit**

```powershell
git add Scripts/Battle/battle_skill_condition.gd Tests/Battle/test_ac6_4_goblin_wave_b.gd
git commit -m "feat: define Wave B skill conditions"
```

### Task 3: Add round-local history queries

**Files:**

- Modify: `Scripts/Battle/battle_history_query.gd`
- Modify: `Tests/Battle/test_ac6_4_goblin_wave_b.gd`
- Modify: `Tests/Battle/test_ac6_2_keyword_reactions.gd`

- [ ] **Step 1: Write failing query tests**

Define and test these signatures:

```gdscript
static func consumed_advantage_this_round(
	records: Array[BattleActionRecord], actor_id: StringName, round_number: int
) -> bool

static func ally_acted_before_this_round(
	records: Array[BattleActionRecord], actor_side: BattleUnitState.Side,
	excluded_actor_id: StringName, round_number: int
) -> bool

static func was_directly_hit_by_ally_this_round(
	records: Array[BattleActionRecord], attacker_side: BattleUnitState.Side,
	target_id: StringName, excluded_actor_id: StringName, round_number: int
) -> bool

static func distinct_allied_attackers_this_round(
	records: Array[BattleActionRecord], attacker_side: BattleUnitState.Side,
	target_id: StringName, excluded_actor_id: StringName, round_number: int
) -> Array[StringName]
```

Assert that reactions, wrong-side actors, other rounds, zero-damage entries, and the current actor are excluded. Advantage consumption counts any prior committed action whose valid `advantage_consumed` source is present. Ordering follows committed record sequence, while the distinct result is stable by first qualifying hit.

- [ ] **Step 2: Prove RED**

Expected: the new query calls do not exist.

- [ ] **Step 3: Implement pure queries over authoritative records**

Reuse validity checks from the existing query helper. Do not infer history from logs or keyword state. Keep `distinct_allied_attackers()` intact for existing callers and implement the round-local variant explicitly so Mobcaller cannot count earlier rounds or itself.

- [ ] **Step 4: Validate and run AC6.2 plus AC6.4**

Expected: new history tests pass and AC6.2 remains 113/113.

- [ ] **Step 5: Commit**

```powershell
git add Scripts/Battle/battle_history_query.gd Tests/Battle/test_ac6_4_goblin_wave_b.gd Tests/Battle/test_ac6_2_keyword_reactions.gd
git commit -m "feat: query Wave B action history"
```

### Task 4: Extend immutable authored effects for conditional Armor and scaled damage

**Files:**

- Modify: `Scripts/Battle/battle_skill_effect_definition.gd`
- Modify: `Tests/Battle/test_ac6_4_goblin_wave_b.gd`
- Modify: `Tests/Battle/test_ac6_3_goblin_wave_a.gd`

- [ ] **Step 1: Write failing definition tests**

Add these generic effect kinds and factories:

```gdscript
enum Kind {
	DAMAGE,
	KEYWORD,
	SPEED,
	OPTIONAL_SELF_MOVE,
	HISTORY_SCALED_DAMAGE,
	CONDITIONAL_ARMOR,
}

static func history_scaled_damage(
	role: int, base_percent: int, percent_per_distinct_attacker: int,
	maximum_percent: int
) -> RefCounted

static func conditional_armor(
	role: int, base_amount: int, advantage_consumed_amount: int
) -> RefCounted
```

Prove Dogpile Math stores `90`, `20`, and `150`; Hand-Me-Down stores `4` and `5`; duplicate definitions preserve fields. Reject non-primary scaled damage, non-positive steps, maximum below base, non-primary conditional Armor, and a conditional amount below its base.

- [ ] **Step 2: Prove RED**

Expected: new enum members/factories do not exist.

- [ ] **Step 3: Implement immutable fields and validation**

Add read-only fields `history_increment`, `maximum_power_percent`, and `conditional_magnitude`. Preserve all existing factory signatures and duplicate behavior. These types describe calculation only; they do not inspect history themselves.

- [ ] **Step 4: Validate and run AC6.3 regression**

Expected: definition assertions pass and AC6.3 remains 116/116.

- [ ] **Step 5: Commit**

```powershell
git add Scripts/Battle/battle_skill_effect_definition.gd Tests/Battle/test_ac6_4_goblin_wave_b.gd Tests/Battle/test_ac6_3_goblin_wave_a.gd
git commit -m "feat: define history-derived skill effects"
```

### Task 5: Resolve Wave B conditions and values into one locked plan

**Files:**

- Modify: `Scripts/Battle/battle_skill_authoring_resolver.gd`
- Modify: `Scripts/Battle/skill_effect_plan.gd`
- Modify: `Scripts/Battle/battle_arena.gd`
- Modify: `Tests/Battle/test_ac6_4_goblin_wave_b.gd`
- Modify: `Tests/Battle/test_ac2_8_skill_targeting.gd`

- [ ] **Step 1: Write failing resolver tests for all new predicates**

Construct fresh unit snapshots and action records to prove:

- Bleed and below-half-health conditions inspect the primary target at preview and confirmation.
- Hand-Me-Down selects one active ally and locks Armor `4` or `5` from that ally's earlier Advantage-consumption record.
- Dirty Window uses `145%` only when a different allied actor committed an earlier action in the same round.
- Dogpile Math uses `min(150, 90 + 20 * distinct_prior_allied_attackers)` and does not count Mobcaller before its hit resolves.
- Louder Together requires the selected ally to have a non-empty race different from the actor's `&"goblin"` race.

- [ ] **Step 2: Prove RED**

Expected: new conditions reject and the plan cannot represent conditional per-target Armor.

- [ ] **Step 3: Add locked Armor operations to `SkillEffectPlan`**

Append a backward-compatible parameter:

```gdscript
armor_operations_value: Array[Dictionary] = []
```

Each entry has exactly a non-empty `target_id` and positive `amount`. Validate unique target IDs, deep-copy input/output, and include Armor operations in `is_valid()` without changing legacy plans; unit activity is validated by the resolver and again at confirmation because the plan itself does not own the unit collection.

- [ ] **Step 4: Resolve every new condition and effect generically**

Pass `Array[BattleActionRecord]` into `BattleSkillAuthoringResolver.build_plan()` alongside the existing log history. Evaluate all conditions before constructing operations. Freeze scaled damage and conditional Armor into the plan; do not recalculate them during arena mutation. For Louder Together, keep selection order as ally first and enemy second by extending the target profile only if Task 7 proves the current same-side profile cannot express the pair.

- [ ] **Step 5: Apply locked Armor atomically in the arena**

Before mutation, revalidate every Armor recipient, target identity, race/health/keyword condition, and battle revision through the normal confirmation rebuild. Then apply damage, keywords, Armor, Speed, cooldown, history, and queue rebuild in the existing authored order. Record Armor deltas in the authoritative action record. Any stale recipient rejects before HP, Armor, keywords, cooldowns, history, logs, queue, revision, or turn index change.

- [ ] **Step 6: Validate each script and run targeted regressions**

Run AC6.4, AC6.3, AC6.2, and AC2.8 targeting. Expected: all pass with unchanged legacy counts.

- [ ] **Step 7: Commit**

```powershell
git add Scripts/Battle/battle_skill_authoring_resolver.gd Scripts/Battle/skill_effect_plan.gd Scripts/Battle/battle_arena.gd Tests/Battle/test_ac6_4_goblin_wave_b.gd Tests/Battle/test_ac2_8_skill_targeting.gd
git commit -m "feat: resolve Wave B skill plans"
```

### Task 6: Author Scrapbroker and Shivrunner catalogs

**Files:**

- Create: `Scripts/Run/goblin_wave_b_catalog.gd`
- Modify: `Scripts/Run/run_character_catalog.gd`
- Modify: `Tests/Battle/test_ac6_4_goblin_wave_b.gd`

- [ ] **Step 1: Write failing exact catalog assertions**

Require fresh definitions and unknown-ID rejection:

| Class ID | Display name | Race | HP | Power | Speed | Defense | Skill IDs |
|---|---|---|---:|---:|---:|---:|---|
| `scrapbroker` | Scrapbroker | `goblin` | 18 | 3 | 8 | 1 | `spot_buyer`, `hand_me_down`, `emergency_kit` |
| `shivrunner` | Shivrunner | `goblin` | 12 | 7 | 10 | 0 | `quick_nick`, `dirty_window`, `collect_debt` |

- [ ] **Step 2: Prove RED**

Expected: Wave B catalog lookup returns `null`.

- [ ] **Step 3: Implement the six exact skill definitions**

Encode `Docs/Races/Goblins/Classes.md` exactly:

- Spot Buyer: apply Advantage until round end; CD1.
- Hand-Me-Down: one ally gets 4 Armor, or 5 after that ally consumed Advantage this round; CD2.
- Emergency Kit: one ally below 50% maximum HP gets 6 Armor; CD4.
- Quick Nick: 80% Power, then one canonical two-committed-action Bleed; CD1.
- Dirty Window: requires Bleeding, 125% Power or 145% after a prior allied action this round; CD2; never consumes Advantage.
- Collect Debt: requires Bleeding and below 50% maximum HP, 175% Power; CD4; does not consume Bleed.

Use exact tooltips from the authority document. Return fresh `RunCharacter` and `CharacterSkill` instances and fail closed on duplicate IDs or invalid definitions.

- [ ] **Step 4: Delegate root lookup without changing reward/starter APIs**

Try Wave A, then Wave B, and return `null` only when both reject. Do not alter `create_starters()` or `create_for_reward()`.

- [ ] **Step 5: Validate and run catalog tests**

Expected: exact identity, race, stats, tooltip, cooldown, targeting, condition, and ordered-effect assertions pass.

- [ ] **Step 6: Commit**

```powershell
git add Scripts/Run/goblin_wave_b_catalog.gd Scripts/Run/run_character_catalog.gd Tests/Battle/test_ac6_4_goblin_wave_b.gd
git commit -m "feat: author Scrapbroker and Shivrunner"
```

### Task 7: Add ordered mixed-side targeting and author Mobcaller

**Files:**

- Modify: `Scripts/Battle/battle_skill_target_profile.gd`
- Modify: `Scripts/Battle/battle_skill_transaction.gd`
- Modify: `Scripts/Battle/battle_skill_rules.gd`
- Modify: `Scripts/Battle/battle_skill_authoring_resolver.gd`
- Modify: `Scripts/Run/goblin_wave_b_catalog.gd`
- Modify: `Tests/Battle/test_ac6_4_goblin_wave_b.gd`
- Modify: `Tests/Battle/test_ac2_8_skill_transaction.gd`

- [ ] **Step 1: Write failing ordered-stage target tests**

Extend `BattleSkillTargetProfile` with an optional immutable `target_sides_value: Array[int] = []`. An empty array preserves the existing single-side contract. Louder Together uses:

```gdscript
BattleSkillTargetProfile.create(
	2,
	2,
	BattleUnitState.Side.PLAYER,
	false,
	false,
	[BattleUnitState.Side.PLAYER, BattleUnitState.Side.ENEMY]
)
```

Assert stage zero accepts only an active different-race ally, stage one accepts only an active enemy, duplicate selection rejects, cancel clears both, and any stale locked stage rejects confirmation atomically.

- [ ] **Step 2: Prove RED**

Expected: profiles cannot express ordered mixed-side selection.

- [ ] **Step 3: Implement generic ordered-stage selection**

Validate that `target_sides` is either empty or exactly `maximum_targets` long and contains only valid sides. `BattleSkillRules.evaluate_targets()` filters against the next stage; the transaction retains locked order; confirmation re-evaluates each stage against the current unit snapshot. Preserve all AC2/AC6.3 same-side behavior.

- [ ] **Step 4: Author the three Mobcaller skills**

Add Mobcaller `17 HP / 4 Power / 9 Speed / 1 Defense / goblin` with:

- Point and Yell: apply Advantage until round end; CD1.
- Dogpile Math: require an earlier direct hit by an ally; deal `90% + 20%` per distinct prior allied attacker, capped at `150%`; CD2.
- Louder Together: select one different-race ally then one enemy; apply Advantage to the enemy, apply non-stacking `+1 Speed` to the ally until round end, and rebuild unresolved queue entries; CD3.

Use exact tooltips and stable IDs `point_and_yell`, `dogpile_math`, and `louder_together`.

- [ ] **Step 5: Validate and run transaction/catalog tests**

Run AC6.4 and AC2.8 transaction. Expected: mixed-side selection passes, cancellation/staleness is atomic, and existing transaction behavior is unchanged.

- [ ] **Step 6: Commit**

```powershell
git add Scripts/Battle/battle_skill_target_profile.gd Scripts/Battle/battle_skill_transaction.gd Scripts/Battle/battle_skill_rules.gd Scripts/Battle/battle_skill_authoring_resolver.gd Scripts/Run/goblin_wave_b_catalog.gd Tests/Battle/test_ac6_4_goblin_wave_b.gd Tests/Battle/test_ac2_8_skill_transaction.gd
git commit -m "feat: author Mobcaller mixed-side skills"
```

### Task 8: Prove all nine Wave B skills through the authoritative arena

**Files:**

- Modify: `Tests/Battle/test_ac6_4_goblin_wave_b.gd`
- Modify: `Tests/Battle/test_ac6_2_keyword_reactions.gd`
- Modify: `Tests/Battle/test_ac6_3_goblin_wave_a.gd`

- [ ] **Step 1: Add arena success cases**

For every skill, create fresh catalog units, preview, select all targets in order, confirm, and assert exact HP, Armor, Advantage, Bleed, Speed, cooldown, queue, history, action-record, and log outcomes. Explicitly prove:

- Hand-Me-Down reads the selected ally's consumption history, not the actor's.
- Emergency Kit accepts `current_hp * 2 < max_hp` and rejects exactly half HP.
- Quick Nick damage resolves before Bleed is applied and the canonical Bleed duration is unchanged.
- Dirty Window's allied-action bonus is independent of Advantage and leaves Bleed present.
- Collect Debt leaves Bleed present.
- Dogpile Math counts distinct prior allied attackers once each, excludes Mobcaller, and caps at 150%.
- Louder Together accepts a non-Goblin ally, rejects a Goblin ally, applies both effects atomically, does not stack Speed, refreshes expiry, and rebuilds only unresolved queue entries.

- [ ] **Step 2: Add rejection and lifecycle cases**

For every skill cover wrong side, defeated target, cooldown, revision mismatch, and stale target. Add exact-half Emergency Kit, non-Bleeding Dirty Window, no-prior-ally Dogpile Math, duplicate/same-race Louder Together, stale second-stage selection, and post-preview history-change cases. Assert every rejection leaves HP, Armor, keywords, positions, Speed modifiers, cooldowns, queue, history, logs, battle revision, and turn index unchanged.

- [ ] **Step 3: Prove fresh-battle isolation**

End battle, create new battle units from the same catalog definitions, and assert no HP loss, Armor, Advantage, Bleed, Speed modifier, cooldown, action history, or reaction guard leaks. Race identity must remain present because it is persistent character identity, not battle-local state.

- [ ] **Step 4: Run the focused runner twice with waited processes**

Expected: identical assertion count and deterministic action/log order on both runs.

- [ ] **Step 5: Run AC6 foundation and Wave A regressions**

Run AC6.1, AC6.2, and AC6.3. Expected: 40/40, 113/113, and 116/116 respectively.

- [ ] **Step 6: Commit**

```powershell
git add Tests/Battle/test_ac6_4_goblin_wave_b.gd Tests/Battle/test_ac6_2_keyword_reactions.gd Tests/Battle/test_ac6_3_goblin_wave_a.gd
git commit -m "test: verify Goblin wave B battle behavior"
```

### Task 9: AC6.4 verification and evidence gate

**Files:**

- Modify: `Docs/superpowers/specs/2026-08-29-ac6-goblin-combat-vertical-slice-design.md`
- Test: all `Tests/Battle/test_*.gd`

- [ ] **Step 1: Run the complete Battle suite with waited processes**

```powershell
$godot = (Get-Command godot).Source
Get-ChildItem Tests/Battle/test_*.gd | ForEach-Object {
	$process = Start-Process -FilePath $godot -ArgumentList @(
		'--headless', '--path', (Get-Location).Path, '--script', "res://Tests/Battle/$($_.Name)"
	) -NoNewWindow -Wait -PassThru
	if ($process.ExitCode -ne 0) { throw "Failed: $($_.Name)" }
}
```

Expected: every runner exits 0 with its exact PASS count.

- [ ] **Step 2: Capture deterministic focused evidence**

Run `test_ac6_4_goblin_wave_b.gd` twice, retain both complete outputs, normalize process-only timestamps if present, and diff them. Expected: identical assertion count and action/log ordering.

- [ ] **Step 3: Run the GodotIQ project gate**

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(find="orphans", detail="brief")
verify_project_runs(scene="main", check_scope="scene", stop_after=true)
```

Expected: zero validation errors, no new parser failure beyond any already-recorded editor-cache caveat, zero orphan signals, clean production startup, and zero captured runtime/script errors.

- [ ] **Step 4: Record only earned AC6.4 evidence**

Update the design ledger with implementation commit hashes, exact focused/full-suite commands, PASS counts, deterministic rerun result, GodotIQ results, and date. Mark AC6.4 satisfied only if every gate passed. Advance AC6-AC04 to complete for all 18 regular skills, but leave AC6.5–AC6.7 and overall AC6 incomplete.

- [ ] **Step 5: Commit evidence**

```powershell
git add Docs/superpowers/specs/2026-08-29-ac6-goblin-combat-vertical-slice-design.md
git commit -m "docs: record AC6.4 verification evidence"
```

## Self-review

- **Spec coverage:** All three class identities, exact stats, nine skill contracts, cooldowns, target counts/order, health and keyword conditions, Advantage-consumption history, prior allied-action timing, distinct-attacker scaling/cap, mixed-race selection, Speed refresh/queue rebuild, atomicity, logs, and cleanup map to explicit tasks.
- **Architecture:** Catalog files own authored content; race identity is stable run/battle data; generic immutable conditions/effects and pure history queries own reusable rules; the resolver freezes outcomes; the arena coordinates without Goblin IDs.
- **Scope:** Brakka, closest-enemy selection, Cache/preparation, save changes, progression, and full production-flow evidence remain outside AC6.4.
- **Atomicity:** Ordered selections, conditions, health/keyword/history predicates, race identity, locked values, and battle revision revalidate before the first mutation.
- **Type consistency:** `race_id`, `target_sides`, `armor_operations`, condition names, history-query signatures, and effect factories are defined before use and remain consistent across tasks.
- **Governance:** AC6.4 remains incomplete until the focused runner, full Battle suite, deterministic rerun, GodotIQ project/runtime gate, and evidence ledger all pass.
