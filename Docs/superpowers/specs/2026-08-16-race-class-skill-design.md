# Race, Class, and Skill Design

**Status:** Approved for documentation

## Goal

Make the five-race monster coalition ready for implementation by defining one readable identity per race, exactly six distinct classes per race, four skills per class, deterministic shared mechanics, explicit stat templates, and traceable synergy and counterplay.

The design is based on `Docs/Races/MONSTER_RACE_DESIGN_GUIDE_INITIAL_DRAFT.md`. Ignite is removed without replacement because it does not yet have a sufficiently distinct mechanical identity.

## Documentation Architecture

- `Docs/Mechanics/SkillKeywords.md` is the canonical source for Bleed, Poison, Stun, Advantage, and Leech.
- `Docs/Mechanics/FormationMovement.md` defines the six-slot ring, movement ranges, path selection, and atomic character shifting.
- `Docs/Mechanics/SkillAuthoringContract.md` defines the four-skill package, required skill fields, timing language, progression, formulas, and lifecycle rules.
- `Docs/Races/<Race>/Lore.md` owns the race fantasy, visual read, culture, mechanical promise, strengths, weaknesses, synergies, and counterplay.
- `Docs/Races/<Race>/Classes.md` owns exactly six class records, exact stats, tactical rhythm, and four implementation-target skills per class.
- `Docs/Races/RACE_CLASS_SKILL_TRACEABILITY.md` maps every readiness criterion to its documentary evidence.

Shared rules are referenced from race documents instead of being redefined in them.

## Roster

| Race | Identity | Six classes |
|---|---|---|
| Goblins | Tempo, disruption, and coalition sequencing | Scrapshield Bruiser, Wirefang Skirmisher, Snarewright, Scrapbroker, Shivrunner, Mobcaller |
| Orcs | Contact, lane dominance, and bounded interruption | Iron Tusk Vanguard, Bonebreaker Reaver, Bloodbanner Captain, Chainwarden, War Drummer, Siegebreaker |
| Werewolves | Wounded-target hunting and aggressive recovery | Moonfang Skirmisher, Pack Howler, Bloodtrail Stalker, Duskhide Ravager, Den Warden, Moonblood Seer |
| Lizardmen | Patient attrition and single-axis toxin planning | Venom Saurian, Scale Sentinel, Mire Spitter, Fang Alchemist, Reed Ambusher, Sunscale Warder |
| Harpies | Exposure, isolation, and formation disruption | Talon Duelist, Storm Siren, Gale Scout, Skyhook Raider, Nestguard, Carrion Cantor |

No two classes within one race may share the same combination of primary job, tactical rhythm, and signature mechanic.

## Skill and Progression Contract

Every class has exactly four character-specific skills: three Active skills and one Passive skill. The three actives fill Opener, Converter, and Pivot roles. The passive is the class's signature sequencing or role reward. Offense, control, mobility, support, utility, reaction, and capstone remain design tags rather than new engine-level skill kinds.

Progression uses three tiers:

1. Tier 1 unlocks the Opener and Converter so the class identity works immediately.
2. Tier 2 selects one of two mutually exclusive passive variants, aggressive or protective. The selection is reversible between battles.
3. Tier 3 unlocks the Pivot and one cross-race upgrade to an existing skill.

No new mana or race-specific resource system is part of the initial roster. Cooldowns, position, health thresholds, statuses, and party sequencing provide the action economy.

## Canonical Mechanics

- **Bleed:** Triggers after the affected unit commits an action, lasts two affected-unit actions by default, has a maximum of three stacks, and gains one stack plus refreshed duration when reapplied.
- **Poison:** Triggers at round end, lasts three rounds by default, has a maximum of three stacks, and reduces exactly one declared axis: Power, Defense, or Speed.
- **Stun:** Skips the next eligible action, cannot stack or refresh, and grants Stun Guard until the target completes its next action. A class has at most one single-target Stun skill with cooldown 4-5 and another requirement.
- **Advantage:** A non-stacking token on an ally. Its next eligible Active skill consumes the token to activate that skill's authored Advantage rider. It expires at round end. Default Attack and Swap do not consume it.
- **Leech:** Restores 25-40% of actual direct HP damage after Defense, excluding overkill and status, reflected, or counter damage. Healing cannot exceed missing HP.

All combat statuses clear at battle end. Previewed, cancelled, rejected, or stale actions never mutate statuses, movement, cooldowns, or Advantage.

## Formation Movement

The six slots form a ring:

```text
Back top     1 ----- 6  Front top
             |       |
Back middle  2       5  Front middle
             |       |
Back bottom  3 ----- 4  Front bottom
```

- Move 1 reaches either neighboring ring slot.
- Move 2 reaches a slot two ring steps away.
- Move 3 reaches any slot because the maximum ring distance is three.
- Moving to an occupied slot rotates every character along the chosen path one slot toward the mover's origin; the mover takes the destination.
- At distance three, the player selects either equal path, determining which three occupants shift.
- The complete rotation validates and resolves atomically. A failed path causes no movement, secondary effect, status, or cooldown change.
- A skill that explicitly says `swap` exchanges only two characters and does not rotate the path.

Every movement skill declares the moving side, maximum range, path ownership, and whether it moves the user, an ally, or an enemy.

## Combat Resolution and Formulas

Direct physical damage is `max(1, ceil(Power * skill multiplier) - effective Defense)`. Effective Power and Speed have a floor of 1; effective Defense has a floor of 0. Healing is capped at missing HP.

Resolution order is fresh validation, target and path lock, direct damage, movement or Guard, status application, Leech or healing, cooldown application, authoritative log/history commit, defeat/result evaluation, action advancement, then applicable status ticks.

Durations never use bare `turn`. Skill text uses `committed action`, `next eligible action`, or `round`.

## Identity Safeguards

- At least four Goblin kits include sequencing or coalition setup; no other race may exceed two.
- Goblins create Advantage through initiative, cheap tricks, and ally order.
- Harpies create Advantage only after a successful formation change, exposure, or isolation.
- Harpies own displacement quality; Goblin movement primarily improves sequencing.
- Orcs own reliable contact control, with Stun limited to no more than two classes.
- Werewolves own Leech as a primary racial mechanic.
- Lizardmen own Poison; each Poison skill names one weakened stat axis.
- Bleed is shared physical pressure and cannot serve as a race's sole identity.

## Current Implementation Boundary

The current runtime supports four character skills, Active and Passive kinds, damage, temporary Speed boosts, positional and health requirements, cooldowns, atomic confirmation, generic combos, action history, and unresolved-queue rebuilding.

Implementation still requires typed support for Power and Defense resolution, healing and Leech, general status ownership and lifecycle, Bleed, Poison, Stun, Advantage, forced movement and path rotation, Guard, cleanse, passive trigger ordering and recursion guards, and status-aware previews, tooltips, logs, and AI validation.

## Acceptance Criteria

1. Each of the five races has a complete identity dossier containing its lore hook, visual read, and mechanical promise.
2. Each race has exactly six implementation-target classes with distinct combat jobs.
3. Each class has exactly four skills with explicit trigger, duration, stack or refresh behavior, cooldown, failure behavior, tooltip, log text, and counterplay.
4. Keyword use follows the canonical race profiles and remains readable in tooltips and combat logs.
5. All 30 class stat templates remain inside their race bands and support their declared roles.
6. Each race documents at least three positive synergy pairings and two counterplay cases.
7. Goblins remain the unique tempo/disruption coalition glue according to the quantitative identity safeguards.
8. Canonical mechanics, race profiles, and class skills contain no Ignite keyword, profile assignment, or authored effect; historical design-decision records may state that it was removed.
9. A traceability matrix identifies the authoritative document and future automated or runtime evidence for every criterion.
