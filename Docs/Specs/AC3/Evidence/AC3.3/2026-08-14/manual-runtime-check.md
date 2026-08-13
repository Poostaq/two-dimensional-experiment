# AC3.3 manual runtime check

Date: 2026-08-14

- Opened the map and confirmed the persistent **Manage Party** button is present.
- Opened party management and confirmed all six formation slots fit at 1152×648.
- Confirmed occupied slots show a green HP bar with numeric current/max HP at the bottom of the character card.
- Clicked an occupied character and confirmed its stats and skills appear below the slot-management area.
- Closed and reopened party management and confirmed no character remains selected and the details panel is empty.
- Confirmed move-to-empty and occupied-slot swap behavior through the scene drag/drop contract tests, with immediate `RunRoster` mutation and refresh.
- Confirmed the next battle receives units in their exact six-slot formation indices.
- Confirmed recruitment suspends reward completion, opens chosen-slot placement, permits cancellation without roster mutation, and commits only after selecting an empty slot.

Result: PASS.
