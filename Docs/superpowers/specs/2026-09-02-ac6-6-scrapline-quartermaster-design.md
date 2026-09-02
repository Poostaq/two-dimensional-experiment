# AC6.6 Scrapline Quartermaster Design

**Status:** Approved for implementation planning

**Acceptance criterion:** AC6.6 — Scrapline Quartermaster Cache state and pre-battle preparation choice

## Goal

Implement Brakka Rustbanner's Scrapline Quartermaster world-map passive as a durable, atomic handoff between accepted world movement and Combat initialization. The feature must show Cache progress on the world HUD, require a valid preparation choice before battle actions begin, survive save/reload without losing or duplicating a bonus, and leave unrelated movement and encounter rules unchanged.

## Scope

AC6.6 includes:

- Brakka-only Cache accrual after four accepted moves;
- one stored charge at most, with progress frozen while the charge is ready;
- a top-of-HUD progress or ready indicator;
- an input-blocking preparation choice for regular Combat encounters;
- Frontline Briefing and Spare Plating battle-start modifiers;
- atomic Cache consumption and preparation persistence;
- focused state, codec, transaction, runtime, and manual verification.

AC6.6 does not change movement range, move acceptance, reveal authority, encounter generation, Safe encounters, Boss encounters, rewards, commander progression, or AC6.7's full end-to-end integration gate.

## Authoritative Rules

Cache accrues only while Brakka is the selected commander. An accepted move advances `cache_move_progress` by one only when Cache is not ready. Rejected moves do nothing. When progress reaches four, Cache becomes ready and progress resets to zero. While ready, later accepted moves do not advance or bank progress.

Accrual occurs before destination encounter processing. Therefore, a fourth accepted move that enters Combat makes the newly earned Cache immediately available for that battle.

Cache is offered and consumed only for a regular Combat encounter. Safe and Boss encounters neither offer preparation nor consume Cache. After a successful Combat preparation commit, the next charge requires four new accepted moves.

## Ownership

### Durable run state

`WorldRunState` remains the durable authority and gains:

- `cache_move_progress: int`, constrained to `0..3`;
- `cache_ready: bool`;
- a serialized preparation record representing no preparation, an offered preparation, or a committed preparation.

Cache progress is independent from total `move_count`; it cannot be derived from the global count because progress freezes while a charge is stored.

### Preparation transaction

A focused typed preparation transaction owns choice state, setup identity, validation, and commit output. It accepts an immutable identity for the initialized battle setup and rejects cancellation while a choice is required.

The transaction supports exactly two choices:

- **Frontline Briefing:** select one active enemy from the matching battle setup and apply Advantage at battle start.
- **Spare Plating:** apply `+2 Armor` to every active player unit occupying a canonical frontline slot in the matching setup.

The transaction rejects an inactive target, allied target, missing target, changed setup, changed relevant formation, mismatched encounter, or already consumed transaction. A stale Frontline Briefing target is not redirected.

### Runtime coordination

`WorldRuntimeController` coordinates the world-to-battle handoff without owning the transaction's rules:

1. Commit an accepted move and its Cache accrual.
2. If the destination is regular Combat and Cache is ready, persist an offered preparation record and initialize the battle in a locked state.
3. Collect and validate the player's choice against the current immutable setup identity.
4. Persist a committed record containing the choice, optional target, and setup identity while consuming Cache in the same durable transition.
5. Apply the committed modifier idempotently to the matching battle setup.
6. Unlock battle actions.
7. Clear the preparation record only when the battle transition finishes safely.

The controller opens Combat normally when Cache is absent. It does not create a preparation transaction for Safe or Boss encounters.

### Battle ownership

`BattleArena` remains the authority for battle-local unit state and action availability. It displays the preparation UI, exposes the initialized setup identity needed for validation, applies an already committed preparation, and keeps all combat mutation locked until preparation is committed or confirmed unnecessary.

Preparation application is keyed by the committed preparation identity. Reapplying the same commit is a no-op, preventing duplicate Armor or Advantage after reload or scene reconstruction.

## Durable State Machine

The preparation record has three semantic states:

- **NONE:** no preparation belongs to the current world state.
- **OFFERED:** Cache remains ready; the encounter and setup identity are stored; the player must make a valid choice.
- **COMMITTED:** Cache is consumed; the chosen modifier and optional target are stored; the matching battle may apply the commit exactly once.

An offered record reloads into the same deterministic Combat setup with the prompt open and Cache intact. A committed record reloads into the matching setup, applies the stored modifier idempotently, and unlocks combat. The committed record remains durable until battle completion/exit cleanup so a crash cannot create a consumed-Cache-without-bonus window.

Persistence failure during commit leaves the durable record offered, keeps Cache ready, applies no modifier, and leaves combat locked. Validation failure has the same no-partial-mutation behavior.

## User Interface

### World HUD

The top world-map HUD shows Cache status only when Brakka is selected:

- `Cache 0/4`
- `Cache 1/4`
- `Cache 2/4`
- `Cache 3/4`
- `Cache Ready`

The ready label remains stable while progress is frozen. Runs without Brakka hide the indicator.

### Battle preparation panel

Before ordinary Combat controls become available, an input-blocking panel presents:

- `Frontline Briefing`;
- `Spare Plating`;
- concise choice and validation text;
- a confirmation action.

Frontline Briefing enters enemy-target selection. Only active enemy slots from the current setup are selectable. The selected target may be changed before confirmation. Spare Plating requires no secondary selection.

The panel cannot be dismissed while preparation is required. Default Attack, formation movement, skill selection and confirmation, turn advancement, and debug battle mutations remain disabled until a successful durable commit. Save or validation errors leave the panel open with a specific retryable message.

Successful application adds one battle-log entry naming the selected preparation and its target or affected allies.

## Save Compatibility and Validation

The V2 codec adds Cache and preparation fields while retaining compatibility with existing V2 saves. Missing fields decode as progress zero, Cache not ready, and no preparation record.

Decode rejects malformed combinations through the existing structured save-error path, including:

- progress outside `0..3`;
- an unknown preparation state or choice;
- an offered or committed record without a valid Combat/setup identity;
- committed Frontline Briefing without a target;
- preparation data attached to an unsupported encounter type;
- inconsistent Cache and transaction combinations.

## Error and Staleness Handling

No failure path may consume Cache, partially apply a modifier, or unlock combat. Transaction validation occurs immediately before commit. Relevant battle setup data is compared with the stored setup identity, and Frontline Briefing revalidates the target's side and active state.

Cancellation is rejected while preparation is required. A stale result remains visible and retryable; it never silently redirects to a different enemy or modifier.

## Verification Strategy

### Focused automated coverage

Quartermaster state tests verify:

- accrual only with Brakka selected;
- accepted versus rejected moves;
- the fourth-move boundary;
- immediate eligibility when the fourth move enters Combat;
- progress freezing while Cache is ready;
- progress restarting only after consumption;
- Safe and Boss non-consumption.

Save-codec tests verify:

- default values for older V2 saves;
- progress and ready-state round trips;
- offered and committed preparation round trips;
- malformed-state rejection;
- preservation of existing run-state fields.

Preparation transaction tests verify:

- both valid choices;
- active enemy and frontline ally resolution;
- cancellation rejection;
- stale target and setup rejection;
- atomic failure behavior;
- idempotent committed application.

Runtime integration tests verify:

- all HUD states and Brakka-only visibility;
- immediate preparation on a fourth-move Combat entry;
- complete battle-action locking;
- retry behavior after failed persistence;
- reload before commit;
- reload after commit;
- correct Advantage and Armor application;
- cleanup after battle completion.

Existing movement, autosave, battle-entry, Brakka-selection, Armor, Advantage, and battle-action suites remain regression gates.

### Manual evidence

The AC6.6 evidence record demonstrates HUD progression, Cache Ready freezing, both preparation paths, blocked controls, visible starting modifiers, offered and committed reload behavior, Safe/Boss non-consumption, and a clean debug console.

## Completion Boundary

AC6.6 is complete when the focused automated suites pass, production runtime evidence demonstrates both choices and save/reload durability, existing affected suites remain green, and the project runs without new parser or runtime errors. AC6.7 remains responsible for the full Goblin integration walkthrough across reward and next-battle transitions.
