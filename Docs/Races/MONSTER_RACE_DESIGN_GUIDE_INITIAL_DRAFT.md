# Monster Race Design Guide

## Scope and Authority

This guide identifies the core monster-coalition roster and its balance boundaries. Detailed rules live in:

- `Docs/Mechanics/SkillKeywords.md`
- `Docs/Mechanics/FormationMovement.md`
- `Docs/Mechanics/SkillAuthoringContract.md`
- each race's `Lore.md` and `Classes.md`
- `Docs/Races/RACE_CLASS_SKILL_TRACEABILITY.md`

## Fantasy Pillar

A coordinated warband of dangerous, imperfect species wins through timing, pressure, and role contrast rather than raw stat stacking. Each race solves a different tactical problem while combining cleanly in a six-slot party.

## Core Five

| Race | Mechanical promise | Primary profile | Weakness |
|---|---|---|---|
| Goblins | Create openings that other allies convert | Advantage, sequencing, disruption | Low durability and poor isolated trades |
| Orcs | Break enemy plans after establishing contact | Lane control, bounded Stun, physical pressure | Slow tempo and vulnerability to kiting |
| Werewolves | Punish wounded targets and recover through offense | Leech, execution, Bleed tracking | Weak when denied wounded targets or pursuit |
| Lizardmen | Make enemy actions less effective over time | Single-axis Poison and patient control | Vulnerable before attrition ramps |
| Harpies | Decide who is exposed through formation rotation | Move, isolation, conditional Advantage | Fragile in static or prolonged trades |

## Six Classes Per Race

- **Goblins:** Scrapshield Bruiser, Wirefang Skirmisher, Snarewright, Scrapbroker, Shivrunner, Mobcaller.
- **Orcs:** Iron Tusk Vanguard, Bonebreaker Reaver, Bloodbanner Captain, Chainwarden, War Drummer, Siegebreaker.
- **Werewolves:** Moonfang Skirmisher, Pack Howler, Bloodtrail Stalker, Duskhide Ravager, Den Warden, Moonblood Seer.
- **Lizardmen:** Venom Saurian, Scale Sentinel, Mire Spitter, Fang Alchemist, Reed Ambusher, Sunscale Warder.
- **Harpies:** Talon Duelist, Storm Siren, Gale Scout, Skyhook Raider, Nestguard, Carrion Cantor.

No two classes within a race share the same `(primary job, tactical rhythm, signature mechanic)` combination.

## Race Stat Bands

| Race | Health | Power | Speed | Defense |
|---|---:|---:|---:|---:|
| Goblins | 12-20 | 3-7 | 7-10 | 0-2 |
| Orcs | 24-30 | 4-8 | 2-5 | 2-5 |
| Werewolves | 16-24 | 6-9 | 6-9 | 0-2 |
| Lizardmen | 18-26 | 4-7 | 3-6 | 1-3 |
| Harpies | 12-20 | 5-8 | 7-10 | 0-1 |

Race class documents assign exact templates inside these bands. A defensive Goblin remains durable for a Goblin and does not reach Orc durability.

## Global Guardrails

1. At least four Goblin kits use sequencing or coalition setup; no other race exceeds two.
2. Goblins grant Advantage through initiative and ally order. Harpies grant it only after successful movement, exposure, or isolation.
3. Stun is single-target, guarded against repetition, and available to no more than two Orc classes.
4. Every Poison skill declares exactly one weakened axis.
5. Leech is offense-dependent recovery and does not replace dedicated protection.
6. Bleed remains shared physical pressure, not a complete race identity.
7. Formation movement follows the six-slot ring and atomic occupied-path rotation.

## Coalition Examples

1. Goblin setup into Orc contact payoff.
2. Goblin sequencing into Werewolf execution.
3. Lizardman erosion into Orc or Werewolf conversion.
4. Harpy rotation into Orc lockdown.
5. Harpy isolation into Goblin or Werewolf follow-up.

## Progression

Every class uses the common three-tier ladder and exactly four class skills defined in `SkillAuthoringContract.md`: Tier 1 Opener and Converter, Tier 2 mutually exclusive Passive style, and Tier 3 Pivot plus coalition upgrade.

## Acceptance Criteria

1. Each race has one complete identity dossier with lore hook, visual read, and mechanical promise.
2. Each race has exactly six implementation-target classes with distinct combat jobs.
3. Each class has exactly four skills with explicit trigger, duration, stack/refresh, cooldown, failure, tooltip, log, AI, and counterplay rules.
4. Keyword usage follows the canonical race profiles and is readable in logs and tooltips.
5. All class stats remain inside their race bands and support their roles.
6. Each race documents at least three positive synergy pairings and two counterplay cases.
7. Goblins remain unique as tempo/disruption coalition glue under the quantitative guardrails.

## Alternate Race Concepts

Minotaurs, Insectoids, Naga, Demonkin, and Ratkin remain possible future races. They receive no reserved keyword until a later design establishes a distinct mechanic that does not duplicate the core five.

