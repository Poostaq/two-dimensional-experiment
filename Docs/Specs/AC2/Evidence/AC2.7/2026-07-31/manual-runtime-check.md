# AC2.7 Hover Tooltip Manual Runtime Check

- Tested implementation commit: `43a792bd92144eb9d604ed4951b404aac0e192d0`
- Engine: Godot 4.7.1 stable Steam
- Viewport: `1152x648`
- Result: PASS

## Inspection coverage

- Player active: Shield Bash showed its name, `Active`, Effect, Targeting, Requirements, and Cooldown while hovered.
- Player passive: Frontline Guard showed its name, `Passive`, all four rows, and explicit `Cooldown: None` while hovered.
- Enemy active: Savage Blow showed its exact six-part tooltip while hovered.
- Enemy passive: Blood Scent showed its exact six-part tooltip, including `Cooldown: None`, while hovered.

## Interaction and lifecycle

- Tooltips appeared from hover without requiring a click.
- Moving between buttons replaced the content and anchor with the new skill.
- Leaving the button hid the tooltip immediately.
- Clicking did not pin the tooltip; leaving after clicking still hid it.
- Hover did not change HP, turn, round, battle log, inspected unit, or selected skill.
- Character changes and arena reconfiguration cleared tooltip state.
- Duplicate entries and stale exits did not displace or hide the current tooltip.

## Placement and readability

- Shield Bash rendered at `[54,245]` with size `288x184`, centered above its `[154,437]-[242,525]` button with the required 8-pixel gap.
- Blood Scent rendered at `[146,219]` with size `288x210`; all wrapped rows remained inside the `1152x648` viewport.
- Automated placement checks passed for 12-pixel horizontal clamping and below-button fallback when top space is insufficient.
- The fixed right-docked description column is absent; the skill selection region uses the released inspector width.
- No tooltip row was clipped, truncated, overlapped, or obscured.
- The tooltip uses ignored mouse filtering and caused no pointer flicker.

## Runtime health

- `verify_project_runs` returned PASS.
- GodotIQ debugger capture contained 0 runtime errors and 0 script errors.
- The runtime tour showed the tooltip floating above the selected skill row and remaining within viewport bounds.
