# World Camera Edge-Centering Design

## Goal

At every supported camera framing, the player can place any radius-8 boundary hex at the center of the desktop viewport. Space outside the hex-shaped board uses the existing dark world background.

## Scope

This change affects only Stage 3 world-camera bounds, camera tests, minimap-footprint presentation, and associated evidence. It does not change world generation, accepted moves, encounters, boss pursuit, Party behavior, saves, or the production 25-cell scene.

## Camera contract

- Camera position is clamped to the axis-aligned bounds of the canonical world-cell centers, not to bounds reduced by half the visible viewport.
- Consequently, every outermost cell center—including all six canonical radius-8 corners—can equal the camera position at approximately 3-, 5-, and 11-hex framing.
- Panning cannot move the camera center beyond the outer cell-center bounds. The map therefore cannot be lost completely through unbounded overscroll.
- The existing dark world background is visible wherever the viewport extends beyond the hex board.
- Initial opening behavior remains unchanged: the camera centers on the player at `(-8, 0)`.
- Click-drag pan and wheel zoom remain the only camera navigation inputs. Edge scrolling remains absent.
- Camera actions continue to consume zero world turns.

## Minimap contract

The minimap continues receiving the live visible-world rectangle after configure, pan, center, and zoom operations. Its camera footprint may extend beyond the rendered board outline when an edge cell is centered; it must not be clipped or silently reduced to board bounds.

## Verification

Automated camera tests must prove:

1. Each of the six canonical radius-8 corner cell centers can be centered at 3-, 5-, and 11-hex framing.
2. Attempts to pan beyond those center bounds clamp to the nearest permitted center-boundary position.
3. Centering and zooming emit the live camera rectangle used by the minimap.
4. Camera operations do not modify the supplied move count.
5. No edge-scroll API or process-driven edge-scroll path exists.

The composed preview test must center representative opposite boundary cells and verify that the minimap footprint changes without altering the shared `WorldPlan`.

## Visual acceptance

At 3-, 5-, and 11-hex framing, capture the preview with a boundary hex centered. Confirm that:

- the selected boundary hex is at viewport center;
- outside-board space uses the existing dark background;
- HUD, formation, context bar, and minimap remain readable;
- the minimap footprint represents the overscanned viewport.

## Failure and compatibility behavior

Invalid or empty world bounds retain the existing defensive behavior; this change introduces no new player-facing error. Existing camera method signatures remain stable. The new clamp semantics replace the Stage 3 requirement that the visible rectangle remain fully enclosed by the world rectangle.
