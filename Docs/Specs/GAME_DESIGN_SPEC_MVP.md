# Design Spec: Fantasy Turn-Based Roguelike MVP

**Project:** Two-Dimension Exploration  
**Target Platform:** Godot 4.7  
**Scope:** Small-to-Medium (MVP focus)  
**Status:** Ready for Implementation  

---

## 1. GAME OVERVIEW

**Fantasy Turn-Based Roguelike** — Player starts with 1 character and traverses a deterministic 25-hex map arranged as a 5x5 layout, recruiting up to 6 units to fight in turn-based combat with player-selected actions. The player starts in one corner hex, and the final boss objective is in the opposite corner. The player has at most 15 moves to engage the boss under normal conditions. If the boss is not engaged by then, Sudden Death begins: the boss becomes empowered and tracks the player, moving immediately after each player move until combat is forced. Win the final boss battle to complete the run. Lose when all units fall in combat (units revive between battles, encouraging risk/reward). Meta-progression unlocks new characters and items for future runs.

---

## 2. CORE MECHANICS

- **World Map Traversal** — Move across a deterministic 25-hex (5x5) map from one corner to the opposite-corner boss objective with at most 15 moves before Sudden Death triggers
- **Turn-Based Combat (Player-Controlled)** — Battles take place on a 6-slot player side and 6-slot enemy side; units act in speed order; players choose each unit action; skills may have positional requirements, condition requirements, and either pre-use cooldowns or cooldowns applied after use
- **Unit Recruitment** — Acquire additional units from seeded encounters, rewards, or other run-based opportunities up to a roster cap of 6; if the roster is full, the player must dismiss one character before taking a new one
- **Party Management** — Player can freely rearrange the active 6-character lineup before and after fights through a party-management UI for tactical preparation
- **Equipment & Stat Management** — Characters have predetermined base stats; equipment can be freely removed and reassigned between eligible characters, and usually grants stat bonuses or mechanical changes while respecting item restrictions such as race
- **Meta-Progression** — Winning runs unlock specific characters or items for future runs, while other characters or items can be unlocked by completing special events

---

## 3. WIN & LOSS CONDITIONS

| Condition | Trigger |
|-----------|---------|
| **WIN** | Reach the opposite-corner boss hex and defeat boss unit |
| **LOSS** | All player units reduced to 0 HP in a single battle |

**Units revive between battles** — After victory, characters who passed out during the battle return for the next battle at 50% health, with harder difficulties able to reduce that recovery value further. Units do not permanently die.

---

## 4. DESIGN DECISIONS (MVP)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Map Layout** | 25 hexes (5x5) | Enables route planning and corner-to-corner objective pressure |
| **Move Limit** | 15 player moves before Sudden Death | Enforces tempo and prevents indefinite stalling |
| **Boss Difficulty** | Boss uses its own stat scaling, potentially around 10× a regular player baseline and 20×-30× during Sudden Death | Final tuning will be determined through playtesting to find a fair but high-pressure boss curve |
| **Permadeath** | Units revive after battle (no permadeath) | Simplifies MVP; focuses on tactical combat over roster attrition |
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
- **Skill Loadout:** Each character has 4 character-specific skills plus 2 default skills shared by all characters
- **Active Skill Requirement:** At least 1 of the 4 skills must be active
- **Passive/Active Mix:** The remaining 3 skills can be active or passive
- **Default Attack:** Every character can use a default attack that applies its power value
- **Default Swap:** Every character can use a default swap action to exchange places with an adjacent allied character
- **Turn Usage Limit:** A character can use only 1 active skill per turn

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

| Action | Cost | Effect |
|--------|------|--------|
| **Acquire Unit** | Varies by source | Add 1 unit to roster (max 6) through events, rewards, or other run systems |
| **Battle Win** | — | Present a choice of post-battle rewards based on the event type, such as tavern recruitment, unique character recruitment, monetary reward, item reward, or rest |

**Post-Battle Rewards:**
- Battle rewards are presented as a choice between multiple options, similar to a campfire-style decision point
- Available reward options depend on the event or battle type
- Example rewards include recruiting from a tavern, recruiting a unique event character, gaining money, receiving an item, or resting to recover health
- Stronger or cleaner battle results may grant more than one reward choice or reward pickup, but this still requires playtesting

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
- [x] AC1.1 — Player can move on a 25-hex (5x5) map from starting corner toward opposite-corner boss objective
- [x] AC1.2 — Hex encounter types (Safe/Combat/Boss) are seeded and deterministic per run ID
- [x] AC1.3 — World-map navigation is controlled by mouse selection of adjacent hexes (no Q/W/E/A/S/D movement requirement)
- [x] AC1.4 — Entering any map hex automatically opens an Encounter overlay for that hex's seeded encounter type
- [x] AC1.5 — If boss is not engaged within 15 player moves, boss becomes empowered and moves immediately after each player move until battle is triggered

### Combat System
- [ ] AC2.1 — Battles use a 6-slot player side and a 6-slot enemy side
- [ ] AC2.2 — Faster units act earlier according to speed order
- [ ] AC2.3 — Unit takes damage; at 0 HP, removed from battle
- [ ] AC2.4 — Player wins if all enemies defeated; loses if all units defeated
- [ ] AC2.5 — Winning battle presents multiple reward options based on the event type, with the player choosing from options such as recruitment, money, or item rewards
- [ ] AC2.6 — Skills support positional requirements, condition requirements, and either pre-use cooldowns or cooldowns applied after use
- [ ] AC2.7 — Skills grant combo bonuses only when their specific combo conditions are met

### Unit Management
- [ ] AC3.1 — Player can acquire a unit from a valid run-based source if roster < 6
- [ ] AC3.2 — If the roster is already full at 6 characters, the player must dismiss one character before acquiring a new one
- [ ] AC3.3 — Player can freely rearrange the active party before and after fights through a party-management interface
- [ ] AC3.4 — Character progression follows the unit's defined model, such as level-up growth, class evolution, or permanent upgrade progression
- [ ] AC3.5 — Equipment restrictions, including race restrictions, are enforced before equip
- [ ] AC3.6 — Equipment can be unequipped and reassigned freely between eligible characters
- [ ] AC3.7 — Every character has a default attack and a default adjacent-swap action in addition to its character-specific skills
- [ ] AC3.8 — After battle victory, characters who passed out return for the next battle at 50% health, with lower recovery allowed on harder difficulties

### Meta-Progression
- [ ] AC4.1 — Winning the final battle unlocks specific characters or items for future runs
- [ ] AC4.2 — Special events can unlock additional characters or items outside of run completion rewards
- [ ] AC4.3 — Meta-progression unlocks persist across future runs

### Roguelike Structure
- [ ] AC5.1 — Each run is seeded and independent; prior run roster does not carry over
- [ ] AC5.2 — Unlocked characters, items, and event-driven progression persist across runs
- [ ] AC5.3 — Run ID uniquely identifies a playable sequence; same ID = reproducible battles

### Verification Paths

| AC ID | Verification Type | Verification Path |
|------|-------------------|-------------------|
| `AC1.1` | Manual runtime check | Start a run on a 25-hex map, move from the starting corner, and confirm the player can traverse valid adjacent hexes toward the opposite-corner boss objective. |
| `AC1.2` | Determinism check | Start two runs with the same Run ID and confirm the Safe/Combat/Boss hex layout is identical; start a run with a different Run ID and confirm the layout can differ. The AC1.2 fixture pair `AC1.2-A` and `AC1.2-B` is expected to differ by at least one non-boss tile under the documented hash algorithm. |
| `AC1.3` | Manual runtime check | Use mouse clicks on adjacent hexes to move the player marker. Confirm valid adjacent clicks move exactly one hex and invalid or non-adjacent clicks do not move the player. |
| `AC1.4` | Automated and manual runtime check | Enter Safe, Combat, and Boss hexes and verify each accepted move immediately opens one input-blocking Encounter overlay with the matching seeded type. Close it with `Close (Debug)` and verify the player remains on the entered hex with navigation restored. |
| `AC1.5` | Automated and manual runtime check | Run `Tests/Map/test_ac1_5_sudden_death.gd` to verify the move-15 activation boundary, deterministic shortest-path tie-breaking, one-step pursuit from move 16 onward, both engagement directions, runtime Boss identity, and reset behavior. Then avoid the boss for 15 player moves in the running game and confirm Sudden Death activates before one boss step follows each subsequent accepted player move until engagement. |
| `AC2.1` | Manual runtime check | Enter battle and verify the battlefield shows exactly 6 player slots and 6 enemy slots. |
| `AC2.2` | Manual runtime check | Start a battle with at least two units of different speed values and confirm action order follows descending speed. |
| `AC2.3` | Manual runtime check | Apply damage to a unit until HP reaches 0 and verify it is removed from active battle participation. |
| `AC2.4` | Manual runtime check | Complete one battle by defeating all enemies and one battle by losing all player units, verifying the correct win/loss result in each case. |
| `AC2.5` | Manual runtime check | Win battles from at least two different event types and verify the reward screen presents multiple selectable options appropriate to each event. |
| `AC2.6` | Manual runtime check | Use skills with positional requirements, condition requirements, pre-use cooldowns, and post-use cooldowns, verifying invalid uses are blocked and valid uses resolve correctly. |
| `AC2.7` | Manual runtime check | Trigger a skill's documented combo condition and confirm the bonus applies; repeat without the condition and confirm the bonus does not apply. |
| `AC3.1` | Manual runtime check | Acquire a character reward while the roster has fewer than 6 characters and confirm the new character is added successfully. |
| `AC3.2` | Manual runtime check | Attempt to acquire a new character while already at 6 roster members and verify the game requires dismissing one character before the acquisition completes. |
| `AC3.3` | Manual runtime check | Open the party-management interface before a fight and after a fight, reorder the party, and verify the updated lineup is used for the next battle. |
| `AC3.4` | Manual runtime check | Test one leveling character, one evolution character, and one mechanical unit, confirming each follows its own defined progression behavior. |
| `AC3.5` | Manual runtime check | Attempt to equip an item on an ineligible character, such as the wrong race, and verify the equip is blocked; then equip it on an eligible character and verify success. |
| `AC3.6` | Manual runtime check | Equip an item on one character, unequip it, and assign it to another eligible character, verifying the shared inventory updates correctly. |
| `AC3.7` | Manual runtime check | In battle, verify every character can use the default attack and, when adjacent to an ally, the default swap action. |
| `AC3.8` | Manual runtime check | Let a character pass out during battle, win the battle, and verify that character begins the next battle at 50% HP or the configured lower value on harder difficulties. |
| `AC4.1` | Manual persistence check | Complete a full run, then start a new run and verify the specific character or item unlocked by the victory is now available in future-run content pools. |
| `AC4.2` | Manual persistence check | Complete a special event with an unlock condition, then start a new run and verify the corresponding unlocked character or item is available. |
| `AC4.3` | Persistence check | Unlock a character or item, save or exit the game, reload, and verify the unlock remains available across sessions and future runs. |
| `AC5.1` | Manual runtime check | Finish or abandon one run, start a new run, and verify the prior run's roster does not carry over into the new run. |
| `AC5.2` | Persistence check | Unlock content through victory or special events, start a new run, and verify the unlocked characters, items, and event-driven progression remain available. |
| `AC5.3` | Determinism check | Replay the same Run ID using the same choices and verify the same encounter sequence, battle setup, and outcomes occur within the documented deterministic systems. |

---

## 11. ESTIMATED SCOPE

**MVP Implementation Phases:**

| Phase | Features | Effort |
|-------|----------|--------|
| **Phase 1: Core Loop** | 25-hex map traversal, seeded encounters, movement rules, and encounter overlay flow | 2–3 weeks |
| **Phase 2: Combat** | Turn-based combat engine, 6v6 slot arena, turn order, player actions, power scaling, cooldowns, combos, default actions, positional logic | 4–6 weeks |
| **Phase 3: Progression** | Character progression models, equipment system, stat scaling, battle recovery rules, reward integration | 2–4 weeks |
| **Phase 4: Meta-Loop** | Run completion unlocks, special event unlocks, persistence, save/load, unlock tracking | 2–3 weeks |
| **Phase 5: Polish & QA** | Party-management UI, combat UX, balancing, bug fixing, determinism validation, content tuning | 2–4 weeks |

Recruitment flow and roster management are not part of Phase 1 completion criteria and remain deferred to later phases.

**Total Estimate:** 12–20 weeks solo development

---

## 12. NEXT STEPS

1. ✅ **Spec Validation** — Review this spec for completeness, consistency, and traceability
2. **Godot Setup** — Initialize project structure (managers, scenes, Resources)
3. **Phase 1 Implementation** — Map + movement + basic recruitment
4. **Playtesting** — Manual QA after each phase; validate acceptance criteria

---

## APPENDIX A: Worked Example

**Run Setup:** 25-hex (5x5) map, Normal difficulty, starting with 1 Warrior in one corner, boss in the opposite corner.

**Warrior Base Stats (from core stat model):** HP=30, Power=8, Speed=5, Defense=2

**Warrior Skills (example loadout details):**
- **Active - "Slash":** 100% Power multiplier attack that hits 2 targets (a selected target and one adjacent target)
- **Passive - "Victory Rush":** Heal self for 20% of Power after defeating an enemy

**Hex 1 (Safe): Choose one option**
- **Rest:** Heal all characters (currently only Warrior) by 30% of max health
- **Search:** Try to find items
- **Tavern:** Recruit new characters

**Hex 2 (Combat: 2 Goblins, HP=15 each, Power=4, Speed=3, Defense=0)**
- Turn 1: Warrior (SPD=5) acts → "Slash" hits both Goblins for 8 each → Goblin 1 at 7 HP, Goblin 2 at 7 HP
- Turn 2: Goblin 1 acts → "Hit" (Power 4 vs Warrior Defense 2) → Warrior at 28 HP
- Turn 3: Goblin 2 acts → "Hit" (Power 4 vs Warrior Defense 2) → Warrior at 26 HP
- Turn 4: Warrior acts → "Slash" hits both Goblins for 8 each → Goblin 1 defeated, Goblin 2 defeated
- Turn 4 (Passive Trigger): "Victory Rush" heals Warrior for 20% of Power (1.6), rounded up by default to 2, while keeping difficulty-based rounding policy support for final balance tuning
- **Victory:** Choose a post-battle reward such as rest, money, recruitment, or an item drop (for example, Iron Sword +2 Power)

**Boss Hex (Dragon: HP=3000, DMG=20, SPD=8)** — Target is opposite-corner objective; if not engaged by move 15, dragon becomes empowered and pursues after each player move

**Win:** Defeat dragon → Run complete! Unlock a specific character or item for future runs.

---

**Author:** Gameplay Systems Designer  
**Date:** 2026-07-20  
**Status:** Ready for Spec Validation & Implementation
