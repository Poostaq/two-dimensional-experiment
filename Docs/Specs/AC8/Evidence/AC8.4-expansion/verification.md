# AC8.4 expansion verification

Date: 2026-09-20. Implementation: `cf25a14` on `feat/ac8-4-world-debug-drawer`, based on AC8.4 town ownership at `c4dbfb9`.

## Delivered behavior

The HUD shows the habitat of the committed player hex. A collapsed right-edge Debug drawer shows coordinates, terrain, base/effective encounter, consumed state, town status/index, habitat/ownership, neighboring cells, valid destinations, incident road endpoints, forest memberships, seed/version, boss/run/gold state, and interaction/persistence diagnostics. It receives detached data and never writes run state.

World version 1 uses an explicit Goblin compatibility rule for every valid cell. Diagnostics identify `Legacy world v1 rule` and habitat ID `Not generated`; invalid inputs and unsupported versions fail explicitly. Town ownership retains its town-only contract. Generated habitat topology remains AC9; filtered offers remain AC8.5/AC8.6. No generator, save schema or migration changed.

## Automated verification

[Final results](final-results.json): **27/27 runners passed**, each exit 0 with PASS and no ERROR. Individual `final-*.log` files retain output. Coverage includes new habitat, presenter, drawer and integration tests; existing ownership/reload, HUD, generator fixtures, model/scenes/camera, save coordinator, codecs v1-v5, launcher/repository/start service, gold/rewards/defeat and battle drawer regressions.

The integration checks cover committed versus rejected/failed-save movement, retry, hovered-cell independence, reload/session replacement, modal hiding, detached snapshots, town/forest/road/consumed/boss fixtures, unavailable preview state, and unchanged persistent data after drawer interactions. Viewport mouse events verify handle/close, panel click and wheel isolation, and dragging from the map into the panel before releasing. Keyboard tests verify Escape, repeated Tab/Shift+Tab containment and focus restoration.

Red/green evidence is retained for absent habitat/drawer/integration APIs, presenter town and empty-reward formatting, and repeated Tab cycles. Review exposed echoed Tab escaping the focus ring; the failing regression now passes. The first broad gate exposed shifted boss HUD alignment; moving the habitat label before the existing spacer restored the layout and all final HUD assertions pass. An intermediate seed assertion was corrected to inspect MapDetails, where the presenter displays seed/version.

## Runtime verification

[GodotIQ results](final-godotiq.json): project compilation checked 217 scripts with zero errors. Convention validation checked 217 scripts and 21 scenes: zero errors, 33 warnings and 5 informational findings, unchanged from baseline warning/info counts. The controller has no orphan or missing signal connections. Main-scene Play verification passed; the final debug console contains no runtime or script errors.

The actual production launcher was exercised with disposable repository `user://ac8-expansion-final-qa-20260920.json`. Starting seed `world-debug-qa` produced player coordinate `(-8, 0)` and Goblin habitat. Real viewport pointer events opened the drawer without changing its diagnostic snapshot. Moving to `(-7, 0)` committed move 1 and opened an encounter, closing the drawer. After stopping and restarting the game, Continue restored `(-7, 0)`, move 1, Goblin habitat and a collapsed drawer. The normal active save slot was not overwritten.

## Visual verification

The rendered capture runner passed at both actual viewport sizes: [1280 log](rendered-1280.log), [1920 log](rendered-1920.log). It opens/closes through viewport pointer input, checks state preservation, and renders a detached long-seed diagnostic fixture before scrolling.

| Viewport | Open drawer | Scrolled long-seed diagnostics | Closed HUD |
|---|---|---|---|
| 1280 x 720 | [Screenshot](drawer-1280.png) | [Screenshot](drawer-scroll-1280.png) | [Screenshot](hud-1280.png) |
| 1920 x 1080 | [Screenshot](drawer-1920.png) | [Screenshot](drawer-scroll-1920.png) | [Screenshot](hud-1920.png) |

Inspected images show a readable opaque dark drawer with gold section headings at the right edge, a reachable close control, and scrolling through all diagnostic sections. Long seed text wraps within the panel. Current habitat sits beside gold; the existing boss status stays right-aligned within the existing HUD. The world HUD retains its pre-existing fixed-size layout at larger resolutions; this expansion does not redesign that layout.

## Review and workspace preservation

Independent implementation review approved the presenter and drawer integration after the repeated-Tab fix and real drag-release regression. Relevant scripts, scenes, tests and UIDs are committed in `cf25a14`. Unrelated pre-existing documentation and battle-drawer scene changes were restored unstaged and compared against the preservation stash, unchanged apart from normalized line endings. The stash is retained as a backup. No remote push was requested or performed.
