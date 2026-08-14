# AC3.2 manual runtime check

Date: 2026-08-14
Implementation commit: `172fdaf5ec5a9e0de5287a3d6ba671a39279c827`
Viewport: 1152×648

- Main scene starts with zero runtime or script-console errors: PASS.
- A valid recruit remains visible and selectable after a Boss victory with a six-member roster: PASS.
- Confirming the recruit opens replacement mode without mutating the roster: PASS.
- Replacement instructions, the pending Champion card, six occupied targets, details panel, destructive target feedback, and Cancel all fit without clipping or overlap: PASS.
- Clicking an occupied member displays the expected name, HP, speed, and readable details: PASS.
- Clicking Cancel closes replacement mode, restores the selected reward, and leaves formation unchanged: PASS.
- Reopening replacement and dragging Champion onto occupied semantic slot 1 through real viewport input completes one atomic replacement: PASS.
- Replacement mode and the completed battle close after the successful request: PASS.
- The next battle opens with Champion in exact semantic slot 1; the inspector reports `Champion`, speed `9`, and HP `24/24`: PASS.
- No runtime or script errors were reported during the flow: PASS.

Fixture note: the live content cannot naturally reach six unique members, so a temporary GodotIQ-injected runtime fixture added two uniquely identified characters for this check. It exercised the normal production UI and controller paths, was removed before final verification, and was not committed.

Result: PASS. All AC3.2 automated, pointer-interaction, visual, cancellation, replacement, and next-battle gates passed.
