# Commander Skill Tooltip Hover Design

## Problem

The commander carousel skill tooltip flickers when it appears beneath the pointer. The tooltip and skill button currently act as separate hover regions: leaving the button hides the tooltip immediately, which exposes the button again and creates a repeating exit/re-entry feedback loop.

## Desired behavior

- Show a skill tooltip when its skill button is hovered or focused.
- Keep it visible while the pointer is over either the originating skill button or the tooltip.
- Allow the pointer to cross the 10-pixel visual gap between those controls without closing the tooltip.
- Hide it 100 milliseconds after both controls are no longer hovered, unless keyboard focus still owns it.
- Switching commander or tooltip targets must not let a stale hide request close the current tooltip.

## Design

`WorldProductionLauncher` will treat the active skill button and tooltip as one logical hover region. Mouse exit schedules a single short deferred hide. Mouse entry on either control cancels that request. When the delay expires, the launcher rechecks the active target, pointer ownership, and focus before hiding, preventing stale callbacks from affecting a newer tooltip.

The existing tooltip layout and 10-pixel offset remain unchanged. No invisible bridge node or overlap is introduced, so the interaction does not depend on a specific layout geometry.

## Verification

Add a focused regression test to `test_world_run_start_scene.gd` that proves:

1. Leaving a skill button does not hide its tooltip immediately.
2. Entering the tooltip during the grace period keeps it visible.
3. Leaving both regions hides it after the grace period.
4. A pending hide for an old target cannot hide a newly selected tooltip.

Run the focused UI test, project validation and parser checks, then exercise the commander carousel in Play mode and confirm stable tooltip behavior with no debug-console errors.
