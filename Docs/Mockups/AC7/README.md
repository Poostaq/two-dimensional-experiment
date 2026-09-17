# AC7 Battle UI Visual Oracle

Open [`battle-ui-oracle.html`](battle-ui-oracle.html) in a browser. It is a self-contained, interactive reference for the approved post-MVP battle presentation.

The oracle records these design decisions:

- Living Lanes retain the six-slot formation while presenting combatants as characters.
- The current turn uses a persistent outer gold frame and `NOW`/`ACTIVE` labels.
- Hovering or keyboard-focusing turn-order entries highlights the matching battlefield character.
- Hovering or keyboard-focusing an action previews legal targets without committing selection.
- Clicking an action commits its target state; clicking a legal unit demonstrates selected-target treatment.
- Default Attack and Default Swap remain compact and use distinct target glyphs.
- An unavailable skill shows `NO TARGET` and its reason.
- The right-edge handle opens the overlay debug drawer without moving the battle layout.

This file is a visual oracle, not production UI code. Where it conflicts with the acceptance criteria, [`GAME_DESIGN_SPEC_MVP.md`](../../Specs/GAME_DESIGN_SPEC_MVP.md) and the implementation plan remain authoritative for behavior.
