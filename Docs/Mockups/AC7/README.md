# AC7 Battle UI Visual Oracle

Open [`battle-ui-oracle.html`](battle-ui-oracle.html) in a browser. It is the standalone export of the exact Living Lanes mockup approved in the conversation, including the right-edge debug drawer. The embedded visualization runtime supplies icons and tooltips.

The oracle records these design decisions:

- Living Lanes present the original sample characters in four formation lanes.
- The current turn uses a persistent outer gold frame and `NOW`/`ACTIVE` labels.
- Hovering or keyboard-focusing turn-order entries highlights the matching battlefield character.
- The A/B selector shows exactly one action bar at a time.
- Clicking an action updates its selection and description.
- Variant B preserves the compact, icon-only Attack and Move actions with tooltips.
- The right-edge handle opens the overlay debug drawer without moving the battle layout.

## Exact source and preservation

[`battle-ui-oracle.fragment.html`](battle-ui-oracle.fragment.html) preserves the original conversation source from `living-lanes-action-bar.html`, after the compact-action fix and debug-drawer addition. Keep this source unchanged unless the user explicitly approves a mockup revision. Do not redraw the oracle or add acceptance-criteria behaviors to it.

The standalone HTML is generated with the visualize 1.0.37 skill's `scripts/render.py`:

```text
python <visualize-skill>/scripts/render.py Docs/Mockups/AC7/battle-ui-oracle.fragment.html Docs/Mockups/AC7/battle-ui-oracle.html --force --title "AC7 Approved Battle UI Oracle"
```

The drawer data and command messages are illustrative; this mockup does not run a battle simulation. Labels, numbers, sample formation occupancy, and unimplemented interactions must not be interpreted as new gameplay rules. The exact composition is the visual reference; [`GAME_DESIGN_SPEC_MVP.md`](../../Specs/GAME_DESIGN_SPEC_MVP.md) and the implementation plan remain authoritative for production behavior (including Swap terminology). Record implementation differences separately rather than modifying this approved reference.
