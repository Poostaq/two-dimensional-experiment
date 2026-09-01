# AC6.5 — Brakka Rustbanner Design

**Status:** Approved for implementation planning

**Acceptance criterion:** AC6.5 / AC6-AC05 — Brakka retains all three Scrapshield Bruiser skills, adds Banner Holder as her fourth commander skill, and deterministically targets the closest active enemy.

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

### GodotIQ and production runtime evidence

The implementation gate runs:

- per-file GodotIQ validation and parser checks after each code change;
- final project validation, project parser checks, and orphan-signal audit;
- production startup and debug-console checks;
- visual tour of the New Run screen and focused inspection of the commander panel and tooltips;
- a production walkthrough that starts a seeded run, confirms Brakka in middle frontline, enters combat, observes Banner Holder's deterministic target and log, verifies once-per-round behavior and Default action exclusions, then saves/reloads and reconfirms identity and formation.

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
