# AC9.1 verification

Verified 2026-09-27 on `feat/ac9-1-clan-selection-and-direct-start`.

- `RunCharacterCatalog` exposes the five player clans in stable order and filters each to its owning commander.
- `RunClanSelection` rejects empty, unknown, and cross-clan pairs before world generation.
- Runtime inspection selected all five clans and resolved the expected owning commander for each.
- A generated Orc/Goruk run encoded and decoded through `WorldRunSaveCodecV6` as `orc:goruk_ironline`.
- A V5 run decoded through the V6 fallback chain successfully.
- `WorldProductionLauncher` bypasses the overwrite-confirmation state and uses the existing atomic repository replacement path; duplicate Start requests are rejected while the request guard is active.
- `verify_project_runs` passed: 269 scripts parsed, the main launcher started with a runtime attachment, and the debug console contained zero errors.

AC9.2 and later criteria are not included in this verification.
