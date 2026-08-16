# Goblin Classes

## Reading the Skill Records

All skills inherit `Docs/Mechanics/SkillAuthoringContract.md` and keyword rules. `CD N` means a post-use cooldown of N successful owning-side actions. Active skills trigger on confirmed use; Passives use their stated trigger and frequency limit. Unless stated otherwise: duration, stacks, reapplication, movement, and Advantage are `None`; effects clear at battle end; invalid targets or changed previews reject atomically; AI uses a skill only when every requirement and at least one listed effect is legal; damage rounds as the shared contract states. Each UI cell contains exact tooltip text followed by exact log text.

## Class 1: Scrapshield Bruiser

**Role:** Nuisance anchor and adjacent protector. **Rhythm:** Claim a front slot, protect a neighbor, then drag an enemy into an allied conversion. **Weakness:** Lowest Goblin tempo and limited damage. **Stats:** 20 Health, 4 Power, 7 Speed, 2 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Shield Jab | Active Opener; offense/control; one ring-neighbor enemy; front-half required; CD 1 | Deal 80% Power, then rotate the target Move 1 along its chosen legal path; position evaluates after movement | Reject if target cannot move; AI prefers a path that brings target beside an ally; counter by leaving a harmful path empty | Tooltip: `Deal 80% Power and move a neighboring enemy 1.` Log: `<actor> jabbed <target> and moved it 1.` |
| Hook Drag | Active Converter; control/setup; one enemy moved this round; CD 2 | Deal 60% Power; rotate target Move 1; if movement succeeds, grant Advantage to the next active ally in unresolved order with a rider | Reject without moved target/eligible path; AI requires eligible ally; counter by controlling the intended consumer | Tooltip: `Move a previously moved enemy 1 and grant the next eligible ally Advantage.` Log: `<actor> dragged <target>; <ally> gained Advantage.` |
| Junk Brace | Active Pivot; Armor/support; self plus ring-neighbor ally; CD 3 | Self and ally each gain 3 Armor, additive to cap 10 and persistent until consumed | Reject without active neighbor; AI uses when both can gain Armor; counter with repeated hits or status damage | Tooltip: `You and a neighboring ally each gain 3 Armor.` Log: `<actor> braced with <ally>; both gained 3 Armor.` |
| Pack Wall | Passive Signature; Armor; first ring-neighbor ally targeted by direct damage each round | Before damage, that ally gains 2 Armor; once per round | Does not trigger on self or status damage; AI stays beside fragile ally; counter by attacking the Bruiser first | Tooltip: `Once per round, a neighboring ally targeted by direct damage gains 2 Armor.` Log: `<actor>'s Pack Wall granted <ally> 2 Armor.` |

## Class 2: Wirefang Skirmisher

**Role:** Fast setup striker. **Rhythm:** Rotate into position, grant Advantage, then exploit a later opening. **Weakness:** Extremely fragile. **Stats:** 14 Health, 6 Power, 10 Speed, 0 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Wire Cut | Active Opener; mobility/setup; self Move 1 then one ally; CD 0 | Rotate self Move 1; after success grant chosen ally Advantage until round end | Reject if no legal path/eligible ally; AI chooses ally with rider; counter by changing occupancy before confirmation | Tooltip: `Move 1, then grant one ally Advantage until round end.` Log: `<actor> cut through the line and granted <ally> Advantage.` |
| Cheap Shot | Active Converter; offense; one enemy; CD 2 | Deal 110% Power; Advantage rider raises multiplier to 160% and consumes token; no duration/stack | Reject inactive enemy; AI prioritizes rider on low-HP target; counter with Defense or denying token | Tooltip: `Deal 110% Power; with Advantage, deal 160% instead.` Log: `<actor> used Cheap Shot on <target> for <damage>.` |
| Scuttle Shift | Active Pivot; mobility/offense; self destination within Move 2 and enemy neighboring destination; CD 2 | Atomically rotate self up to Move 2, then deal 80% Power to selected neighboring enemy; position checks after move | Reject path or post-move target failure; AI requires both; counter by clearing threatened adjacency | Tooltip: `Move up to 2, then deal 80% Power to a new neighbor.` Log: `<actor> scuttled to <slot> and struck <target>.` |
| Keep It Moving | Passive Signature; tempo; first ally consumption of this Goblin's Advantage each round | Reduce Wire Cut or Scuttle Shift cooldown by 1; once per round | No trigger from other Advantage sources; AI sequences consumer before round end; counter by forcing expiry | Tooltip: `Once per round, an ally consuming your Advantage reduces one movement cooldown by 1.` Log: `<actor> kept momentum after <ally>'s follow-up.` |

## Class 3: Snarewright

**Role:** Movement controller. **Rhythm:** Start a rotation, deepen it, and hand the displaced target to an ally. **Weakness:** Low direct output when enemies stay still. **Stats:** 16 Health, 4 Power, 9 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Tripwire | Active Opener; offense/control; one enemy; CD 1 | Deal 70% Power, then rotate target Move 1 on a chosen path | Reject without legal path; AI chooses the more disruptive path; counter by changing occupancy before confirmation | Tooltip: `Deal 70% Power and move an enemy 1.` Log: `<actor> tripped <target> for <damage> and moved it 1.` |
| Reel In | Active Converter; control/setup; enemy forcibly moved this round; CD 2 | Rotate target Move 2; after success grant chosen ally Advantage | Reject without prior forced movement, path, or eligible ally; AI selects harmful path; counter by controlling the recipient | Tooltip: `Move an already-moved enemy 2 and grant an ally Advantage.` Log: `<actor> reeled <target> along <path>; <ally> gained Advantage.` |
| Tangled Ring | Active Pivot; control; up to three enemies; CD 4 | Rotate each selected enemy Move 1 in declared order; validate all paths before any movement | Reject fewer than two legal targets or any changed path; AI maximizes changed neighbors; counter by spreading valuable units | Tooltip: `Move up to three enemies 1 in a declared order.` Log: `<actor> tangled <targets> along <paths>.` |
| Bad Footing | Passive Signature; setup; first enemy forcibly moved each round | Grant Advantage to a chosen eligible ally; once per round | No trigger from voluntary movement; AI chooses an unresolved consumer; counter by preventing forced movement | Tooltip: `Once per round, your first forced enemy movement grants an ally Advantage.` Log: `<actor> used Bad Footing to grant <ally> Advantage.` |

## Class 4: Scrapbroker

**Role:** Utility support and debuff relief. **Rhythm:** Identify a weakness, reinforce a converter, then repair disruption. **Weakness:** Lowest Goblin Power. **Stats:** 18 Health, 3 Power, 8 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Appraise Weakness | Active Opener; setup; one ally; CD 1 | Grant Advantage until round end; recipient must have eligible rider; no damage | Reject no eligible recipient; AI picks earliest rider; counter by controlling recipient | Tooltip: `Grant one eligible ally Advantage until round end.` Log: `<actor> appraised an opening for <ally>.` |
| Hand-Me-Down | Active Converter; Armor/support; one ally; CD 2 | Ally gains 4 Armor; Advantage rider grants 6 Armor instead; additive to cap 10 | Reject if recipient already has 10 Armor; AI chooses threatened ally; counter with repeated direct hits or status damage | Tooltip: `Grant an ally 4 Armor; with Advantage, grant 6.` Log: `<actor> handed <ally> <amount> Armor.` |
| Emergency Parts | Active Pivot; Armor/support; one ally below half HP; CD 4 | Ally gains 7 Armor, additive to cap 10 | Reject threshold or full Armor pool; AI protects lowest HP; counter with status damage | Tooltip: `Grant an ally below half HP 7 Armor.` Log: `<actor> fitted <ally> with 7 emergency Armor.` |
| Useful Garbage | Passive Signature; Armor; first Active support skill each round | Lowest-HP active ally gains 2 Armor; once per round | No active ally able to gain Armor, no trigger; AI supports early; counter with status damage | Tooltip: `Once per round after your support skill, the lowest-HP ally gains 2 Armor.` Log: `<actor>'s Useful Garbage granted <ally> 2 Armor.` |

## Class 5: Shivrunner

**Role:** Opportunistic Bleed finisher. **Rhythm:** Cut after an ally, relocate, then cash in Bleed. **Weakness:** Lowest Health and no Defense. **Stats:** 12 Health, 7 Power, 10 Speed, 0 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Quick Nick | Active Opener; offense/Bleed; enemy already damaged by ally this round; CD 1 | Deal 80% Power and apply 1 Bleed for 2 target actions; max 3 and refresh per canon | Reject without prior allied damage; AI selects active target with low stacks; counter by denying sequence | Tooltip: `After an ally damages an enemy, deal 80% Power and apply 1 Bleed.` Log: `<actor> nicked <target> for <damage> and applied Bleed.` |
| Slip Behind | Active Converter; mobility/offense; self Move 2 then neighboring Bleeding enemy; CD 2 | Rotate self up to Move 2, then deal 120% Power; Advantage rider raises to 150% | Reject path/post-move target; AI seeks wounded Bleeding target; counter by changing occupancy | Tooltip: `Move up to 2 and strike a neighboring Bleeding enemy for 120% Power.` Log: `<actor> slipped to <slot> and struck <target> for <damage>.` |
| Collect the Cut | Active Pivot; offense; one Bleeding enemy below half HP; CD 4 | Deal 180% Power; remove one Bleed stack after damage; no duration/reapply | Reject threshold/no Bleed; AI uses on lethal candidate; counter with Armor or Defense | Tooltip: `Deal 180% Power to a Bleeding enemy below half HP, then remove 1 Bleed.` Log: `<actor> collected <target>'s cut for <damage>.` |
| Never Fight Fair | Passive Signature; Advantage; first time each round an ally damages an enemy | Grant self Advantage; once per round | No eligible Advantage rider, no trigger; AI follows the ally's target; counter by forcing token expiry | Tooltip: `Once per round after an ally deals damage, gain Advantage.` Log: `<actor> gained Advantage by refusing a fair fight.` |

## Class 6: Mobcaller

**Role:** Coalition coordinator. **Rhythm:** Nominate a target, accumulate distinct allied pressure, then reposition the team. **Weakness:** Requires several surviving allies. **Stats:** 17 Health, 4 Power, 9 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Point and Yell | Active Opener; Advantage; one ally; CD 1 | Grant chosen eligible ally Advantage until round end | Reject no eligible ally; AI chooses earliest unresolved consumer; counter by controlling recipient | Tooltip: `Grant one eligible ally Advantage until round end.` Log: `<actor> pointed and granted <ally> Advantage.` |
| Dogpile | Active Converter; offense; enemy damaged by an ally this round; CD 2 | Deal 90% Power plus 20% per distinct allied attacker this round, maximum 150%; Advantage rider counts one extra attacker | Reject no prior allied attacker; AI waits for two attackers; counter by spreading attacks | Tooltip: `Deal 90% Power, +20% per distinct ally that hit this target this round (max 150%).` Log: `<actor>'s Dogpile hit <target> for <damage> with <count> contributors.` |
| Scatter! | Active Pivot; mobility; up to two allies; CD 4 | Each selected ally rotates Move 1 on its chosen path in declared order; validate both paths first | Reject any invalid path or changed occupancy; AI uses to improve targeting; counter by changing paths before confirmation | Tooltip: `Move up to two allies 1 in a declared order.` Log: `<actor> scattered <allies> along <paths>.` |
| Louder Together | Passive Signature; Advantage; first different-race ally committed action each round | Grant that ally Advantage if it has an eligible later Active skill; once per round | No eligible future rider, no trigger; AI prefers mixed roster; counter by forcing expiry | Tooltip: `Once per round after a different-race ally acts, grant it Advantage.` Log: `<actor>'s call granted <ally> Advantage.` |

## Role and Progression Summary

| Class | Primary job | Signature mechanic | Tier 3 coalition upgrade |
|---|---|---|---|
| Scrapshield Bruiser | Anchor | Neighbor protection | Hook Drag may grant Advantage to a different-race ally |
| Wirefang Skirmisher | Setup striker | Self rotation into Advantage | Cheap Shot rider also reduces consumer cooldown by 1 |
| Snarewright | Controller | Movement-trigger trap | Reel In grants Advantage after forced movement |
| Scrapbroker | Armor support | Advantage into Armor | Emergency Parts may target a different-race ally |
| Shivrunner | Finisher | Prior-ally and Bleed payoff | Collect the Cut preserves Bleed when a different race applied it |
| Mobcaller | Coalition support | Distinct-attacker scaling | Louder Together uses its stronger variant for different-race allies |
