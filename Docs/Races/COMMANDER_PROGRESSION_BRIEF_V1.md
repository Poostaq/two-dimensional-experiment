# Commander Progression Brief V1.1

Date: 2026-08-28
Scope: Player-available core five races (Goblins, Orcs, Werewolves, Lizardmen, Harpies)

## 1) Design intent and progression pillars

- Commander choice must change both battle cadence and world-map decision quality.
- Every commander keeps its root class's three battle skills and adds one commander-specific fourth skill.
- Every commander gets exactly one world-map skill (active or passive).
- World-map power must avoid free movement-economy exploits and avoid invalid assumptions about hidden-map systems.
- Enemy displacement in battle is intentionally rare and never a baseline expectation for non-Harpy commanders.
- Identity boundaries stay intact:
  - Goblins remain broad setup/tempo glue.
  - Orcs remain contact-and-armor momentum.
  - Werewolves remain wounded-target execution and hunt pressure.
  - Lizardmen remain precision planning/attrition.
  - Harpies remain movement-led reposition specialists.

## 1A) Design locks for this revision

- Regular units retain 3 battle skills; commander units add exactly 1 commander skill.
- Most turns should be stationary skill choices; movement remains an optional defensive action.
- Enemy displacement is rare:
  - Non-Harpy commander skills cannot directly move enemies.
  - Harpy commander kit may reference hostile movement, but only as a single once-per-round trigger condition.
- Commander world-map skills cannot grant undocumented free movement economy.
- Any world-map skill with unresolved runtime dependency must declare a contract-safe fallback.

## 1B) Commander quick matrix

| Race | Commander | Battle signature focus | World-map focus | Enemy displacement usage | Runtime status |
|---|---|---|---|---|---|
| Goblins | Brakka Rustbanner | Advantage sequencing | Encounter prep leverage | None | Dependency + fallback |
| Orcs | Goruk Ironline | Contact armor discipline | Defensive route planning | None | Contract-safe now |
| Werewolves | Veyra Moontrace | Wounded threshold conversion | Boss-pressure forecasting | None | Dependency |
| Lizardmen | Sszek Still-Mire | Same-axis poison spread | Adjacent batch analysis | None | Contract-safe now |
| Harpies | Kyris Windscar | Movement-trigger ally follow-through | Route readability overlay | Trigger-only (no direct displacement skill) | Contract-safe now |

## 2) Skill roster candidates (commander cards)

### Goblins Commander

Name: Brakka Rustbanner, Packmarshal  
Theme: Frontline organizer who turns mixed crews into one action sequence.  
Fourth commander skill: Banner Holder (Passive)  
- Tactical moment: Start of Brakka eligible action, once per round.
- Effect: Apply Advantage to the active enemy closest to Brakka. Ties resolve frontline before backline, then lowest slot index.
- Counterplay: Change the closest target, defeat Brakka, or expire the token.

World-map passive: Scrapline Quartermaster (revised)
- Tactical moment: Gain 1 Cache charge every 4 accepted moves, maximum 1 stored.
- Effect: On entering the next Combat encounter, consume Cache and choose one prep bonus:
  - Frontline Briefing: choose one active enemy to start battle with Advantage.
  - Spare Plating: all frontline allies start battle with +2 Armor.
- Exclusions: No tile reveal, no movement range increase, no move_count behavior changes.
- Dependency: Requires pre-encounter modifier hook for battle start bonuses.
- Contract-safe fallback if hook is unavailable: consume Cache to reduce one selected allied skill cooldown by 1 at battle start, once per battle.

Gameplay fantasy hook: The crew always has one more rumor than the enemy.

### Orcs Commander

Name: Goruk Ironline, War-Khan  
Theme: Makes first contact stick and prevents line collapse.  
Battle signature passive (replaces Unbroken Contact): Iron Decree  
- Tactical moment: First time each round Goruk ends an action neighboring an enemy.
- Effect: Goruk gains 2 Armor; one neighboring ally gains 2 Armor (deterministic ally priority).
- Counterplay: Rotate Goruk off contact; isolate him from allied adjacency; status pressure.

World-map active: Siege March (revised)
- Tactical moment: Activated before movement; cooldown 6 accepted moves.
- Effect: Choose one adjacent legal hex and gain Route Fortified for the next accepted move toward it.
- Route Fortified: If that move enters Combat, frontline allies start the encounter with +2 Armor.
- Exclusions: No extra steps, no movement range increase, no move_count change behavior changes.
- Contract status: Compatible as a pre-move planning and durability effect under current flow.

Gameplay fantasy hook: Once the line commits, retreat options shrink.

### Werewolves Commander

Name: Veyra Moontrace, Hunt Matriarch  
Theme: Converts one blood-threshold moment into immediate pack pressure.  
Battle signature passive (replaces Fate Smells of Blood): Mark of the Alpha  
- Tactical moment: First enemy each round crossing below 50% HP from direct allied damage.
- Effect: Veyra gains Advantage; triggering ally gains +15% Leech on next eligible Active direct hit this round.
- Cap: Total Leech on that hit cannot exceed 50%.
- Counterplay: Threshold denial via Armor/Defense; disable triggering ally before consumption.

World-map passive: Apex Scent (revised)
- Tactical moment: Passive while Veyra is commander.
- Effect: Always show boss-pressure forecast as turns-to-contact band (Near 0-2, Mid 3-5, Far 6+), recalculated after each accepted move.
- Escalation: When Sudden Death is active, also show directionality hint (Closing, Stable, Widening) so the signal scales into late campaign pressure.
- Exclusions: No extra tile reveal; no movement bonus; no turn-count change.
- Dependency: Requires exposing pursuit-distance metadata to HUD.

Gameplay fantasy hook: The pack reads when the kill window opens, not just where prey stands.

### Lizardmen Commander

Name: Sszek Still-Mire, Delta Strategist  
Theme: Extends single-axis poison plans into controlled area pressure.  
Battle signature passive (replaces Exact Mixture): Cartographer of Venoms  
- Tactical moment: First same-axis reapplication each round by Sszek to a target already carrying Sszek poison.
- Effect: Also apply 1 stack of that same axis to one adjacent enemy for 2 rounds.
- Safeguards: Secondary stack cannot trigger passives and cannot refresh itself.
- Counterplay: Remove Sszek; break adjacency; force axis mismatch.

World-map active: Survey the Ground (revised)
- Tactical moment: No-move action on current hex; cooldown 5 accepted moves.
- Effect: Single panel summary for all adjacent cells (encounter type + terrain tags) in one activation.
- Exclusions: No beyond-adjacent reveal; no boss prediction; no move_count change.
- Contract status: Compatible as UI-compression utility under current inspect behavior.

Gameplay fantasy hook: Planning advantage comes from precise local reads, not omniscience.

### Harpies Commander

Name: Kyris Windscar, Sky Matron  
Theme: Turns one successful displacement into a controlled ally follow-through.  
Battle signature passive (replaces Clear Sightline): Open-Sky Command  
- Tactical moment: First successful hostile movement each round caused by Kyris.
- Effect: Chosen ally may rotate Move 1 immediately after its next Active direct hit this round.
- Eligibility: Consume only on hit dealing at least 1 HP after Defense/Armor.
- Counterplay: Break initial displacement; force path illegality; deny useful post-hit slots.

World-map passive: High Thermals (revised)
- Tactical moment: Passive while Kyris leads.
- Effect: Improves route readability by pre-highlighting legal two-step movement chains from current hex.
- Exclusions: No hidden-tile reveal, no boss reveal change, no move_count change.
- Contract status: Compatible if implemented as path-preview overlay only.

Gameplay fantasy hook: Aerial perspective converts movement options into immediate positional plans.

## 3) Deferred commander progression candidates

The following tree, XP curve, specialization, and respec values are retained for future evaluation only. They are not implementation requirements for the Goblin milestone.

### Candidate tree structure

- Tier C1 (unlock level 1): Commander selection unlock; grants battle signature passive swap.
- Tier C2 (unlock level 3): World-map skill unlock (base effect only).
- Tier C3 (unlock level 5): Commander specialization branch, choose one:
  - Branch A: Battle-focus (stronger trigger reliability, unchanged world skill).
  - Branch B: World-focus (clarity and reliability only; no extra movement economy).
- Respec policy:
  - Free respec at run start.
  - Mid-run respec costs one commander token and disables world-map skill for next 2 accepted moves.

## 4) Progression curves

- Commander XP pacing:
  - Level 1 to 2: 120 XP
  - Level 2 to 3: 180 XP
  - Level 3 to 4: 260 XP
  - Level 4 to 5: 360 XP
- Gain model:
  - +20 XP Combat victory
  - +8 XP Safe resolved objective
  - +12 XP Boss pressure event survived
- Power breakpoint policy:
  - C1 should feel like about 8-12% net combat value swing in ideal conditions.
  - C2 should create decision clarity, not raw map speed.
  - C3 branch bonuses should add about 4-7% relative value over C2 baseline.

## 5) Skill interactions, combos, counterplay, edge cases

- Goblin Brakka combo: Banner Holder -> Orc converter or Werewolf finisher.
- Orc Goruk combo: Harpy forced movement into contact -> Iron Decree stabilizes retaliation.
- Werewolf Veyra combo: Lizardman attrition crosses 50% -> Mark of the Alpha creates burst-heal turn.
- Lizardman Sszek combo: Same-axis stack plan -> splash stack creates multi-target attrition fork.
- Harpy Kyris combo: Move 2/3 opener -> ally hit -> post-hit Move 1 enables safe disengage.

Edge-case rules
- No world-map skill may change move_count unless explicitly declared and tested.
- Any world-map action with no movement cannot trigger encounter entry.
- Boss-reveal authority remains unchanged unless a dedicated visibility contract is approved.
- Commander passives follow once-per-round guards and deterministic tie-break ordering.
- Commander skills may not create infinite trigger loops from passive-to-passive chains.
- Harpy commander trigger checks revalidate legality at consumption time, not trigger time.
- If a dependency-backed world skill is unavailable, the fallback behavior is mandatory rather than optional.

## 6) Race identity through commanders

- Goblins: coalition setup certainty without direct stat brute force.
- Orcs: positional commitment and line durability.
- Werewolves: threshold execution timing and offensive sustain windows.
- Lizardmen: deterministic planning and axis discipline.
- Harpies: movement-derived tactical geometry.

Party responsibility read
- Goblin commander calls sequencing windows.
- Orc commander secures contact lane.
- Werewolf commander calls execute timing.
- Lizard commander calls target-priority attrition plan.
- Harpy commander calls displacement-to-angle conversions.

## 7) Tuning ranges

- Battle passive triggers: once per round baseline, optional hard cap once per battle only for extreme effects.
- Bonus Armor from commander passives: 2-3 per trigger, never above Armor cap rules.
- Advantage grants: 1 token, non-stacking, round-expiry only.
- Leech modifiers: +10% to +15% additive riders, total capped at 50%.
- World-map actives cooldown band: 5-8 accepted moves.
- World-map passives: information quality or path readability only unless explicitly approved for economy changes.
- Enemy displacement budget at commander layer: 0 direct enemy-move effects outside Harpies.

## 8) Acceptance criteria for implementation readiness

1. One commander entry exists for each of the five player-available races.
2. Every commander defines:
   - one theme statement,
   - one fourth commander skill added to the root class's three skills,
   - one world-map skill with trigger, effect, exclusions, and cooldown if active.
3. Every commander has explicit counterplay and at least one edge-case guard.
4. World-map skills are tagged either:
   - Contract-safe now, or
   - Dependency on future visibility/transaction contracts.
5. No commander world-map skill grants undocumented free movement economy.
6. Advantage, Armor, Leech, and movement language remains consistent with shared keyword contracts.
7. Commander progression includes unlock tiers and respec policy.
8. Numerical ranges stay within listed tuning bands for post-implementation balancing.
9. Commander layer maintains enemy displacement rarity and keeps it as a Harpy-limited trigger pattern.

## Gameplay Systems Designer review log

- Brakka Rustbanner: Revised after review findings to replace nearby-visibility reveal with campaign-long encounter-prep utility.
- Goruk Ironline: Revised after review findings to remove extra-step movement economy and replace it with route durability planning.
- Veyra Moontrace: Revised after review findings to replace redundant boss-location reveal with boss-pressure forecast utility and explicit Leech cap wording.
- Sszek Still-Mire: Revised after review findings to narrow spread-trigger scope and define no-chain safeguards.
- Kyris Windscar: Revised after review findings to replace hidden-reveal scouting with path-readability overlay and strict post-hit consumption rules.
