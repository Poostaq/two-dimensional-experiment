# Lizardman Classes

## Reading the Skill Records

All skills inherit shared mechanics. `CD N` is post-use cooldown in successful owning-side actions. Unstated duration, stacks, reapplication, movement, and Advantage are `None`; cleanup is battle end; invalid previews reject atomically; AI requires legal effects; UI cells contain exact tooltip and log text.

## Class 1: Venom Saurian

**Role:** Power Poison specialist. **Rhythm:** Weaken retaliation, deepen dose, convert stacks. **Weakness:** Limited burst without Poison. **Stats:** 20 Health, 7 Power, 5 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Weakening Bite | Active Opener; offense/Poison; one enemy; CD 1 | Deal 80% Power; apply 1 Power Poison for 3 rounds, max 3/refresh canon | Reject inactive; AI targets high Power/no stack; counter Cleanse | Tooltip: `Deal 80% Power and apply 1 Power Poison for 3 rounds.` Log: `<actor> bit <target> for <damage>; Power Poison <stacks>/3.` |
| Venom Pulse | Active Converter; Poison; enemy with this Power Poison; CD 2 | Deal 100% Power; add one source stack and refresh; no separate axis | Reject no source stack/cap at full duration; AI deepens dangerous target; counter Cleanse | Tooltip: `Deal 100% Power and add 1 stack to your Power Poison.` Log: `<actor> pulsed venom through <target>; <stacks>/3.` |
| Cold Finish | Active Pivot; offense; enemy with Power Poison; CD 4 | Deal 120% Power +20% per source stack, max 180%; does not consume Poison; Advantage rider +20% | Reject no Poison; AI uses at 3 stacks/lethal; counter Guard/Cleanse | Tooltip: `Deal 120% Power, +20% per Power Poison stack (max 180%).` Log: `<actor> coldly struck <target> for <damage>.` |
| Measured Dose | Passive Signature; Poison; first source application each round | If target has no other Poison axis, duration +1 round; once/round; Aggressive tick +10% Power, Protective actor +1 Defense round | Other axis prevents bonus; AI keeps axis focused; counter introduce/cleanse axis | Tooltip: `Once per round, your first single-axis Poison lasts 1 extra round.` Log: `<actor>'s Measured Dose extended <target>'s Poison.` |

## Class 2: Scale Sentinel

**Role:** Durable control anchor. **Rhythm:** Brace, check movement, shed accumulated pressure. **Weakness:** Lowest Lizardman output and Speed. **Stats:** 26 Health, 4 Power, 3 Speed, 3 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Brace Scales | Active Opener; defense; self; CD 1 | +2 Defense for 2 rounds; one/source, refresh not stack | Reject equal longer buff; AI uses before contact; counter Poison Defense/true status damage | Tooltip: `Gain 2 Defense for 2 rounds.` Log: `<actor> braced its scales; Defense +2.` |
| Tail Check | Active Converter; offense/control; ring-neighbor enemy; CD 2 | Deal 90% Power and rotate target Move 1; if Brace active, target -1 Power through next action | Reject no path; AI maintains contact; counter safe rotation/Cleanse | Tooltip: `Deal 90% Power and move a neighbor 1; while Braced, reduce its Power by 1.` Log: `<actor> tail-checked <target> for <damage>.` |
| Shed Skin | Active Pivot; Cleanse/defense; self; CD 4 | Remove one player-selected Bleed, Poison, or movement lock; then shield 3 until round end | Reject no eligible status; AI chooses highest pressure; counter reapply after cooldown | Tooltip: `Cleanse one eligible status from self and gain a 3 shield this round.` Log: `<actor> shed <status> and gained a 3 shield.` |
| Cold-Blooded Patience | Passive Signature; defense; first round with no movement by Sentinel | +1 Defense next round; once/round, max one; Aggressive next Tail Check +1 Power, Protective +2 Defense | Movement cancels trigger; AI holds useful slot; counter forced movement | Tooltip: `Once per round if you did not move, gain 1 Defense next round.` Log: `<actor>'s patience granted <bonus> Defense.` |

## Class 3: Mire Spitter

**Role:** Speed Poison controller. **Rhythm:** Slow a key actor, exploit reordered queue, saturate several threats. **Weakness:** Fragile and low direct damage. **Stats:** 18 Health, 5 Power, 6 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Slowing Spit | Active Opener; offense/Poison; one enemy; CD 1 | Deal 70% Power; apply 1 Speed Poison 3 rounds, max 3/refresh; rebuild unresolved queue | Reject inactive; AI targets unresolved fast enemy; counter Cleanse | Tooltip: `Deal 70% Power and apply 1 Speed Poison for 3 rounds.` Log: `<actor> slowed <target>; Speed Poison <stacks>/3.` |
| Bog Down | Active Converter; control; enemy with this Speed Poison; CD 2 | Add one stack/refresh; target voluntary Move -1 this round, non-stack | Reject no source Poison; AI acts before target; counter forced movement/Cleanse | Tooltip: `Add 1 Speed Poison stack and reduce the target's voluntary Move by 1 this round.` Log: `<actor> bogged down <target>.` |
| Saturate Ground | Active Pivot; Poison/control; up to three enemies; CD 4 | Apply 1 Speed Poison to each for 3 rounds; independent legal targets, preview lists all; max/refresh canon | Reject fewer than two legal targets; AI hits unresolved threats; counter spread Cleanse/focus Spitter | Tooltip: `Apply 1 Speed Poison to up to three enemies for 3 rounds.` Log: `<actor> saturated <targets> with Speed Poison.` |
| Patient Pursuit | Passive Signature; tempo; first poisoned enemy moved behind Spitter in unresolved order | Spitter gains +1 Speed current round, rebuild queue; once/round; Aggressive +1 Power, Protective +1 Defense | No ordering change, no trigger; AI poisons fast targets; counter Cleanse | Tooltip: `Once per round when Poison drops an enemy behind you, gain 1 Speed this round.` Log: `<actor>'s Patient Pursuit gained 1 Speed.` |

## Class 4: Fang Alchemist

**Role:** Defense Poison utility. **Rhythm:** Corrode armor, catalyze stacks, exchange toxin for relief. **Weakness:** Requires exact target management. **Stats:** 21 Health, 6 Power, 5 Speed, 2 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Corrosive Dose | Active Opener; offense/Poison; one enemy; CD 1 | Deal 70% Power; apply 1 Defense Poison 3 rounds, max 3/refresh | Reject inactive; AI chooses high Defense; counter Cleanse | Tooltip: `Deal 70% Power and apply 1 Defense Poison for 3 rounds.` Log: `<actor> corroded <target>; Defense Poison <stacks>/3.` |
| Catalyze | Active Converter; offense; enemy with any Poison; CD 2 | Deal 80% Power +20% per total Poison stack, max 160%; stacks remain; Advantage rider ignores 1 Defense | Reject no Poison; AI picks most stacked; counter early Cleanse | Tooltip: `Deal 80% Power, +20% per Poison stack (max 160%).` Log: `<actor> catalyzed <target> for <damage>.` |
| Antidote Exchange | Active Pivot; Cleanse/Poison; ally with cleansable Poison and one enemy; CD 4 | Remove one selected Poison source from ally; apply one Defense Poison stack to enemy for remaining rounds, max/refresh | Reject either target/axis; AI saves high stacks; counter by blocking enemy target | Tooltip: `Remove one Poison from an ally and apply 1 Defense Poison to an enemy.` Log: `<actor> exchanged <ally>'s toxin onto <target>.` |
| Exact Mixture | Passive Signature; Poison; first same-axis reapplication each round | Snapshot duration becomes max(current,new)+1, capped 4 rounds; once/round; Aggressive tick +10% Power, Protective shield ally 2 | Mixed axis no trigger; AI stays same axis; counter Cleanse | Tooltip: `Once per round, reapplying the same Poison axis extends it by 1 round (max 4).` Log: `<actor>'s Exact Mixture extended <target>'s Poison.` |

## Class 5: Reed Ambusher

**Role:** Patient positional striker. **Rhythm:** Stay still, mark a line, lunge across the ring, withdraw. **Weakness:** Forced movement breaks preparation. **Stats:** 19 Health, 7 Power, 6 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Stillwater Mark | Active Opener; setup; one enemy while actor has not moved this round; CD 1 | Mark 2 rounds; actor's next direct hit on target ignores 1 Defense; one/source, refresh | Reject actor moved/equal mark; AI marks reachable enemy; counter force movement/Cleanse | Tooltip: `If you have not moved this round, mark an enemy for 2 rounds; your next hit ignores 1 Defense.` Log: `<actor> marked <target> from still water.` |
| Sudden Lunge | Active Converter; mobility/offense; self Move 3 then neighboring marked enemy; CD 3 | Rotate self up to Move 3, deal 160% Power, consume mark; Advantage rider 190% | Reject path/mark/post-move adjacency; AI seeks lethal; counter movement lock | Tooltip: `Move up to 3 and deal 160% Power to neighboring marked prey.` Log: `<actor> lunged from reeds at <target> for <damage>.` |
| Vanish into Reeds | Active Pivot; mobility/defense; self Move 2; CD 3 | Rotate self up to Move 2; +2 Defense until next action; non-stack, refresh | Reject no path; AI exits threat; counter forced follow/Poison | Tooltip: `Move up to 2 and gain 2 Defense until your next action.` Log: `<actor> vanished to <slot>; Defense +2.` |
| Motionless Hunter | Passive Signature; offense; first round actor neither moved nor was moved | Next attack +2 Power; once/round, expires after next action; Aggressive +3, Protective +2 Defense also | Any movement cancels; AI holds safe slot; counter rotate actor | Tooltip: `If you remain unmoved for a round, gain 2 Power on your next attack.` Log: `<actor>'s stillness prepared <bonus> Power.` |

## Class 6: Sunscale Warder

**Role:** Mitigation support. **Rhythm:** Shield a neighbor, punish a direct hit, shelter the formation. **Weakness:** Low Power and no Poison conversion. **Stats:** 24 Health, 4 Power, 4 Speed, 3 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Warming Guard | Active Opener; defense/support; ring-neighbor ally; CD 1 | Ally gains shield 3 and +1 Power until round end; reapply refreshes shield to max, no add | Reject no neighbor/equal shield; AI protects converter; counter status/multi-hit | Tooltip: `A neighboring ally gains a 3 shield and 1 Power this round.` Log: `<actor> warmed <ally> with a 3 shield.` |
| Reflecting Scale | Active Converter; defense/reaction; self; CD 3 | Until next direct hit or round end, reduce hit by 2 and deal 60% Power counter to attacker; non-stack/refresh | Reject equal effect; AI anticipates focus; counter status/area or wait | Tooltip: `Reduce your next direct hit by 2 and counter for 60% Power this round.` Log: `<actor>'s scale reduced <amount> and reflected <damage>.` |
| Solar Bulwark | Active Pivot; defense/capstone; all allies; CD 5 | Each ally gains shield 2 for current round; allies currently Poisoned instead gain 3; non-stack/refresh | Reject fewer than two active allies; AI uses before burst; counter delayed/status damage | Tooltip: `Shield all allies for 2 this round, or 3 if they are Poisoned.` Log: `<actor> raised a Solar Bulwark for <allies>.` |
| Shared Shelter | Passive Signature; support; first neighboring ally shield broken each round | Warder gains shield 2 until round end; once/round; Aggressive +1 Power next action, Protective restore 1 shield to ally | No broken shield, no trigger; AI stays adjacent; counter attack Warder first | Tooltip: `Once per round when a neighbor's shield breaks, gain a 2 shield.` Log: `<actor> shared <ally>'s shelter and gained 2 shield.` |

## Role Summary

| Class | Primary job | Signature mechanic |
|---|---|---|
| Venom Saurian | Power suppressor | Power Poison |
| Scale Sentinel | Anchor | Stationary Defense and Cleanse |
| Mire Spitter | Tempo controller | Speed Poison |
| Fang Alchemist | Anti-armor utility | Defense Poison |
| Reed Ambusher | Positional striker | Stillness into Move 3 |
| Sunscale Warder | Mitigation support | Shared shields |

