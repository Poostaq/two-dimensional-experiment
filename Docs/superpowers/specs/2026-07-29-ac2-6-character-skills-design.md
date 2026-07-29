# AC2.6 Character-Specific Skills Design

**Status:** Approved

**Acceptance criterion:** AC2.6 — Each character can expose up to 4 character-specific skills, and each skill is identified as active or passive.

## Goal

Give every player and enemy character a typed roster of zero to four character-specific skills. Provide a minimal battle debug inspector that identifies each skill as Active or Passive without implementing descriptions, skill use, targeting, requirements, cooldowns, combos, or effects.

## Scope

AC2.6 includes:

- A typed character-skill value object.
- Zero to four character-specific skills on every `BattleUnitState`.
- The same skill contract for player and enemy units.
- Explicit Active and Passive classification.
- Varied fixed battle fixtures that demonstrate zero-skill, mixed-skill, and four-skill characters.
- A minimal debug inspection panel in the battle arena.
- Selection of populated player and enemy formation slots for inspection.
- Cleanup when the arena is reconfigured or the inspected unit is defeated.
- Focused automated coverage and manual runtime evidence.

AC2.6 excludes:

- Player-facing skill descriptions or pre-action inspection, which belong to AC2.7.
- Positional or condition requirements and cooldown behavior, which belong to AC2.8.
- Combo conditions or bonuses, which belong to AC2.9.
- Default attack and adjacent-swap actions, which belong to AC3.7.
- Skill execution, targeting, damage, healing, passive effects, animation, and balancing.
- Persistent character definitions, roster storage, progression, acquisition, and serialization.

## Architecture

Store a copied typed skill array directly on the existing runtime `BattleUnitState`. This keeps the feature aligned with the current battle fixtures and avoids introducing a character catalog or persistent `CharacterDefinition` layer before the unit-management acceptance criteria require one.

`CharacterSkill` is a small `RefCounted` value object. `BattleUnitState` owns at most four such objects and enforces the limit at construction. `BattleArena` reads this state for debug presentation but does not own, modify, or execute skills.

## Components

### CharacterSkill

`CharacterSkill` contains:

- `skill_id: StringName` — stable identity for tests and future consumers.
- `display_name: String` — the short name shown by the AC2.6 debug inspector.
- `kind: Kind` — an enum containing `ACTIVE` and `PASSIVE`.

Construction requires a non-empty ID, a non-empty display name, and a valid enum value. The object contains no description, targeting data, requirements, cooldown state, combo data, scene references, or executable behavior.

### BattleUnitState skill roster

`BattleUnitState` gains:

- `skills: Array[CharacterSkill]`.
- A `MAX_CHARACTER_SKILLS` constant set to `4`.

The constructor accepts an optional typed skill array so existing callers remain source-compatible. It rejects input containing more than four skills and duplicates valid input so later caller mutation cannot add, remove, or replace entries in the unit's roster accidentally.

Zero skills are valid. The same rules apply to `PLAYER` and `ENEMY` units.

### Fixed battle fixtures

The existing battle setup will assign fixed character-specific skills to units on both sides. The fixture set must visibly cover:

- At least one character with zero skills.
- At least one character with a mixed Active/Passive roster.
- At least one character with four skills.
- At least one player and one enemy with skills.

These fixtures demonstrate the contract only. Their skill names and classifications do not imply implemented effects.

### BattleArena debug skill inspector

The existing battle arena receives a compact debug-only skill inspection panel containing:

- A neutral prompt when no unit is inspected.
- The inspected unit's display name.
- A count formatted from `0/4` through `4/4`.
- One row per skill formatted as `Skill Name — Active` or `Skill Name — Passive`.
- A clear `No character-specific skills` state for a zero-skill unit.

Clicking a populated player or enemy formation slot selects that unit. Clicking an empty slot is a no-op and preserves the current inspection. The panel contains no skill-use controls and no description surface.

## State and data flow

1. A battle creates or receives typed `BattleUnitState` instances.
2. Each unit retains its copied zero-to-four-item skill roster.
3. `BattleArena.configure_units()` clears the prior inspection and renders the formations.
4. Each populated formation slot is connected to inspection using its stable `unit_id`.
5. Selecting a populated slot resolves the current unit and renders its name, count, and typed skill labels.
6. Turn advancement and non-terminal damage preserve inspection while the unit remains active.
7. If the inspected unit is defeated and removed from battle, the arena clears the inspection rather than showing stale state.
8. Reconfiguration clears the selection and restores the neutral prompt.

Reward presentation and battle completion do not add skill behavior or change the selected unit unless that unit has been removed.

## Defensive behavior

- More than four character-specific skills is invalid and fails clearly at the model boundary; it is never silently truncated.
- Empty skill IDs and display names are invalid.
- Unknown kind values are invalid.
- Caller-side array mutation does not change a constructed unit's roster.
- Both battle sides use identical validation and presentation rules.
- Empty formation slots cannot become inspection targets.
- Reconfiguration and inspected-unit defeat cannot leave stale character details visible.
- AC2.6 labels only Active or Passive and does not suggest that either type is executable.

## Verification strategy

### Automated coverage

A focused AC2.6 test runner verifies:

- `CharacterSkill` preserves valid ID, display name, and typed Active/Passive identity.
- Empty IDs, empty names, and invalid kind values are rejected.
- `BattleUnitState` accepts zero through four skills.
- A fifth skill is rejected rather than truncated.
- The input array is copied.
- Player and enemy units use the same roster contract.
- The fixed runtime fixtures include zero-skill, mixed-skill, four-skill, player, and enemy examples.
- The debug inspector begins in its neutral state.
- Selecting a populated player slot renders the correct name, count, skill names, and labels.
- Selecting a populated enemy slot follows the same contract.
- Selecting a zero-skill character shows the explicit empty state.
- Clicking an empty slot does not change inspection.
- Reconfiguration clears inspection.
- Defeating the inspected unit clears inspection.
- Existing AC2.1 through AC2.5 tests remain green.

### Manual runtime coverage

1. Enter a battle and inspect multiple populated player and enemy slots.
2. Verify each inspected character reports between zero and four character-specific skills.
3. Verify every listed skill is labeled exactly Active or Passive.
4. Inspect the zero-skill fixture and verify the explicit empty state.
5. Inspect the four-skill fixture and verify all four rows remain readable.
6. Click an empty slot and verify it does not replace the current inspection.
7. Defeat the inspected unit and verify the inspector clears.
8. Exit and enter another battle and verify no prior inspected character remains selected.

## Completion boundary

AC2.6 is complete when both player and enemy characters carry validated zero-to-four typed skill rosters, the debug inspector exposes names and Active/Passive labels for multiple characters without stale state, focused and regression tests pass, runtime inspection passes, and matching evidence is recorded. Descriptions and all functional skill mechanics remain intentionally unimplemented.
