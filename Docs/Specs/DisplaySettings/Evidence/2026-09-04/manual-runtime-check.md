# Display Resolution Settings Runtime Check

- Date: 2026-09-04
- Branch: plan/display-resolution-settings
- Tested implementation: 906bcd2
- Godot: 4.7.2.stable.steam.ed1daf0bf
- Platform: Windows, D3D12 Forward Mobile
- Default: 1920×1080 Windowed

## Real DisplayServer matrix

The standalone runtime runner used the production DisplayAdapter, waited two frames after each transition, and inspected DisplayServer.window_get_mode() and DisplayServer.window_get_size().

| ID | Selection | Result |
|---|---|---|
| D1 | 1280×720 Windowed | PASS — exact requested window size |
| D2 | 1920×1080 Windowed | PASS — exact requested window size |
| D3 | 2560×1440 Windowed | PASS — exact requested window size |
| D4 | 1280×720 preferred Fullscreen | PASS — Fullscreen active; returning to Windowed restored 1280×720 |
| D5 | 1920×1080 preferred Fullscreen | PASS — Fullscreen active; returning to Windowed restored 1920×1080 |
| D6 | 2560×1440 preferred Fullscreen | PASS — Fullscreen active; returning to Windowed restored 2560×1440 |

Restart simulation loaded the persisted 1280×720 Fullscreen configuration into a fresh service instance and passed. The runner then restored 1920×1080 Windowed before exit.

## Main-menu Settings surface

GodotIQ runtime inspection confirmed:

- Settings opens as launcher screen value 2 (Screen.SETTINGS).
- Resolution choices are exactly 1280×720, 1920×1080, and 2560×1440.
- Mode choices are exactly Windowed and Fullscreen.
- Settings panel is centered within the full viewport.
- Resolution and mode controls are 48 pixels high.
- Apply and Back are 140×48 pixels.
- No Settings control was reported as an undersized touch target.
- Applying shows Display settings applied.
- Automated scene input verifies Back discards pending changes.
- Automated scene input distinguishes restored-default load warnings from save failures.

The editor's embedded play surface forces its own physical window size, so physical-size assertions were taken from the separate standalone production-adapter runner rather than the embedded tour.

## Regression coverage

The world-map HUD, battle tooltip, battle skill scene, launcher, and world cutover focused runners all passed. GodotIQ runtime startup reported zero script/runtime errors. The project-wide parser check reported zero errors, and project convention counts remained equal to baseline.
