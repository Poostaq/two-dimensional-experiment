# HUD Layout Refresh Design

## Goal

Improve the world-map HUD's use of screen space while preserving its existing information, behavior, and signals. The refreshed layout must remain readable at the current 1152×648 presentation size and adapt correctly to alternate viewport widths.

## Scope

This change affects the world-map HUD presentation only:

- top-bar dimensions and alignment;
- minimap dimensions and placement;
- party-preview width, alignment, headings, and slot borders;
- placement and width of the Manage Party button;
- layout-focused automated tests and runtime visual verification.

No gameplay rules, displayed values, party-management behavior, or public HUD API will change.

## Layout Design

### Top bar

The top bar spans the full viewport width and uses a compact height of approximately 44–48 logical pixels at the current viewport size. Cache information is grouped at the left edge. Boss countdown and boss state are grouped at the right edge. The layout uses anchors and containers so both groups retain their edge alignment when the viewport width changes.

### Minimap

The minimap is exactly 75 percent of its current width and height. At the current presentation size, the existing approximately 300×300 region becomes approximately 225×225. It is anchored flush to the left edge and placed immediately below the top bar, with no unintended gap between the two regions.

### Party preview

The party-preview panel is narrower than its current approximately 360-pixel footprint, targeting approximately 245 pixels at the current presentation size. It is anchored flush to the left edge of the viewport.

The column headings read only `Back` and `Front`; the word `Line` is removed. Each party slot has a visible border so the six positions read as distinct cells. Existing slot content and back/front ordering remain unchanged.

The Manage Party button is part of the same bordered party-preview panel and appears below the slot grid. It is centered horizontally, uses approximately 60 percent of the panel width, and does not span the full panel.

### Champion names

Occupied party slots display only the champion's first name, defined as the text before the first whitespace in the character's display name. Single-word names remain unchanged. This keeps every slot at its authored width and preserves a consistent font size; slot controls must never expand to accommodate a longer display name.

## Implementation Approach

The layout remains scene-native. Anchors, offsets, container relationships, minimum sizes, and theme/style overrides in `Scenes/world_map_hud.tscn` define the presentation. `Scripts/UI/world_map_hud.gd` should change only if a node-path adjustment is required by the scene hierarchy; no script-driven viewport sizing will be added.

This approach preserves Godot's responsive layout behavior and avoids scaling complete UI groups, which could distort text, borders, and interaction targets.

## Compatibility and Error Handling

Existing node responsibilities, signal connections, displayed state, and the `WorldMapHud` public API remain intact. The layout must not overlap the instruction/context area at the supported viewport sizes. If the viewport narrows, edge anchoring and container sizing must preserve the top-bar information and keep the party controls usable.

## Verification

Verification will include:

- automated assertions for the top bar's full-width anchors and reduced height;
- automated assertions for the minimap's 75-percent dimensions and left/top-bar alignment;
- automated assertions for cache-left and boss-right alignment;
- automated assertions for the narrower, left-aligned party panel;
- checks that headings are `Back` and `Front`, all six slots have borders, and the centered Manage Party button is inside and narrower than the party panel;
- checks that multi-word champion names render as their first name while slot width remains fixed;
- GodotIQ scene validation and project error checks;
- a runtime launch with no parser or runtime errors;
- visual inspection at 1152×648 and at least one alternate viewport width.

## Acceptance Criteria

The change is complete when all requested layout relationships are visibly present, layout tests pass, existing HUD behavior remains intact, and runtime verification reports no new errors.
