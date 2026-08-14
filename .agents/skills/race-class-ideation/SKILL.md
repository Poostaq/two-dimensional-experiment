---
name: race-class-ideation
description: "Design a coherent race and class foundation for a game before implementation: fantasy identity, role balance, progression, and party synergy."
argument-hint: "[game concept or setting theme] [--review full|lean|solo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Task
model: sonnet
---

# Race and Class Ideation

Use this skill to design exactly one thing per invocation: a race, a class, or a skill.

The skill must always produce 2–6 examples that fit the user’s prompt and the project’s current reality. It must never create a broad roster without a single target, and it must never ignore known mechanics, lore, or previously prepared races, classes, and skills.

When the user needs a decision checkpoint, pause and ask for confirmation in plain language rather than using a platform-specific tool name.

## Core Rules

1. Single-entity focus
   - One run = one design target: race, class, or skill.
   - Do not mix multiple entity types in the same output unless the user explicitly asks for a comparison.

2. Context-first design
   - Read all relevant project information before drafting.
   - This includes existing mechanics, story/lore, themes, environments, combat rules, progression systems, and any already designed races, classes, or skills.
   - If the project already has a class system, the new design must respond to it instead of duplicating it.

3. Fit-to-context examples
   - Produce 2–6 examples that are all plausible for the project and the request.
   - Each example should feel like a natural part of the existing design language rather than a random fantasy insert.

4. No orphan design
   - Every proposal should clarify how it connects to project lore, gameplay loop, and/or the rest of the roster.
   - If a class or skill seems incompatible with the current world or other design pillars, say so and explain the mismatch.

5. Keep the design readable
   - Prefer clear identity, simple fantasy hooks, and strong gameplay logic over vague lore-heavy filler.

## Phase 0: Resolve Review Mode

1. If `--review [full|lean|solo]` is passed, use that mode.
2. Else read `production/review-mode.txt` if it exists.
3. Else default to `lean`.

Use the resolved review mode to decide whether to bring in additional design reviewers or keep the process focused.

## Phase 1: Clarify User Intent and Entity Type

Ask or infer the target type:

- Is the user asking for a race, class, or skill?
- What is the core fantasy, theme, or fantasy hook?
- What is the game tone and player fantasy?
- Are there specific mechanics, factions, or conflicts the design must fit?

If the user gives a loose request, identify the likely entity type and state the assumption before producing examples.

## Phase 2: Read Project Context

Check relevant project files and notes such as:

- `Docs/Specs/`
- `Docs/` concept notes
- active design documents
- gameplay rules, boss fights, progression notes, and existing entity lists

Read only the materials needed to understand the current design space and constraints. Then summarize the project facts that matter for this entity type.

## Phase 3: Design the Correct Entity Type

### If the user is asking for a race

Prepare 2–6 race examples. Each example must include:

- theme of the race
- core fantasy identity
- cultural or world connection
- strengths and weaknesses
- how it plays mechanically in the current project
- how it fits the game’s tone and progression
- examples of classes that fit the race
- one or two likely conflicts or tensions with other races or factions

Also include a short section explaining which race archetypes are most likely to work well with the project’s existing mechanics and lore.

### If the user is asking for a class

Prepare 2–6 class examples. Each example must include:

- class theme
- what fantasy it gives the player
- why it fits the project’s current races and lore
- why this class fits the race or races it is designed for
- what other classes it works well with and what roles it complements
- suggested companion classes that could be created later and how they interact
- examples of skills or skill ideas this class might use, without writing full skill definitions
- how this class plays in combat or exploration
- what role it fills in a party composition

Do not treat a class as a generic damage build. It must have a theme, a role, and a clear identity in the party.

### If the user is asking for a skill

Prepare 2–6 skill examples. Each example must include:

- exact mechanic description
- intended purpose in gameplay
- type of effect: offense, defense, mobility, support, combo trigger, utility, or control
- potential combos or interaction rules
- costs, cooldowns, or resource usage if applicable
- whether there are no direct costs or cooldowns and why that design is intentional
- what races or classes it is prepared for
- restrictions for race/class usage, if any
- how the skill interacts with the class theme and race theme
- any edge cases, counters, or balance concerns

A skill must be designed with race/class synergy in mind. It should not be a generic “spell” with no relationship to party role or world fantasy.

## Phase 4: Cross-Check Against Existing Project Information

Before finalizing, verify that each example is consistent with:

- known mechanics
- lore and setting constraints
- already prepared races, classes, and skills
- progression and difficulty expectations
- role coverage in the party or solo experience

If any idea conflicts with an existing game pillar, explicitly say that it is a mismatch and why.

## Phase 5: Recommend the Best Fit

End with a single recommended direction based on the user’s request and current project information.

The recommendation should explain:

- why it fits the project best
- how it connects to existing lore or mechanics
- which of the examples is strongest
- which risks or mismatches need review before implementation

## Output Contract

Return a structured result that matches the user’s target type:

- For race: race theme + example race list + race-class fit + recommended option
- For class: class theme + role + race fit + allied classes + skill ideas + recommended option
- For skill: mechanic breakdown + combo/cost/cooldown notes + intended race/class fit + restrictions + recommended option

The final output must include:

- the target type clearly labeled
- the project context used
- 2–6 authored examples
- direct references to known project facts where relevant
- a recommendation and a short rationale

## Failure Behavior

If no project context is available, keep the design grounded but make the missing constraints explicit. Do not invent a full setting from scratch without acknowledging the gap.

## Completion Signal

A pass is complete when the skill provides exactly one entity type, 2–6 coherent examples that fit the known project state, and a clearly justified recommendation grounded in current design context.
