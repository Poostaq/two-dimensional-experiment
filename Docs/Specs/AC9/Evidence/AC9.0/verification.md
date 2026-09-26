# AC9.0 Full Roster Readiness Verification

**Acceptance criterion:** AC9.0

**Owner:** Project Lead — AC9.0 content-readiness delivery owner

**CI job:** `ac9-0-roster-readiness`

**Expected pass condition:** All 38 named runners exit `0`; 100% of assertions pass;
unexpected `ERROR:`, `SCRIPT ERROR`, parser errors, and unhandled exceptions are rejected; all
catalog, persistence, runtime, and visual thresholds pass; and every required artifact is present.

**Status:** COMPLETE — all AC9.0 acceptance criteria passed on 2026-09-26.

## Required artifacts

- [x] [`automated-test.log`](automated-test.log)
- [x] [`rendered-qa.log`](rendered-qa.log)
- [x] `verification.md`
- [x] [`player-commander-selector-1152x648.png`](player-commander-selector-1152x648.png)
- [x] [`player-commander-selector-1920x1080.png`](player-commander-selector-1920x1080.png)
- [x] [`human-boss-party-1152x648.png`](human-boss-party-1152x648.png)
- [x] [`human-boss-party-1920x1080.png`](human-boss-party-1920x1080.png)
- [x] [`elf-boss-party-1152x648.png`](elf-boss-party-1152x648.png)
- [x] [`elf-boss-party-1920x1080.png`](elf-boss-party-1920x1080.png)
- [x] [`dwarf-boss-party-1152x648.png`](dwarf-boss-party-1152x648.png)
- [x] [`dwarf-boss-party-1920x1080.png`](dwarf-boss-party-1920x1080.png)

## Automated results

| Check | Verification path | Expected result | Actual result |
|---|---|---|---|
| Full AC9.0 job payload | `Scripts/CI/run_ac9_0.ps1`; CI job `ac9-0-roster-readiness` | Every runner exits `0`; exact diagnostic contract; all artifacts present | PASS — 38/38 runners |
| Shared mechanics | `Tests/Battle/test_ac9_0_shared_mechanics.gd` | Typed authored mechanics, lifecycle, stale/cancel safety | PASS — 75/75 assertions |
| Faction catalogs and mechanics | Seven faction integration runners | Exact IDs/counts/skills, representative behavior, and per-faction save/reload | PASS — 370/370 assertions |
| Commander and boss fixtures | Shared/faction/Brakka/boss-party runners | Eight exact commanders; three authored enemy boss parties | PASS — boss catalog 30/30 plus faction assertions |
| Player selection | Catalog identity and production-launcher runners | Exactly Brakka, Goruk, Veyra, Sszek, and Kyris are selectable | PASS — exactly 5 |
| Identity persistence | `Tests/Save/test_ac9_0_roster_identity_round_trip.gd` | All 56 stable IDs and commander roots round-trip without drift | PASS — 507/507 assertions |
| Regression suite | Named Goblin, AC6, AC8, launcher, UI, and V5 save runners | All retained contracts pass | PASS |

The CI runner permits only seven exact, ordered `ERROR:` records emitted intentionally by the
AC6.2 and AC6.3 negative-construction assertions. Any additional, missing, or changed `ERROR:`
record fails the job. `SCRIPT ERROR`, parser errors, unhandled exceptions, nonzero exits, and
missing evidence artifacts also fail the job.

## Acceptance traceability

| Criterion | Verification type | Evidence | Status |
|---|---|---|---|
| Exact approved faction IDs, skill counts, and commanders construct | Automated | `automated-test.log`; seven faction runners | PASS |
| Shared mechanics and all commander-specific behaviors resolve deterministically | Automated integration | Shared-mechanics, faction, Brakka, and boss-party runners | PASS |
| Five monster commanders are selectable; three human-aligned commanders are enemy-only | Automated + rendered UI | Launcher/UI runners; selector fixtures | PASS |
| Human, Elf, and Dwarf bosses use authored commander-led parties | Automated + rendered battle | Boss catalog/faction runners; six boss-party fixtures | PASS |
| All 48 class and 8 commander identities survive save/reload | Automated persistence | 507-assertion identity round-trip runner | PASS |
| Production runtime has no parser/runtime errors or unhandled exceptions | Live runtime | `rendered-qa.log` | PASS |
| Required 1152×648 and 1920×1080 surfaces match approved fixtures | Independent visual comparison | Eight exact consecutive-capture matches and SHA-256 manifest | PASS |
| Goblin, AC6, AC8, launcher, and V5 behavior remains green | Regression | 38-runner CI log | PASS |
| Habitat, town-placement, and road generation remain out of scope | Scope inspection | AC9.0 commits and design boundary | PASS |

## Numerical thresholds

- **Automated:** PASS — 38/38 runners exited `0`; every reported assertion passed.
- **Catalog:** PASS — exactly 48 regular classes and 8 commanders; regulars have 3 skills and commanders have 4.
- **Persistence:** PASS — all 56 identities, including independent commander root-class IDs, passed 507/507 global round-trip assertions plus seven independent faction-runner round trips.
- **Runtime:** PASS — GodotIQ runtime preflight compiled 264 scripts; the final project gate compiled all 265 scripts with 0 parser errors, 0 runtime errors, and 0 unhandled exceptions.
- **Visual:** PASS — all 8 required PNGs have exact dimensions, passed visual inspection, and matched an independent consecutive capture byte-for-byte.

## Sign-off checklist

- [x] The `ac9-0-roster-readiness` workflow rejects every unexpected diagnostic and its full 38-runner payload passes locally.
- [x] `rendered-qa.log` records the required representative interactions, visual comparison, hashes, and debug-console check.
- [x] All automated runners and every numerical threshold pass with full authored class/commander behavior coverage.
- [x] Exactly 48 regular classes, 8 commanders, and 56 save-safe identities including commander roots are verified.
- [x] All 8 required images are independently compared at the exact required resolutions.
- [x] No habitat, town-placement, or road-generation work was included.
- [x] The canonical MVP specification marks only AC9.0 complete and links this evidence.

**Project Lead sign-off:** AC9.0 accepted — 2026-09-26.

## Remediation closure

- Generic faction skills were replaced by approved authored mechanics and executable tests.
- Poison expiry now affects production stat reads and round cleanup.
- Commander root-class identity is independently represented and round-tripped.
- Enemy AI supplies legal authored movement paths.
- CI rejects unexpected diagnostics, and rendered evidence uses a reproducible independent comparison.
