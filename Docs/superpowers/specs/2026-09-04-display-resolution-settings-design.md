# Display Resolution Settings Design

## Goal

Add a settings screen accessible from the main menu that lets the player choose one of three supported 16:9 resolutions and switch between windowed and fullscreen display modes. Applied settings persist across restarts. A first launch or invalid settings file falls back to 1920×1080 Windowed.

## Scope

The supported resolutions are exactly:

- 1280×720
- 1920×1080
- 2560×1440

The supported display modes are exactly Windowed and Fullscreen. Borderless windowed, exclusive fullscreen, arbitrary resolutions, refresh-rate selection, monitor selection, render-scale controls, and graphics-quality settings are outside this change.

## Architecture

A focused display-settings service owns the supported values, validation, persistence, and interaction with Godot's `DisplayServer`. It is a regular project class rather than an autoload: the launcher creates it during startup, loads and applies the persisted configuration, and passes user selections to it when Apply is pressed. This keeps platform and persistence logic out of the already large launcher UI controller while avoiding unnecessary global state.

The existing `world_run_start.tscn` remains the main-menu scene and gains a scene-native Settings screen. Anchors, containers, minimum sizes, and theme overrides own the visual layout. The launcher script owns screen navigation and delegates display behavior to the service.

The launcher's `Screen` enum expands from `MAIN`, `NEW_RUN`, and `OVERWRITE_CONFIRM` to include `SETTINGS`. Opening Settings records the current non-modal screen in `_settings_return_screen` before transitioning. Back discards pending UI values and returns to that recorded screen. Settings is initially reachable only from `MAIN`, so normal Back behavior returns to `MAIN`; the recorded state keeps navigation explicit and prevents a future entry point from silently returning to the wrong screen. The overwrite confirmation remains a modal state and cannot open Settings.

## Service API and Platform Boundary

The service presents a small deterministic API:

- `get_supported_resolutions() -> Array[Vector2i]` returns a defensive copy in selector order.
- `get_supported_modes() -> Array[int]` returns the two service mode values in selector order.
- `load_and_apply() -> Dictionary` returns the committed configuration plus an explicit load status.
- `get_committed_config() -> Dictionary` returns a defensive copy of the currently committed resolution and mode.
- `apply_and_save(resolution: Vector2i, mode: int) -> Dictionary` validates and applies the complete selection, attempts one save, and returns explicit apply and save outcomes.

The service never lets UI code call `DisplayServer`. It receives a narrow display adapter with operations to read the current mode, set Windowed or Fullscreen mode, and set the window size. Production uses a `DisplayServer` adapter; tests use a fake that records ordered calls. The settings path is also injectable for tests, allowing deterministic temporary-file persistence tests without touching a player's real `user://` data.

## Settings Model and Persistence

The service exposes immutable supported-resolution data and a small typed display configuration containing a `Vector2i` resolution and a display-mode enum. The canonical first-launch defaults are 1920×1080 and Windowed.

The service's committed configuration is the authoritative location for the preferred window size. Its resolution remains populated in both Windowed and Fullscreen modes and is persisted alongside the mode. Entering Fullscreen does not replace it with the monitor's fullscreen dimensions. Returning to Windowed first changes the OS mode to Windowed and then applies the committed resolution through the display adapter. This ordering avoids asking the platform to resize a fullscreen surface and makes restoration directly observable in tests.

Settings are stored in a dedicated `ConfigFile` under `user://`. The stored representation contains explicit width, height, and mode values. Loading accepts only exact supported resolution pairs and known mode values. A missing file, unreadable file, missing key, partial value, unsupported resolution, or unknown mode produces the complete canonical default instead of partially applying corrupt data.

Apply performs the following transaction:

1. Validate the pending resolution and display mode.
2. If entering Fullscreen, retain the selected resolution as the committed preferred window size and then change the OS mode to Fullscreen.
3. If entering Windowed, change the OS mode to Windowed and then set the window to the selected resolution.
4. Persist the validated configuration.
5. Update the settings screen's committed state.

If persistence fails, the UI displays a non-blocking save error and retains the applied runtime values as the service's committed configuration so the player can retry Apply. The settings file is never written when the player presses Back without applying.

## Display Behavior

In Windowed mode, the game window uses the chosen pixel dimensions. In Fullscreen mode, the operating system controls the physical fullscreen surface while the service retains the selected resolution in its committed configuration. Returning to Windowed changes mode first and then restores that exact committed size.

At application startup, the launcher loads and applies saved display settings before the main menu becomes interactive. Project defaults in `project.godot` are set to 1920×1080 Windowed so startup is correct even before user persistence is available. The existing `canvas_items` stretch mode and `expand` aspect policy remain in place, allowing the UI and viewport to expand across all three 16:9 sizes.

## Main-Menu User Experience

The main screen gains a Settings button alongside Continue, Start New Run, and Exit. Activating it opens a dedicated Settings screen in the same root scene.

The Settings screen contains:

- a resolution selector showing `1280 × 720`, `1920 × 1080`, and `2560 × 1440`;
- a display-mode selector showing `Windowed` and `Fullscreen`;
- an Apply button;
- a Back button;
- a compact status/error label for Apply or persistence feedback.

Opening Settings initializes both selectors from the currently committed configuration. Changing a selector only changes pending UI state. Apply validates, applies, and persists both fields together. Back discards pending edits and returns to the recorded prior screen (`MAIN` for the current entry point). Reopening Settings therefore shows the last applied values.

Keyboard focus and controller navigation follow the visual order: resolution, display mode, Apply, Back. The Settings screen uses containers and centered bounded content so it remains readable at the smallest supported size, 1280×720.

## Error Handling

- Invalid or incomplete persisted data falls back to the complete 1920×1080 Windowed default.
- Unsupported values cannot be emitted by the selectors and are rejected again at the service boundary.
- A missing settings file is a normal first-launch condition and produces no error message.
- A malformed, unreadable, or invalid existing settings file does not block the main menu. The service applies defaults and returns a load-warning status. When Settings is next opened, the status label reports that defaults were restored; opening or editing selectors does not clear it.
- A successful Apply clears any prior load warning and shows a short success state.
- A settings-save failure replaces other status text with a save-specific error on the Settings screen and can be retried. It is never described as a load failure.
- Display application is guarded so tests can substitute a fake display adapter and avoid changing the test runner's real window.

## Testing and Verification

Automated tests cover:

- exact supported-resolution and display-mode catalogs;
- 1920×1080 Windowed first-launch defaults;
- valid save/load round trips;
- missing, partial, malformed, and unsupported persisted values falling back to the complete default;
- Apply validating and sending the expected calls through a fake display adapter;
- fullscreen retaining the chosen preferred window size in committed state and persistence;
- returning to Windowed ordering the fake-adapter calls as mode change followed by exact size restoration;
- the main menu opening Settings;
- the launcher entering `Screen.SETTINGS`, remembering its return screen, and Back restoring that screen;
- Apply committing both selectors and persisting once;
- Back discarding pending changes and performing no write;
- reopening Settings reflecting the last applied state;
- missing-file startup producing no warning, invalid-file startup producing a load warning, successful Apply clearing it, and save failure producing a distinct save error;
- required controls fitting inside a 1280×720 viewport.

Runtime verification exercises all six resolution/mode combinations, switches back from Fullscreen to Windowed, restarts after applying a non-default choice, confirms persistence, and checks the main menu, Settings screen, New Run screen, world HUD, overlays, and battle UI for clipping or overlap. GodotIQ project validation, parser/error checks, orphan-signal inspection, runtime startup verification, debugger inspection, and a visual tour at each supported windowed resolution form the completion gate.

## Acceptance Criteria

1. Settings is accessible from the main menu without starting or loading a run.
2. The resolution selector offers only 1280×720, 1920×1080, and 2560×1440.
3. The mode selector offers only Windowed and Fullscreen.
4. First launch defaults to 1920×1080 Windowed.
5. Selector changes do not affect the display until Apply is pressed.
6. Apply changes both settings together and persists them across restarts.
7. Back without Apply discards pending changes.
8. Returning from Fullscreen to Windowed restores the selected window size.
9. Missing or invalid persisted settings safely restore the complete default.
10. All main gameplay and menu surfaces remain usable without clipping or overlap at every supported resolution.
11. Display behavior is accessed through the service's injectable adapter; the launcher and Settings UI never call OS display APIs directly.
