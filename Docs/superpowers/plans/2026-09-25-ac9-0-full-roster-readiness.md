# AC9.0 Full Roster Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (\`- [ ]\`) syntax for tracking.

**Goal:** Deliver the remaining seven approved race rosters and commanders as battle-ready, presented, durable content while preserving Goblin and AC6/AC8 behavior.

**Architecture:** \`RunCharacterCatalog\` delegates stable IDs to Wave A/Wave B and commander catalogs. Catalogs own authored definitions and presentation metadata; a new \`BossPartyCatalog\` owns only Human/Elf/Dwarf enemy fixtures. Typed battle effects and \`BattleArena\` consume catalog data generically. AC9 habitat, town, road, spawn, and generator code are out of scope.

**Tech Stack:** Godot 4 GDScript, SceneTree headless tests, GodotIQ, versioned world-run saves.

---

## File map

- \`Scripts/Run/run_character_catalog.gd\`: dispatches every regular class and commander identity.
- \`Scripts/Run/<faction>_wave_a_catalog.gd\`: classes 1–3; \`<faction>_wave_b_catalog.gd\`: classes 4–6.
- \`Scripts/Run/<faction>_commander_catalog.gd\`: commander construction, inherited skills, fourth skill, presentation.
- \`Scripts/Battle/boss_party_catalog.gd\`: the three deterministic enemy commander-party fixtures.
- \`Scripts/Battle/{battle_keyword_operation,battle_skill_effect_definition,battle_skill_condition,battle_skill_authoring_resolver,battle_unit_state,battle_reaction_dispatcher,battle_arena}.gd\`: only missing typed mechanics from approved records.
- \`Tests/Battle/test_ac9_0_shared_mechanics.gd\`, \`test_ac9_0_boss_party_catalog.gd\`, \`test_ac9_1_orcs_integration.gd\` through \`test_ac9_7_dwarves_integration.gd\`: new focused SceneTree runners.
- \`Tests/Save/test_ac9_0_roster_identity_round_trip.gd\`: durable identity round trip.
- \`Docs/Specs/AC9/Evidence/AC9.0/\`: CI, runtime, and visual evidence.

Use the exact class IDs, catalog names, and test paths in \`Docs/superpowers/specs/2026-09-25-ac9-0-full-roster-readiness-design.md\`. \`Docs/Races/<Faction>/Classes.md\` is the authoritative source for each class's stats and three skills.

### Task 1: Establish RED harnesses and a Goblin baseline

**Files:**
- Create: \`Tests/Battle/test_ac9_0_shared_mechanics.gd\`
- Create: \`Tests/Battle/test_ac9_0_boss_party_catalog.gd\`
- Create: \`Tests/Save/test_ac9_0_roster_identity_round_trip.gd\`
- Modify: \`Docs/Specs/AC9/Evidence/AC9.0/verification.md\`

- [x] **Step 1: Write the shared-mechanics failing assertions.**

Follow the SceneTree harness in \`Tests/Battle/test_ac6_3_goblin_wave_a.gd\`: maintain \`_failures\` and \`_assertions\`, print the total, and return exit 1 on a failure. Start with:

\`\`\`gdscript
_expect(BattleKeywordOperation.Kind.has("APPLY_POISON"), "Poison operation exists")
_expect(BattleKeywordOperation.Kind.has("APPLY_STUN"), "Stun operation exists")
_expect(BattleKeywordOperation.Kind.has("LEECH"), "Leech operation exists")
_expect(BattleUnitState.MAX_ARMOR == 10, "Armor cap is fixed at 10")
\`\`\`

- [x] **Step 2: Run the RED harness.**

Run: \`godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/Battle/test_ac9_0_shared_mechanics.gd\`

Expected: exit 1 because the new API is absent—not a parser error.

- [x] **Step 3: Record the baseline.**

Run existing Goblin, AC6 commander, world-run start, and V5 save runners. Append commands, stdout, stderr, assertion totals, and exit codes to \`Docs/Specs/AC9/Evidence/AC9.0/automated-test.log\`.

- [x] **Step 4: Commit.**

\`\`\`bash
git add Tests/Battle/test_ac9_0_shared_mechanics.gd Tests/Battle/test_ac9_0_boss_party_catalog.gd Tests/Save/test_ac9_0_roster_identity_round_trip.gd Docs/Specs/AC9/Evidence/AC9.0/automated-test.log
git commit -m "test: define AC9.0 roster contracts"
\`\`\`

### Task 2: Complete the typed shared mechanic seam

**Files:**
- Modify: \`Scripts/Battle/battle_keyword_operation.gd\`
- Modify: \`Scripts/Battle/battle_skill_effect_definition.gd\`
- Modify: \`Scripts/Battle/battle_skill_condition.gd\`
- Modify: \`Scripts/Battle/battle_skill_authoring_resolver.gd\`
- Modify: \`Scripts/Battle/battle_unit_state.gd\`
- Modify: \`Scripts/Battle/battle_reaction_dispatcher.gd\`
- Modify: \`Scripts/Battle/battle_arena.gd\`
- Test: \`Tests/Battle/test_ac9_0_shared_mechanics.gd\`

- [x] **Step 1: Extend the failing test with one group for every new mechanic.**

Cover Poison (one axis, cap 3, three-round expiry), Stun/Stun Guard (one skipped eligible action, no refresh), Leech (actual direct HP damage only, excluding overkill/status/counter damage), and Move 1–3 declared ring paths. For each, assert preview, cancellation, stale confirmation, and rejected confirmation leave no mutation.

- [x] **Step 2: Run RED after each group.**

Run the Task 1 command. Expected: the named missing behavior fails.

- [x] **Step 3: Implement minimal typed operations.**

Add immutable keyword/effect definitions; store status snapshots, expiry, and guards in \`BattleUnitState\`; make the resolver build plans without mutation; apply a plan only when \`BattleArena\` confirms it. Preserve the existing Armor, Bleed, Advantage, Snared, reaction, and default-action contracts.

- [x] **Step 4: Run GREEN and existing combat regressions.**

Run the shared runner plus \`test_ac6_1_combat_foundation.gd\`, \`test_ac6_2_keyword_reactions.gd\`, \`test_ac6_3_goblin_wave_a.gd\`, \`test_ac6_4_goblin_wave_b.gd\`, and \`test_ac6_5_brakka.gd\`. Expected: every runner exits 0.

- [x] **Step 5: Validate and commit.**

After each script write: \`godotiq_validate(target=<file>, detail="brief")\` then \`godotiq_check_errors(scope=<file>)\`.

\`\`\`bash
git add Scripts/Battle Tests/Battle/test_ac9_0_shared_mechanics.gd
git commit -m "feat: add AC9 authored battle mechanics"
\`\`\`

### Task 3: Generalize construction and enemy fixtures

**Files:**
- Modify: \`Scripts/Run/run_character_catalog.gd\`
- Create: \`Scripts/Battle/boss_party_catalog.gd\`
- Modify: \`Scripts/Battle/debug_encounter_catalog.gd\`
- Modify: \`Scripts/Save/world_run_save_codec_v5.gd\`
- Test: \`Tests/Battle/test_ac9_0_boss_party_catalog.gd\`
- Test: \`Tests/Save/test_ac9_0_roster_identity_round_trip.gd\`

- [x] **Step 1: Write failing construction tests.**

Assert \`RunCharacterCatalog.create_by_class_id(&"unknown") == null\`; a created faction class preserves \`character_id\`, \`class_id\`, and \`race_id\`; \`BossPartyCatalog.create_by_enemy_clan_id(&"human")\` contains its commander exactly once; and a V5 save round trip preserves those fields for a regular unit and commander.

- [x] **Step 2: Run both runners in RED.**

Expected: missing catalog delegation/boss construction failures.

- [x] **Step 3: Implement static catalog delegation.**

Keep \`RunCharacterCatalog.create_by_class_id()\` as the single public construction path. It loads each catalog script and returns the first valid object. \`BossPartyCatalog\` owns only Human, Elf, and Dwarf fixtures and rejects an unknown clan.

- [x] **Step 4: Keep codec dispatch versioned.**

Encode only stable roster identity needed for reconstruction through V5. \`decode_any()\` must continue dispatching V2–V4 payloads unchanged; it must not create AC9 topology or infer faction identities from labels.

- [x] **Step 5: Run GREEN, validate, and commit.**

\`\`\`bash
git add Scripts/Run/run_character_catalog.gd Scripts/Battle/boss_party_catalog.gd Scripts/Battle/debug_encounter_catalog.gd Scripts/Save/world_run_save_codec_v5.gd Tests/Battle/test_ac9_0_boss_party_catalog.gd Tests/Save/test_ac9_0_roster_identity_round_trip.gd
git commit -m "feat: add faction catalog and boss party seams"
\`\`\`

### Task 4: Deliver Orcs

**Files:**
- Create: \`Scripts/Run/orc_wave_a_catalog.gd\`
- Create: \`Scripts/Run/orc_wave_b_catalog.gd\`
- Create: \`Scripts/Run/orc_commander_catalog.gd\`
- Create: \`Tests/Battle/test_ac9_1_orcs_integration.gd\`
- Modify: \`Scripts/Run/run_character_catalog.gd\`

- [x] **Step 1: Write the Orc runner in RED.**

Assert the six exact Orc IDs, the documented stats and three-skill loadout of each, and rejection of unknown IDs. Assert \`goruk_ironline\` inherits \`orc_iron_tusk_vanguard\`’s three skills, appends \`iron_decree\`, exposes a defensive presentation snapshot, fires once per round through \`BattleArena\`, and round-trips through save/reload.

- [x] **Step 2: Run RED.**

Run: \`godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/Battle/test_ac9_1_orcs_integration.gd\`

Expected: exit 1 because the three catalogs do not exist.

- [x] **Step 3: Implement Wave A, Wave B, commander, and dispatch.**

Use the Goblin catalog constructor shape and authored-effect helpers, but implement every stat and skill from \`Docs/Races/Orcs/Classes.md\`. Construct Goruk from the root class, duplicate its three skills, append a guarded \`iron_decree\` passive, and return catalog-owned presentation data.

- [x] **Step 4: Run GREEN, validate every script, and commit.**

\`\`\`bash
git add Scripts/Run/orc_* Scripts/Run/run_character_catalog.gd Tests/Battle/test_ac9_1_orcs_integration.gd
git commit -m "feat: add Orc roster and commander"
\`\`\`

### Task 5: Deliver Lizardmen, Werewolves, and Harpies—one green packet at a time

**Files:**
- Create: \`Scripts/Run/lizardman_{wave_a,wave_b,commander}_catalog.gd\`, \`Tests/Battle/test_ac9_2_lizardmen_integration.gd\`
- Create: \`Scripts/Run/werewolf_{wave_a,wave_b,commander}_catalog.gd\`, \`Tests/Battle/test_ac9_3_werewolves_integration.gd\`
- Create: \`Scripts/Run/harpy_{wave_a,wave_b,commander}_catalog.gd\`, \`Tests/Battle/test_ac9_4_harpies_integration.gd\`
- Modify: \`Scripts/Run/run_character_catalog.gd\`

- [x] **Step 1: Lizardmen: write RED, implement, GREEN, commit.**

Assert six exact IDs, exact documented stats/three skills, Poison axis/cap/expiry, Sszek’s inherited root skills plus \`cartographer_of_venoms\`, presentation, and save/reload. Commit: \`feat: add Lizardman roster and commander\`.

- [x] **Step 2: Werewolves: write RED, implement, GREEN, commit.**

Assert six exact IDs, exact documented stats/three skills, Leech’s actual-direct-damage exclusions, Veyra’s inherited root skills plus \`mark_of_the_alpha\`, presentation, and save/reload. Commit: \`feat: add Werewolf roster and commander\`.

- [x] **Step 3: Harpies: write RED, implement, GREEN, commit.**

Assert six exact IDs, exact documented stats/three skills, Move 2/3 selected-path legality and stale-path rejection, Kyris’s inherited root skills plus \`open_sky_command\`, presentation, and save/reload. Commit: \`feat: add Harpy roster and commander\`.

- [x] **Step 4: Validate and regression-test after each faction.**

Run that faction’s runner, all Task 2 regressions, \`godotiq_validate\`/ \`godotiq_check_errors\` for each changed script, and only then begin the next faction.

### Task 6: Deliver Humans and Marshal Elian Voss

**Files:**
- Create: \`Scripts/Run/human_wave_a_catalog.gd\`
- Create: \`Scripts/Run/human_wave_b_catalog.gd\`
- Create: \`Scripts/Run/human_commander_catalog.gd\`
- Create: \`Tests/Battle/test_ac9_5_humans_integration.gd\`
- Modify: \`Scripts/Battle/boss_party_catalog.gd\`
- Modify: \`Scripts/Battle/debug_encounter_catalog.gd\`

- [x] **Step 1: Write the Human runner in RED.**

Assert six documented Human classes. Assert \`marshal_elian_voss\` inherits \`human_vanguard\` then appends \`marshal_the_line\`: once per action-start round, grant 2 Armor to Elian and the deterministic lowest-slot adjacent ally; no ally is a guarded no-result. Assert the Human boss fixture includes Elian exactly once and identity round trips.

- [x] **Step 2: Run RED, implement, and run GREEN.**

Implement the three catalogs and the action-start passive through typed reaction/effect paths. Update \`BossPartyCatalog\`; make \`DebugEncounterCatalog\` delegate instead of retaining a duplicate Human team. Do not expose Human player selection.

- [x] **Step 3: Validate and commit.**

\`\`\`bash
git add Scripts/Run/human_* Scripts/Battle/boss_party_catalog.gd Scripts/Battle/debug_encounter_catalog.gd Tests/Battle/test_ac9_5_humans_integration.gd
git commit -m "feat: add Human boss roster and commander"
\`\`\`

### Task 7: Deliver Elves and Lady Saelith Moonfall

**Files:**
- Create: \`Scripts/Run/elf_wave_a_catalog.gd\`
- Create: \`Scripts/Run/elf_wave_b_catalog.gd\`
- Create: \`Scripts/Run/elf_commander_catalog.gd\`
- Create: \`Tests/Battle/test_ac9_6_elves_integration.gd\`
- Modify: \`Scripts/Battle/boss_party_catalog.gd\`
- Modify: \`Scripts/Battle/debug_encounter_catalog.gd\`

- [x] **Step 1: Write the Elf runner in RED.**

Assert six documented Elf classes. Assert \`lady_saelith_moonfall\` inherits \`elf_highborn_mystic\` then appends \`moonfall_edict\`: once per action-start round, apply Advantage to the closest active enemy and grant Saelith +1 Speed for the round only if that target is Snared. Stale/no-enemy paths must not redirect/mutate. Assert one Saelith in the Elf boss fixture.

- [x] **Step 2: Run RED, implement, and run GREEN.**

Use the existing closest-opponent tie-break and reaction guard from Brakka. Use \`BattleUnitState.add_speed_modifier()\`; do not branch on Saelith in \`BattleArena\`.

- [x] **Step 3: Validate and commit.**

\`\`\`bash
git add Scripts/Run/elf_* Scripts/Battle/boss_party_catalog.gd Scripts/Battle/debug_encounter_catalog.gd Tests/Battle/test_ac9_6_elves_integration.gd
git commit -m "feat: add Elf boss roster and commander"
\`\`\`

### Task 8: Deliver Dwarves and Thane Brokk Stonevein

**Files:**
- Create: \`Scripts/Run/dwarf_wave_a_catalog.gd\`
- Create: \`Scripts/Run/dwarf_wave_b_catalog.gd\`
- Create: \`Scripts/Run/dwarf_commander_catalog.gd\`
- Create: \`Tests/Battle/test_ac9_7_dwarves_integration.gd\`
- Modify: \`Scripts/Battle/boss_party_catalog.gd\`
- Modify: \`Scripts/Battle/debug_encounter_catalog.gd\`

- [x] **Step 1: Write the Dwarf runner in RED.**

Assert six documented Dwarf classes. Assert \`thane_brokk_stonevein\` inherits \`dwarf_forgewarden\` then appends \`stonevein_bulwark\`: once per action-start round, grant 2 Armor to Brokk and every active adjacent ally, respecting Armor cap 10. Assert deterministic no-result behavior and exactly one Brokk in the Dwarf boss fixture.

- [x] **Step 2: Run RED, implement, and run GREEN.**

Implement Brokk via root construction and skill duplication; construct deterministic supporting Dwarf formation slots in \`BossPartyCatalog\`; retain generic \`BattleArena\` behavior.

- [x] **Step 3: Validate and commit.**

\`\`\`bash
git add Scripts/Run/dwarf_* Scripts/Battle/boss_party_catalog.gd Scripts/Battle/debug_encounter_catalog.gd Tests/Battle/test_ac9_7_dwarves_integration.gd
git commit -m "feat: add Dwarf boss roster and commander"
\`\`\`

### Task 9: Integrate player commander presentation without AC9 topology work

**Files:**
- Modify: \`Scripts/Run/world_run_start_service.gd\`
- Modify: \`Scripts/Run/world_production_launcher.gd\`
- Modify: \`Tests/Run/test_world_run_start_service.gd\`
- Modify: \`Tests/UI/test_world_run_start_scene.gd\`
- Modify: \`Tests/Save/test_ac9_0_roster_identity_round_trip.gd\`

- [x] **Step 1: Write selection RED tests.**

Assert exactly five selectable monster commander IDs; each maps to its own faction; an invalid pair fails before generator/save mutation; a valid card presents four skills and catalog-owned title/root-class text. Assert Human/Elf/Dwarf IDs reject in player setup but construct as boss fixtures.

- [x] **Step 2: Run RED, implement catalog-driven selection, and run GREEN.**

Keep the current New Run/seed surface. Replace Goblin-only lookup with faction/commander validation. Do not implement AC9.1 final selection persistence, habitat generation, or roads.

- [x] **Step 3: Runtime visual validation and commit.**

Use \`godotiq_run(action="play")\`, \`godotiq_ui_map\`, \`godotiq_read_debug_console()\`, and screenshots at 1152×648/1920×1080. Commit:

\`\`\`bash
git add Scripts/Run/world_run_start_service.gd Scripts/Run/world_production_launcher.gd Tests/Run/test_world_run_start_service.gd Tests/UI/test_world_run_start_scene.gd Tests/Save/test_ac9_0_roster_identity_round_trip.gd
git commit -m "feat: expose AC9 ready monster commanders"
\`\`\`

### Task 10: Run the AC9.0 evidence gate

**Files:**
- Modify: \`Docs/Specs/AC9/Evidence/AC9.0/verification.md\`
- Create: \`Docs/Specs/AC9/Evidence/AC9.0/automated-test.log\`
- Create: \`Docs/Specs/AC9/Evidence/AC9.0/rendered-qa.log\`
- Create: all PNG fixture names mandated in \`verification.md\`
- Modify: \`Docs/Specs/GAME_DESIGN_SPEC_MVP.md\`

- [x] **Step 1: Run the complete suite.**

Run every AC9 runner, Task 2 regressions, \`test_goblin_encounter_integration.gd\`, \`test_world_run_start_service.gd\`, \`test_world_run_start_scene.gd\`, and \`test_world_run_save_codec_v5.gd\`. Store complete command/output/exit evidence.

- [x] **Step 2: Run project gates.**

Call \`godotiq_validate(target="project", detail="brief")\`, \`godotiq_check_errors(scope="project")\`, and \`godotiq_signal_map(find="orphans", detail="brief")\`. No new errors are allowed.

- [x] **Step 3: Complete runtime/visual QA.**

For the launcher plus Human, Elf, and Dwarf boss fixtures: verify play, inspect console, exercise a commander action, capture both required resolutions, compare approved golden fixtures, and record results in \`rendered-qa.log\`.

- [x] **Step 4: Change the acceptance status only after every threshold is green.**

Require all headless exits 0, 100% assertions passing, 0 console errors, 48 regular classes plus 8 commanders constructed, all 56 identities round-tripped, and all required images approved. Then complete \`verification.md\` and mark only AC9.0 as \`[x]\` in the MVP spec.

- [x] **Step 5: Commit.**

\`\`\`bash
git add Docs/Specs/AC9/Evidence/AC9.0 Docs/Specs/GAME_DESIGN_SPEC_MVP.md
git commit -m "docs: record AC9.0 roster readiness evidence"
\`\`\`

## Self-review

- AC9.0 scope is covered by Tasks 1–10; every remaining faction has a separate RED/GREEN packet.
- No task changes AC9 habitats, towns, roads, spawns, or AC10 behavior.
- Production code follows a failing test, then minimal code, a green focused runner, validation, and a commit.
- Catalog IDs, commander IDs, test names, evidence names, and numerical thresholds match the approved design specification.
