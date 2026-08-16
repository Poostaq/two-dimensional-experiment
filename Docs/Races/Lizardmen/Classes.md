# Lizardman Classes

## Reading the Skill Records

All skills inherit shared mechanics. `CD N` is post-use cooldown in successful owning-side actions. Unstated duration, stacks, reapplication, movement, and Advantage are `None`; cleanup is battle end; invalid previews reject atomically; AI requires legal effects; UI cells contain exact tooltip and log text.

## Class 1: Venom Saurian

**Role:** Power Poison specialist. **Rhythm:** Weaken retaliation, deepen dose, convert stacks. **Weakness:** Limited burst without Poison. **Stats:** 20 Health, 7 Power, 5 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Weakening Bite | Active Opener; offense/Poison; one enemy; CD 1 | Deal 80% Power; apply 1 Power Poison for 3 rounds, max 3/refresh canon | Reject inactive; AI targets high Power/no stack; counter with Armor on the direct hit | Tooltip: `Deal 80% Power and apply 1 Power Poison for 3 rounds.` Log: `<actor> bit <target> for <damage>; Power Poison <stacks>/3.` |
| Venom Pulse | Active Converter; Poison; enemy with this Power Poison; CD 2 | Deal 100% Power; add one source stack and refresh; no separate axis | Reject no source stack/cap at full duration; AI deepens dangerous target; counter by defeating the source | Tooltip: `Deal 100% Power and add 1 stack to your Power Poison.` Log: `<actor> pulsed venom through <target>; <stacks>/3.` |
| Cold Finish | Active Pivot; offense; enemy with Power Poison; CD 4 | Deal 120% Power +20% per source stack, max 180%; does not consume Poison; Advantage rider +20% | Reject no Poison; AI uses at 3 stacks/lethal; counter with Armor | Tooltip: `Deal 120% Power, +20% per Power Poison stack (max 180%).` Log: `<actor> coldly struck <target> for <damage>.` |
| Measured Dose | Passive Signature; Poison; first source application each round | If target has no other Poison axis, duration +1 round; once per round | Other axis prevents bonus; AI keeps axis focused; counter with a different Poison axis | Tooltip: `Once per round, your first single-axis Poison lasts 1 extra round.` Log: `<actor>'s Measured Dose extended <target>'s Poison.` |

## Class 2: Scale Sentinel

**Role:** Durable control anchor. **Rhythm:** Brace, check movement, shed accumulated pressure. **Weakness:** Lowest Lizardman output and Speed. **Stats:** 26 Health, 4 Power, 3 Speed, 3 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Brace Scales | Active Opener; Armor; self; CD 1 | Gain 5 Armor | Reject full pool; AI uses before contact; counter with Poison or Bleed | Tooltip: `Gain 5 Armor.` Log: `<actor> braced its scales and gained 5 Armor.` |
| Tail Check | Active Converter; offense/control; ring-neighbor enemy; CD 2 | Deal 90% Power and rotate target Move 1; Advantage rider deals 120% | Reject no path; AI maintains contact; counter by changing occupancy | Tooltip: `Deal 90% Power and move a neighbor 1; with Advantage, deal 120%.` Log: `<actor> tail-checked <target> for <damage>.` |
| Layered Scales | Active Pivot; Armor; self; CD 4 | Gain 8 Armor | Reject Armor pool above 2; AI uses under pressure; counter with status damage | Tooltip: `Gain 8 Armor.` Log: `<actor> layered its scales and gained 8 Armor.` |
| Cold-Blooded Patience | Passive Signature; Armor; round end with no movement | Gain 2 Armor; once per round | Movement cancels trigger; AI holds useful slot; counter by forced movement | Tooltip: `Once per round if you did not move, gain 2 Armor.` Log: `<actor>'s patience granted 2 Armor.` |

## Class 3: Mire Spitter

**Role:** Speed Poison controller. **Rhythm:** Slow a key actor, exploit reordered queue, saturate several threats. **Weakness:** Fragile and low direct damage. **Stats:** 18 Health, 5 Power, 6 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Slowing Spit | Active Opener; offense/Poison; one enemy; CD 1 | Deal 70% Power; apply 1 Speed Poison 3 rounds, max 3/refresh; rebuild unresolved queue | Reject inactive; AI targets unresolved fast enemy; counter by defeating the source | Tooltip: `Deal 70% Power and apply 1 Speed Poison for 3 rounds.` Log: `<actor> slowed <target>; Speed Poison <stacks>/3.` |
| Bog Down | Active Converter; Poison/control; enemy with this Speed Poison; CD 2 | Add one Speed Poison stack/refresh, then rotate target Move 1 | Reject no source Poison/path; AI changes target neighbors; counter by changing occupancy | Tooltip: `Add 1 Speed Poison stack and move the target 1.` Log: `<actor> bogged down <target> and moved it 1.` |
| Saturate Ground | Active Pivot; Poison/control; up to three enemies; CD 4 | Apply 1 Speed Poison to each for 3 rounds; independent legal targets, preview lists all; max/refresh canon | Reject fewer than two legal targets; AI hits unresolved threats; counter by focusing the Spitter | Tooltip: `Apply 1 Speed Poison to up to three enemies for 3 rounds.` Log: `<actor> saturated <targets> with Speed Poison.` |
| Patient Pursuit | Passive Signature; cooldown; first Speed-Poisoned enemy movement each round | Reduce Bog Down cooldown by 1; once per round | No Poison/movement, no trigger; AI poisons mobile targets; counter by not moving | Tooltip: `Once per round when a Speed-Poisoned enemy moves, reduce Bog Down cooldown by 1.` Log: `<actor>'s Patient Pursuit reduced Bog Down cooldown.` |

## Class 4: Fang Alchemist

**Role:** Defense Poison utility. **Rhythm:** Corrode armor, catalyze stacks, exchange toxin for relief. **Weakness:** Requires exact target management. **Stats:** 21 Health, 6 Power, 5 Speed, 2 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Corrosive Dose | Active Opener; offense/Poison; one enemy; CD 1 | Deal 70% Power; apply 1 Defense Poison 3 rounds, max 3/refresh | Reject inactive; AI chooses high Defense; counter by defeating the source | Tooltip: `Deal 70% Power and apply 1 Defense Poison for 3 rounds.` Log: `<actor> corroded <target>; Defense Poison <stacks>/3.` |
| Catalyze | Active Converter; offense; enemy with any Poison; CD 2 | Deal 80% Power +20% per total Poison stack, max 160%; stacks remain; Advantage rider +20% | Reject no Poison; AI picks most stacked; counter with Armor | Tooltip: `Deal 80% Power, +20% per Poison stack (max 160%).` Log: `<actor> catalyzed <target> for <damage>.` |
| Antidote Exchange | Active Pivot; Poison; ally with Poison and one enemy; CD 4 | Remove one selected Poison source from ally; apply one matching-axis Poison stack to enemy for remaining rounds | Reject either target or invalid remaining duration; AI moves high stacks; counter with target selection denial | Tooltip: `Move one Poison source from an ally to an enemy, preserving its axis and duration.` Log: `<actor> exchanged <ally>'s <axis> Poison onto <target>.` |
| Exact Mixture | Passive Signature; Poison; first same-axis reapplication each round | Duration becomes max(current,new)+1, capped 4 rounds; once per round | Mixed axis no trigger; AI stays on one axis; counter by applying a different axis | Tooltip: `Once per round, reapplying the same Poison axis extends it by 1 round (max 4).` Log: `<actor>'s Exact Mixture extended <target>'s Poison.` |

## Class 5: Reed Ambusher

**Role:** Patient positional striker. **Rhythm:** Stay still, mark a line, lunge across the ring, withdraw. **Weakness:** Forced movement breaks preparation. **Stats:** 19 Health, 7 Power, 6 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Stillwater Focus | Active Opener; Advantage; self has not moved this round; CD 1 | Grant self Advantage | Reject actor moved or no eligible rider; AI prepares Sudden Lunge; counter by forcing movement | Tooltip: `If you have not moved this round, gain Advantage.` Log: `<actor> focused from still water and gained Advantage.` |
| Sudden Lunge | Active Converter; mobility/offense; self Move 3 then neighboring enemy; CD 3 | Rotate self up to Move 3 and deal 160% Power; Advantage rider 190% | Reject path/post-move adjacency; AI seeks lethal; counter by changing occupancy | Tooltip: `Move up to 3 and deal 160% Power to a neighboring enemy.` Log: `<actor> lunged from reeds at <target> for <damage>.` |
| Vanish into Reeds | Active Pivot; mobility/Armor; self Move 2; CD 3 | Rotate self up to Move 2, then gain 4 Armor | Reject no path; AI exits threat; counter with Poison or Bleed | Tooltip: `Move up to 2 and gain 4 Armor.` Log: `<actor> vanished to <slot> and gained 4 Armor.` |
| Motionless Hunter | Passive Signature; Advantage; round end with no movement | Gain Advantage; once per round | Any movement cancels; AI holds safe slot with a rider; counter by forced movement | Tooltip: `Once per round if you remained unmoved, gain Advantage.` Log: `<actor>'s stillness granted Advantage.` |

## Class 6: Sunscale Warder

**Role:** Armor support. **Rhythm:** Armor a neighbor, spend Armor offensively, shelter the formation. **Weakness:** Low Power and no Poison conversion. **Stats:** 24 Health, 4 Power, 4 Speed, 3 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Warming Armor | Active Opener; Armor/support; ring-neighbor ally; CD 1 | Ally gains 4 Armor | Reject no neighbor/full pool; AI protects converter; counter with status damage | Tooltip: `A neighboring ally gains 4 Armor.` Log: `<actor> granted <ally> 4 Armor.` |
| Reflecting Scale | Active Converter; Armor/offense; self with Armor and one enemy; CD 3 | Spend up to 3 own Armor; deal 50% Power per point spent | Reject no Armor/target; AI spends 3 when useful; counter by consuming Armor first | Tooltip: `Spend up to 3 Armor to deal 50% Power per point to an enemy.` Log: `<actor> spent <armor> Armor and reflected <damage> to <target>.` |
| Solar Bulwark | Active Pivot; Armor/capstone; all allies; CD 5 | Every active ally gains 4 Armor | Reject fewer than two allies able to gain Armor; AI uses before burst; counter with status damage | Tooltip: `All active allies gain 4 Armor.` Log: `<actor> raised a Solar Bulwark; <allies> gained 4 Armor.` |
| Shared Shelter | Passive Signature; Armor; first neighboring ally losing Armor each round | Warder gains 2 Armor; once per round | No neighbor Armor loss, no trigger; AI stays adjacent; counter by attacking Warder first | Tooltip: `Once per round when a neighbor loses Armor, gain 2 Armor.` Log: `<actor> shared <ally>'s Armor loss and gained 2 Armor.` |

## Role Summary

| Class | Primary job | Signature mechanic |
|---|---|---|
| Venom Saurian | Power suppressor | Power Poison |
| Scale Sentinel | Anchor | Stationary Armor |
| Mire Spitter | Tempo controller | Speed Poison |
| Fang Alchemist | Anti-armor utility | Defense Poison |
| Reed Ambusher | Positional striker | Stillness into Move 3 |
| Sunscale Warder | Armor support | Shared Armor |
