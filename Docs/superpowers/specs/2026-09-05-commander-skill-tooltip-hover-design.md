# Commander Skill Tooltip Hover Design

## Problem

The commander carousel skill tooltip flickers when it appears beneath the pointer. The tooltip and skill button currently act as separate hover regions: leaving the button hides the tooltip immediately, which exposes the button again and creates a repeating exit/re-entry feedback loop.

## Desired behavior

- Show a skill tooltip when its skill button is hovered or keyboard-focused.
- Keep it visible only while the originating skill button is hovered or focused.
- Make the tooltip and every descendant completely transparent to mouse input.
- Hide it immediately once the originating skill button is neither hovered nor focused.
- A stale exit from an old skill button must not hide a newer skill's tooltip.

## Design

`WorldProductionLauncher` will make the tooltip root and all descendant `Control` nodes use `MOUSE_FILTER_IGNORE`. The active skill button alone owns pointer visibility. Its mouse entry shows the tooltip, while mouse exit hides it unless that same button still owns keyboard focus. Focus entry also shows it, and focus exit hides it unless the pointer is still over that button.

The existing tooltip layout and 10-pixel offset remain unchanged. No delay, invisible bridge, overlap, tooltip-hover state, or timer is needed because the informational tooltip cannot intercept pointer events.

## Verification

Add a focused regression test to `test_world_run_start_scene.gd` that proves:

1. The tooltip root and descendants ignore mouse input.
2. Hovering or focusing a skill button shows its tooltip.
3. Leaving an unfocused skill button hides its tooltip immediately.
4. Losing focus while the pointer remains over the same skill keeps the tooltip visible.
5. A stale exit from an old target cannot hide a newly selected tooltip.

Run the focused UI test, project validation and parser checks, then exercise the commander carousel in Play mode and confirm stable tooltip behavior with no debug-console errors.
