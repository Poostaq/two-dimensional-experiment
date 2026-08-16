# Skill Keywords

## Purpose

This document is the canonical contract for named combat keywords. Race and class documents may assign these keywords, but they must not redefine them. Formation movement and unnamed effects such as Guard or Cleanse are documented in `FormationMovement.md` and `SkillAuthoringContract.md`.

## Shared Rules

- Status identity is `(target, keyword, source unit, source skill)`.
- An application records the source Power needed by later ticks so source defeat or removal cannot invalidate it.
- Previewed, cancelled, rejected, or stale actions never apply, consume, tick, or remove a keyword.
- All keyword state clears when battle ends; no keyword persists into the world map or the next battle.
- Durations use `committed action`, `next eligible action`, or `round`, never bare `turn`.
- Effective Power and Speed cannot fall below 1. Effective Defense cannot fall below 0.
- A tooltip states application, trigger, duration, cap, and reapplication behavior. A log entry identifies source, target, result, stacks, and remaining duration.

## Bleed

Bleed is action-punishing physical pressure.

- **Application:** One Bleed application adds one stack, to a maximum of three.
- **Trigger:** After the affected unit successfully commits an Active skill or Default action. Preview, cancellation, rejection, Passive triggers, and skipped actions do not trigger it.
- **Damage:** Each stack deals `max(1, ceil(snapshot source Power * 0.20))` status damage.
- **Duration:** Two affected-unit committed actions by default.
- **Reapplication:** Add one stack and set remaining duration to the greater of the current and new durations. Durations never add together.
- **Resolution:** Deal the tick, decrement remaining duration, then remove Bleed at zero.
- **Exclusions:** Bleed damage cannot Leech, consume Advantage, or activate direct-damage combo conditions.
- **Tooltip pattern:** `Apply 1 Bleed (max 3) for 2 committed actions. After each affected action, each stack deals 20% source Power.`
- **Log pattern:** `<source> applied Bleed to <target> (<stacks>/3, <actions> actions remaining).`

## Poison

Poison is slow attrition paired with one readable stat erosion axis.

- **Application:** Every Poison skill declares exactly one axis: Power, Defense, or Speed.
- **Trigger:** At the end of each round.
- **Damage:** Each source instance deals `max(1, ceil(snapshot source Power * 0.10))` status damage per stack.
- **Penalty:** Each stack reduces its declared axis by 1, to a maximum aggregate penalty of 3 on that axis.
- **Duration:** Three rounds by default.
- **Reapplication:** The same source skill adds one stack to a maximum of three and refreshes duration to the greater remaining value. Different sources remain distinct.
- **Axis handling:** Different axes never merge into one stack display. Multiple sources on one axis coexist, but their aggregate stat penalty remains capped at 3.
- **Speed interaction:** A changed effective Speed rebuilds only unresolved queue entries using the existing deterministic queue rules.
- **Resolution:** Deal round-end damage, decrement remaining rounds, then remove expired instances and their penalties.
- **Tooltip pattern:** `Apply 1 <axis> Poison (max 3) for 3 rounds. At round end, each stack deals 10% source Power and reduces <axis> by 1.`
- **Log pattern:** `<source> applied <axis> Poison to <target> (<stacks>/3, <rounds> rounds remaining).`

## Stun

Stun is rare, bounded action denial.

- **Application:** Stun marks one target to skip its next eligible action.
- **Stacking:** Stun never stacks or refreshes. Applying it to a Stunned target fails with `Already Stunned`.
- **Skip:** The skipped action is not a committed action. It does not tick Bleed or ordinary action-based cooldowns and does not activate Passive action triggers.
- **Stun Guard:** After the skip, the target gains Stun Guard. Stun Guard rejects further Stun until that target successfully commits its next action, then clears.
- **Authoring budget:** At most one Stun skill per class, at most one target, cooldown 4-5 successful actions, and at least one positional or state requirement.
- **Bosses:** Boss Stun immunity or resistance is authored on the boss. A skill preview must expose that interaction before confirmation.
- **Tooltip pattern:** `Stun one eligible target. It skips its next eligible action, then gains Stun Guard until it completes an action.`
- **Log pattern:** `<target> was Stunned by <source> and will skip its next eligible action.`

## Advantage

Advantage is a short coalition setup window, not a generic damage bonus.

- **Application:** Grant one non-stacking Advantage token to an ally.
- **Consumer:** The next eligible Active skill used by that ally consumes the token and activates that skill's explicitly written `Advantage rider`.
- **Eligibility:** Each granting skill may restrict the recipient. Each consuming skill states its rider; a skill without a rider is ineligible and leaves the token intact.
- **Expiry:** Advantage expires at the end of the current round.
- **Reapplication:** Replace the existing token's source and refresh its round expiry; never create a second token.
- **Exclusions:** Default Attack and Default Swap do not consume Advantage. Previewed, cancelled, rejected, or stale actions do not consume it.
- **Atomicity:** Consumption and its rider are recorded in the same authoritative action history entry as the consuming skill.
- **Tooltip pattern:** `Grant Advantage until round end. The recipient's next eligible Active skill consumes it for that skill's Advantage effect.`
- **Log pattern:** `<source> granted Advantage to <ally> until round end.`

## Leech

Leech is offense-dependent recovery, not general healing.

- **Application:** A direct offensive skill declares a Leech ratio from 25% through 40% unless a capstone explicitly permits 50%.
- **Healing:** `floor(actual direct HP damage * ratio)`, with a minimum of 1 only when actual damage is greater than zero.
- **Damage basis:** Use applied damage after Defense and exclude overkill, Guard absorption, status damage, reflected damage, and counter damage.
- **Timing:** Resolve after all direct damage from the skill and before final battle-result evaluation.
- **Limits:** Healing cannot exceed missing HP. A defeated actor receives no Leech healing.
- **Multi-target skills:** Sum eligible actual damage, then apply the ratio once unless the skill explicitly declares a per-target cap.
- **Tooltip pattern:** `Leech <ratio>% of actual direct HP damage dealt, excluding overkill and status damage.`
- **Log pattern:** `<source> leeched <applied healing> HP from <actual eligible damage> damage.`

## Race Profiles

- Goblins: Advantage primary; Bleed secondary on physical opportunists.
- Orcs: Stun is bounded to specialist control; Bleed is secondary physical pressure.
- Werewolves: Leech primary; Bleed secondary for tracking and wounded-target play.
- Lizardmen: Poison primary; Advantage secondary only through degradation-based ally setup.
- Harpies: formation movement is primary; Advantage follows successful exposure or isolation; Bleed is limited to one physical branch.

