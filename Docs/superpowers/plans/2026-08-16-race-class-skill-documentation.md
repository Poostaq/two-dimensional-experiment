# Race, Class, and Skill Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce an implementation-ready, race-oriented documentation set for five races, 30 classes, 120 class skills, shared keywords, ring movement, progression, and acceptance traceability.

**Architecture:** Shared mechanics live once under `Docs/Mechanics`; each race owns a `Lore.md` identity dossier and `Classes.md` roster modeled after the existing Goblin structure. A traceability document verifies counts, required fields, race bands, synergy/counterplay coverage, Goblin uniqueness, and removal of Ignite from canonical design content.

**Tech Stack:** Markdown, PowerShell, ripgrep, Git

---

### Task 1: Canonical mechanics

**Files:**
- Modify: `Docs/Mechanics/SkillKeywords.md`
- Create: `Docs/Mechanics/FormationMovement.md`
- Create: `Docs/Mechanics/SkillAuthoringContract.md`

- [ ] **Step 1: Rewrite the keyword canon**

Keep exactly Armor, Bleed, Poison, Stun, Advantage, and Leech. For each keyword, state trigger, duration unit or persistence, cap, reapplication, invalid interaction, cleanup boundary, tooltip pattern, and log pattern. Remove the Ignite section and comparisons. Use the approved values in `Docs/superpowers/specs/2026-08-16-race-class-skill-design.md`.

- [ ] **Step 2: Document the six-slot movement ring**

Define ring order `back_top -> back_middle -> back_bottom -> front_bottom -> front_middle -> front_top -> back_top`. Define Move 1, Move 2, and Move 3, both directions, player choice at distance three, occupied-path rotation, two-unit explicit swaps, partial occupancy, defeated-unit handling, and atomic rejection. Include both approved opposite-corner examples.

- [ ] **Step 3: Document the skill authoring contract**

Require exactly three Active skills and one Passive per class. Define Opener, Converter, Pivot, and Signature Passive; Tier 1-3 progression; cooldown bands; direct-damage formula; resolution order; battle cleanup; passive recursion guards; required tooltip/log fields; and the complete authoring schema listed in the approved design.

- [ ] **Step 4: Verify shared mechanics**

Run:

```powershell
rg -n "^### (Bleed|Poison|Stun|Advantage|Leech)$" Docs/Mechanics/SkillKeywords.md
rg -ni "ignite" Docs/Mechanics Docs/Races
rg -n "Move 1|Move 2|Move 3|atomic|three Active|one Passive" Docs/Mechanics
```

Expected: six keyword headings; no Ignite result in canonical mechanics or race documents; movement and four-skill rules present.

- [ ] **Step 5: Commit canonical mechanics**

```powershell
git add Docs/Mechanics
git commit -m "docs: define race skill mechanics"
```

### Task 2: Update the baseline guide and Goblins

**Files:**
- Modify: `Docs/Races/MONSTER_RACE_DESIGN_GUIDE_INITIAL_DRAFT.md`
- Modify: `Docs/Races/Goblins/Lore.md`
- Replace: `Docs/Races/Goblins/Classes.md`
- Modify: `Docs/Races/Goblins/Commanders.md`

- [ ] **Step 1: Align the guide**

Replace every two-class list with the approved six-class roster. Remove Ignite from Harpies and the Demonkin alternate. Link shared mechanics rather than duplicating rules. Rewrite AC2 to require exactly six classes and AC3 to require exactly four fully authored skills per class.

- [ ] **Step 2: Complete Goblin identity evidence**

Keep the established scavenger-coalition lore while removing duplicated sentences and obsolete Kobold/Gnoll roster references. Add three concrete positive pairings, two concrete counters, visual read, mechanical promise, and the quantitative rule that at least four Goblin classes use sequencing/setup while no other race exceeds two.

- [ ] **Step 3: Author six Goblin kits**

Write Scrapshield Bruiser `20/4/7/2`, Wirefang Skirmisher `14/6/10/0`, Snarewright `16/4/9/1`, Scrapbroker `18/3/8/1`, Shivrunner `12/7/10/0`, and Mobcaller `17/4/9/1`. Give every class role, rhythm, weakness, and exactly four skills following the shared authoring contract.

- [ ] **Step 4: Align the commander exception**

Retain Brakka Rustbanner and specify that Banner Holder occupies the class Passive slot. Make its Advantage target, eligibility, expiry, failure, and once-per-round guard conform to the canonical keyword contract.

- [ ] **Step 5: Verify and commit Goblins**

Run:

```powershell
rg -n "^## Class [1-6]:" Docs/Races/Goblins/Classes.md
rg -n "^\| [^|]+ \| (Active|Passive)" Docs/Races/Goblins/Classes.md
rg -ni "ignite|kobold|gnoll" Docs/Races/Goblins Docs/Races/MONSTER_RACE_DESIGN_GUIDE_INITIAL_DRAFT.md
```

Expected: six class headings, 24 authored skill rows, and no stale race or Ignite references.

```powershell
git add Docs/Races/MONSTER_RACE_DESIGN_GUIDE_INITIAL_DRAFT.md Docs/Races/Goblins
git commit -m "docs: complete goblin class roster"
```

### Task 3: Create Orc and Werewolf dossiers

**Files:**
- Create: `Docs/Races/Orcs/Lore.md`
- Create: `Docs/Races/Orcs/Classes.md`
- Create: `Docs/Races/Werewolves/Lore.md`
- Create: `Docs/Races/Werewolves/Classes.md`

- [ ] **Step 1: Author Orc identity and classes**

Use the approved contact/lane-dominance identity. Author Iron Tusk Vanguard `30/5/2/5`, Bonebreaker Reaver `26/8/4/2`, Bloodbanner Captain `28/5/3/4`, Chainwarden `27/4/4/4`, War Drummer `24/4/5/3`, and Siegebreaker `25/8/2/3`. Tough Orc front liners use Armor and no Orc skill uses Bleed. Limit Stun to Chainwarden; other control uses Armor, direct damage, movement, cooldowns, or requirements.

- [ ] **Step 2: Author Werewolf identity and classes**

Use the approved hunting/aggressive-recovery identity. Author Moonfang Skirmisher `17/9/9/0`, Pack Howler `20/6/8/1`, Bloodtrail Stalker `18/8/8/0`, Duskhide Ravager `22/9/6/1`, Den Warden `24/6/6/2`, and Moonblood Seer `19/6/7/1`. Keep Leech tied to actual direct damage and prevent Den Warden from becoming a conventional healer.

- [ ] **Step 3: Add race-level evidence**

Each Lore document must contain lore hook, visual read, culture, mechanical promise, strengths, weaknesses, three named cross-race/class synergies, and two actionable counters.

- [ ] **Step 4: Verify and commit both races**

Run the class/skill heading counts for both `Classes.md` files and verify Orc `Stun` ownership plus Werewolf `Leech` ownership with `rg`.

```powershell
git add Docs/Races/Orcs Docs/Races/Werewolves
git commit -m "docs: add orc and werewolf class rosters"
```

### Task 4: Create Lizardman and Harpy dossiers

**Files:**
- Create: `Docs/Races/Lizardmen/Lore.md`
- Create: `Docs/Races/Lizardmen/Classes.md`
- Create: `Docs/Races/Harpies/Lore.md`
- Create: `Docs/Races/Harpies/Classes.md`

- [ ] **Step 1: Author Lizardman identity and classes**

Author Venom Saurian `20/7/5/1` with Power Poison, Scale Sentinel `26/4/3/3`, Mire Spitter `18/5/6/1` with Speed Poison, Fang Alchemist `21/6/5/2` with Defense Poison, Reed Ambusher `19/7/6/1`, and Sunscale Warder `24/4/4/3`. Every Poison skill declares one axis; separate axes never merge into one stack.

- [ ] **Step 2: Author Harpy identity and classes**

Author Talon Duelist `14/8/10/0`, Storm Siren `17/6/8/1`, Gale Scout `12/6/10/0`, Skyhook Raider `18/7/8/1`, Nestguard `20/5/7/1`, and Carrion Cantor `16/7/9/0`. Harpy Advantage must follow successful movement or isolation. Restrict Bleed to Carrion Cantor's physical pressure branch.

- [ ] **Step 3: Apply ring movement to every Harpy skill**

Each movement effect states Move range 1-3, clockwise/counterclockwise path choice, affected side, occupied-path rotation, and invalid-path behavior. No Harpy skill uses obsolete grid adjacency or occupied-destination failure.

- [ ] **Step 4: Add race-level evidence and commit**

Add three named synergies and two counters per race, verify heading counts, and run a canonical-content Ignite scan.

```powershell
git add Docs/Races/Lizardmen Docs/Races/Harpies
git commit -m "docs: add lizardman and harpy class rosters"
```

### Task 5: Traceability and completion audit

**Files:**
- Create: `Docs/Races/RACE_CLASS_SKILL_TRACEABILITY.md`

- [ ] **Step 1: Map every acceptance criterion**

Create rows for race identity, six classes, four skills, keyword consistency, stat bands, synergy/counterplay, Goblin uniqueness, Ignite removal, and implementation dependencies. Each row names authoritative files, current documentary evidence, future automated evidence, and status.

- [ ] **Step 2: Record current versus desired implementation**

List current support for four-skill rosters, Active/Passive kinds, damage, Speed boosts, requirements, cooldowns, combos, atomic confirmation, history, and queue rebuilding. List missing Power/Defense, Armor, statuses, Leech, ring rotation, and passive trigger support as implementation dependencies rather than claiming runtime completion.

- [ ] **Step 3: Run the full documentation audit**

```powershell
$raceFiles = Get-ChildItem Docs/Races -Recurse -Filter Classes.md
$raceFiles.Count
foreach ($file in $raceFiles) {
    $classes = (Select-String -Path $file.FullName -Pattern '^## Class [1-6]:' -AllMatches).Count
    $skills = (Select-String -Path $file.FullName -Pattern '^\| [^|]+ \| (Active|Passive)' -AllMatches).Count
    "{0}: classes={1}, skills={2}" -f $file.FullName, $classes, $skills
}
rg -ni "ignite" Docs/Mechanics Docs/Races
rg -n "FIXME|NEEDS DECISION|DRAFT ONLY" Docs/Mechanics Docs/Races
git diff --check
```

Expected: five class files; each reports `classes=6, skills=24`; no canonical Ignite hit; no incomplete-design marker; no whitespace errors.

- [ ] **Step 4: Review acceptance evidence manually**

Confirm every race has one Lore and one Classes document, every class stat lies within its guide band, every skill has every authoring-contract field, each race has three named synergies and two counters, and Goblin sequencing density exceeds every other race.

- [ ] **Step 5: Commit traceability and final corrections**

```powershell
git add Docs/Mechanics Docs/Races Docs/superpowers/specs/2026-08-16-race-class-skill-design.md Docs/superpowers/plans/2026-08-16-race-class-skill-documentation.md
git commit -m "docs: verify race class skill readiness"
```
