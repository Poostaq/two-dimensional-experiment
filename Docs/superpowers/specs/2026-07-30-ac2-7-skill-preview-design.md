# AC2.7 Structured Skill Preview Design

**Status:** Approved

**Presentation superseded:** The fixed right-docked preview described below was replaced by the shared hover-tooltip design in `Docs/superpowers/specs/2026-07-31-skill-hover-tooltip-design.md`. The `CharacterSkill` metadata contract, exact fixture descriptions, and non-actionability requirements remain authoritative.

**Acceptance criterion:** AC2.7 — The player can inspect a readable description for each skill before committing an action, including passive skills from an inspectable UI surface.

## Goal

Extend every AC2.6 player and enemy skill with a complete, structured description and present the selected skill in a readable right-docked preview within the existing battle skill inspector. Inspection remains non-actionable and does not implement skill mechanics.

## Scope

AC2.7 includes:

- Four required preview fields on every `CharacterSkill`: effect, targeting, requirements, and cooldown.
- Exact preview content for all eleven AC2.6 fixture skills on both battle sides.
- A scene-owned preview region inside the existing `SkillInspectorPanel`.
- A stable four-row presentation that shows `None` when a category does not apply.
- Inspection of both active and passive skills before any action is committed.
- Selection, defeat, removal, invalidation, reconfiguration, and new-battle lifecycle handling.
- Focused automated coverage, regression coverage, and manual runtime evidence.

AC2.7 excludes:

- Executing active skills or applying passive effects.
- Enforcing targeting, positional requirements, condition requirements, or cooldowns.
- Tracking cooldown state.
- Combo conditions or combo bonuses.
- Default attack and adjacent-swap actions.
- Localization, persistent character definitions, serialization, animation, and balancing.

## Architecture

Extend the existing `CharacterSkill` value object rather than adding a separate preview type or placing descriptions in `BattleArena`. This keeps identity, classification, and authored preview metadata together; preserves the defensive-copying contract already owned by `BattleUnitState`; and gives AC2.8 a stable descriptive contract without prematurely implementing mechanics.

`BattleArena` remains a reader of skill metadata. It owns selection and presentation state but does not interpret or enforce the preview fields.

## CharacterSkill preview contract

`CharacterSkill` gains four read-only properties backed by convention-private fields:

- `effect_text: String`
- `targeting_text: String`
- `requirements_text: String`
- `cooldown_text: String`

`create()`, `_init()`, `is_valid_definition()`, `is_valid()`, and `duplicate_skill()` carry all four values. Every field must remain non-empty after trimming surrounding whitespace. Validation uses trimming only to detect blank input; valid authored text is retained exactly.

When a category does not apply, the author must provide the literal display value `None`. `None` is valid content rather than a missing value. This makes omissions distinguishable from deliberately inapplicable behavior and guarantees that all four preview rows always have readable content.

Invalid construction follows the existing runtime-safe behavior: it calls `push_error()`, `create()` returns `null`, and an invalid directly initialized object cannot enter a `BattleUnitState` skill roster. `duplicate_skill()` returns a fresh validated object containing exact copies of all identity, classification, and preview fields.

## Exact fixture previews

The existing AC2.6 skill IDs, names, kinds, order, and unit assignments remain unchanged. Their preview fields are:

| Skill | Effect | Targeting | Requirements | Cooldown |
|---|---|---|---|---|
| Shield Bash | Deal 7 damage. | Closest active enemy. | User must occupy a front-row slot. | 1 turn after use. |
| Frontline Guard | Reduce the next damage taken by an adjacent ally by 3. | Adjacent active allies. | User must occupy a front-row slot. | None |
| Quick Step | Gain 2 Speed until the end of the next turn. | Self. | None | 2 turns after use. |
| Quick Strike | Deal 5 damage. | Closest active enemy. | None | None |
| Rally | Grant all active allies 2 Speed until the end of the round. | All active allies, including the user. | None | 2 turns after use. |
| Evasion | Prevent the first damage instance received each round. | Self. | None | None |
| Momentum | Gain 1 Speed after taking an action, lasting until battle ends. | Self. | User must remain active. | None |
| Savage Blow | Deal 12 damage. | Closest active enemy. | User must be above 50% HP. | 2 turns after use. |
| Blood Scent | Deal 3 additional damage to injured enemies. | Enemies below 50% HP. | Target must be below 50% HP. | None |
| Brace | Reduce the first damage received each round by 2. | Self. | None | None |
| Shadow Lunge | Deal 10 damage. | Farthest active enemy. | User must occupy a back-row slot. | Unavailable for the first turn of battle; none after use. |

These strings define the player-facing descriptive contract only. They do not imply executable effects or enforcement in AC2.7.

## Inspector layout

The existing scene-owned `SkillInspectorPanel` remains the only skill inspector. Its body becomes two responsive horizontal regions:

```text
SkillInspectorPanel
└── SkillInspectorContent
    ├── SkillInspectorTitleLabel
    ├── SkillInspectorPromptLabel
    └── SkillInspectorBody (HBoxContainer)
        ├── SkillSelectionRegion (approximately 70% width)
        │   ├── SkillInspectorCharacterBlock
        │   └── SkillInspectorSkills or SkillInspectorEmptyLabel
        └── SkillPreviewPanel (approximately 30% width, right-docked)
            └── SkillPreviewContent
                ├── SkillPreviewPromptLabel
                ├── SkillPreviewHeading
                │   ├── SkillPreviewNameLabel
                │   └── SkillPreviewKindLabel
                ├── SkillPreviewEffectLabel
                ├── SkillPreviewTargetingLabel
                ├── SkillPreviewRequirementsLabel
                └── SkillPreviewCooldownLabel
```

The preview occupies approximately 30% of the inspector's available width and must remain within the accepted 25–33% range at the project target viewport. The selection region expands into the remaining width. Spacing or a vertical separator visually distinguishes the right-docked preview from the skill buttons while both regions remain inside the same outer panel.

Preview values use wrapping labels and remain readable without overlap. At the project target viewport:

- The complete inspector remains inside the viewport bounds.
- The preview occupies 25–33% of the inspector's rendered width.
- All four skill buttons of the four-skill fixture are fully visible.
- The selected skill name, kind, and all four preview rows are simultaneously visible.
- No heading, row label, or row value is clipped, truncated, overlapped, or obscured.
- The inspector requires no horizontal scrolling.

## Presentation states

When no character is inspected, the existing character prompt is visible and the inspector body is hidden.

When a character is inspected but no skill is selected:

- The selection region shows the character and its skill buttons or zero-skill empty state.
- `SkillPreviewPromptLabel` shows `Select a skill to inspect its description.`
- The selected-skill heading and four preview rows are hidden.

When a skill is selected:

- The selected button retains the AC2.6 highlight.
- The preview prompt is hidden.
- The exact skill display name and `Active` or `Passive` kind are shown.
- All four labeled rows are visible in this order: `Effect`, `Targeting`, `Requirements`, `Cooldown`.
- A row whose category does not apply displays `None`; rows are never omitted.

## State and lifecycle

1. Battle configuration clears character selection, skill selection, and preview content.
2. Selecting a populated player or enemy slot selects that character and restores the preview prompt.
3. Selecting a skill validates it against the currently inspected unit, stores its stable `skill_id`, highlights exactly one button, and renders its preview.
4. Skill inspection does not advance the turn, change HP, mutate the battle log, complete the battle, or resolve any active or passive behavior.
5. Turn advancement and damage preserve the selected preview while the inspected unit remains in `_units`.
6. A retained defeated unit remains inspectable, keeps its selected preview, and is labeled `Defeated`.
7. Selecting another character clears the selected skill and restores the preview prompt.
8. An empty slot remains a no-op and preserves the current character and preview.
9. Removing or invalidating the inspected unit clears character selection, skill selection, and preview.
10. Reconfiguration and a new battle restore the complete neutral state.

Active and passive skills use the same selection and presentation path.

## Defensive behavior

- Blank preview fields reject the complete skill definition.
- Missing content cannot be represented by an empty string; `None` must be authored explicitly.
- Invalid skills cannot enter a unit roster.
- Defensive duplication preserves all preview fields and prevents source-object mutation from changing stored skill metadata.
- A stale or foreign `skill_id` cannot populate the preview.
- At most one selected skill and one populated preview exist.
- Preview rendering never becomes an action-resolution path.
- The right-docked preview remains within the shared panel and accepted width range.
- Layout changes cannot make the existing four-skill fixture unreadable at the target viewport.

## Verification strategy

### Automated coverage

Create a focused AC2.7 test runner that verifies:

- Valid preview values are preserved exactly.
- Blank effect, targeting, requirements, and cooldown values are each rejected.
- `None` is accepted as explicit display content.
- Defensive duplication retains all four values in a distinct skill object.
- Every one of the eleven player and enemy fixture skills matches the exact table above.
- The preview begins in its prompt state.
- Active and passive selections show the correct name, kind, and all four labeled rows.
- `None` rows remain visible.
- Selecting a skill highlights only that button and does not advance the turn, change HP, or add a battle-log entry.
- Selecting another character clears the preview.
- Empty-slot inspection preserves the preview.
- Turn advancement and damage preserve the preview.
- Retained defeat preserves the preview and changes the unit status to `Defeated`.
- Unit removal, invalidation, reconfiguration, and new-battle setup clear the preview.
- The preview belongs to the existing inspector, is right-docked, and occupies 25–33% of the inspector width at the target viewport.
- The four-skill fixture remains inside the viewport with four readable buttons.

Update the AC2.6 runner only where the expanded required constructor contract demands complete valid preview fixtures. Its AC2.6 behavioral assertions remain unchanged. Run all existing AC2.1 through AC2.6 focused runners as regressions.

### Manual runtime coverage

1. Enter battle without committing an action.
2. Inspect an active player skill and confirm the exact heading and four labeled preview rows.
3. Inspect a passive player skill and confirm the same stable surface, including visible `None` values.
4. Repeat active and passive inspection for enemy skills.
5. Confirm the preview occupies 25–33% of the shared inspector's rendered width.
6. Inspect the four-skill fixture and confirm all four buttons, the selected skill name and kind, and all four preview rows are simultaneously visible with no clipping, truncation, overlap, obscuring, horizontal scrolling, or viewport overflow.
7. Select different skills and characters and confirm highlight and preview state follow the lifecycle contract.
8. Advance a turn, apply damage, and defeat the inspected unit; confirm retained inspection remains stable and non-actionable.
9. Reconfigure or enter a new battle and confirm no prior preview remains.

Record the automated log, manual runtime record, and implementation commit link under `Docs/Specs/AC2/Evidence/AC2.7/<verification-date>/`. The automated log and manual record must identify the same tested implementation commit.

After every automated, regression, runtime, and evidence gate passes:

1. Change the AC2.7 checkbox in `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` from `[ ]` to `[x]`.
2. Replace the AC2.7 verification row with an `Automated and manual runtime check` path that names the focused test runner, structured model validation, exact eleven-skill fixture coverage, active/passive preview states, lifecycle behavior, non-actionability, the 25–33% width constraint, and the no-clipping target-viewport gate.
3. Confirm the MVP document contains exactly one AC2.7 acceptance row and exactly one AC2.7 verification row.
4. Keep AC2.8 and AC2.9 unchecked and avoid claiming executable skill mechanics.
5. Commit the MVP closeout and evidence files together so the checked criterion points to a complete, traceable evidence package.

## Completion boundary

AC2.7 is complete when every AC2.6 fixture skill on both battle sides carries the exact validated structured preview, the existing inspector presents a readable right-docked four-row preview before action commitment for both active and passive skills, lifecycle and non-actionability contracts hold, the AC2.1–AC2.6 regressions remain green, the measurable target-viewport layout gates pass, matching evidence is recorded against one tested implementation commit, and the MVP checkbox and verification row are formally closed out. Functional skill mechanics remain unimplemented, and AC2.8 and AC2.9 remain unchecked.
