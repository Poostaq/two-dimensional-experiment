# Stage 3 Visual Fixture Review

This review uses the deterministic `golden-alpha` preview at 1152×648. Geometry and layer metrics are checked by `test_world_visual_fixtures.gd` before visual capture. Screenshots are observations, not automatically approved pixel baselines.

## Required states

- Road through forest: road remains above the forest layer and retains its 16 px protected corridor.
- Town on Safe: the single-cell building footprint remains readable against the Safe encounter fill.
- Highlighted road: highlight remains outside and above the road without replacing the persistent cell outline.
- Player on road: green `icon.svg`, plate, outline, and `P` label remain above the road.
- Boss adjacent to forest: red `icon.svg`, plate, outline, and `B` label remain distinct from nearby forest color.

## Manual observations

- 5-hex framing: terrain, roads, town buildings, and the player-centered area are immediately legible. The first composition placed the minimap over the left part of the turn counter; the minimap was moved to `(16, 48)` so the complete top status strip remains visible.
- 3-hex framing: the persistent hex outlines remain crisp at close range; terrain fills stay inside their cells and the fixed HUD does not scale with the map. The minimap footprint clearly contracts to the close camera region.
- 11-hex framing: individual cells, alternating encounter fills, forest areas, towns, and the full road corridor remain distinguishable. Roads remain the strongest map-space feature at this scale, while the fixed HUD and minimap remain readable.

## Approval

Manual observation completed at 3-, 5-, and 11-hex framing. The deterministic fixture contract is approved for Stage 3; no pixel baseline is approved automatically.
