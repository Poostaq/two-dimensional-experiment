# Skill Hover Tooltip Design

**Status:** Approved

**Supersedes:** The fixed right-docked preview presentation in `Docs/superpowers/specs/2026-07-30-ac2-7-skill-preview-design.md`. The `CharacterSkill` description contract and authored content remain unchanged.

**Implementation baseline:** This change depends on the completed fixed-preview implementation at `feat/ac2-7-skill-preview` commit `95ca733`, or on a branch containing that commit after integration. It must not be implemented directly against a `main` revision that does not yet contain AC2.7.

## Goal

Replace the battle skill inspector's permanently visible description region with a transient tooltip that appears whenever a skill button is hovered and disappears immediately when that button is no longer hovered.

## Scope

This change includes:

- One reusable, scene-owned tooltip in the battle arena.
- Hover-driven inspection for every active and passive skill button.
- Skill name, kind, effect, targeting, requirements, and cooldown content.
- Above-button placement, viewport clamping, and below-button fallback.
- Lifecycle cleanup, focused automated coverage, regression coverage, and runtime visual verification.
- Updates to AC2.7 verification documentation where it describes the fixed right-docked preview.

This change excludes:

- Character skill metadata or balance changes.
- Skill execution, targeting, cooldown enforcement, or other action mechanics.
- Pinning the tooltip after a click.
- Hover delays, fade animations, and keyboard/focus-triggered tooltips.
- Unrelated battle inspector restructuring.

## Architecture and ownership

Remove the fixed `SkillPreviewPanel` from `SkillInspectorBody` so the skill-selection region can use the full inspector width. Add one floating tooltip panel to a scene-owned battle UI layer outside layout containers. The tooltip must render above ordinary battle controls without changing their minimum size or container allocation.

`BattleArena` owns the tooltip node references, content, visibility, and placement. Every generated skill button connects `mouse_entered` with both its `CharacterSkill` and button reference, and connects `mouse_exited` to dismissal. The shared tooltip is populated from the existing read-only `CharacterSkill` fields; no duplicate description model is introduced.

The tooltip and its descendants use `Control.MOUSE_FILTER_IGNORE`. They cannot intercept pointer input, trigger false button exits, or become an actionable battle surface.

Existing click selection and `_selected_skill_id` may remain for future action-selection behavior. Selection and hover are independent: clicking may update the button highlight, but it neither opens nor pins the tooltip.

## Exact scene structure

In `Scenes/battle_arena.tscn`, remove this fixed subtree from `Margin/VBox/SkillInspectorPanel/SkillInspectorContent/SkillInspectorBody`:

```text
SkillPreviewPanel
└── SkillPreviewContent
    ├── SkillPreviewPromptLabel
    ├── SkillPreviewNameLabel
    ├── SkillPreviewKindLabel
    ├── SkillPreviewEffectLabel
    ├── SkillPreviewTargetingLabel
    ├── SkillPreviewRequirementsLabel
    └── SkillPreviewCooldownLabel
```

Add this floating subtree as a direct child of the `BattleArena` scene root, after `Margin` in sibling order so it is not managed by the inspector's containers:

```text
BattleArena
├── Margin
├── SkillTooltipPanel               PanelContainer
│   └── SkillTooltipMargin          MarginContainer
│       └── SkillTooltipContent     VBoxContainer
│           ├── SkillTooltipNameLabel          Label
│           ├── SkillTooltipKindLabel          Label
│           ├── SkillTooltipEffectLabel        Label
│           ├── SkillTooltipTargetingLabel     Label
│           ├── SkillTooltipRequirementsLabel  Label
│           └── SkillTooltipCooldownLabel      Label
└── ... existing root children
```

`SkillTooltipPanel` and all six labels are `unique_name_in_owner`. The panel starts hidden, has `z_index = 20`, `mouse_filter = Control.MOUSE_FILTER_IGNORE`, and a `custom_minimum_size.x` of `288.0`. `SkillTooltipMargin` applies 10 pixels on every side. `SkillTooltipContent` uses 4 pixels of vertical separation. Every label uses `mouse_filter = Control.MOUSE_FILTER_IGNORE`; the four description labels use word wrapping. There is no prompt label because the tooltip is absent when no skill is hovered.

After removing the fixed preview, `SkillSelectionRegion` becomes the only child of `SkillInspectorBody` and uses horizontal expand/fill with stretch ratio `1.0`.

## Tooltip content

The scene-owned tooltip preserves the structured AC2.7 presentation:

- Skill display name.
- `Active` or `Passive` kind.
- `Effect: <effect_text>`.
- `Targeting: <targeting_text>`.
- `Requirements: <requirements_text>`.
- `Cooldown: <cooldown_text>`.

All fields are shown together. Existing `None` values remain explicit rather than hiding non-applicable rows.

## Interaction behavior

The tooltip is hidden when the arena starts and whenever no skill button is hovered.

On `mouse_entered`, `BattleArena` immediately:

1. Populates all tooltip labels from that button's skill.
2. Measures the tooltip after its minimum size is resolved.
3. Positions it relative to the hovered button.
4. Shows it without delay.

On `mouse_exited`, `BattleArena` immediately hides the tooltip and clears its displayed content. Moving directly from one skill button to another therefore replaces the content and anchor with the newly hovered skill; no prior click is required.

Clicking a hovered skill does not change tooltip visibility. Leaving the button after a click still hides the tooltip immediately.

Hover inspection must not modify HP, turn order, round number, battle log, inspected unit, or selected skill.

## Signal wiring and hover state

`BattleArena` adds these private fields:

```gdscript
const SKILL_TOOLTIP_VIEWPORT_MARGIN: float = 12.0
const SKILL_TOOLTIP_ANCHOR_GAP: float = 8.0

var _hovered_skill_button: Button
var _skill_tooltip_generation: int = 0
```

When `_refresh_skill_buttons()` creates each populated skill button, it keeps the existing `pressed` connection and adds:

```gdscript
button.mouse_entered.connect(
	_on_skill_button_mouse_entered.bind(skill, button)
)
button.mouse_exited.connect(
	_on_skill_button_mouse_exited.bind(button)
)
```

`_on_skill_button_mouse_entered(skill, button)` performs these steps in order:

1. If `skill` is invalid, `skill.is_valid()` is false, or `button` is invalid, call `_hide_skill_tooltip()` and return.
2. Set `_hovered_skill_button = button` and increment `_skill_tooltip_generation`.
3. Populate the six labels and show `SkillTooltipPanel`.
4. Call `reset_size()` on the panel so the new wrapped content determines its minimum size.
5. Defer `_position_skill_tooltip(button, generation)` once, passing the captured generation value.

The deferred positioning method returns without moving the tooltip unless all of these remain true: the panel is visible, the button is valid, `_hovered_skill_button == button`, and the captured generation equals `_skill_tooltip_generation`. This prevents stale deferred calls from repositioning a newer tooltip.

`_on_skill_button_mouse_exited(button)` hides only when `button == _hovered_skill_button`. Duplicate exits or an exit from a previously hovered button are no-ops. `_hide_skill_tooltip()` increments the generation, clears `_hovered_skill_button`, hides the panel, and clears all six labels; repeated calls are safe.

## Placement contract

The exact constants are a 12-pixel viewport margin and an 8-pixel anchor gap. Placement uses viewport/global coordinates from `button.get_global_rect()`, `SkillTooltipPanel.size`, and `get_viewport_rect().size`.

For a button rectangle `button_rect`, tooltip size `tooltip_size`, and viewport size `viewport_size`, calculate:

```text
centered_x = button_rect.position.x + (button_rect.size.x - tooltip_size.x) / 2
max_x = max(12, viewport_size.x - 12 - tooltip_size.x)
x = clamp(centered_x, 12, max_x)

above_y = button_rect.position.y - 8 - tooltip_size.y
below_y = button_rect.end.y + 8
max_y = max(12, viewport_size.y - 12 - tooltip_size.y)
y = above_y if above_y >= 12 else clamp(below_y, 12, max_y)
```

Assign `SkillTooltipPanel.global_position = Vector2(x, y)`. If there is insufficient room both above and below, the below fallback is clamped inside the vertical safe margins. The tooltip must remain fully inside the viewport at the target `1152x648` size.

Placement is recalculated for every hover entry. It does not depend on the previously selected or hovered skill.

## Lifecycle handling

The tooltip is force-hidden and cleared when:

- the inspected character changes;
- the current inspector is cleared;
- the hovered unit is defeated, removed, or invalidated;
- units are reconfigured;
- the battle arena is reset or torn down.

Empty formation slots and non-skill controls never show the tooltip. Hiding is idempotent so overlapping refresh and exit paths remain safe.

Additional defensive behavior is mandatory:

- A null or invalid `CharacterSkill` never populates or shows the tooltip.
- A freed or invalid button reference cannot show, move, or retain a tooltip.
- Duplicate `mouse_entered` events refresh the same tooltip safely and invalidate older deferred placement calls.
- Duplicate or stale `mouse_exited` events cannot hide a tooltip owned by a newer hovered button.
- Rebuilding the skill button container calls `_hide_skill_tooltip()` before freeing old buttons.

## Verification

Update `Tests/Battle/test_ac2_7_skill_preview.gd` to verify:

- the tooltip is hidden initially;
- active and passive buttons show the exact six-part structured content on `mouse_entered` without a click;
- `mouse_exited` immediately hides and clears it;
- moving between buttons replaces content and placement;
- clicking does not pin the tooltip;
- hovering and leaving do not mutate battle or selection state;
- character change, invalidation, reconfiguration, and teardown clear stale tooltip state;
- preferred placement is above and centered on the hovered button;
- horizontal placement is clamped at both viewport edges;
- insufficient top space flips placement below the button;
- the complete tooltip remains visible and unclipped at `1152x648`.

Run the focused AC2.7 runner, AC2.1-AC2.6 regression runners, complete project tests, GodotIQ project validation and parser checks, runtime startup, debugger checks, and one target-viewport visual tour. Runtime inspection must cover player and enemy active and passive skills.

The focused execution path is:

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_7_skill_preview.gd
```

It must exit `0`. The regression path runs, in order, `Tests/Map/test_ac2_1_battle_arena.gd` and `Tests/Battle/test_ac2_2_speed_order.gd` through `Tests/Battle/test_ac2_6_character_skills.gd`, each through the same `godot --headless --path . --script res://...` command shape and each with exit code `0`.

## Documentation and evidence artifacts

Update these specific artifacts during implementation:

- `Docs/superpowers/specs/2026-07-30-ac2-7-skill-preview-design.md`: mark only its fixed right-docked presentation as superseded by this design; retain its metadata contract.
- `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`: replace the AC2.7 verification wording that requires a fixed right-docked preview with the hover visibility and placement contract.
- `Docs/Specs/AC2/Evidence/AC2.7/2026-07-31/automated-test.log`: record the focused and AC2.1-AC2.6 regression commands, results, and tested implementation SHA.
- `Docs/Specs/AC2/Evidence/AC2.7/2026-07-31/manual-runtime-check.md`: record player/enemy active/passive hover coverage, immediate dismissal, above placement, below fallback, clamping, and `1152x648` viewport health against the same SHA.
- `Docs/Specs/AC2/Evidence/AC2.7/2026-07-31/implementation-link.txt`: contain only that tested 40-character implementation SHA plus a trailing newline.

## Acceptance criteria

The change is complete when:

- no fixed skill description occupies inspector layout space;
- hovering any populated skill button immediately shows its complete structured tooltip;
- leaving that button immediately hides the tooltip, including after a click;
- the tooltip prefers above-button placement, clamps horizontally, and flips below when required;
- the tooltip stays inside the `1152x648` viewport without clipping, overlap, or pointer interception;
- hover inspection remains non-actionable and lifecycle-safe;
- focused, regression, project, and runtime verification pass;
- AC2.7 documentation accurately describes the hover-tooltip contract.
