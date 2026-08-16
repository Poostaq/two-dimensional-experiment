# Race-Class-Skill Implementation Readiness

## Scope

This matrix verifies documentary readiness for the five core races, 30 implementation-target classes, and 120 class skills. `Complete` means the desired behavior is sufficiently specified for implementation planning; it does not claim the current runtime already supports the mechanic.

## Acceptance Matrix

| ID | Requirement | Authoritative evidence | Verification | Status |
|---|---|---|---|---|
| RD-1 | Each race has lore hook, visual read, and mechanical promise | `Docs/Races/*/Lore.md` | Five race directories each contain one `Lore.md` with all three named sections | Complete |
| RD-2 | Each race has exactly six distinct classes | `Docs/Races/*/Classes.md` | Five files each contain six numbered class headings; uniqueness summaries identify different jobs and signature mechanics | Complete |
| RD-3 | Each class has exactly four authored skills | All five `Classes.md`; `Docs/Mechanics/SkillAuthoringContract.md` | Each class file contains 24 Active/Passive skill rows; total is 120 | Complete |
| RD-3A | Skills specify trigger, duration, stacks/refresh, cooldown, failure, UI, AI, and counterplay | Class-file inheritance preambles and every skill row | Shared defaults explicitly set unlisted fields to `None`; every row states record, effect/lifecycle, failure/AI/counterplay, tooltip, and log | Complete |
| RD-4 | Keyword usage is race-consistent and readable | `Docs/Mechanics/SkillKeywords.md`; race profiles and skill rows | Five canonical headings; tooltip/log patterns; assigned race profiles; class wording references canonical behavior | Complete |
| RD-5 | Stats stay inside race ranges and support roles | Baseline guide stat bands and 30 class headers | Automated range audit plus class role/weakness review | Complete |
| RD-6 | Three synergies and two counters per race | Five `Lore.md` files | Every file contains three numbered positive synergies and two numbered counterplay cases | Complete |
| RD-7 | Goblins remain unique tempo/disruption glue | Goblin identity safeguard, guide guardrails, all role summaries | At least four Goblin kits use sequencing/setup; non-Goblin setup is gated by race identity and no other race exceeds two coalition-setup kits | Complete |
| RD-8 | Removed keyword is absent from canonical mechanics, race profiles, and skills | `Docs/Mechanics`; `Docs/Races` | Case-insensitive canonical scan returns no matches | Complete |
| RD-9 | Formation movement matches the approved occupied-slot behavior | `Docs/Mechanics/FormationMovement.md`; Harpy skill rows | Ring order, Move 1-3, equal-path choice, both opposite-corner examples, atomic path rotation, and explicit swaps are specified | Complete |

## Roster Count Evidence

| Race | Classes | Skills | Stat band source |
|---|---:|---:|---|
| Goblins | 6 | 24 | Guide: HP 12-20, Power 3-7, Speed 7-10, Defense 0-2 |
| Orcs | 6 | 24 | Guide: HP 24-30, Power 4-8, Speed 2-5, Defense 2-5 |
| Werewolves | 6 | 24 | Guide: HP 16-24, Power 6-9, Speed 6-9, Defense 0-2 |
| Lizardmen | 6 | 24 | Guide: HP 18-26, Power 4-7, Speed 3-6, Defense 1-3 |
| Harpies | 6 | 24 | Guide: HP 12-20, Power 5-8, Speed 7-10, Defense 0-1 |
| **Total** | **30** | **120** | All exact templates are inside their race band |

## Identity Separation

| Race | Owned design space | Explicit exclusions |
|---|---|---|
| Goblins | Early sequencing, broadly accessible Advantage, coalition action order | Movement cannot isolate better than Harpies; low fair-trade power |
| Orcs | Contact, Guard, anti-movement, specialist Stun | No broad initiative theft; no routine multi-target Stun |
| Werewolves | Wounded thresholds, pursuit, direct-damage Leech | No conventional healer; status damage cannot Leech |
| Lizardmen | Long attrition and one-axis Poison planning | One skill cannot weaken several axes; axes never merge |
| Harpies | Move 2-3 rotation, changed neighbors, exposure/isolation | Advantage requires successful hostile movement or isolation |

Bleed remains shared physical pressure and is not sufficient to define any race.

## Current Runtime Evidence

GodotIQ inspection of `CharacterSkill`, `BattleSkillRules`, and `BattleUnitState`, together with `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`, confirms current support for:

- a maximum of four character skills;
- Active and Passive skill kinds;
- direct damage and temporary Speed effects;
- free and predefined targeting;
- front/back and health requirements;
- post-use action cooldown and round-gate cooldown;
- atomic confirmation, generic combo data, action history, and unresolved Speed queue rebuilding.

## Implementation Dependencies

The design is ready for implementation planning, but runtime work must add:

1. Power and Defense fields and the approved damage formula.
2. Direct healing and actual-damage-based Leech.
3. Typed status ownership, snapshots, caps, refresh, expiry, and battle cleanup.
4. Bleed, Poison, Stun, Stun Guard, and Advantage behavior.
5. Six-slot ring path calculation, selected direction, atomic occupied-path rotation, and two-unit swap distinction.
6. Guard, shields, Cleanse, Exposed, Isolated, movement lock, marks, and temporary Power/Defense changes.
7. Passive trigger ordering and recursion guards.
8. Status-aware previews, tooltip generation, combat logs, AI eligibility, save boundaries, and tests.

These are declared dependencies, not hidden assumptions or claims about current behavior.

## Future Verification Contract

Implementation tests must cover:

- apply, cap, reapply, expire, Cleanse, source defeat, target defeat, and battle teardown for every status;
- no mutation on preview, cancellation, rejection, stale confirmation, or invalid path;
- clockwise and counterclockwise Move 1-3, both Move 3 paths, partial occupancy, full occupancy, defeat-created empty slots, and exact shift order;
- exact tooltip and log snapshots for every effect family;
- Stun Guard and boss resistance;
- Advantage eligibility, refresh, expiry, consumption, and non-consumption by defaults;
- Leech exclusions for overkill and non-direct damage;
- Poison axis separation, floors, queue rebuild, and source snapshots;
- Passive once guards and recursion prevention;
- all 30 templates and 120 skills loading into four-slot character definitions.

