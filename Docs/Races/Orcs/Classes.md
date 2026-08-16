# Orc Classes

## Reading the Skill Records

All skills inherit the shared mechanics contract. `CD N` is post-use cooldown in successful owning-side actions. Unstated duration, stacks, reapplication, movement, and Advantage are `None`; cleanup occurs at battle end; changed or invalid previews reject atomically; AI requires all listed effects to be legal; standard rounding applies. UI cells give exact tooltip and log text.

## Class 1: Iron Tusk Vanguard

**Role:** Defensive anchor. **Rhythm:** Brace, make contact, deny escape. **Weakness:** Minimal reach and damage. **Stats:** 30 Health, 5 Power, 2 Speed, 5 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Brace Line | Active Opener; defense; self and ring-neighbor ally; front half; CD 1 | Self +2 Defense and Guard ally until round end; reapply refreshes, no stack | Reject no neighbor; AI protects threatened ally; counter with area/status damage | Tooltip: `Gain 2 Defense and Guard a neighboring ally until round end.` Log: `<actor> braced the line for <ally>.` |
| Shield Ram | Active Converter; offense/control; neighboring enemy; CD 2 | Deal 100% Power and rotate target Move 1; if target was movement-locked, deal 140% instead | Reject illegal path; AI chooses contact-preserving path; counter by creating safe rotation | Tooltip: `Deal 100% Power and move an enemy 1; deal 140% if movement-locked.` Log: `<actor> rammed <target> for <damage> and moved it 1.` |
| Hold the Gap | Active Pivot; control; self and two ring-neighbor enemy slots; CD 4 | For 2 rounds, enemies leaving either threatened neighbor voluntarily take 80% Power; non-stack, refresh | Reject no active threatened enemy; AI uses on two contacts; counter by forced movement or ranged actions | Tooltip: `For 2 rounds, enemies leaving your neighboring slots take 80% Power.` Log: `<actor> held the gap around <slots>.` |
| Unbroken Contact | Passive Signature; defense; first round-end while neighboring an enemy | Gain +1 Defense next round, max one; once/round; Aggressive next attack +1 Power, Protective Defense +2 | No contact, no trigger; AI maintains neighbor; counter by rotating Orc away | Tooltip: `Once per round, maintain enemy contact to gain 1 Defense next round.` Log: `<actor> maintained contact and gained <bonus> Defense.` |

## Class 2: Bonebreaker Reaver

**Role:** Disabled-target bruiser. **Rhythm:** Open a wound, exploit control, execute. **Weakness:** Few defensive tools. **Stats:** 26 Health, 8 Power, 4 Speed, 2 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Open Wound | Active Opener; offense/Bleed; one enemy; CD 1 | Deal 100% Power; apply 1 Bleed for 2 target actions, max 3/refresh canon | Reject inactive target; AI prefers unbled; counter with Cleanse | Tooltip: `Deal 100% Power and apply 1 Bleed for 2 actions.` Log: `<actor> opened <target>'s wound for <damage>.` |
| Break Formation | Active Converter; offense; moved, movement-locked, or Stunned enemy; CD 2 | Deal 150% Power; Advantage rider ignores 1 Defense | Reject without condition; AI targets lowest effective Defense; counter by avoiding control state | Tooltip: `Deal 150% Power to a moved, locked, or Stunned enemy.` Log: `<actor> broke <target>'s formation for <damage>.` |
| Execution Swing | Active Pivot; offense/capstone; enemy below half HP; front half; CD 4 | Deal 200% Power; no duration/stack | Reject threshold/position; AI uses when lethal; counter with Guard/healing/rotation | Tooltip: `From the front, deal 200% Power to an enemy below half HP.` Log: `<actor> executed a swing on <target> for <damage>.` |
| No Escape | Passive Signature; offense; first attack each round against controlled enemy | +1 Power for attack; once/round; Aggressive +2, Protective gain +1 Defense through next action | No moved/locked/Stunned target, no trigger; AI follows controller; counter by cleansing/rotating | Tooltip: `Once per round, gain 1 Power against a controlled enemy.` Log: `<actor>'s No Escape added <bonus> Power against <target>.` |

## Class 3: Bloodbanner Captain

**Role:** Formation support. **Rhythm:** Plant support, reinforce contact, prevent collapse. **Weakness:** Low personal output. **Stats:** 28 Health, 5 Power, 3 Speed, 4 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Plant Banner | Active Opener; support; self plus ring neighbors; CD 2 | Allies gain +1 Power and Defense for 2 rounds; one source, refresh not stack | Reject no ally; AI catches two allies; counter by rotating formation apart | Tooltip: `Neighboring allies gain 1 Power and Defense for 2 rounds.` Log: `<actor> planted the banner for <allies>.` |
| Rally Strike | Active Converter; offense/support; one enemy and one buffed ally; CD 2 | Deal 90% Power; chosen Plant Banner ally gains +1 Defense until next action | Reject no buffed ally; AI protects exposed ally; counter by dispelling Banner | Tooltip: `Deal 90% Power; a Banner ally gains 1 Defense until its next action.` Log: `<actor> rallied <ally> while striking <target> for <damage>.` |
| Last Standard | Active Pivot; defense/capstone; all allies below half HP; CD 5 | All active allies gain a 3-damage shield and movement-lock immunity for current round; non-stack | Reject unless at least two allies below half; AI uses under collapse; counter by delaying burst or status damage | Tooltip: `If two allies are below half HP, shield all allies for 3 this round.` Log: `<actor> raised the Last Standard for <allies>.` |
| Discipline of the Line | Passive Signature; support; first ally ending an action beside Captain each round | Ally +1 Defense until next action; once/round; Aggressive also +1 Power, Protective lasts 2 actions | No neighbor, no trigger; AI anchors center; counter by forced rotation | Tooltip: `Once per round, an ally acting beside you gains 1 Defense until its next action.` Log: `<actor> disciplined <ally>'s position.` |

## Class 4: Chainwarden

**Role:** Anti-mobility controller. **Rhythm:** Mark movement, drag target, spend one Stun window. **Weakness:** Long cooldowns and Stun Guard. **Stats:** 27 Health, 4 Power, 4 Speed, 4 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Chain Mark | Active Opener; control; one enemy; CD 1 | Mark 2 rounds; voluntary movement range -1, min 0; one/source, refresh | Reject equal longer mark; AI marks mobile enemy; counter with Cleanse/forced move | Tooltip: `Mark an enemy for 2 rounds, reducing voluntary Move by 1.` Log: `<actor> chained <target>'s movement.` |
| Yank Back | Active Converter; control/offense; marked enemy; CD 3 | Rotate target up to Move 2, then deal 80% Power; mark remains | Reject no mark/path; AI pulls into Orc contact; counter by path disruption | Tooltip: `Move a Chain-Marked enemy up to 2, then deal 80% Power.` Log: `<actor> yanked <target> along <path> for <damage>.` |
| Lockdown | Active Pivot; Stun; one enemy moved this round without Stun Guard; front half; CD 5 | Apply canonical Stun; non-stack/no refresh; cleanup canon | Reject boss immunity, Guard, no movement, position; AI targets imminent actor; counter with Stun Guard/Cleanse immunity | Tooltip: `Stun one enemy moved this round; it later gains Stun Guard.` Log: `<actor> locked down <target>.` |
| Short Leash | Passive Signature; control; first marked enemy movement each round | After movement, rotate Warden Move 1 toward its new slot if legal; once/round; Aggressive deal 50% Power, Protective +1 Defense | No legal self path, no move; AI marks reachable target; counter by choosing unsafe pursuit path | Tooltip: `Once per round after a marked enemy moves, move 1 toward it.` Log: `<actor>'s Short Leash followed <target>.` |

## Class 5: War Drummer

**Role:** Formation cadence support. **Rhythm:** Stabilize speed, strike on cadence, accelerate unresolved allies. **Weakness:** Benefits predictable formations, not initiative theft. **Stats:** 24 Health, 4 Power, 5 Speed, 3 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Marching Beat | Active Opener; support; self and ring neighbors; CD 2 | +1 Speed for current round; one source, refresh; unresolved queue rebuild | Reject no unresolved ally; AI uses early; counter by separating or Speed Poison | Tooltip: `You and neighboring allies gain 1 Speed for this round.` Log: `<actor> set a Marching Beat for <allies>.` |
| Crushing Cadence | Active Converter; offense; enemy hit by ally this round; CD 2 | Deal 120% Power; if actor has Marching Beat, deal 140% | Reject no prior hit; AI follows ally; counter by spreading targets | Tooltip: `Deal 120% Power after an ally hits the target; 140% while Marching.` Log: `<actor> struck <target> on cadence for <damage>.` |
| War Tempo | Active Pivot; support/capstone; all unresolved allies; CD 5 | +2 Speed for current round; does not stack with itself, refresh; rebuild unresolved queue | Reject no unresolved ally; AI uses before slow allies; counter by acting first or Speed Poison | Tooltip: `Unresolved allies gain 2 Speed for this round.` Log: `<actor> raised War Tempo for <allies>.` |
| Keep the Measure | Passive Signature; support; second adjacent allied committed action each round | Drummer gains +1 Power next action; once/round; Aggressive +2, Protective neighbors +1 Defense current round | Fewer than two adjacent actions, no trigger; AI stays central; counter by rotation | Tooltip: `Once per round after two neighboring allies act, gain 1 Power next action.` Log: `<actor> kept the measure and gained <bonus> Power.` |

## Class 6: Siegebreaker

**Role:** Anti-Defense heavy striker. **Rhythm:** Test armor, sunder it, finish under contact. **Weakness:** Slowest Orc and easy to rotate away. **Stats:** 25 Health, 8 Power, 2 Speed, 3 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Test the Guard | Active Opener; offense/debuff; one neighboring enemy; CD 1 | Deal 110% Power; apply Sunder -1 Defense for 2 rounds; max 1/source, refresh | Reject no neighbor; AI picks high Defense; counter with rotation/Cleanse | Tooltip: `Deal 110% Power and reduce Defense by 1 for 2 rounds.` Log: `<actor> tested <target>'s guard for <damage>.` |
| Sunder | Active Converter; offense/debuff; Sundered enemy; CD 3 | Deal 140% Power; increase this source's penalty to -2 and refresh 2 rounds, cap -2 | Reject no source Sunder; AI focuses same target; counter by Cleanse/Guard | Tooltip: `Deal 140% Power and deepen your Sunder to 2 Defense for 2 rounds.` Log: `<actor> sundered <target> for <damage>; Defense -2.` |
| Demolishing Blow | Active Pivot; offense/capstone; neighboring Sundered enemy; CD 5 | Deal 210% Power, then remove this source's Sunder | Reject no contact/Sunder; AI seeks lethal; counter by rotation or shield | Tooltip: `Deal 210% Power to a neighboring Sundered enemy, then remove Sunder.` Log: `<actor> demolished <target> for <damage>.` |
| Weight Behind It | Passive Signature; offense; first consecutive-round attack on same enemy | Ignore 1 Defense; once/round; Aggressive ignore 2, Protective gain +1 Defense through action | Target changed/no prior-round contact, no trigger; AI persists; counter by rotating target | Tooltip: `Once per round, repeated contact with the same enemy ignores 1 Defense.` Log: `<actor> put its weight behind the blow, ignoring <amount> Defense.` |

## Role Summary

| Class | Primary job | Signature mechanic |
|---|---|---|
| Iron Tusk Vanguard | Anchor | Contact protection |
| Bonebreaker Reaver | Bruiser | Controlled-target payoff |
| Bloodbanner Captain | Support | Formation durability |
| Chainwarden | Controller | Movement mark and bounded Stun |
| War Drummer | Cadence support | Local unresolved Speed |
| Siegebreaker | Specialist striker | Non-Poison Defense sunder |
