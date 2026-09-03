# AC6.7 Production Goblin Integration Evidence

Date: 2026-09-03

Branch: `feat/ac6-7-goblin-integration`

Implementation commit: `f35c5025006255357b821c60882a75214cf2fd92`
Seed: `ac6-7-integration`

## Result

PASS. The production world scene restores regular Goblin formation IDs, all six regular catalogs carry Goblin identity and three authored skills, Brakka retains her three-plus-one loadout, and the complete battle/reward/reload/next-battle path passes 104/104 assertions twice deterministically.

## Production-path walkthrough

The waited `Tests/WorldMap/test_ac6_7_goblin_integration.gd` runner instantiates `Scenes/world_map_runtime.tscn` and uses the production controller, arena, reward, party-management, run-state, and persistence boundaries.

| Checkpoint | Observed result | Status |
|---|---|---|
| Catalog | Six regular class IDs resolve in canonical order; each has `race_id=goblin` and three skills; Brakka has Banner Holder as skill four. | PASS |
| Battle one | Six-member Goblin formation restores through the production controller; Brakka occupies slot 1. | PASS |
| Real interaction | A real enemy is previewed/confirmed as an attack target; a legal formation path commits; action history and battle records update. | PASS |
| Brakka | Advancing through real turn order triggers Banner Holder and its authored production log. | PASS |
| Reward | Combat victory exposes three production rewards; Recruit Scout opens full-roster replacement and persists `scout`. | PASS |
| Formation | Ordinary party management rearranges the post-reward mixed party without consuming a world move. | PASS |
| Save/reload | Exact formation and Cache readiness survive reconstruction from the durable run state. | PASS |
| Preparation | Second Combat starts locked; Spare Plating commits durably, consumes Cache once, and grants +2 Armor only to active player frontline slots. | PASS |
| Fresh battle | Round is 1; HP and Speed match persistent definitions; action/history/cooldown/Bleed/Snared state is empty; no prior temporary Armor leaks. | PASS |
| Passive cleanup | Brakka's round-one Banner Holder guard is fresh and triggers again in battle two. | PASS |

## Aggregate verification

- Focused AC6 runners: 9/9 PASS.
- Retained suite: 61/61 PASS; zero failed or missing PASS runners.
- Deterministic AC6.7 rerun: 104/104 PASS, exit 0.
- GodotIQ project parse: 145 scripts, zero errors.
- GodotIQ signal audit: zero orphan signals. Reported missing built-in UI signals are test emissions, not project-defined signal orphans.
- GodotIQ production startup: PASS with zero captured runtime or script errors; Play stopped normally.
- GodotIQ project conventions: zero errors, 26 pre-existing warnings, and 6 informational findings.

## RED-to-GREEN record

The initial runner failed because Wave A characters had no Goblin race identity and `WorldRuntimeController._restore_roster()` did not include regular Goblin catalogs. The minimal production fix adds Wave A race identity, exposes one canonical six-class ID list from `RunCharacterCatalog`, and uses it during roster restoration. A subsequent RED parse proved the new catalog API was absent before implementation.

## Progression exclusion

Repository search found no Goblin leveling, evolution, or mechanical-upgrade implementation in `Scripts`, `Scenes`, or `Tests`. `Docs/TO_CONSIDER.md`, `Docs/Races/Goblins/Classes.md`, and `Docs/Races/Goblins/Commanders.md` explicitly retain leveling, XP, specialization, tier upgrade, evolution, and mechanical progression as deferred work.

## Conclusion

AC6.7 and AC6-AC01 through AC6-AC11 are evidenced. The aggregate AC6 Goblin Combat Vertical Slice milestone is complete. No progression system, equipment work, encounter-generation change, movement-count change, boss rule change, or reveal-authority change was added.
