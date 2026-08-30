# Skill Authoring Contract

## Character Loadout

Every implementation-target regular class has exactly three character-specific battle skills plus Default Attack and Default Swap:

1. **Opener (Active):** Establishes the class condition, position, status, or setup.
2. **Converter (Active):** Exploits the opener or a canonical keyword applied by an ally.
3. **Pivot (Active):** Provides Armor, movement, keyword support, or a high-cooldown capstone.

A commander keeps all three skills of its root class and adds exactly one commander-specific fourth skill. The commander skill may be Active or Passive. It does not replace a root-class skill.

Offense, control, mobility, support, utility, reaction, and capstone are design tags. Runtime kinds remain Active and Passive.

## Required Skill Record

Every skill states stable ID and name; kind and package slot; tags; target and selection; position and condition requirements; trigger; ordered effects; magnitude or Power multiplier and rounding; duration; stack cap; reapplication; cleanup; pre-use or post-use cooldown; Advantage interaction; movement semantics; tooltip; log text; AI condition; and counterplay. Use `None` when a field does not apply; omission is invalid.

Allowed effects are direct damage, canonical formation movement, cooldown changes, authored temporary stat modifiers, and Armor, Bleed, Poison, Stun, Advantage, Snared, or Leech. A class skill cannot introduce another named combat state. Any temporary stat modifier must name its magnitude, expiry, reapplication behavior, floor, and unresolved-queue consequence.

## Standard Formulas

- Direct physical damage: `max(1, ceil(Power * multiplier) - effective Defense)`.
- Armor, Leech, Bleed, and Poison use `SkillKeywords.md`.
- Damage rounds up unless a keyword explicitly uses `floor`.

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

Resolution order is: revalidate; lock targets and path; direct damage through Defense then Armor; movement; keyword application or consumption; Leech; new cooldown; authoritative log/history; defeat/result; queue advance/rebuild; declared action or round ticks and later cooldown decrements.

An invalid operation rejects the whole skill before damage. There is no partial success unless the skill explicitly defines independent target resolution and preview shows it.

## Passive Safety

- Every Passive declares a trigger and once-per-action, once-per-round, or once-per-battle guard.
- A Passive cannot trigger itself.
- Passive chains stop after one authored downstream reaction unless both definitions name the interaction.
- Follow-ups, counters, status ticks, and reflection are not committed Active skills unless stated.
- Passive effects join the triggering history or create one typed reaction entry; they never mutate invisibly.

## Progression

Character leveling, tier unlocking, evolution, mechanical-unit progression, and commander progression are deferred for re-evaluation. Current design targets require the complete three-skill regular loadout, or the complete three-plus-one commander loadout, without level gates. The initial roster uses no mana or race-specific meter.

## Implementation Boundary

**Observed runtime baseline (2026-08-29):** `BattleUnitState` supports a four-slot roster ceiling, HP-based activity, base/effective Speed, round- or action-scoped Speed modifiers, and action cooldowns. `BattleSkillRules` supports typed Active/Passive definitions, basic damage and Speed effect plans, positional and health requirements, target evaluation, stale-revision confirmation, and generic combo evaluation. Existing arena tests cover those AC2-era capabilities.

This baseline does **not** establish implementation of the authoring contract as a whole. Regular three-slot versus commander three-plus-one catalog validation, Power/Defense formula resolution, Armor, general statuses, Bleed, Poison, Stun, enemy-bound Advantage, Snared, Leech, formation movement, reactive Passive scheduling, Goblin skill definitions, status-aware preview/log/UI, Cache, and battle preparation remain implementation dependencies until linked tests and runtime evidence pass.

Class and commander documents are design authority. Their language describes required future behavior and must not be cited as evidence that the behavior is shipped.
