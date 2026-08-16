# Skill Authoring Contract

## Character Loadout

Every implementation-target class has exactly four character-specific skills plus Default Attack and Default Swap:

1. **Opener (Active):** Establishes the class condition, position, status, or setup.
2. **Converter (Active):** Exploits the opener or compatible ally setup.
3. **Pivot (Active):** Provides defense, movement, support, recovery, or a high-cooldown capstone.
4. **Signature Passive:** Rewards the intended sequencing or party job.

Offense, control, mobility, support, utility, reaction, and capstone are design tags. Runtime kinds remain Active and Passive.

## Required Skill Record

Every skill states stable ID and name; kind and package slot; tags; target and selection; position and condition requirements; trigger; ordered effects; magnitude or Power multiplier and rounding; duration; stack cap; reapplication; cleanup; pre-use or post-use cooldown; failure behavior; Advantage interaction; movement semantics; tooltip; log text; AI condition; and counterplay. Use `None` when a field does not apply; omission is invalid.

## Standard Formulas

- Direct physical damage: `max(1, ceil(Power * multiplier) - effective Defense)`.
- Direct healing: `min(missing HP, ceil(Power * multiplier))`.
- Temporary stat change: flat integer; Power and Speed floor at 1, Defense floor at 0.
- Leech, Bleed, and Poison use `SkillKeywords.md`.
- Damage and healing round up unless a keyword explicitly uses `floor`.

Recommended damage multipliers are 0.6-0.9 for setup attacks, 1.0-1.3 for ordinary attacks, 1.4-1.7 for conditional converters, and 1.8-2.2 for cooldown 4-5 capstones with a real requirement.

## Cooldown Bands

- Opener: 0-1 successful owning-side actions after use.
- Converter: 1-2 successful owning-side actions after use.
- Utility/support Pivot: 2-3 successful owning-side actions after use.
- Capstone Pivot: 4-5 successful owning-side actions after use.
- Stun: 4-5 successful owning-side actions after use plus another requirement.

A new cooldown does not decrement during its creating action. Skipped, previewed, cancelled, rejected, and stale actions do not decrement cooldowns.

## Timing and Resolution

Never use bare `turn` for duration. Use `committed action`, `next eligible action`, or `round`.

Resolution order is: revalidate; lock targets and path; direct damage; movement/Guard; statuses and temporary stats; Leech/healing; new cooldown; authoritative log/history; defeat/result; queue advance/rebuild; declared action or round ticks and later cooldown decrements.

An invalid operation rejects the whole skill before damage. There is no partial success unless the skill explicitly defines independent target resolution and preview shows it.

## Passive Safety

- Every Passive declares a trigger and once-per-action, once-per-round, or once-per-battle guard.
- A Passive cannot trigger itself.
- Passive chains stop after one authored downstream reaction unless both definitions name the interaction.
- Follow-ups, counters, status ticks, and reflection are not committed Active skills unless stated.
- Passive effects join the triggering history or create one typed reaction entry; they never mutate invisibly.

## Guard and Cleanse

- **Guard:** Redirects the next direct hostile hit against one declared ring-neighbor ally to the guarding unit, then expires. It excludes area damage, Bleed, Poison, reflection, and already committed damage.
- **Cleanse:** Removes one declared cleansable negative status. The skill states player selection or oldest-first removal. Stun Guard is not negative and cannot be cleansed.

Guard and Cleanse are effect families, not shared keywords.

## Progression

1. Tier 1 unlocks Opener and Converter.
2. Tier 2 selects one of two mutually exclusive Signature Passive variants, aggressive or protective; selection is reversible between battles.
3. Tier 3 unlocks Pivot and one cross-race upgrade to an existing skill.

Tier upgrades add no skill slots. The initial roster uses no mana or race-specific meter.

## Implementation Boundary

Current runtime support includes four-skill rosters, Active/Passive kinds, damage, Speed boosts, positional and health requirements, cooldowns, atomic confirmation, generic combos, history, and unresolved-queue rebuilding.

Dependencies still needed are Power/Defense resolution, healing, general statuses, Bleed, Poison, Stun, Advantage, Leech, ring rotation, Guard, Cleanse, passive ordering, and status-aware preview, tooltip, log, and AI rules. Class documents describe desired behavior and do not imply these already exist.

