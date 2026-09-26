# AC9.0 Full Roster Readiness Verification

**Acceptance criterion:** AC9.0

**Owner:** Project Lead — AC9.0 content-readiness delivery owner

**CI job:** `ac9-0-roster-readiness`

**Expected pass condition:** Every named runner exits `0`, 100% of assertions pass, no
`SCRIPT ERROR` or parser error is emitted, all runtime and catalog thresholds pass, and every
required evidence artifact is present.

**Status:** REOPENED — final implementation review found blocking acceptance gaps.

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
| Full AC9.0 job payload | Local execution of `Scripts/CI/run_ac9_0.ps1`, used by `ac9-0-roster-readiness` | Every runner exits `0`; 100% assertions pass; no parser/runtime error | PARTIAL — 38/38 exit `0`, but the gate does not yet reject unexpected `ERROR:` records |
| Faction catalog | Eight catalog/integration runners | Exactly 48 regular classes and 8 commanders; regulars have 3 skills and commanders have 4 | PASS |
| Commander mechanics | Shared-mechanics and seven faction runners plus retained Brakka runner | Deterministic active/passive behavior, targeting, movement, status, guard, logging, and teardown | FAIL — class-sheet behavior coverage and Poison lifecycle remediation required |
| Player selection | Catalog identity and production-launcher UI runners | Exactly Brakka, Goruk, Veyra, Sszek, and Kyris are player-selectable | PASS — exactly 5 |
| Enemy boss parties | Boss catalog plus Human, Elf, and Dwarf integration runners | Authored commander-led parties, not generic debug teams | PASS — 3/3 |
| Identity persistence | `Tests/Save/test_ac9_0_roster_identity_round_trip.gd` | All 56 stable IDs round-trip without identity/root/presentation drift | PARTIAL — identity strings pass; independent root-class proof is missing |
| Regression suite | Named Goblin, AC6, AC8, launcher, UI, and V5 save runners | All retained contracts pass | PASS |

Intentional `push_error` output in AC6.2/AC6.3 negative-construction tests is assertion input,
not an unhandled parser/runtime failure; both runners exit `0` with all assertions passing.

## Acceptance traceability

| Criterion | Verification type | Evidence | Status | Remaining gap |
|---|---|---|---|---|
| Exact approved faction IDs, skill counts, and commanders construct | Automated | `automated-test.log`; faction integration runners | PASS | None |
| Shared mechanics and all commander-specific behaviors resolve deterministically | Automated integration | Shared-mechanics, faction, Brakka, and boss-party runners | FAIL | Poison expiry and placeholder skill behaviors |
| Five monster commanders are selectable; three human-aligned commanders are enemy-only | Automated + rendered UI | Launcher/UI runners; player selector fixtures | PASS | None |
| Human, Elf, and Dwarf bosses use authored commander-led parties | Automated + rendered battle | Boss catalog/faction runners; six boss-party fixtures | PASS | None |
| All 48 class and 8 commander identities survive save/reload | Automated persistence | 56-identity round-trip runner | PARTIAL | Explicit commander root-class round trip |
| Production runtime has no parser/runtime errors or unhandled exceptions | Live runtime | `rendered-qa.log` | PASS | None |
| Required 1152×648 and 1920×1080 surfaces match approved fixtures | Visual inspection | Eight PNG fixtures and SHA-256 manifest in `rendered-qa.log` | PARTIAL | Independent comparison and representative interaction evidence |
| Goblin, AC6, AC8, launcher, and V5 behavior remains green | Regression | 38-runner CI log | PASS | None |
| Habitat, town-placement, and road generation remain out of scope | Scope inspection | AC9.0 commits and design boundary | PASS | None |

## Runtime and visual results

| Surface | Resolutions | Actual result |
|---|---|---|
| Player commander selector | 1152×648, 1920×1080 | PASS — readable carousel/card/skills/seed/actions with no clipping |
| Human boss party | 1152×648, 1920×1080 | PASS — Elian Voss and authored party identities render correctly |
| Elf boss party | 1152×648, 1920×1080 | PASS — Saelith Moonfall and authored party identities render correctly |
| Dwarf boss party | 1152×648, 1920×1080 | PASS — Brokk Stonevein and authored party identities render correctly |
| Debug console | Production launcher runtime | PASS — 0 parser errors, 0 runtime errors, 0 unhandled exceptions |

## Sign-off checklist

- [ ] The `ac9-0-roster-readiness` workflow rejects every unexpected runtime error and its complete payload passes locally.
- [ ] `rendered-qa.log` records every required representative interaction, visual comparison, and debug-console check.
- [ ] All automated runners and every numerical threshold pass with full class-sheet behavior coverage.
- [ ] Exactly 48 regular classes, 8 commanders, and 56 save-safe identities including commander roots are verified.
- [ ] All 8 required images are independently compared at the exact required resolutions.
- [x] No habitat, town-placement, or road-generation work was included.
- [ ] The canonical MVP specification marks only AC9.0 complete and links this evidence.

**Project Lead sign-off:** Pending remediation and a fresh full verification gate.

## Reopened gaps

- Replace remaining generic/placeholder faction skill implementations with their approved class-sheet mechanics and executable tests.
- Apply Poison expiry to production stat reads and round cleanup.
- Represent and verify commander root-class identity independently from commander identity.
- Supply legal authored movement paths to enemy AI actions.
- Tighten the CI/runtime evidence gate and regenerate non-circular interaction/visual evidence.
