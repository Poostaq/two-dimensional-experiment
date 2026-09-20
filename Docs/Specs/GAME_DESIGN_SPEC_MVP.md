# Design Spec: Fantasy Turn-Based Roguelike MVP

**Project:** Two-Dimension Exploration  
**Target Platform:** Godot 4.7  
**Scope:** Small-to-Medium (MVP focus)  
**Status:** Ready for Implementation  

---

## 1. GAME OVERVIEW

The player selects a main clan and its commander, then begins a seeded hex-world run with 100g. Two distinct allied clans are selected randomly, with at least one synergistic with the main clan. Each of the three allied habitats contains three towns. The player starts on the easternmost hex inside their main clan's habitat; a seeded Human, Elven or Dwarven commander-led enemy party starts on the westernmost hex.

Win battles to earn 50g per defeated enemy, then recruit at allied towns for 500g per character, up to a six-character roster. Each town offers its own clan's classes that are absent from the current roster. The enemy party targets and besieges allied towns, leaving traversable ruins without services. After all nine allied towns are burned, it pursues the player. Defeating the commander-led enemy party wins the run; losing the player's entire party in battle loses the run.

AC8.1-AC8.3 are implemented and verified; the remaining AC8-AC10 criteria below define planned behavior. They replace reward-choice recruitment and move-count-based Sudden Death. Cross-run progression and unrelated AC5 questions remain deferred.

---

## 2. CORE MECHANICS

- **World Map Traversal** - Explore a seeded hex world with three allied habitats, nine towns and roads; start in the east while the enemy commander party advances from the west
- **Turn-Based Combat (Player-Controlled)** — Battles take place on a 6-slot player side and 6-slot enemy side; units act in speed order; players choose each unit action; skills may have positional requirements, condition requirements, and either pre-use cooldowns or cooldowns applied after use
- **Unit Recruitment** - Spend 500g in an intact allied town to recruit a class from its clan absent from the current roster; retain the six-character cap and placement/replacement flow
- **Party Management** — Player can freely rearrange the active 6-character lineup before and after fights through a party-management UI for tactical preparation
- **Equipment & Stat Management** — Characters have predetermined base stats; equipment can be freely removed and reassigned between eligible characters, and usually grants stat bonuses or mechanical changes while respecting item restrictions such as race
- **Meta-Progression** — Cross-run unlocks are deferred to a later consideration pass; the MVP currently focuses on run-local structure, deterministic progression, and combat loop behavior

---

## 3. WIN & LOSS CONDITIONS

| Condition | Trigger |
|-----------|---------|
| **WIN** | Defeat the main enemy commander-led party in battle |
| **LOSS** | All player units reduced to 0 HP in a single battle. The run ends and the player returns to the main menu; the lost run cannot be continued, so the player must start a new run. |

**Units revive between battles** — After victory, characters who passed out during the battle return for the next battle at 50% health, with harder difficulties able to reduce that recovery value further. Units do not permanently die.

---

## 4. DESIGN DECISIONS (MVP)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Map Layout** | Three allied habitats with three towns each; western enemy habitat extends two hexes from its spawn | Seeded territory and town-road planning under AC9; retain the current radius-8 board provisionally, subject to generation feasibility |
| **Campaign Pressure** | Siege and burn every allied town, then pursue the player | AC10 replaces move-count-based Sudden Death |
| **Boss Party** | Main enemy clan commander and supporting party; balance through playtesting | No inherited Sudden Death activation or automatic empowerment |
| **Permadeath** | Units revive after victory; a lost fight ends the run | Individual knockouts do not permanently remove units; full-party defeat requires a new run |
| **Max Roster** | 6 units | Tight team building; every unit matters; manageable scope |
| **Difficulty Modes** | None for MVP | Deferred post-launch; single balanced difficulty for testing |

---

## 5. CORE STATS & SCALING

### Unit Stats (Per Character)

| Stat | Range | Purpose |
|------|-------|---------|
| `health` | 10–30 | Survivability; around 10 for squishy casters and around 30 for seasoned warrior types |
| `power` | 1–10 | Base output value used to scale damaging, healing, and support skill effects |
| `speed` | 1–10 | Turn order baseline; higher values act earlier, with multi-action behavior still to be decided |
| `defense` | 0–5 | Flat damage reduction baseline; most characters start at 0 defense |
| `progression_state` | Varies by character type | Tracks level, evolution state, or upgrade tier depending on the character |

### Character Definition

- **Identity:** Each character is defined by a name, race, and class
- **Stats:** Each character uses the stat model defined in this section
- **Skill Loadout:** Each character has up to 4 character-specific skills plus 2 default actions shared by all characters
- **Skill Type:** Each character-specific skill is classified as either active or passive
- **Default Attack:** Every character can use a default attack that applies its power value
- **Default Swap:** Every character can use a default swap action to exchange places with an adjacent allied character
- **Turn Usage Limit:** A character can use only 1 active skill per turn
- **Skill Description Requirement:** Every character-specific skill must expose a player-visible name and description before use
- **Description Content:** A skill description must explain, in player-readable language, the skill's effect and any relevant targeting, positional requirement, condition requirement, cooldown timing, and notable limitations
- **Description Visibility:** The player must be able to inspect a skill's description from at least one stable UI surface before committing the action; passive skill descriptions must also be inspectable even when the passive is not directly activated

### AC2.3 Debug Damage Slice

- **Debug Health:** AC2.3 battle fixtures start at `20/20 HP`.
- **Debug Damage:** The current unit's temporary debug action deals a fixed `7` damage, then advances the turn once.
- **Closest Enemy:** Targets are selected deterministically by same-row distance, then front before back, then lowest semantic slot index.
- **Defeat:** Units at `0 HP` remain visible as defeated but are removed immediately from targeting and turn order.
- **Battle Log:** A full-width scrollable log records round, attacker, receiver, applied damage, remaining HP, and defeat.
- **Damage Feedback:** Resolution highlights the attacker green and receiver red for `0.8` seconds while showing the receiver's negative applied damage.
- **Log Inspection:** Hovering a historical entry reproduces its attacker/receiver highlights and damage value until pointer exit.
- **Result Boundary:** An arena with no active opponent disables damage but does not announce victory or loss; AC2.4 owns battle results.

### Character Progression

- **Base Stats:** Each character has a predefined stat line before equipment modifiers
- **Stat Scale:** Skills can scale their effects beyond base power through multipliers and effect-specific modifiers
- **Power Scaling:** Damaging, healing, and temporary-boost skills can scale from the character's power stat using a skill-specific percentage modifier
- **Scaling Examples:** A single-target heal might use 150% of power, while an area heal might use 30% of power
- **Rounding Policy:** Final rounded values for scaled effects may round up or down depending on final difficulty and balance rules, still to be defined
- **Speed Tuning:** Speed currently defines action order; whether very fast characters can act multiple times in one round remains to be defined later
- **Leveling Characters:** Some characters gain experience and improve stats through level-ups
- **Evolution Characters:** Some characters evolve into a new class rather than following a standard level curve
- **Mechanical Units:** Some characters do not gain experience and instead receive permanent upgrades or bonuses through other systems
- **Tuning Status:** Exact formulas, thresholds, and supported progression types remain to be defined later

### Equipment

- **Slots per unit:** 4 (weapon, armor, accessory, special)
- **Transfer Rules:** Equipment can be removed and reassigned freely between eligible characters
- **Restrictions:** Equipment may be restricted by race or other item-specific rules
- **Effects:** Equipment usually grants stat bonuses or mechanical changes
- **Ownership Model:** Equipment is not permanently bound to one character; unequipping returns it to the shared inventory

---

## 6. COMBAT FLOW

**Battle Arena:**
- Combat uses 6 player slots and 6 enemy slots in opposing formations
- Position inside those slots matters for skills, targeting, and swap actions

**Turn-Based Order:**
1. Calculate action queue (sort by speed stat, descending)
2. Execute actions in order:
   - Player selects an available skill or action for the acting unit
   - The acting unit can use at most 1 active skill during its turn
   - Default actions such as basic attack and adjacent swap are always available unless blocked by battle conditions
   - Validate positional requirements, condition requirements, and any pre-use cooldown requirement before execution
   - Resolve damage/healing/effects
   - Apply post-use cooldown when the chosen skill uses cooldown-after-use timing
   - Decrement active cooldown counters after the player action is resolved
   - Check for defeated units (remove from battle)
3. Repeat until one side has 0 units

**Combo System:**
- Skills can grant bonus effects when their specific combo conditions are met

**Skill Cooldown:**
- Range: 0–5 player actions
- Some skills require their cooldown to be clear before use, while others enter cooldown only after use
- Cooldowns decrement each time the player resolves an action; a skill is ready when its relevant cooldown requirement is satisfied

---

## 7. RECRUITMENT & ECONOMY

| Action | Gold | Effect |
|--------|------|--------|
| **Start New Run** | 100g initial balance | Initialize the run wallet once |
| **Win Battle** | +50g per distinct defeated enemy character | Show a money icon and the earned amount; replace previous reward choices |
| **Recruit in Town** | -500g | Add an eligible character through placement/replacement, with a six-character roster cap |
| **Lose Battle** | Run lost; no reward | Return to the main menu and start a new run; no gold for enemies defeated in a lost fight and no Continue for that run |

`g` means gold. A three-enemy victory awards 150g. From the initial 100g, eight enemy defeats in won battles fund the first recruit.

Towns offer only recruitable classes belonging to their own habitat's clan and absent from the entire current roster. Canonical class identity determines eligibility; a passed-out roster member still counts. Offers refresh after roster changes and reload. Removing the final member of a class makes it eligible again. An empty eligible set produces a clear empty state, not a duplicate-class fallback.

**Interim rule before habitats:** Every existing town counts as Goblin habitat and offers only eligible Goblin classes. Implement AC8 against the existing towns without waiting for habitat generation. This does not change their count, placement or roads. Once habitats are implemented, habitat-enabled worlds use each town's explicit owning clan; preserve the Goblin-town rule for pre-habitat world versions rather than silently reassigning existing saves.

Purchases revalidate class absence, town availability and funds at commit. Roster placement/replacement and the 500g deduction form one durable transaction. Cancellation, failed saves and repeated/stale requests must not charge or add a duplicate. Gold awards are settled once per battle and survive reload without duplication. Existing post-battle recovery remains in effect.

Burned towns have no services, although their hexes and roads remain traversable. Siege duration and the proposed suspension of services during a siege are described in the AC10 plan.

---

## 8. META-PROGRESSION

**Run Completion Unlocks:**
- Completing the run (defeating the boss) unlocks specific characters or items for future runs
- Unlock outcomes are tied to predefined rewards rather than a generic progression resource

**Special Event Unlocks:**
- Some characters are unlocked by completing specific events or encounter chains
- Some items are unlocked by resolving special events or meeting event conditions
- Unlock mapping and event requirements remain to be tuned

---

## 9. DETERMINISM (Critical for Roguelike Replayability)

- **Run ID** seeds all RNG: enemy composition, hex encounters, loot drops, and unit acquisition opportunities
- **Same run ID + same decisions = identical battles** (enables coaching, replay analysis)
- **Logging:** Every RNG call is recorded; replay any sequence with predictable outcomes

---

## 10. ACCEPTANCE CRITERIA (MVP Scope)

### Map & Navigation
- [x] AC1.1 - Historical 25-hex movement milestone; AC9 supersedes its map layout and start/objective placement. Adjacent movement remains a regression requirement.
- [x] AC1.2 — Hex encounter types (Safe/Combat/Boss) are seeded and deterministic per run ID
- [x] AC1.3 — World-map navigation is controlled by mouse selection of adjacent hexes (no Q/W/E/A/S/D movement requirement)
- [x] AC1.4 — Entering any map hex automatically opens an Encounter overlay for that hex's seeded encounter type
- [x] AC1.5 - Historical move-count-based Sudden Death milestone, superseded by AC10 for the new campaign rules; not an active requirement to retain the timer or empowerment.

### Combat System
- [x] AC2.1 — Battles use a 6-slot player side and a 6-slot enemy side
- [x] AC2.2 — Faster units act earlier according to speed order
- [x] AC2.3 — Unit takes damage; at 0 HP, removed from battle
- [x] AC2.4 — Player wins if all enemies defeated; loses if all units defeated
- [x] AC2.5 - Historical post-battle reward-choice milestone, superseded by AC8 gold rewards and town recruitment. Battle result idempotence remains a regression requirement.
- [x] AC2.6 — Each character can expose up to 4 character-specific skills, and each skill is identified as active or passive
- [x] AC2.7 — The player can inspect a readable description for each skill before committing an action, including passive skills from an inspectable UI surface
- [x] AC2.8 — Skills support positional requirements, condition requirements, and either pre-use cooldowns or cooldowns applied after use
- [x] AC2.9 — Skills grant combo bonuses only when their specific combo conditions are met

### Unit Management
- [x] AC3.1 — Player can acquire a unit from a valid run-based source if roster < 6
- [x] AC3.2 — If the roster is already full at 6 characters, the player must dismiss one character before acquiring a new one
- [x] AC3.3 — Player can freely rearrange the active party before and after fights through a party-management interface
- [x] AC3.4 — Every character has a default attack and a default adjacent-swap action in addition to its character-specific skills
- [x] AC3.5 — After battle victory, characters who passed out return for the next battle at 50% health, with lower recovery allowed on harder difficulties

### To Consider: Meta-Progression
See [Docs/TO_CONSIDER.md](../TO_CONSIDER.md) for the deferred unlock questions that were previously grouped as AC4.

### To Consider: Roguelike Structure (AC5)
All of AC5 is deferred because both meta-progression and roguelike structure need to be rethought. See [TC-007](../TO_CONSIDER.md#tc-007--how-should-run-independence-fit-the-revised-roguelike-structure).

- **TO CONSIDER — AC5.1:** Each run is seeded and independent; prior run roster does not carry over
- **TO CONSIDER — AC5.2:** Unlocked characters, items, and event-driven progression persist across runs
- **TO CONSIDER — AC5.3:** Run ID uniquely identifies a playable sequence; same ID = reproducible battles

### Goblin Combat Vertical Slice
- [x] AC6.1 — Shared Power, Defense, physical damage, default actions, formation movement, and committed-action history foundation
- [x] AC6.2 — Shared Advantage, Snared, Armor, Bleed, temporary Speed, cooldown adjustment, and bounded Passive reaction foundation
- [x] AC6.3 — Goblin Wave A classes and their nine authored skills
- [x] AC6.4 — Goblin Wave B classes and their nine authored skills
- [x] AC6.5 — Brakka Rustbanner is selectable before seed entry, starts in middle frontline slot 1, and Banner Holder deterministically applies Advantage once per round to the closest active enemy
- [x] AC6.6 — Scrapline Quartermaster Cache state and pre-battle preparation choice
- [x] AC6.7 — Full production Goblin integration, reward, save/reload, and next-battle gate

### Battle UI Presentation
- [x] AC7.1 — Battles present both six-slot formations as readable backline/frontline character lanes with character identity, HP, role, and active status iconography visible without opening a separate screen ([verification](AC7/Evidence/AC7.1/verification.md))
- [x] AC7.2 — The turn-order ribbon gives the current actor a persistent framed `NOW` treatment and highlights the corresponding battlefield character while its turn-order entry is hovered or keyboard-focused ([verification](AC7/Evidence/AC7.2/verification.md))
- [x] AC7.3 — The active player character's full skill controls share one action bar with compact, accessible Default Attack and Default Swap icon actions, while preserving the existing preview, target, confirm, cancel, and turn-lock behavior ([verification](AC7/Evidence/AC7.3/verification.md))
- [x] AC7.4 — A collapsed edge handle opens an overlay debug drawer containing the battle log, live battle state, initiative queue, and existing debug commands without shifting or resizing the player-facing battle layout ([verification](AC7/Evidence/AC7.4/verification.md))
- [x] AC7.5 — Battles use one deterministic, accessible visual-state language for the current actor, turn-order preview, hovered-skill target preview, selected-action valid targets, selected targets, Default Attack targets, Default Swap targets, invalid or unavailable units, and actions with no legal targets; transient highlights clear correctly when hover, focus, selection, turn, phase, or battle state changes ([verification](AC7/Evidence/AC7.5/verification.md))
- [x] AC7.6 — Active battle skills have equal rendered button dimensions and hover/focus descriptions while default controls retain their sizes. Right-clicking an allied or enemy character opens a left-side information panel with name/class-role, HP, speed, base damage, flat damage reduction, buffs/debuffs with accurate expiry, and visible passive descriptions. Inspection uses complete committed snapshots, preserves pending battle actions, and obeys explicit modal, pointer, keyboard and focus precedence. Passives leave the battle action bar without changing their mechanics. ([plan](../superpowers/plans/2026-09-18-battle-skill-and-character-information.md), [verification — NOT RUN](AC7/Evidence/AC7.6/verification.md))

AC7.6 owns the character-information and skill-sizing change. It supersedes only AC2.6, AC2.7 and AC7.3 presentation expectations that passive skills occupy battle action buttons and are inspected through those buttons; their skill-data, passive-mechanics, tooltip-content, default-action and turn-lock contracts remain regression requirements. Existing PASS records describe their historical implementation and do not establish AC7.6 completion.

AC7.4 is a required AC7.6 integration dependency for debug-drawer layering, Escape arbitration, focus restoration and modal ownership. AC7.6 acceptance requires fresh `Tests/Battle/test_ac7_4_debug_drawer.gd` regression results and two-panel interaction coverage in `Tests/Battle/test_battle_character_inspection.gd`, recorded in AC7.6 verification; historical AC7.4 PASS alone is insufficient.

### AC8 — Town Recruitment and Gold

Plan: [AC8 implementation plan](../superpowers/plans/2026-09-18-ac8-town-recruitment-and-gold.md). AC8.1-AC8.3 are implemented and verified; AC8.4-AC8.8 remain planned and unchecked. See [AC8.2 evidence](AC8/Evidence/AC8.2/verification.md) and [AC8.3 evidence](AC8/Evidence/AC8.3/verification.md).

Focused plan: [AC8.1 starting gold and HUD](../superpowers/plans/2026-09-19-ac8-1-starting-gold-and-hud.md).

- [x] AC8.1 — A new run starts with exactly 100g; the current gold balance is visible on the world HUD.
- [x] AC8.2 — Each won fight awards 50g per distinct defeated enemy character. Losing any fight, including an ordinary encounter or boss fight, ends the current run and returns the player to the main menu. The lost run cannot be continued, including after restarting the application; the player must start a new run. Lost fights award no gold, even if some enemies were defeated; duplicate defeat/result events cannot increase the award or repeat run termination.
- [x] AC8.3 — Victory shows a reward screen with a money icon and the exact gold amount received. This replaces all previous post-battle reward choices, including recruitment choices, while preserving post-battle health recovery.
- [ ] AC8.4 — Before habitats are implemented, every existing town counts as Goblin habitat and offers only Goblin classes absent from the current roster. This works on the existing map and after reload, without requiring habitat generation or changing town count, placement, roads or spawns. Habitat-enabled worlds later use explicit clan ownership.
- [ ] AC8.5 — Recruitment is available in intact allied towns at exactly 500g per character. Each town offers only recruitable classes from its habitat's clan.
- [ ] AC8.6 — Towns offer only classes absent from the whole current roster, including passed-out members. Offers refresh after recruitment, dismissal/replacement and reload; a class becomes eligible again when its final roster member leaves. Empty eligibility shows no purchasable offer, and stale requests cannot bypass this rule.
- [ ] AC8.7 — Recruitment preserves the six-member limit and chosen-slot placement/replacement. Insufficient funds, cancelled placement, invalid/stale requests and failed saves leave gold and roster unchanged.
- [ ] AC8.8 — Wallet, reward settlement and recruitment are durable and atomic. Save retry, reload and repeated input never duplicate a reward, character or charge. Burned towns reject recruitment through both UI and domain entry points.

### AC9 — Seeded Clans, Habitats and Roads

Plan: [AC9 implementation plan](../superpowers/plans/2026-09-18-ac9-clans-and-habitats.md).

- [ ] AC9.0 — Implement and verify the remaining races and their commanders before starting habitat, habitat-town-placement or inter-habitat-road implementation. This includes remaining Orc, Lizardman, Harpy, Werewolf, Human, Elven and Dwarven content appropriate to player/enemy roles: approved classes/skills, commander mechanics, presentation, battle integration and durable identities. Existing completed content may be reused after verification; lore, placeholder commanders and debug teams alone do not satisfy this prerequisite.
- [ ] AC9.1 — The player selects a main clan and a commander belonging to it before the new world is created; invalid clan/commander combinations are rejected.
- [ ] AC9.2 — Select exactly two distinct other allied clans randomly from the eligible clan pool, with at least one synergistic with the main clan. All three allied clan identities are distinct; selection uses explicit catalog synergy data and the resolved run seed.
- [ ] AC9.3 — After player setup and seed resolution, select one main enemy clan from Human, Elven or Dwarven using the seed. Its commander-led party is the main enemy/boss party, with authored clan-appropriate content.
- [ ] AC9.4 — The player starts on the easternmost map hex inside the main clan's habitat. The enemy starts on the westernmost hex. Enemy habitat covers every on-map hex within distance two of that spawn, clipped at the map boundary.
- [ ] AC9.5 — Each of the three allied clans has its own habitat containing exactly three seeded, distinct town placements: nine allied towns total. The enemy habitat contains no towns and is excluded from town-road endpoint pairing.
- [ ] AC9.6 — Within each allied habitat, each of its three towns has a road connection to both others: all three town pairs are connected.
- [ ] AC9.7 — Every pair of allied habitats has road connections between its closest cross-habitat town pair(s). Include every endpoint pair tied at the minimum distance, rather than selecting just one of the ties. One deterministic shortest road route per selected pair suffices; shared segments are deduplicated.
- [ ] AC9.8 — Same resolved seed, player configuration and generator version reproduce initial clan selections, habitats, towns, roads and spawns. Continue restores the saved selections/topology without rerolling. Generation publishes only a complete valid world; failed generation preserves the prior save.
- [ ] AC9.9 — Start New Run proceeds without any save-overwrite confirmation. Persist the complete candidate run atomically before replacing the prior save, preserve it on failure, and prevent duplicate Start submissions. This supersedes only the overwrite-confirmation proposal in deferred AC5.1; other AC5 questions stay deferred.
- [ ] AC9.10 — Map/minimap presentation makes habitat ownership, towns, roads and both party positions inspectable. Version generated topology and saves explicitly; do not reinterpret old world data with a new generator or claim existing fixtures verify the new topology.

### AC10 — Enemy Town Sieges and Pursuit

Plan: [AC10 implementation plan](../superpowers/plans/2026-09-18-ac10-enemy-town-siege-ai.md).

- [ ] AC10.1 — When choosing a target, the main enemy party selects the closest intact player-allied town by traversable hex distance. Equal-distance ties use seeded random selection, and the party retains that target until reached or invalidated rather than switching/rerolling each turn.
- [ ] AC10.2 — Enemy campaign actions advance with accepted world turns. Rejected or modal-blocked movement, battle rounds, reward/town UI actions and save retries do not independently advance enemy movement or siege time. The initial proposed rate is one enemy hex per accepted player move.
- [ ] AC10.3 — Arrival starts a visible siege instead of immediately burning the town. Give the player an interception opportunity before destruction. The plan proposes one complete player world-turn opportunity after arrival; arrival does not itself consume the siege countdown.
- [ ] AC10.4 — Completing the siege marks that town burned and permanently disables its town services for the run. Its hex remains traversable ruins and roads remain usable. Town destruction occurs exactly once.
- [ ] AC10.5 — The enemy continues targeting towns until all nine allied towns are burned, then actively pursues the player. A smaller destruction threshold is outside the first version. Pursuit follows the player's changing map position.
- [ ] AC10.6 — Replace current move-count-based Sudden Death and its automatic boss empowerment. Ordinary world-turn accounting remains available for unrelated existing systems; no old move threshold may trigger early pursuit in a new-rule run.
- [ ] AC10.7 — Player/enemy interception opens the commander-party battle once, including at a besieged town. Resolve interception before burning that town or opening an ordinary encounter at the same destination. Defeating the enemy party wins the run; losing the player's party loses it.
- [ ] AC10.8 — Save/reload preserves enemy position, party identity, AI mode, locked target, seeded selection progress, siege countdown and every town's status. Player movement, enemy action and town changes commit atomically; failure/retry cannot move twice, reroll or burn twice. An unreachable intact town is an explicit navigation failure, not evidence that all towns burned.
- [ ] AC10.9 — The world HUD/minimap distinguish intact, besieged and burned towns and communicate remaining allied towns and pursuit state. Verify a full nine-town destruction sequence and both early interception outcomes.

**Supersession and status:** Historical checked AC1.1, AC1.5 and AC2.5 records remain historical evidence only. AC8 supersedes reward-based recruitment portions of AC3.1/AC3.2 and AC6.7 while preserving roster, formation, recovery and save integrity. AC9 supersedes old fixed town counts, minimum-spanning-tree-only roads and spawn orientation. AC10 supersedes Sudden Death. New acceptance requires fresh AC8-AC10 evidence; documentation updates do not mark implementation complete. Proposed pacing, habitat partition, content readiness and old-save compatibility details remain explicitly distinguished in the linked plans.

### Verification Paths

Rows for superseded milestones describe historical checks. Use AC8-AC10 rows for the new economy and campaign; adapt retained roster/save regressions to town recruitment. The new test paths below are planned additions, not existing passing tests.

| AC ID | Verification Type | Verification Path |
|------|-------------------|-------------------|
| `AC1.1` | Manual runtime check | Start a run on a 25-hex map, move from the starting corner, and confirm the player can traverse valid adjacent hexes toward the opposite-corner boss objective. |
| `AC1.2` | Determinism check | Start two runs with the same Run ID and confirm the Safe/Combat/Boss hex layout is identical; start a run with a different Run ID and confirm the layout can differ. The AC1.2 fixture pair `AC1.2-A` and `AC1.2-B` is expected to differ by at least one non-boss tile under the documented hash algorithm. |
| `AC1.3` | Manual runtime check | Use mouse clicks on adjacent hexes to move the player marker. Confirm valid adjacent clicks move exactly one hex and invalid or non-adjacent clicks do not move the player. |
| `AC1.4` | Automated and manual runtime check | Enter Safe, Combat, and Boss hexes and verify each accepted move immediately opens one input-blocking Encounter overlay with the matching seeded type. Close it with `Close (Debug)` and verify the player remains on the entered hex with navigation restored. |
| `AC1.5` | Automated and manual runtime check | Run `Tests/Map/test_ac1_5_sudden_death.gd` to verify the move-15 activation boundary, deterministic shortest-path tie-breaking, one-step pursuit from move 16 onward, both engagement directions, runtime Boss identity, and reset behavior. Then avoid the boss for 15 player moves in the running game and confirm Sudden Death activates before one boss step follows each subsequent accepted player move until engagement. |
| `AC2.1` | Manual runtime check | Enter battle and verify the battlefield shows exactly 6 player slots and 6 enemy slots. |
| `AC2.2` | Manual runtime check | Start a battle with at least two units of different speed values and confirm action order follows descending speed. |
| `AC2.3` | Automated and manual runtime check | Run `Tests/Battle/test_ac2_3_damage_defeat_log.gd`, then use the debug damage action in battle. Verify deterministic closest-enemy targeting, fixed `7` damage with zero clamping, immediate defeated-unit queue/target exclusion, one turn advance and log entry per action, transient negative damage feedback, scroll-to-newest history, and green-attacker/red-receiver hover inspection. |
| `AC2.4` | Automated and manual runtime check | Run `Tests/Battle/test_ac2_4_battle_results.gd` to verify pure outcome evaluation, final-hit victory and defeat, terminal idempotence, reset behavior, and exact persistent result presentation. Then complete Combat and Boss battles in both directions, confirming `Victory` after all enemies fall, `Defeat` after all player units fall, frozen combat mutation after completion, readable persistent presentation, and a working debug exit. |
| `AC2.5` | Automated and manual runtime check | Run `Tests/Battle/test_ac2_5_reward_selection.gd` to verify the fixed Combat/Boss catalogs, explicit selection and Confirm gating, typed signal order and idempotence, defeat and unsupported-event behavior, cleanup, reset, and new-battle isolation. Then win Combat and Boss battles, verify each presents its three appropriate fixed options, select and confirm one, confirm the reward screen disappears with the fight, and verify the next battle starts without stale reward UI or selection. |
| `AC2.6` | Automated and manual runtime check | Run `Tests/Battle/test_ac2_6_character_skills.gd` to verify runtime-safe invalid skill and roster rejection, defensive skill-object and roster-array copying, typed Active/Passive identity, zero-to-four limits, exact player/enemy fixtures, persistent inspector reshaping, selected-character slot inspection, numbered square skill buttons, non-actionable skill selection, zero-skill and empty-slot behavior, defeated-unit retention, selection cleanup, and four-skill viewport fit. Then inspect multiple player and enemy characters in battle, verify each exposes 0 to 4 character-specific skill buttons labeled Active or Passive, and confirm selecting a skill button highlights it without resolving a battle action. |
| `AC2.7` | Automated and manual runtime check | Run `Tests/Battle/test_ac2_7_skill_preview.gd` to verify required structured effect, targeting, requirements, and cooldown text; runtime-safe blank rejection; defensive copying; exact ten-skill player/two-enemy fixture; hover-only active and passive tooltip states; immediate exit dismissal; click non-pinning; lifecycle cleanup; stale and duplicate event guards; non-actionability; above-button placement; horizontal viewport clamping; below-button fallback; and target-viewport no-clipping coverage. Then hover active and passive skills on both battle sides at 1152×648 without clicking and confirm the name, kind, and all four rows appear together above the button, remain inside the viewport without clipping or overlap, update when the hovered skill changes, and disappear immediately when the pointer leaves, including after a click. |
| `AC2.8` | Manual runtime check | Use skills with positional requirements, condition requirements, pre-use cooldowns, and post-use cooldowns, verifying invalid uses are blocked and valid uses resolve correctly. |
| `AC2.9` | Automated and manual runtime check | Run `Tests/Battle/test_ac2_9_combo_system.gd` to verify generic combo evaluation, Quick Strike/Combo Probe parity, positive and negative combo cases, authoritative history ownership, lifecycle cleanup, and runtime visual confirmation. |
| `AC3.1` | Automated and manual runtime check | Run `Tests/Run/test_ac3_1_run_roster.gd`, `Tests/Map/test_ac3_1_recruitment_integration.gd`, and `Tests/Map/test_ac3_3_party_management_integration.gd` to verify the three-character starter roster, six-unit capacity, duplicate/full/invalid rejection, eligible reward filtering, defensive fresh battle conversion, run reset, cancellable pending placement, and exact chosen-slot population in the next battle. Then recruit Scout from a Combat victory while below capacity, cancel placement once without roster mutation, place Scout in a chosen empty formation slot, enter the next fight, and confirm the original characters and Scout retain their exact slot indices. Verify duplicate and full-roster victories omit recruitment while preserving money and item options. |
| `AC3.2` | Automated and manual runtime check | Run `Tests/Run/test_ac3_3_party_formation.gd`, `Tests/UI/test_ac3_3_party_management.gd`, `Tests/Map/test_ac3_1_recruitment_integration.gd`, and `Tests/Map/test_ac3_3_party_management_integration.gd` to verify atomic six-member replacement, full-roster reward eligibility, replacement-mode interaction, exact-slot preservation, cancellation restoration, dismissed-character eligibility, and stale/repeated/teardown rejection. Then fill the roster, win a supported battle, confirm recruitment remains available, inspect and cancel replacement once without mutation, reopen and replace any occupied member with real pointer input, and confirm the next battle uses the recruit in the exact replaced slot without runtime errors. |
| `AC3.3` | Automated and manual runtime check | Run `Tests/Run/test_ac3_3_party_formation.gd`, `Tests/UI/test_ac3_3_party_management.gd`, and `Tests/Map/test_ac3_3_party_management_integration.gd` to verify fixed six-slot formation storage, exact battle slot conversion, immediate drag-to-swap and drag-to-empty movement, defensive rejection, map-button gating, click inspection, selection cleanup, and cancellable chosen-slot recruitment. Then use the persistent Manage Party button before and after fights, inspect a character, rearrange occupied and empty slots with real pointer input, reopen with no selection, and confirm the next battle uses the exact formation. Finally cancel one recruitment placement without mutation, place the recruit into a chosen empty slot, and confirm the following battle uses that slot. |
| `AC3.4` | Automated and manual runtime check | Run `Tests/Battle/test_ac3_4_default_actions.gd` to verify separate default-action controls alongside four character-specific skills, attack preview/confirmation, adjacent allied swap, invalid-target atomicity, and turn-change cleanup. Retain `Tests/Battle/test_ac6_1_combat_foundation.gd` for domain transaction coverage and `Tests/Battle/test_active_turn_skill_lock.gd` for active-turn ownership. Then enter battle at 1152×648 and confirm Attack and Swap remain readable, use battlefield-slot targeting, advance exactly once on confirmation, and are unavailable outside an active player turn. Evidence: `Docs/Specs/AC3/Evidence/AC3.4/2026-09-05/`. |
| `AC3.5` | Automated integration and runtime smoke check | Run `Tests/Run/test_ac3_5_post_battle_recovery.gd` and `Tests/WorldMap/test_ac3_5_recovery_integration.gd` to verify victory-only recovery, rounded-up half health for passed-out characters, full health for survivors, identity-preserving next-battle setup, save/reload durability, idempotence, and failure atomicity. Retain the focused AC2.4, AC2.5, AC3.1, AC3.3, AC6.7, world-battle-entry, and Save V2 regression runners, then launch the production main scene and confirm a clean debug console. Evidence: `Docs/Specs/AC3/Evidence/AC3.5/2026-09-14/`. Harder-difficulty reduction remains deferred because difficulty modes are not implemented. |
| `AC5.1` | TO CONSIDER | Verification deferred until meta-progression and roguelike structure are rethought and the run-independence requirement is confirmed or revised. See [TC-007](../TO_CONSIDER.md#tc-007--how-should-run-independence-fit-the-revised-roguelike-structure). |
| `AC5.2` | TO CONSIDER | Verification deferred until meta-progression and roguelike structure are rethought and the cross-run persistence requirement is confirmed or revised. See [TC-007](../TO_CONSIDER.md#tc-007--how-should-run-independence-fit-the-revised-roguelike-structure). |
| `AC5.3` | TO CONSIDER | Verification deferred until meta-progression and roguelike structure are rethought and the reproducible Run ID requirement is confirmed or revised. See [TC-007](../TO_CONSIDER.md#tc-007--how-should-run-independence-fit-the-revised-roguelike-structure). |
| `AC6.5` | Automated and runtime check | Run `Tests/Battle/test_ac6_5_brakka.gd`, `Tests/Run/test_world_run_start_service.gd`, `Tests/Run/test_world_production_launcher.gd`, `Tests/UI/test_world_run_start_scene.gd`, Save V2, roster, formation, and cutover runners. Then open Start New Run at 1152x648 and verify the portrait-adjacent disabled arrows, Brakka details, four focusable tooltip skill squares, seed below the columns, and Begin at the bottom. Confirm Brakka persists at formation slot 1 and Banner Holder applies Advantage once per round to the deterministic closest active enemy without consuming the action or redirecting stale targets. |
| `AC7.1` | Automated scene/UI contract and visual runtime check | Run `Tests/Battle/test_ac7_1_living_lanes.gd` to verify two lanes per side, six stable slot identities, character presentation, HP/status refresh, empty and defeated states, and unchanged slot ordering. At 1152×648, confirm all combatants and the action bar remain readable without clipping. |
| `AC7.2` | Automated interaction and manual pointer/keyboard check | Run `Tests/Battle/test_ac7_2_turn_order_ribbon.gd` to verify current-turn framing, `NOW` labeling, queue refresh, hover/focus-to-character linkage, cleanup, and defeated-unit exclusion. Then exercise pointer hover and keyboard focus across player and enemy entries and confirm exactly one battlefield character is emphasized. |
| `AC7.3` | Automated regression and accessibility runtime check | Run `Tests/Battle/test_ac7_3_unified_action_bar.gd`, `Tests/Battle/test_ac3_4_default_actions.gd`, `Tests/Battle/test_ac2_6_character_skills.gd`, and `Tests/Battle/test_active_turn_skill_lock.gd`. Confirm full character-skill buttons coexist with compact Attack and Swap icons, accessible names/tooltips, one shared selection state, and unchanged preview/confirm/cancel mechanics. |
| `AC7.4` | Automated drawer-state and runtime integration check | Run `Tests/Battle/test_ac7_4_debug_drawer.gd` and `Tests/Battle/test_ac2_3_damage_defeat_log.gd` to verify collapsed-by-default state, edge-handle toggle, overlay geometry, live state/queue/log refresh, existing debug-command routing, focus return, battle-reset cleanup, and absence from production input flow when closed. |
| `AC7.5` | Automated state-resolution, interaction, accessibility, and visual runtime check | Run `Tests/Battle/test_ac7_5_battle_visual_states.gd` to verify the visual-state matrix, layered-state precedence, hovered-skill previews, committed selection stability, Attack/Swap differentiation, no-legal-target reasons, pointer/keyboard parity, and cleanup after hover exit, focus loss, cancel, confirmation, turn change, defeat, phase transition, and battle reset. At 1152×648, exercise self-, ally-, enemy-, multi-, and no-valid-target actions and confirm every state is recognizable by shape/icon/text as well as color, no stale highlight remains, and selected/current/valid states stay distinguishable when they overlap. Recorded PASS: [AC7.5 evidence](AC7/Evidence/AC7.5/verification.md). |
| `AC7.6` | Automated snapshot, interaction and regression tests plus inspected runtime evidence | Add `Tests/Battle/test_battle_character_info_presenter.gd`, `test_battle_character_info_panel.gd`, and `test_battle_character_inspection.gd` in the same directory; extend `Tests/Battle/test_ac7_3_unified_action_bar.gd`. Verify fixed skill dimensions, preserved defaults, complete content/passives, atomic committed snapshots with epoch/revision/request guards, one-owner input precedence, modal/focus cleanup and lifecycle behavior. Run all Battle regressions and world battle entry. Inspect 1152×648 and 1024×648 input/tooltip/panel cases and 1920×1080 sizing. All five contract groups must pass with an implementation commit, logs and inspected captures in [AC7.6 verification](AC7/Evidence/AC7.6/verification.md), alongside `.gdignore`. Recorded PASS: implementation `4da4935`, 31 passing runners and inspected runtime captures; see the linked AC7.6 verification record. |
| `AC8.1` | Automated wallet/persistence/HUD tests and rendered input verification | PASS: 23 headless suites plus production-menu keyboard input, map click, Continue and replacement checks. Verified 100g start, exact 0g/375g restoration, failed-save retry, V2 migration to 0g, candidate preservation and readable HUD at 1152x648 and 1920x1080. See [evidence and existing preview-runner limitation](AC8/Evidence/AC8.1/verification.md). Implementation: `c644778`. |
| `AC8.2-AC8.3` | Automated battle settlement, terminal loss, reward presentation and restart checks | PASS: AC8.2 settlement/terminal-loss evidence and AC8.3 35-run gate, six rendered restart runs, and twelve inspected captures. Verify exact receipt amount, no production choices, retained recovery, V5 compatibility, failed-save retry/discard, duplicate/stale callbacks and no reaward after restart. See [AC8.2](AC8/Evidence/AC8.2/verification.md) and [AC8.3](AC8/Evidence/AC8.3/verification.md). |
| `AC8.4` | [Ownership prerequisite verified](AC8/Evidence/AC8.4/verification.md); filtered offers pending AC8.5/AC8.6 | Extend `Tests/WorldMap/test_ac8_town_recruitment.gd` to verify every existing town resolves to Goblin ownership in pre-habitat worlds, uses roster-class filtering and retains that behavior after reload without topology changes. Verify habitat-enabled towns use explicit ownership and reject missing ownership rather than silently defaulting to Goblin. |
| `AC8.5-AC8.8` | Planned recruitment and transaction checks | Add `Tests/WorldMap/test_ac8_town_recruitment.gd`. Verify town-clan filtering, whole-roster class exclusion including passed-out members, refresh after purchase/dismissal/replacement/reload, empty offers, stale requests, 499g/500g boundary, six-member placement/replacement, cancellation, failed-save retry, duplicate settlement and ruins rejection. |
| `AC9.0` | Required content-readiness gate before habitat implementation | Record implementation and combat/save/presentation verification for the remaining races and commanders. Verify approved class/skill and commander catalogs, actual player/enemy party integration and stable saved identities. Habitat generation tasks remain blocked until this content stage passes; debug encounter teams or lore-only entries are insufficient. |
| `AC9.1-AC9.3` | Planned catalog and seeded selection checks | Add `Tests/Run/test_ac9_clan_selection.gd`. Verify valid clan/commander pairs, three distinct allied clans, at least one main-clan synergy, deterministic selection and reachability of each enemy clan across a seed corpus, and an authored commander-led boss party for every eligible enemy clan. |
| `AC9.4-AC9.7` | Planned geometry and road fixtures | Add `Tests/WorldMap/test_ac9_habitats_and_roads.gd`. Verify east/west rendered spawns, player inside main habitat, exact clipped radius-two enemy footprint, nine allied towns, zero enemy towns, three internal town-pair connections per habitat, every habitat pair connected, all equal-minimum endpoint ties and valid deterministic road routes. |
| `AC9.8-AC9.10` | Planned generation/save/launcher and visual checks | Add `Tests/Run/test_ac9_start_without_confirmation.gd`; extend versioned world/save fixtures and existing repository/start tests. Verify byte-stable regeneration, no reroll on Continue, no overwrite prompt, failed generation/save preservation, single successful replacement, explicit version handling and readable habitat/town/road/party presentation. |
| `AC10.1-AC10.3` | Planned targeting and siege timing checks | Add `Tests/WorldMap/test_ac10_enemy_campaign.gd`. Verify closest-town selection, seeded equal-distance ties, target locking, one action per accepted world turn, no UI/battle/rejected-move ticking, siege on arrival and an interception opportunity before destruction. |
| `AC10.4-AC10.6` | Planned destruction and pursuit checks | Exercise all nine allied towns, ruins traversal and service denial, remaining-town count, no pursuit while an intact target remains, pursuit after the final burn, changing player destinations and absence of old Sudden Death activation/empowerment. Include `Tests/UI/test_ac10_town_states.gd`. |
| `AC10.7-AC10.9` | Planned transaction, interception and runtime checks | Add `Tests/WorldMap/test_ac10_campaign_transactions.gd`. Verify collision precedence, one commander encounter, early victory/defeat, mid-siege reload, preserved target/RNG progress, atomic failed-save retry and unreachable-town failure. Inspect siege/ruins/pursuit UI and run a full campaign with GodotIQ play, verify_project_runs, console and state inspection. |


---

## 11. ESTIMATED SCOPE

The phase estimates below are historical and have not been recalculated for AC8-AC10. Delivery order is AC8 gold/recruitment using existing towns as Goblin habitat, then remaining races and commanders (AC9.0), then AC9 habitat/town/road generation, then AC10 campaign behavior. AC8 does not wait for habitats; habitat implementation must wait for completed race and commander content.

**MVP Implementation Phases:**

| Phase | Features | Effort |
|-------|----------|--------|
| **Phase 1: Core Loop** | 25-hex map traversal, seeded encounters, movement rules, and encounter overlay flow | 2–3 weeks |
| **Phase 2: Combat** | Turn-based combat engine, 6v6 slot arena, turn order, player actions, power scaling, cooldowns, combos, default actions, positional logic | 4–6 weeks |
| **Phase 3: Progression** | Character progression models, equipment system, stat scaling, battle recovery rules, reward integration | 2–4 weeks |
| **Phase 4: Roguelike Structure — TO CONSIDER** | AC5 is deferred pending reconsideration of meta-progression and roguelike structure; revisit scope and estimates after those decisions | Deferred |
| **Phase 5: Meta-Progression (To Consider)** | Run completion unlocks, special event unlocks, future cross-run reward tuning | TBD |
| **Phase 6: Polish & QA** | Party-management UI, combat UX, balancing, bug fixing, determinism validation, content tuning | 2–4 weeks |

Recruitment flow and roster management are not part of Phase 1 completion criteria and remain deferred to later phases.

Meta-progression is intentionally deferred to the consideration register until the unlocked-content model is explicitly chosen.

**Total Estimate:** 12–20 weeks solo development

---

## 12. NEXT STEPS

Prioritize the linked AC8-AC10 plans: implement gold and class-filtered recruitment in existing Goblin towns; implement and verify all remaining races and their commanders; only then implement habitats, clan-owned towns and roads, followed by siege/pursuit. Keep each new acceptance item unchecked until its automated and runtime evidence is recorded.

1. ✅ **Spec Validation** — Review this spec for completeness, consistency, and traceability
2. **Godot Setup** — Initialize project structure (managers, scenes, Resources)
3. **Phase 4 — TO CONSIDER** — Revisit all AC5 requirements after rethinking meta-progression and roguelike structure; implementation is deferred.
4. **Playtesting** — Manual QA after each phase; validate acceptance criteria

---

## APPENDIX A: Worked Example

1. Select Goblins and a Goblin commander. Resolve the seed, two distinct allied clans (at least one synergistic with Goblins), and one Human, Elven or Dwarven main enemy clan.
2. Start on the easternmost hex inside the Goblin habitat with 100g. Each of the three allied habitats has three towns; the commander-led enemy party starts in its town-free western habitat.
3. Win a fight against two enemies. The reward screen shows a money icon and 100g received, bringing the balance to 200g. No recruitment/item/rest choice appears; normal battle recovery still applies.
4. After eight defeated enemies across won fights, the balance is 500g. Visit an intact Goblin town: it offers Goblin classes absent from the current roster. Recruit one for 500g through placement/replacement; balance becomes 0g and that class disappears from offers.
5. Meanwhile, the enemy locks its nearest intact allied town, choosing randomly among equal-distance targets. Arrival begins a siege; interception can force the boss-party battle before the town burns.
6. An uninterrupted siege leaves traversable ruins with no recruitment. After all nine allied towns are burned, the enemy pursues the player. No move-count-based Sudden Death activates.
7. Defeat the commander-led party to complete the run. Cross-run unlocks remain deferred rather than being awarded by this example.

---

**Author:** Gameplay Systems Designer  
**Date:** 2026-07-20  
**Status:** Ready for Spec Validation & Implementation
