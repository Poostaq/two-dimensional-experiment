# AC9.3 Seeded Enemy Boss Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax.

**Goal:** Deterministically select and persist one Human, Elf, or Dwarf four-member commander-led boss party for every new run.

**Architecture:** RunCharacterCatalog owns canonical enemy order. BossPartyCatalog owns exact versioned compositions and validates their commander and combo contract. RunEnemyBossSelection is the immutable persisted cross-reference, chosen by a pure FNV-1a selector. V8 carries it through launch, Continue, and autosave without changing the V1 map.

**Tech Stack:** Godot 4, typed GDScript, SceneTree tests, FNV-1a, versioned JSON envelopes, GodotIQ.

---

## File map

| File | Responsibility |
|---|---|
| Scripts/Run/run_character_catalog.gd | Canonical enemy clan order |
| Scripts/Battle/enemy_boss_party_definition.gd | Immutable definition and defensive member access |
| Scripts/Battle/boss_party_catalog.gd | Exact definitions, lookup, validation, construction |
| Scripts/Run/run_enemy_boss_selection.gd | Immutable clan/party identity |
| Scripts/Run/run_enemy_clan_selector.gd | Pure seed-to-enemy selector |
| Scripts/Run/world_run_start_service.gd | Selection before generation |
| Scripts/Save/world_run_save_codec_v8.gd | V8 writer/reader plus V7 fallback |
| Scripts/Save/world_run_save_envelope.gd | Exact V8 envelope |
| Scripts/Run/world_production_launcher.gd | V8 new-run session |
| Scripts/Run/world_single_slot_repository.gd | V8 decoder entry |
| Scripts/WorldMap/world_runtime_controller.gd | Pass selection to autosave |
| Scripts/WorldMap/world_runtime_save_coordinator.gd | V5/V6/V7/V8 dispatch |
| Tests/Run/test_ac9_3_enemy_boss_selection.gd | Definition, selector, and combo test |
| Tests/Save/test_world_run_save_codec_v8.gd | V8 and compatibility test |

### Task 1: Canonical enemy clans and authored definitions

**Files:** Modify Scripts/Run/run_character_catalog.gd and Scripts/Battle/boss_party_catalog.gd. Create Scripts/Battle/enemy_boss_party_definition.gd and Tests/Run/test_ac9_3_enemy_boss_selection.gd. Extend Tests/Battle/test_ac9_0_boss_party_catalog.gd.

- [ ] **Step 1: Write RED assertions.**

The new runner must lock this exact table, validate clan order [human, elf, dwarf], and require definition lookup by both clan and party ID. For each entry it asserts four ordered members, one exact commander, matching race ID for all members, defensive member/party copies, and unknown lookup rejection.

| Clan | Party ID | Combo ID | Commander | Ordered members |
|---|---|---|---|---|
| human | human_fortified_line_v1 | fortified_line | marshal_elian_voss | marshal_elian_voss, human_iron_sentinel, human_ranger, human_field_medic |
| elf | elf_moonfall_exposure_v1 | moonfall_exposure | lady_saelith_moonfall | lady_saelith_moonfall, elf_warden_of_the_grove, elf_star_archer, elf_crescent_duelist |
| dwarf | dwarf_stonevein_forge_v1 | stonevein_forge | thane_brokk_stonevein | thane_brokk_stonevein, dwarf_rune_sentinel, dwarf_siege_smith, dwarf_hearthkeeper |

Run:

~~~powershell
godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/Run/test_ac9_3_enemy_boss_selection.gd
~~~

Expected: nonzero, because no enemy-clan query, definition, or party-ID API exists.

- [ ] **Step 2: Implement the definition value.**

Create the new GDScript with the exact public data and validation shape:

~~~gdscript
class_name EnemyBossPartyDefinition
extends RefCounted

var boss_party_id: StringName
var enemy_clan_id: StringName
var commander_id: StringName
var combo_id: StringName
var _member_class_ids: Array[StringName] = []

static func create(party_id: StringName, clan_id: StringName, commander: StringName, combo: StringName, members: Array[StringName]) -> Dictionary:
    if party_id.is_empty() or clan_id.is_empty() or commander.is_empty() or combo.is_empty():
        return {"ok": false, "value": null, "error": &"blank_identity"}
    if members.size() != 4 or members.count(commander) != 1:
        return {"ok": false, "value": null, "error": &"member_contract"}
    var seen: Array[StringName] = []
    for member_id: StringName in members:
        if member_id.is_empty() or seen.has(member_id):
            return {"ok": false, "value": null, "error": &"duplicate_member"}
        seen.append(member_id)
    var value := EnemyBossPartyDefinition.new()
    value.boss_party_id = party_id
    value.enemy_clan_id = clan_id
    value.commander_id = commander
    value.combo_id = combo
    value._member_class_ids = members.duplicate()
    return {"ok": true, "value": value, "error": null}

func get_member_class_ids() -> Array[StringName]:
    return _member_class_ids.duplicate()
~~~

In RunCharacterCatalog add ENEMY_CLAN_IDS equal to human, elf, dwarf, plus get_enemy_clan_ids returning a duplicate.

- [ ] **Step 3: Make BossPartyCatalog authoritative.**

Replace its clan match with exactly the three table definitions. Add clan lookup, party-ID lookup, and party-ID construction. The compatibility wrapper create_by_enemy_clan_id resolves the definition then delegates to party-ID construction. The catalog validation constructs all members through RunCharacterCatalog, requires exactly four members of the definition clan, and exactly one expected commander.

- [ ] **Step 4: GREEN, validate, and commit.**

Run the new runner and Tests/Battle/test_ac9_0_boss_party_catalog.gd. For each changed script run GodotIQ validate and check_errors. Commit:

~~~powershell
git add Scripts/Run/run_character_catalog.gd Scripts/Battle/enemy_boss_party_definition.gd Scripts/Battle/boss_party_catalog.gd Tests/Run/test_ac9_3_enemy_boss_selection.gd Tests/Battle/test_ac9_0_boss_party_catalog.gd
git commit -m "feat: define authored enemy boss parties"
~~~

### Task 2: Immutable selection and independent seed selector

**Files:** Create Scripts/Run/run_enemy_boss_selection.gd and Scripts/Run/run_enemy_clan_selector.gd. Modify Tests/Run/test_ac9_3_enemy_boss_selection.gd.

- [ ] **Step 1: Write RED selection assertions.**

Require rejection for unknown and cross-clan party IDs, replay determinism, and reachability of all three clans across 4,096 seeds. Lock this vector:

~~~gdscript
var result := RunEnemyClanSelector.select("ac9-enemy-vector-1")
_expect(result.ok, "golden selection succeeds")
_expect(result.value.enemy_clan_id == &"dwarf", "golden clan is Dwarf")
_expect(result.value.boss_party_id == &"dwarf_stonevein_forge_v1", "golden party is Stonevein")
_expect(WorldPriority.fnv1a32_ascii("twde-ac9|v=1|seed=6163392d656e656d792d766563746f722d31|ns=ac9-enemy-clan-v1") == 1650523226, "golden payload hash")
~~~

Run the Task 1 test. Expected: nonzero because the two selection classes do not exist.

- [ ] **Step 2: Implement the immutable cross-reference.**

Create RunEnemyBossSelection with fields enemy_clan_id and boss_party_id. Its factory validates the clan against RunCharacterCatalog, resolves party ID through BossPartyCatalog, rejects a definition of another clan, requires a constructed four-member party, then returns the immutable value. Its create_party method delegates to catalog party-ID construction.

- [ ] **Step 3: Implement exact FNV selection.**

Create RunEnemyClanSelector with SELECTION_VERSION 1 and SELECTION_NAMESPACE ac9-enemy-clan-v1. The select method must:

1. Read canonical enemy clans and require the exact [human, elf, dwarf] list.
2. Build payload twde-ac9|v=1|seed=<seed_hex>|ns=ac9-enemy-clan-v1.
3. Choose FNV-1a modulo clan count.
4. Resolve that clan definition and build RunEnemyBossSelection.
5. Emit the established WorldGenerationError result with namespace enemy-clan-selection and one of enemy_clan_pool_invalid, boss_party_definition_missing, or enemy_boss_selection_invalid on failure.

- [ ] **Step 4: Add executable combo fixtures.**

Use Scenes/battle_arena.tscn with production party construction and inspect BattleUnitState:

- Human: Elian grants Armor to adjacent authored Iron Sentinel.
- Elf: Warden/Archer establish Snared and Advantage before Saelith or Crescent Duelist performs a legal conversion.
- Dwarf: Brokk grants Armor to adjacent authored defensive member before Rune Sentinel/Hearthkeeper protection and Siege Smith damage remain legal.

Metadata or labels alone do not pass this requirement.

- [ ] **Step 5: GREEN, validate, and commit.**

Run the AC9.3 runner; validate and check errors for both new scripts. Commit:

~~~powershell
git add Scripts/Run/run_enemy_boss_selection.gd Scripts/Run/run_enemy_clan_selector.gd Tests/Run/test_ac9_3_enemy_boss_selection.gd
git commit -m "feat: select deterministic enemy boss parties"
~~~

### Task 3: Start-service integration before generation

**Files:** Modify Scripts/Run/world_run_start_service.gd and Tests/Run/test_world_run_start_service.gd.

- [ ] **Step 1: Write RED spies.**

Add injected allied/enemy selector spies recording call order, count, and seed. Assert one allied selection before one enemy selection, the enemy selector receives selection.seed_text, successful candidates expose enemy_boss_selection, and enemy-selection failure calls neither generator nor commit callback.

Run:

~~~powershell
godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/Run/test_world_run_start_service.gd
~~~

Expected: nonzero because no enemy selector dependency or candidate field exists.

- [ ] **Step 2: Inject selectors and return the value.**

Add source dependencies, stored selector instances, and this constructor signature:

~~~gdscript
func _init(commit_callback: Callable, generator: RefCounted = null, allied_selector: RefCounted = null, enemy_selector: RefCounted = null) -> void:
~~~

Use injected selectors by defaulting to their loaded scripts. Call allied selection first, then enemy selection with resolved_selection.seed_text, before generator.generate. Revalidate a supplied enemy selection through its factory. Return it under enemy_boss_selection while leaving V1 generator inputs, starter formation, and commit semantics unchanged.

- [ ] **Step 3: GREEN, validate, and commit.**

Run start-service and AC9.3 runners; validate/check the service. Commit:

~~~powershell
git add Scripts/Run/world_run_start_service.gd Tests/Run/test_world_run_start_service.gd
git commit -m "feat: attach enemy boss selection to new runs"
~~~

### Task 4: V8 persistence contract

**Files:** Create Scripts/Save/world_run_save_codec_v8.gd and Tests/Save/test_world_run_save_codec_v8.gd. Modify Scripts/Save/world_run_save_envelope.gd.

- [ ] **Step 1: Write V8 test in RED.**

Start a run; encode/decode V8; assert version 8, enemy_clan_id, boss_party_id, and restored immutable value. Reject absent, blank, unknown, and cross-clan IDs. Decode V7 via V8 and require player selection/coalition restoration with no fabricated enemy value; retain V2-V6 fallback checks.

- [ ] **Step 2: Create V8 codec.**

~~~gdscript
class_name WorldRunSaveCodecV8
extends RefCounted

const SAVE_VERSION: int = 8
static var ENVELOPE_SCRIPT: Script = load("res://Scripts/Save/world_run_save_envelope.gd")
static var V7_SCRIPT: Script = load("res://Scripts/Save/world_run_save_codec_v7.gd")

static func encode(plan: RefCounted, seed: String, state: RefCounted, selection: RunClanSelection, coalition: RunClanCoalition, enemy: RunEnemyBossSelection) -> PackedByteArray:
    return ENVELOPE_SCRIPT.encode(plan, seed, state, SAVE_VERSION, selection, coalition, enemy)

static func decode_any(bytes: PackedByteArray) -> Dictionary:
    var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
    if parsed is Dictionary and parsed.get("save_version") == SAVE_VERSION:
        return ENVELOPE_SCRIPT.decode(parsed, SAVE_VERSION)
    return V7_SCRIPT.decode_any(bytes)
~~~

- [ ] **Step 3: Extend shared envelope once.**

Add optional enemy selection parameter; accept 2 through 8; require selection at V6+, coalition at V7+, valid enemy selection at V8. V8 writes exactly enemy_clan_id and boss_party_id. Add both only to V8 shape validation. Decode both via RunEnemyBossSelection.create after coalition validation, return enemy_boss_selection, and map malformed values to SAVE_ENVELOPE_INVALID with constraint enemy_boss_selection. Do not alter V2-V7 keys or fallback dispatch.

- [ ] **Step 4: GREEN, validate, and commit.**

Run V8 then V7 codec suite; validate/check both scripts. Commit:

~~~powershell
git add Scripts/Save/world_run_save_codec_v8.gd Scripts/Save/world_run_save_envelope.gd Tests/Save/test_world_run_save_codec_v8.gd
git commit -m "feat: persist enemy boss selection in V8 saves"
~~~

### Task 5: Launch, Continue, and runtime autosave propagation

**Files:** Modify Scripts/Run/world_production_launcher.gd, Scripts/Run/world_single_slot_repository.gd, Scripts/WorldMap/world_runtime_controller.gd, Scripts/WorldMap/world_runtime_save_coordinator.gd, Tests/Run/test_world_production_launcher.gd, and Tests/WorldMap/test_ac9_2_runtime_save_coordinator.gd.

- [ ] **Step 1: Write RED propagation tests.**

Require V8 new-run bytes and emitted session enemy_boss_selection. Configure the coordinator with selection, coalition, enemy selection; commit candidate; assert V8 and V8 decode. Preserve an existing V7 configuration without enemy selection and assert it still writes V7.

- [ ] **Step 2: Implement mechanical propagation.**

- Launcher and repository load WorldRunSaveCodecV8.
- Launcher encodes started.enemy_boss_selection and emits it in session.
- Runtime controller passes session enemy value to persistence configuration.
- Coordinator stores enemy selection, rejects it unless player selection and coalition are valid, writes V8 only when all three values are valid, and otherwise preserves V7, V6, V5 branches exactly.
- Continue obtains the value only from repository decode; no loaded-session code calls the selector.

- [ ] **Step 3: GREEN, validate each script, and commit.**

Run launcher, V8/V7 codec, coordinator, AC9.3, and start-service suites. After each production script edit run GodotIQ validate and check_errors. Commit:

~~~powershell
git add Scripts/Run/world_production_launcher.gd Scripts/Run/world_single_slot_repository.gd Scripts/WorldMap/world_runtime_controller.gd Scripts/WorldMap/world_runtime_save_coordinator.gd Tests/Run/test_world_production_launcher.gd Tests/WorldMap/test_ac9_2_runtime_save_coordinator.gd
git commit -m "feat: retain enemy boss identity through runtime saves"
~~~

### Task 6: Evidence and project gate

**Files:** Create Docs/Specs/AC9/Evidence/AC9.3/automated-test.log and runtime-smoke.md. Modify Docs/Specs/GAME_DESIGN_SPEC_MVP.md.

- [ ] **Step 1: Run and record focused regressions.**

Run and record command, exit code, and PASS marker for AC9.3 selection, AC9.0 boss catalog, start service, V8 codec, V7 codec, launcher, and runtime save coordinator.

- [ ] **Step 2: Run project and Play gates.**

Run GodotIQ project validate, project check_errors, orphan-signal inspection; play, verify startup, inspect console, and stop. Record exact result. No screenshot tour: AC9.3 changes no scene/presentation resource.

- [ ] **Step 3: Update traceability after green.**

Add an AC9.3 completion note: all clans reachable; exact commander-led parties; executable combos; V8 no-reroll restore; V2-V7 compatibility. Keep later AC9 work planned.

- [ ] **Step 4: Commit evidence.**

~~~powershell
git add Docs/Specs/AC9/Evidence/AC9.3 Docs/Specs/GAME_DESIGN_SPEC_MVP.md
git commit -m "docs: record AC9.3 enemy boss selection evidence"
~~~

## Plan self-review

- Every approved requirement maps to a task: seeded selection, exact authored composition, matching commander, executable combos, V8 persistence, no Continue reroll, and legacy preservation.
- RunCharacterCatalog owns eligibility; BossPartyCatalog owns composition; RunEnemyBossSelection owns the persisted cross-reference.
- Every code task starts RED, ends GREEN, validates each script, checks parse health, and makes a narrow commit.
- AC9.4/AC10 map placement and campaign behavior remain excluded.
