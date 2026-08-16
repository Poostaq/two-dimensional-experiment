# Goblin Classes

## Reading the Skill Records

All skills inherit `Docs/Mechanics/SkillAuthoringContract.md` and keyword rules. `CD N` means a post-use cooldown of N successful owning-side actions. Active skills trigger on confirmed use; Passives use their stated trigger and guard. Unless stated otherwise: duration, stacks, reapplication, movement, and Advantage are `None`; effects clear at battle end; invalid targets or changed previews reject atomically; AI uses a skill only when every requirement and at least one listed effect is legal; damage/healing round as the shared contract states. Each UI cell contains exact tooltip text followed by exact log text.

## Class 1: Scrapshield Bruiser

**Role:** Nuisance anchor and adjacent protector. **Rhythm:** Claim a front slot, protect a neighbor, then drag an enemy into an allied conversion. **Weakness:** Lowest Goblin tempo and limited damage. **Stats:** 20 Health, 4 Power, 7 Speed, 2 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Shield Jab | Active Opener; offense/control; one ring-neighbor enemy; front-half required; CD 1 | Deal 80% Power, then rotate the target Move 1 along its chosen legal path; position evaluates after movement | Reject if target cannot move; AI prefers a path that brings target beside an ally; counter by leaving a harmful path empty | Tooltip: `Deal 80% Power and move a neighboring enemy 1.` Log: `<actor> jabbed <target> and moved it 1.` |
| Hook Drag | Active Converter; control/setup; one enemy moved this round; CD 2 | Deal 60% Power; rotate target Move 1; if movement succeeds, grant Advantage to the next active ally in unresolved order with a rider | Reject without moved target/eligible path; AI requires eligible ally; counter by controlling the intended consumer | Tooltip: `Move a previously moved enemy 1 and grant the next eligible ally Advantage.` Log: `<actor> dragged <target>; <ally> gained Advantage.` |
| Junk Brace | Active Pivot; defense/support; self plus chosen ring-neighbor ally; CD 3 | Self gains +2 Defense for 2 rounds and Guards ally until one direct hit or round end; non-stacking, reapply refreshes | Reject without active neighbor; AI uses when ally is threatened; counter with area/status damage | Tooltip: `Gain 2 Defense for 2 rounds and Guard a neighboring ally until round end.` Log: `<actor> braced and Guarded <ally>.` |
| Pack Wall | Passive Signature; defense/reaction; first ring-neighbor ally hit each round | Reduce that direct hit by 2 after Defense; once per round; no duration/stack; variant Aggressive deals 50% Power counter, Protective reduces by 3 | Does not trigger on self, area, or status damage; AI value rises beside fragile ally; counter by hitting Bruiser first | Tooltip: `Once per round, reduce a neighboring ally's direct damage by 2.` Log: `<actor>'s Pack Wall reduced damage to <ally> by <amount>.` |

## Class 2: Wirefang Skirmisher

**Role:** Fast setup striker. **Rhythm:** Rotate into position, grant Advantage, then exploit a later opening. **Weakness:** Extremely fragile. **Stats:** 14 Health, 6 Power, 10 Speed, 0 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Wire Cut | Active Opener; mobility/setup; self Move 1 then one ally; CD 0 | Rotate self Move 1; after success grant chosen ally Advantage until round end | Reject if no legal path/eligible ally; AI chooses ally with rider; counter with movement lock | Tooltip: `Move 1, then grant one ally Advantage until round end.` Log: `<actor> cut through the line and granted <ally> Advantage.` |
| Cheap Shot | Active Converter; offense; one enemy; CD 2 | Deal 110% Power; Advantage rider raises multiplier to 160% and consumes token; no duration/stack | Reject inactive enemy; AI prioritizes rider on low-HP target; counter with Defense or denying token | Tooltip: `Deal 110% Power; with Advantage, deal 160% instead.` Log: `<actor> used Cheap Shot on <target> for <damage>.` |
| Scuttle Shift | Active Pivot; mobility/offense; self destination within Move 2 and enemy neighboring destination; CD 2 | Atomically rotate self up to Move 2, then deal 80% Power to selected neighboring enemy; position checks after move | Reject path or post-move target failure; AI requires both; counter by clearing threatened adjacency | Tooltip: `Move up to 2, then deal 80% Power to a new neighbor.` Log: `<actor> scuttled to <slot> and struck <target>.` |
| Keep It Moving | Passive Signature; tempo; first ally consumption of this Goblin's Advantage each round | Reduce Wire Cut or Scuttle Shift cooldown by 1; once per round; Aggressive also grants +1 Power for next action, Protective grants +1 Defense | No trigger from other Advantage sources; AI sequences consumer before round end; counter by forcing expiry | Tooltip: `Once per round, an ally consuming your Advantage reduces one movement cooldown by 1.` Log: `<actor> kept momentum after <ally>'s follow-up.` |

## Class 3: Snarewright

**Role:** Movement controller. **Rhythm:** Mark a path, punish rotation, and hand the displaced target to an ally. **Weakness:** Low direct output when enemies stay still. **Stats:** 16 Health, 4 Power, 9 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Tripwire | Active Opener; control; one enemy; CD 1 | Mark for 2 rounds; next voluntary or forced movement deals 70% Power and ends mark; one mark/source, reapply refreshes | Reject already marked at full duration; AI marks likely mover; counter by waiting or cleansing | Tooltip: `Mark an enemy for 2 rounds; its next movement takes 70% Power damage.` Log: `<actor> set a Tripwire on <target>.` |
| Reel In | Active Converter; control/setup; Tripwired enemy; CD 2 | Rotate target Move 2; trigger Tripwire after movement; grant chosen ally Advantage | Reject without mark/legal path/ally; AI selects harmful path; counter by movement lock or Guarding converter target | Tooltip: `Move a Tripwired enemy up to 2, trigger it, and grant an ally Advantage.` Log: `<actor> reeled <target> along <path>; <ally> gained Advantage.` |
| Tangled Ring | Active Pivot; control; all enemies; CD 4 | For current round, enemy voluntary Move values are reduced by 1, minimum 0; non-stacking, reapply refreshes | Reject if already active from this source; AI uses before mobile enemies; counter with non-movement actions | Tooltip: `Reduce every enemy's voluntary Move by 1 for this round.` Log: `<actor> tangled the enemy formation for the round.` |
| Bad Footing | Passive Signature; setup; first enemy forcibly moved each round | Grant Advantage to chosen ally with eligible rider; once per round; Aggressive ally gains +1 Power for rider, Protective ally gains +1 Defense until action | No trigger from voluntary move; AI chooses unresolved ally; counter by preventing forced movement | Tooltip: `Once per round, your first forced enemy movement grants an ally Advantage.` Log: `<actor> exploited <target>'s Bad Footing for <ally>.` |

## Class 4: Scrapbroker

**Role:** Utility support and debuff relief. **Rhythm:** Identify a weakness, reinforce a converter, then repair disruption. **Weakness:** Lowest Goblin Power. **Stats:** 18 Health, 3 Power, 8 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Appraise Weakness | Active Opener; setup; one ally; CD 1 | Grant Advantage until round end; recipient must have eligible rider; no damage | Reject no eligible recipient; AI picks earliest rider; counter by controlling recipient | Tooltip: `Grant one eligible ally Advantage until round end.` Log: `<actor> appraised an opening for <ally>.` |
| Hand-Me-Down | Active Converter; support; one ally; CD 2 | Choose +2 Power or +2 Defense for 2 rounds; one mode/source, reapply refreshes not stacks; Advantage rider grants both +2 | Reject if chosen stat already at equal/longer buff; AI picks offensive or threatened ally; counter with dispel/focus | Tooltip: `Give an ally 2 Power or Defense for 2 rounds; Advantage gives both.` Log: `<actor> loaned <ally> <stats> for 2 rounds.` |
| Emergency Parts | Active Pivot; cleanse/support; one ally with cleansable status; CD 4 | Player selects one Bleed, Poison, or authored movement lock to remove, then heals 50% Power | Reject no cleansable status; AI favors high stacks; counter by reapplying after cooldown | Tooltip: `Cleanse one eligible status from an ally and heal 50% Power.` Log: `<actor> repaired <ally>, removing <status> and healing <amount>.` |
| Useful Garbage | Passive Signature; support; first support Active each round | Shield lowest-HP active ally for 2 damage until round end; once per round; Aggressive target gains +1 Power, Protective shield becomes 3 | No trigger without ally; AI favors early support; counter with status or multi-hit damage | Tooltip: `Once per round after your support skill, shield the lowest-HP ally for 2.` Log: `<actor>'s Useful Garbage shielded <ally> for 2.` |

## Class 5: Shivrunner

**Role:** Opportunistic Bleed finisher. **Rhythm:** Cut after an ally, relocate, then cash in Bleed. **Weakness:** Lowest Health and no Defense. **Stats:** 12 Health, 7 Power, 10 Speed, 0 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Quick Nick | Active Opener; offense/Bleed; enemy already damaged by ally this round; CD 1 | Deal 80% Power and apply 1 Bleed for 2 target actions; max 3 and refresh per canon | Reject without prior allied damage; AI selects active target with low stacks; counter by denying sequence | Tooltip: `After an ally damages an enemy, deal 80% Power and apply 1 Bleed.` Log: `<actor> nicked <target> for <damage> and applied Bleed.` |
| Slip Behind | Active Converter; mobility/offense; self Move 2 then neighboring Bleeding enemy; CD 2 | Rotate self up to Move 2, then deal 120% Power; Advantage rider raises to 150% | Reject path/post-move target; AI seeks wounded Bleeding target; counter with movement lock | Tooltip: `Move up to 2 and strike a neighboring Bleeding enemy for 120% Power.` Log: `<actor> slipped to <slot> and struck <target> for <damage>.` |
| Collect the Cut | Active Pivot; offense; one Bleeding enemy below half HP; CD 4 | Deal 180% Power; remove one Bleed stack after damage; no duration/reapply | Reject threshold/no Bleed; AI uses on lethal candidate; counter by healing above half or cleansing | Tooltip: `Deal 180% Power to a Bleeding enemy below half HP, then remove 1 Bleed.` Log: `<actor> collected <target>'s cut for <damage>.` |
| Never Fight Fair | Passive Signature; offense; first attack each round on enemy already hit by ally | Gain +1 effective Power for that attack; once per round; Aggressive +2 instead, Protective Move 1 after attack | No trigger if Shivrunner acted first; AI delays behind ally; counter by disrupting order | Tooltip: `Once per round, gain 1 Power when attacking after an ally hit that enemy.` Log: `<actor> fought unfairly and gained <bonus> Power.` |

## Class 6: Mobcaller

**Role:** Coalition coordinator. **Rhythm:** Nominate a target, accumulate distinct allied pressure, then reposition the team. **Weakness:** Requires several surviving allies. **Stats:** 17 Health, 4 Power, 9 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Point and Yell | Active Opener; setup; one enemy and one ally; CD 1 | Mark enemy until round end and grant ally Advantage; mark non-stacking, reapply replaces source/refreshes | Reject no eligible ally; AI marks enemy reachable by several allies; counter by controlling recipient | Tooltip: `Mark an enemy and grant one ally Advantage until round end.` Log: `<actor> called the mob onto <target>; <ally> gained Advantage.` |
| Dogpile | Active Converter; offense; marked enemy; CD 2 | Deal 90% Power plus 20% per distinct allied attacker of target this round, maximum 150%; Advantage rider counts one extra attacker | Reject unmarked target; AI waits for two attackers; counter by spreading attacks or cleansing mark | Tooltip: `Deal 90% Power, +20% per distinct ally that hit the marked target this round (max 150%).` Log: `<actor>'s Dogpile hit <target> for <damage> with <count> contributors.` |
| Scatter! | Active Pivot; mobility/support; up to two allies; CD 4 | Each selected ally rotates Move 1 on its own chosen path in declared order; validate both paths before either; then each gains +1 Defense for round | Reject any invalid path/overlap sequence; AI uses to escape threats; counter with movement lock | Tooltip: `Move up to two allies 1 in order; both gain 1 Defense this round.` Log: `<actor> scattered <allies> along <paths>.` |
| Louder Together | Passive Signature; coalition; first cross-race allied follow-up on marked enemy each round | That ally gains +1 Power for action; once per round; Aggressive +2 Power, Protective gains +1 Defense through next action | No same-race trigger; AI prefers mixed roster; counter by removing mark or acting elsewhere | Tooltip: `Once per round, a different-race ally following your mark gains 1 Power.` Log: `<actor>'s call strengthened <ally> by <bonus> Power.` |

## Role and Progression Summary

| Class | Primary job | Signature mechanic | Tier 3 coalition upgrade |
|---|---|---|---|
| Scrapshield Bruiser | Anchor | Neighbor protection | Hook Drag may grant Advantage to a different-race ally |
| Wirefang Skirmisher | Setup striker | Self rotation into Advantage | Cheap Shot rider also reduces consumer cooldown by 1 |
| Snarewright | Controller | Movement-trigger trap | Reel In grants Advantage after forced movement |
| Scrapbroker | Utility support | Flexible buff and Cleanse | Emergency Parts heals a second ring neighbor for 25% Power |
| Shivrunner | Finisher | Prior-ally and Bleed payoff | Collect the Cut preserves Bleed when a different race applied it |
| Mobcaller | Coalition support | Distinct-attacker scaling | Louder Together uses its stronger variant for different-race allies |
