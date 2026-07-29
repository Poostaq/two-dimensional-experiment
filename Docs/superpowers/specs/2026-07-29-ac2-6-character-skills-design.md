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

Construction requires an ID and display name whose string forms remain non-empty after trimming surrounding whitespace, plus a valid enum value. Empty and whitespace-only values such as `""`, `" "`, and `"\t"` are invalid. The object retains the caller-provided non-blank text; trimming is used for validation rather than silently normalizing identity or presentation. The object contains no description, targeting data, requirements, cooldown state, combo data, scene references, or executable behavior.

### BattleUnitState skill roster

`BattleUnitState` gains:

- `skills: Array[CharacterSkill]`.
- A `MAX_CHARACTER_SKILLS` constant set to `4`.

The constructor accepts an optional typed skill array so existing callers remain source-compatible. It rejects input containing more than four skills and duplicates valid input so later caller mutation cannot add, remove, or replace entries in the unit's roster accidentally.

Zero skills are valid. Every roster element must be a valid `CharacterSkill`; `null` is rejected. A roster cannot contain the same `skill_id` more than once, even if the duplicate entries are different objects. The typed `Array[CharacterSkill]` constructor boundary rejects values of any other object type before construction can succeed. Every invalid roster rejects the entire construction attempt rather than filtering, truncating, or partially accepting entries.

The same rules apply to `PLAYER` and `ENEMY` units.

### Fixed battle fixtures

The existing battle setup will assign these exact character-specific skill rosters:

| Unit ID | Display name | Side | Character-specific skills |
|---|---|---|---|
| `player_0` | Player Front 1 | Player | `shield_bash` / Shield Bash / Active; `frontline_guard` / Frontline Guard / Passive |
| `player_1` | Player Front 2 | Player | No character-specific skills |
| `player_2` | Player Front 3 | Player | `quick_step` / Quick Step / Active |
| `player_3` | Player Back 1 | Player | No character-specific skills |
| `player_4` | Player Back 2 | Player | `quick_strike` / Quick Strike / Active; `rally` / Rally / Active; `evasion` / Evasion / Passive; `momentum` / Momentum / Passive |
| `player_5` | Player Back 3 | Player | No character-specific skills |
| `enemy_0` | Enemy Front 1 | Enemy | `savage_blow` / Savage Blow / Active; `blood_scent` / Blood Scent / Passive |
| `enemy_1` | Enemy Front 2 | Enemy | No character-specific skills |
| `enemy_2` | Enemy Front 3 | Enemy | `brace` / Brace / Passive |
| `enemy_3` | Enemy Back 1 | Enemy | No character-specific skills |
| `enemy_4` | Enemy Back 2 | Enemy | `shadow_lunge` / Shadow Lunge / Active |
| `enemy_5` | Enemy Back 3 | Enemy | No character-specific skills |

These fixtures demonstrate the contract only. Their skill names and classifications do not imply implemented effects.

### BattleArena debug skill inspector

The existing battle arena receives this exact subtree, with every listed node wired persistently in `battle_arena.tscn` rather than created by `battle_arena.gd`. Its intended placement is immediately after the turn-status controls and before the battle-result controls. The current concrete location is after `Margin/VBox/TurnStatus` and before `Margin/VBox/BattleResultPanel`; implementation may adapt the parent path if the surrounding layout changes, provided the subtree order, node names, unique-name access, ownership, and persistent scene wiring remain unchanged.

```text
SkillInspectorPanel (PanelContainer, unique name)
└── SkillInspectorContent (VBoxContainer)
    ├── SkillInspectorTitleLabel (Label, unique name, text="Character Skills (Debug)")
    ├── SkillInspectorPromptLabel (Label, unique name, text="Select a populated slot to inspect skills.")
    ├── SkillInspectorHeader (HBoxContainer)
    │   ├── SkillInspectorUnitNameLabel (Label, unique name, text="")
    │   ├── SkillInspectorStatusLabel (Label, unique name, text="")
    │   └── SkillInspectorCountLabel (Label, unique name, text="")
    ├── SkillInspectorSkills (VBoxContainer, unique name)
    └── SkillInspectorEmptyLabel (Label, unique name, text="No character-specific skills")
```

The neutral state shows `SkillInspectorPromptLabel` and hides the header, dynamic skill rows, and empty-state label. An inspected unit hides the prompt and shows:

- `SkillInspectorUnitNameLabel`: the exact unit display name.
- `SkillInspectorStatusLabel`: `Active` while `unit.is_active()` is true, otherwise `Defeated`.
- `SkillInspectorCountLabel`: `Skills: N/4`.
- One dynamic `Label` child under `SkillInspectorSkills` per skill, formatted as `Skill Name — Active` or `Skill Name — Passive`.
- `SkillInspectorEmptyLabel` only when `N` is zero.

Clicking a populated player or enemy formation slot selects that unit. Clicking an empty slot is a no-op and preserves the current inspection. The panel contains no skill-use controls and no description surface.

## State and data flow

1. A battle creates or receives typed `BattleUnitState` instances.
2. Each unit retains its copied zero-to-four-item skill roster.
3. `BattleArena.configure_units()` clears the prior inspection and renders the formations.
4. Each populated formation slot is connected to inspection using its stable `unit_id`.
5. Selecting a populated slot resolves the current unit and renders its name, count, and typed skill labels.
6. Turn advancement and damage preserve inspection while the unit remains present in `_units`.
7. If the inspected unit becomes inactive but remains in `_units`, the inspector remains selected, retains its skill rows, and changes `SkillInspectorStatusLabel` to `Defeated`.
8. If the inspected unit is removed from `_units` or becomes invalid, the arena clears the inspection rather than showing stale state.
9. Reconfiguration clears the selection and restores the neutral prompt.

Reward presentation and battle completion do not add skill behavior or change the selected unit unless that unit has been removed.

## Defensive behavior

- More than four character-specific skills is invalid and fails clearly at the model boundary; it is never silently truncated.
- Empty and whitespace-only skill IDs and display names are invalid.
- Unknown kind values are invalid.
- `null`, wrong-type, and duplicate-ID roster elements reject the complete roster.
- Caller-side array mutation does not change a constructed unit's roster.
- Both battle sides use identical validation and presentation rules.
- Empty formation slots cannot become inspection targets.
- An inactive retained unit remains inspectable and is explicitly labeled `Defeated`.
- Reconfiguration, removal, and invalidation cannot leave stale character details visible.
- AC2.6 labels only Active or Passive and does not suggest that either type is executable.

## Verification strategy

### Automated coverage

A focused AC2.6 test runner verifies:

- `CharacterSkill` preserves valid ID, display name, and typed Active/Passive identity.
- Empty or whitespace-only IDs and names, plus invalid kind values, are rejected.
- `BattleUnitState` accepts zero through four skills.
- A fifth skill is rejected rather than truncated.
- `null`, wrong-type, and duplicate-ID roster entries are rejected.
- The input array is copied.
- Player and enemy units use the same roster contract.
- Every named fixed runtime fixture matches the exact roster table in this design.
- The debug inspector begins in its neutral state.
- Selecting a populated player slot renders the correct name, count, skill names, and labels.
- Selecting a populated enemy slot follows the same contract.
- Selecting a zero-skill character shows the explicit empty state.
- Clicking an empty slot does not change inspection.
- Reconfiguration clears inspection.
- Defeating a retained inspected unit preserves its skill rows and changes its status to `Defeated`.
- Removing or invalidating the inspected unit clears inspection.
- Existing AC2.1 through AC2.5 tests remain green.

### Manual runtime coverage

1. Enter a battle and inspect multiple populated player and enemy slots.
2. Verify each inspected character reports between zero and four character-specific skills.
3. Verify every listed skill is labeled exactly Active or Passive.
4. Inspect the zero-skill fixture and verify the explicit empty state.
5. Inspect the four-skill fixture and verify all four rows remain readable.
6. Click an empty slot and verify it does not replace the current inspection.
7. Defeat the inspected unit and verify its skills remain visible while its status changes to `Defeated`.
8. Reconfigure the arena and verify the inspector returns to its neutral prompt.
9. Exit and enter another battle and verify no prior inspected character remains selected.

## Completion boundary

AC2.6 is complete when every named player and enemy fixture carries its specified validated zero-to-four typed skill roster, the exact debug inspector exposes names, status, counts, and Active/Passive labels without stale state, focused and regression tests pass, runtime inspection passes, and matching evidence is recorded. Descriptions and all functional skill mechanics remain intentionally unimplemented.
