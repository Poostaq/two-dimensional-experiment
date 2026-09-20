# Fix TODOs

## FIX-001 — Recognize every hex traversed by a road

- **Status:** Open; reported 2026-09-20.
- **Observed:** Standing on a hex visibly crossed by a road can show no road in the world debug drawer.
- **Required behavior:** Every hex a road passes through counts as a road hex, including intermediate hexes between endpoints. The debug display must agree with the road shown on the map.
- **Acceptance criteria:**
  - [ ] Every hex traversed by a road is recognized as containing a road, including endpoints, intermediate hexes, bends and shared segments.
  - [ ] Standing on any such hex makes the world debug drawer report that a road is present.
  - [ ] Hexes without a road remain classified and displayed as having no road.
  - [ ] Road classification and the debug display remain consistent after saving and continuing the run.
  - [ ] Automated coverage verifies road membership along a complete route; runtime QA checks the debug display while moving through road and non-road hexes.
