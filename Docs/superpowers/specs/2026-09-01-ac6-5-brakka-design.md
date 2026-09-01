# AC6.5 — Brakka Rustbanner Design

**Status:** Approved for implementation planning

**Acceptance criterion:** AC6.5 / AC6-AC05 — Brakka retains all three Scrapshield Bruiser skills, adds Banner Holder as her fourth commander skill, and deterministically targets the closest active enemy.

**Verification status:** Design approved; implementation and runtime verification have not started. The New Run layout and tooltip behavior in this document are target contracts, not claims about current production behavior.

## Goal

Implement Brakka Rustbanner as the first selectable commander. The production New Run screen presents Brakka in a commander carousel before run creation, starts her in the middle frontline slot, and exposes her complete four-skill loadout. Banner Holder triggers once per round at the start of Brakka's eligible action and atomically applies Advantage to the deterministically closest active enemy.

## Scope

AC6.5 includes:

- a catalog-owned Brakka definition;
- a Brakka-only commander carousel integrated into the existing New Run screen;
- placeholder portrait and ability icon textures;
- four hover- and focus-accessible ability tooltips;
- optional seed entry and a final `Begin` action on the same screen;
- Brakka replacing the existing starter in formation slot `1`;
- a shared closest-enemy formation selector;
- an action-start reaction trigger and Banner Holder resolution;
- focused, regression, save/reload, production runtime, visual, and evidence-ledger verification.

AC6.5 excludes:

- additional commanders, unlocks, commander progression, or respec;
- final portrait or ability art;
- Scrapline Quartermaster, Cache, and battle-preparation behavior, which remain AC6.6;
- changes to seed generation, encounter generation, movement economy, or reveal authority;
- general replacement of the existing launcher or character catalogs.

## Planned file ownership

The implementation plan must confirm these paths after GodotIQ impact checks and retain one clear owner per responsibility.

| Change | File | Responsibility |
|---|---|---|
| Create | `Scripts/Run/goblin_commander_catalog.gd` | Brakka stable ID, presentation metadata, placeholder visual references, inherited root-class construction, and Banner Holder authoring |
| Modify | `Scripts/Run/run_character_catalog.gd` | Delegate Brakka lookup to the commander catalog |
| Modify | `Scripts/Run/world_production_launcher.gd` | Pending commander selection, one-entry carousel state, Begin payload, and UI refresh |
| Modify | `Scenes/world_run_start.tscn` | Two-column commander panel, portrait arrows, four ability squares/tooltips, seed field, Back, and Begin controls |
| Modify | `Scripts/Run/world_run_start_service.gd` | Validate selected commander and construct the three-unit starting formation with Brakka in slot `1` |
| Modify | `Scripts/Battle/battle_formation_rules.gd` | Shared deterministic closest-enemy ranking contract |
| Modify | `Scripts/Battle/battle_reaction_definition.gd` | Add the action-start trigger to the typed reaction definition |
| Modify | `Scripts/Battle/battle_reaction_dispatcher.gd` | Collect deterministic action-start passives without changing existing hit/movement dispatch |
| Modify | `Scripts/Battle/battle_arena.gd` | Invoke and resolve action-start reactions at the authoritative turn boundary; log atomic outcomes |
| Create | `Tests/Battle/test_ac6_5_brakka.gd` | Brakka catalog, loadout, selector, trigger, guard, atomicity, log, and Advantage-exclusion coverage |
| Modify | `Tests/Run/test_world_production_launcher.gd` | Commander selection state, disabled arrows, Begin payload, overwrite continuity |
| Modify | `Tests/Run/test_world_run_start_service.gd` | Valid/invalid commander start transactions and slot-`1` placement |
| Modify | `Tests/UI/test_world_run_start_scene.gd` | Exact commander controls, four skill squares, tooltip/focus wiring, seed field, Back, and Begin scene contract |
| Modify | `Tests/Save/test_world_run_save_codec_v2.gd` | Brakka formation ID round-trip at the existing save boundary |
| Modify | `Tests/Run/test_ac3_1_run_roster.gd` | Brakka catalog reconstruction and battle conversion retain slot, stats, race, and four skills |
| Modify | `Tests/Run/test_ac3_3_party_formation.gd` | Middle-frontline slot identity remains stable through formation operations |
| Modify | `Docs/superpowers/specs/2026-08-29-ac6-goblin-combat-vertical-slice-design.md` | AC6.5 evidence ledger, commit hashes, pass counts, runtime record, and remaining AC6 scope |
| Modify | `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` | Advance AC6.5 only after all evidence gates pass |

## Architecture

### Commander ownership

`GoblinCommanderCatalog` owns Brakka's stable ID, display metadata, placeholder visual references, Scrapshield base stats, inherited skills, and Banner Holder. It constructs Brakka from the authoritative Scrapshield Bruiser definition and fails if the root loadout is not exactly Shield Tap, Pack Brace, and Banner Nudge before appending the passive.

`RunCharacterCatalog.create_by_class_id()` delegates Brakka's ID to the commander catalog after checking the regular Goblin catalogs. The stable character ID is the durable identity already carried by formation and roster reconstruction; AC6.5 does not introduce a second UI-only commander identity into saved state.

### New Run flow

The existing `WorldProductionLauncher` keeps a pending commander ID while the New Run screen is open. The screen remains a single setup surface:

1. The top region displays a two-column commander panel.
2. The left column contains a placeholder portrait, Brakka's name and title, and carousel arrows adjacent to the portrait.
3. The right column contains commander summary, root-class identity, and four square ability icons.
4. The optional world-seed input appears below both columns.
5. `Back` returns to the main launcher screen. `Begin` validates the selected commander and starts the run.

The carousel is data-driven. Both arrows remain visible but disabled while the catalog has only one entry. Adding a later commander may enable the arrows without restructuring the scene, but multi-commander unlock or ordering rules are out of scope.

Each ability square supports pointer hover and keyboard focus. The tooltip uses the authoritative `CharacterSkill` presentation data. Banner Holder receives a distinct passive border. Placeholder textures remain explicit until final art is supplied.

### Run creation and persistence

`WorldRunStartService.start()` accepts the selected commander ID in addition to seed and generator configuration. It validates and constructs the commander before world generation or durable commit. Unknown, empty, or invalid commander definitions fail without generation, overwrite, roster mutation, save mutation, or scene transition.

Brakka replaces the current generic starter in formation slot `1`, the middle frontline slot. Slots `0` and `2` retain their existing starters, preserving the three-unit opening party. Formation persistence stores Brakka's stable ID, and reload reconstructs her complete definition through `RunCharacterCatalog`. `RunRoster.create_battle_units()` remains the production conversion boundary.

## Banner Holder behavior

Banner Holder is Brakka's fourth commander skill:

- kind: Passive;
- trigger: start of Brakka's eligible action;
- frequency: once per round;
- action cost: none;
- effect: apply Advantage to the active enemy closest to Brakka;
- tooltip: `Once per round at the start of your action, apply Advantage to the closest active enemy.`

An eligible action start occurs when Brakka is active, battle is not complete, and Brakka becomes the authoritative current unit. Extra actions and passive chains cannot bypass the once-per-round guard.

The shared reaction definition gains an action-start trigger. The reaction dispatcher exposes an action-start collection path instead of embedding Brakka-specific behavior in `BattleArena`. Existing direct-hit and forced-movement reaction behavior remains unchanged.

## Closest-enemy selection

The shared formation rule uses:

```text
lane_distance = abs((enemy.slot_index % 3) - (Brakka.slot_index % 3))
```

Selection filters to active opposing units with valid formation slots, then orders candidates by:

1. lowest lane distance;
2. frontline before backline;
3. lowest slot index;
4. stable unit ID only as a defensive final ordering key if malformed input duplicates a slot.

The selector returns the selected stable enemy ID, not a mutable UI reference.

Immediately before application, resolution verifies that Brakka and the selected enemy remain active and that the enemy still has the winning distance and tie-break rank. A stale result applies nothing and never redirects to another enemy.

## Atomicity, guard, and logging

Banner Holder produces one of two outcomes:

- Success: the still-valid selected enemy receives Advantage through the existing keyword authority, the once-per-round guard is retained, and the battle log records `<actor>'s Banner Holder applied Advantage to <enemy>.`
- No result: no keyword or unrelated combat state changes, the once-per-round guard prevents a retry in the same round, and the battle log records `Banner Holder found no active enemy.`

The no-result log also covers a target that becomes stale during resolution. This keeps the authored log vocabulary bounded and avoids redirecting stale selection.

Default Attack and Default Swap cannot consume Advantage. Their existing shared behavior remains unchanged and receives AC6.5 regression coverage.

Passive guards and Advantage remain battle-local. Existing battle teardown clears them before a fresh battle.

## Error handling and UI states

- `Begin` is disabled when the commander catalog cannot provide a valid current definition.
- Disabled carousel arrows ignore pointer and keyboard activation and have a visibly disabled state.
- Seed generation and save failures continue through the existing launcher failure overlay.
- Unknown commander IDs fail before any durable or runtime mutation.
- Invalid root loadout, invalid fourth skill, unsupported reaction trigger data, invalid slots, inactive candidates, and stale resolution fail closed.
- UI selection state never mutates catalog definitions or runtime battle state.

## Verification strategy

### Focused automated coverage

`Tests/Battle/test_ac6_5_brakka.gd` proves:

- Brakka identity and retained Scrapshield stats;
- exact three inherited active skills plus Banner Holder in the fourth slot;
- action-start eligibility and no action expenditure;
- once-per-round behavior across normal turns, extra actions, and passive chains;
- active-enemy filtering;
- lane-distance selection;
- frontline-before-backline and lowest-slot tie-breaks;
- stale target with no redirect;
- no-active-enemy outcome;
- exact success and no-result logs;
- Default Attack and Default Swap do not consume Advantage;
- battle teardown clears the guard and Advantage state.

Launcher, scene, service, save, and roster tests prove:

- one Brakka catalog entry and stable ID lookup;
- visible disabled left/right arrows;
- placeholder portrait and four square ability controls;
- hover/focus tooltips sourced from skill definitions;
- Banner Holder's distinct passive presentation;
- optional blank or explicit seed handling;
- `Begin` passes the selected commander and preserves existing overwrite behavior;
- invalid commander rejection is atomic;
- Brakka replaces slot `1` while slots `0` and `2` retain existing starters;
- save/reload reconstructs Brakka with the same four skills;
- roster-to-battle conversion preserves slot, stats, race, and loadout.

Retained AC6.1 through AC6.4 battle suites and existing world launcher, run-start, scene, save, roster, and production-entry suites remain green.

### Exact automated runner mapping

| Verification concern | Runner |
|---|---|
| Brakka definition, four-skill order, closest selector, action-start trigger, stale/no-enemy behavior, logs, guard, Default exclusions | `Tests/Battle/test_ac6_5_brakka.gd` |
| Launcher state, one-entry carousel, selected commander payload, overwrite continuity | `Tests/Run/test_world_production_launcher.gd` |
| Commander validation, atomic start failure, middle-frontline placement, blank/explicit seed continuity | `Tests/Run/test_world_run_start_service.gd` |
| Exact production scene nodes, disabled arrows, portrait placeholder, four ability squares, tooltip/focus wiring, seed input, Back, Begin | `Tests/UI/test_world_run_start_scene.gd` |
| Stable Brakka formation ID through Save V2 encode/decode | `Tests/Save/test_world_run_save_codec_v2.gd` |
| Catalog reconstruction, roster slot, stats, race, and battle-unit four-skill conversion | `Tests/Run/test_ac3_1_run_roster.gd` |
| Middle-frontline identity through formation operations | `Tests/Run/test_ac3_3_party_formation.gd` |
| Existing action lock remains intact when action-start passive resolves | `Tests/Battle/test_active_turn_skill_lock.gd` |
| Production main-scene launcher-to-world cutover remains intact | `Tests/Run/test_world_cutover_entry.gd` |

The implementation plan supplies the exact Godot invocation for each runner, expected RED reason before production work, expected PASS count after implementation, and the bounded retained-suite command.

### GodotIQ and production runtime evidence

The implementation gate runs:

- per-file GodotIQ validation and parser checks after each code change;
- final project validation, project parser checks, and orphan-signal audit;
- production startup and debug-console checks;
- visual tour of the New Run screen and focused inspection of the commander panel and tooltips;
- a production walkthrough that starts a seeded run, confirms Brakka in middle frontline, enters combat, observes Banner Holder's deterministic target and log, verifies once-per-round behavior and Default action exclusions, then saves/reloads and reconfirms identity and formation.

The manual production record must explicitly capture these checks:

1. Main menu `Start New Run` opens the combined commander/seed screen.
2. Brakka portrait placeholder, name, title, and details appear; both adjacent carousel arrows are visible, disabled, and ignore input.
3. Four ability squares are present. Pointer hover and keyboard focus show the authoritative tooltip for Shield Tap, Pack Brace, Banner Nudge, and Banner Holder; the passive square is visually distinct.
4. A blank seed and an explicit known seed each reach the existing correct start path; the final action label is `Begin`.
5. Production world/party inspection reports Brakka's stable ID in formation slot `1`.
6. Production combat reports Brakka as current unit, applies Advantage to the ranked closest active enemy, and emits the exact success log.
7. A same-round extra-action attempt does not trigger Banner Holder again; Default Attack and Default Swap leave the Advantage token present.
8. A save/reload returns Brakka to the same formation identity with four skills.
9. GodotIQ production startup and the final debug-console read contain no parser or runtime errors.

Evidence records include screenshots, state inspections, exact focused/regression commands and pass counts, runtime logs, validation results, date, branch, and implementation commits. The AC6 design ledger and active specification advance AC6.5 / AC6-AC05 only after every required gate passes.

## Success criteria

AC6.5 is complete only when:

- the approved single-screen commander/seed layout is present in production;
- Brakka is the only selectable commander and both arrows are disabled;
- Begin starts a run with Brakka in frontline slot `1`;
- Brakka retains all three Scrapshield skills and exposes Banner Holder fourth;
- Banner Holder applies Advantage to the deterministic closest active enemy once per round with atomic stale/no-enemy handling;
- Default Attack and Default Swap do not consume Advantage;
- save/reload and fresh-battle conversion preserve Brakka correctly;
- focused, retained regression, GodotIQ, production runtime, visual, and evidence-ledger gates pass.
