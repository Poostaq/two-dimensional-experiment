# AC8.4 expansion: current habitat and world debug drawer

**Status:** Approved by the user and implemented on 2026-09-20 in `cf25a14`. See [verification evidence](../../Specs/AC8/Evidence/AC8.4-expansion/verification.md).

**Goal:** Show the player's current habitat in the world HUD and provide a world-map diagnostic drawer matching the existing battle drawer.

## Recommended experience

Add a persistent `Habitat: Goblin` label to the world HUD. It describes the hex occupied by the player, never the hovered destination. Keep this label visible when diagnostics are closed. Update it after a committed move, new session and Continue; a failed save must not display a candidate destination as the player's current habitat.

Add a right-edge Debug handle and an authored overlay drawer, collapsed by default. Match the battle drawer's dark panel, border treatment, close control, scrolling and focus behavior. Opening it overlays the map without resizing or recentering the map, HUD or minimap.

The drawer is read-only and follows the player's current hex. Opening, closing and scrolling never advance moves, change encounters or save state. No teleport, gold editing, debug damage or other state-changing commands are included in this expansion.

## Habitat semantics

**Approved extension:** Every existing on-map hex in world version 1 displays Goblin habitat, including non-towns. This is a compatibility classification for the existing world, not generated habitat topology. Diagnostics identify its source as `Legacy world v1 rule` and show habitat ID as `Not generated`.

Create one shared habitat resolver used by both the HUD/debug presentation and the existing town-ownership resolver. Town ownership still validates that the cell is a town; querying a non-town must continue to return `not_a_town` through the town API. The habitat API accepts any valid on-map cell. Unknown world versions and invalid coordinates fail explicitly, with UI displaying `Unavailable` and diagnostics showing the reason. They must never silently become Goblin.

AC9 later supplies explicit generated habitat/clan data through this same boundary. No generator change, new boundaries, town relocation, new world version or save migration is included now.

## Diagnostic contents

Use clearly labelled sections so the panel remains useful as information grows. Values come from authoritative plan/runtime/run-state objects; missing data displays a reason rather than invented values.

| Section | Fields |
|---|---|
| Current hex | Axial coordinates `(q, r)`; terrain; base encounter type from the plan; effective runtime encounter type; encounter consumed/completed flag; town yes/no and town index |
| Habitat and ownership | Habitat display name; canonical clan ID; resolution source; habitat ID or `Not generated`; town ownership result or `Not a town`; resolution errors |
| Map context | Resolved seed; world generation version; adjacent on-map coordinates; currently valid movement destinations; road endpoint links incident to this coordinate; forest-cluster membership if present |
| Run state | Player coordinate; boss coordinate; move count; boss active/engaged/defeated state as supported by existing state/receipts; run status; gold |
| Interaction and persistence | Session applied; input blocked; active encounter/battle/party management; autosave blocked; integration failure; pending reward battle ID; preparation state; cache progress/ready |

Terrain and encounter type must remain separate: a hex can be forest terrain and a combat encounter simultaneously. Base and effective encounter values must also remain separate because a moving boss can override a cell's encounter. Road links are the plan's endpoint records; do not call a cell a road tile merely because a rendered route appears to pass through it.

Do not dump entire objects, roster records, save contents or absolute file paths. Preserve long seeds/error text through wrapping and scrolling.

## Interaction rules

- Default inspection target is the player's occupied hex. The HUD habitat and `Current hex` section always agree.
- The drawer does not introduce click-to-inspect behavior that competes with map movement. Optional hovered/selected-hex inspection is a later extension unless requested during review.
- Pointer input and scrolling inside the drawer cannot click, pan or zoom the map behind it. Outside its rectangle, existing map interaction continues; accepted movement refreshes the drawer.
- Escape closes the drawer before any lower-priority world action. Tab/Shift+Tab cycle through available drawer controls while open; closing restores valid prior focus or the Debug handle.
- Hide/reset the world drawer during battle, reward, encounter, party-management and save-failure modal surfaces. Existing modal input authority takes precedence. Opening a new session or returning to the launcher clears stale diagnostic data and closes the drawer.
- Diagnostics refresh at existing state/presentation boundaries, including failed-save/blocked-state changes, without a per-frame save or whole-map rebuild.

## Ownership and file boundaries

| File | Responsibility |
|---|---|
| New `Scripts/WorldMap/world_habitat_rules.gd` | Pure versioned habitat resolution |
| Existing `Scripts/WorldMap/town_ownership_rules.gd` | Preserve town-only contract; delegate clan resolution to shared habitat rule |
| Existing `Scripts/WorldMap/world_runtime_model.gd` | Expose current/cell habitat query alongside town query |
| New `Scripts/UI/world_debug_presenter.gd` | Convert detached diagnostic data into readable section text |
| New `Scripts/UI/world_debug_drawer.gd` and `Scenes/UI/world_debug_drawer.tscn` | Authored overlay, display, scrolling, visibility and focus |
| Existing `Scripts/UI/world_map_hud.gd` and `Scenes/world_map_hud.tscn` | Persistent current-habitat label |
| Existing `Scripts/WorldMap/world_runtime_controller.gd` and `Scenes/world_map_runtime.tscn` | Compose authoritative diagnostics, wire drawer and refresh HUD at existing publication boundaries |

The controller remains the coordinator. The drawer receives detached values and owns no world model, repository or mutable run state. Reuse the battle drawer's interaction pattern and visual conventions, without coupling the world drawer to battle-only commands or log controls. Preserve the user's existing local battle-drawer scene changes.

## Alternatives considered

1. **Dedicated world drawer plus persistent habitat label — recommended.** Matches the existing UI and keeps ordinary habitat information accessible without diagnostics.
2. Put all information inside the drawer. Smaller HUD change, but requires opening diagnostics to learn the current habitat.
3. Add a hover inspector for arbitrary map hexes now. Useful for map-authoring diagnosis, but expands target selection and movement-input handling beyond current-hex information.

## Acceptance and verification

1. Current HUD habitat and drawer habitat agree for every tested v1 cell, including non-towns; town APIs still reject non-towns.
2. Invalid inputs/unknown versions expose explicit failures and never show successful Goblin ownership. Existing AC8.4 tests continue passing.
3. Diagnostics distinguish terrain, base encounter and boss-overridden effective encounter. Verify town index, forest membership, road endpoints, consumed encounters, seed and move state against fixtures.
4. Fresh run, accepted move and Continue refresh correctly. A rejected move or failed persistence keeps the committed current location/habitat. Retry updates after successful publication only.
5. Drawer operations leave canonical map bytes, run state, wallet, roster and move count unchanged. Scene geometry remains unchanged when the drawer opens/closes.
6. Real pointer tests confirm no click-through or map zoom/pan through the panel. Keyboard tests cover Escape, Tab, Shift+Tab and focus restoration.
7. Modal transitions, battle return, launcher return and session replacement leave no stale content or extra open drawer.
8. Run focused rules/presenter/HUD/drawer/integration tests plus ownership, world-runtime, persistence, launcher and battle-drawer regressions.
9. Perform GodotIQ runtime verification and visual QA at 1280x720 and 1920x1080, including long seeds and scrolled diagnostic content. Record screenshots and evidence before marking this expansion verified.

Broad AC8.4 recruitment-offer acceptance remains dependent on AC8.5/AC8.6. This expansion adds habitat information and diagnostics only.
