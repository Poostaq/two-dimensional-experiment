# AC9.0 Full Roster Readiness Verification

**Acceptance criterion:** AC9.0

**Owner:** Project Lead — AC9.0 content-readiness delivery owner

**CI job:** `ac9-0-roster-readiness`

**Status:** Not run

## Required artifacts

- [ ] `automated-test.log` — complete output of the required CI job and every named headless runner; exit status `0` and 100% passing assertions are required.
- [ ] `rendered-qa.log` — GodotIQ runtime, debug-console, visual-fixture, and resolution-review transcript.
- [ ] `verification.md` — this signed summary.
- [ ] `player-commander-selector-1152x648.png`
- [ ] `player-commander-selector-1920x1080.png`
- [ ] `human-boss-party-1152x648.png`
- [ ] `human-boss-party-1920x1080.png`
- [ ] `elf-boss-party-1152x648.png`
- [ ] `elf-boss-party-1920x1080.png`
- [ ] `dwarf-boss-party-1152x648.png`
- [ ] `dwarf-boss-party-1920x1080.png`

## Automated results

| Check | Command / CI step | Expected result | Actual result |
|---|---|---|---|
| Full AC9.0 job | `ac9-0-roster-readiness` | All runners exit `0`; 100% assertions pass; no `SCRIPT ERROR` | Not run |
| Faction catalog count | Catalog integration runners | 48 regular classes and 8 commanders construct exactly once | Not run |
| Identity persistence | Save/reload runners | All 56 stable IDs round-trip without drift | Not run |
| Regression suite | Goblin, AC6, AC8 runners | All selected regressions pass | Not run |

## Runtime and visual results

| Surface | Resolutions | Expected result | Actual result |
|---|---|---|---|
| Player commander selector | 1152×648, 1920×1080 | Five selectable monster commanders are readable and correctly identified | Not run |
| Human boss party | 1152×648, 1920×1080 | Elian Voss and class identities render correctly | Not run |
| Elf boss party | 1152×648, 1920×1080 | Saelith Moonfall and class identities render correctly | Not run |
| Dwarf boss party | 1152×648, 1920×1080 | Brokk Stonevein and class identities render correctly | Not run |
| Debug console | Representative faction scenarios | 0 parser errors, 0 runtime errors, 0 unhandled exceptions | Not run |

## Sign-off checklist

- [ ] `automated-test.log` is present and meets the CI pass condition.
- [ ] `rendered-qa.log` is present and records all required visual surfaces and debug-console checks.
- [ ] Every threshold in the AC9.0 design specification is met.
- [ ] No habitat, town-placement, or road-generation work was included in this acceptance.
- [ ] Project Lead has approved AC9.0 completion and the canonical MVP specification has been updated.

**Project Lead sign-off:** Pending
