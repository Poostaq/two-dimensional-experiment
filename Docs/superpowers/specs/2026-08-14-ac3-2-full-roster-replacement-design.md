# AC3.2 Full-Roster Replacement Design

**Status:** Approved

**Acceptance criterion:** AC3.2 — If the roster is already full at 6 characters, the player must dismiss one character before acquiring a new one.

## Goal

Extend the completed AC3.3 party-management and pending-recruitment flow so a valid recruitment reward remains available at roster capacity and completes only after the player atomically replaces one of the six current characters.

## Product decisions

- A full-roster Combat or Boss victory may offer recruitment through the normal reward catalog alongside its non-recruitment alternatives.
- Confirming recruitment opens a replacement flow inside the existing party-management interface.
- The player may cancel replacement and return to the unchanged reward choices and selection.
- Any roster member, including an original starter, may be dismissed.
- A dismissed character is not permanently blacklisted and may become eligible for recruitment later in the same run.
- Duplicate character IDs remain forbidden within the current roster.

## Scope

AC3.2 includes:

- A third `PartyManagement.Mode.REPLACEMENT` mode that shares AC3.3's six slots, character cards, HP presentation, inspection details, and pending-recruit card.
- Full-roster reward eligibility for a valid, non-duplicate recruit.
- Dragging the pending recruit onto an occupied formation slot to choose the character to dismiss.
- Atomic replacement that preserves roster size six and the target slot index.
- Cancellation back to the suspended reward interface with no roster mutation.
- Defensive rejection of invalid, stale, duplicate, repeated, and lifecycle-invalid requests.
- Automated domain, UI, and integration coverage plus current runtime evidence.

AC3.2 does not include:

- Rearranging existing characters during replacement mode; AC3.3 normal mode owns rearrangement.
- Empty-slot recruitment; AC3.3 placement mode remains authoritative below capacity.
- Duplicate copies of the same character in one roster.
- Equipment return, progression disposal, or persistent between-battle health rules; AC3.4–AC3.6 and AC3.8 own those systems when their state becomes authoritative.
- A separate replacement scene or a generic roster-transaction framework.

## Architecture

The existing `PartyManagement` scene gains `Mode.REPLACEMENT`. Normal mode and placement mode keep their current behavior. Replacement mode receives the same defensive six-slot formation snapshot as the other modes plus one pending recruit. Existing members remain inspectable but cannot be dragged or rearranged. The pending recruit can be dragged only onto an occupied slot.

`MapController` remains the sole owner of the pending recruitment transaction. It uses the existing recruitment-suspension seam in `BattleArena`, decides whether the current roster needs empty-slot placement or full-roster replacement, configures the party scene accordingly, and performs authoritative revalidation when the scene emits an intent.

`RunRoster` gains one atomic replacement operation. It validates the requested slot, full-roster state, expected occupant identity, replacement character validity, and duplicate rules before performing a single slot assignment. No public remove-then-add sequence is introduced, so consumers never observe a five- or seven-member intermediate roster.

## Domain contract

Add a typed replacement result and operation to `RunRoster`:

```gdscript
enum ReplaceResult {
	REPLACED,
	INVALID_RECRUIT,
	DUPLICATE,
	NOT_FULL,
	INVALID_SLOT,
	EMPTY_TARGET,
	STALE_TARGET,
}

func try_replace_at(
	recruit: RunCharacter,
	slot_index: int,
	expected_character_id: StringName,
) -> ReplaceResult
```

The operation succeeds only when:

- the roster has exactly six occupied slots;
- `slot_index` is a valid occupied formation slot;
- that slot still contains `expected_character_id`;
- `recruit` is valid and has a non-empty stable character ID;
- no other occupied slot contains the recruit's character ID.

The operation assigns the complete recruit instance directly into the target slot and returns `REPLACED`. The dismissed character is no longer returned by `has_character()`, `get_characters()`, formation snapshots, or battle conversion. Because no blacklist is created, later reward filtering may offer that character again if otherwise eligible.

Every failure result leaves slot occupancy, character order, and membership unchanged. Repeating a previously successful request fails through stale-target or duplicate validation and cannot apply twice.

## Party-management replacement mode

Extend `PartyManagement.Mode` with `REPLACEMENT` and add one configuration entry point and one typed intent signal:

```gdscript
signal replacement_requested(
	destination_slot: int,
	expected_character_id: StringName,
	expected_recruit_id: StringName,
)

func configure_replacement(
	slots: Array[RunCharacter],
	pending_recruit: RunCharacter,
) -> void
```

Replacement mode presents:

- all six occupied formation slots using the existing row labels and cards;
- the pending recruit card outside the formation;
- concise instruction text explaining that dropping the recruit replaces the target;
- `Cancel` instead of `Return to Map`;
- the existing hidden-by-default details panel, populated when an occupied member is clicked.

Existing roster cards cannot begin drags in replacement mode. The pending recruit is the only drag source, and occupied formation slots are the only valid targets. Empty targets, outside drops, stale state, or synthetic invalid requests do nothing and refresh presentation from authoritative state when required.

A valid hover target receives destructive replacement feedback distinct from AC3.3's normal move/swap and empty-slot placement feedback. The UI identifies the member that will be dismissed before drop. A successful drop emits `replacement_requested` with the slot, the card's current occupant ID, and the pending recruit ID. The scene never mutates roster state itself.

Selection remains inspection-only. After a rejected request the authoritative refresh preserves a still-valid selected character; after cancellation, closure, successful replacement, reconfiguration, or teardown, selection, drag, hover, target, and pending-card state are cleared.

## Reward eligibility and transaction flow

Below capacity, AC3.3 behavior is unchanged: eligible recruitment is offered and confirmation opens empty-slot placement.

At capacity, reward filtering continues to reject an invalid or already-owned recruit, but it no longer rejects a valid recruit solely because `RunRoster.is_full()` is true. The normal Combat or Boss reward catalog therefore retains recruitment alongside its money and item alternatives.

The full-roster flow is:

1. The player wins a supported battle and selects a valid recruitment reward.
2. `BattleArena.confirm_reward_selection()` emits the existing `recruitment_placement_requested` signal and suspends reward completion without latching, confirming, exiting, or clearing selection.
3. `MapController` resolves a fresh catalog character and stores the exact reward option and recruit as its single pending transaction.
4. Because the roster is full, `MapController` opens `PartyManagement.configure_replacement()`.
5. Cancel closes party management, clears pending controller state, and calls `BattleArena.restore_pending_recruitment()` with the same option. The unchanged reward overlay and selection return.
6. A replacement request is revalidated against the pending recruit and current roster. `MapController` calls `RunRoster.try_replace_at()`.
7. On success, `MapController` closes party management, clears pending state, and calls `BattleArena.complete_pending_recruitment()` exactly once. Existing `reward_confirmed` and exit ordering remain authoritative.
8. On rejection, the transaction remains open and the party scene refreshes from a new formation snapshot.

The existing pending variables remain the single source of truth; no parallel replacement transaction is introduced. `exit_active_battle()`, `set_run_id()`, party-scene teardown, battle-tree exit, and run reset use the existing idempotent pending-recruit cleanup boundary. Unexpected teardown never applies dismissal or acquisition. Only explicit Cancel restores a live reward UI.

## Equipment and progression boundary

Current `RunCharacter` instances do not own authoritative equipment, progression, or persistent battle-damage state. AC3.2 therefore replaces the complete current character instance without inventing partial cleanup rules or parallel state stores.

Future equipment and progression criteria must extend the atomic replacement boundary before adding such state. For example, returning equipment to a shared inventory must happen as part of the same authoritative transaction, not in the party scene. This design neither promises destruction nor return of state that does not yet exist.

## Defensive behavior

- Reward confirmation never mutates the roster before a valid replacement target is accepted.
- Replacement is permitted only for a full six-member roster; below capacity continues through AC3.3 placement.
- The expected target ID prevents stale presentation from dismissing a different member.
- The expected recruit ID prevents stale or synthetic scene events from substituting a different recruit.
- Duplicate prevention checks every occupied slot without exception; an already-owned recruit remains invalid.
- Every roster mutation occurs in `RunRoster`; UI and battle code emit or coordinate intents only.
- One pending recruit and one party-management scene may exist at a time.
- Cancellation and every teardown boundary are idempotent and mutation-free.
- Successful completion is latched through the existing battle reward contract and cannot apply twice.

## Verification strategy

### Domain automation

Extend the focused roster coverage with:

- successful replacement at each semantic slot category;
- exact target-slot preservation and unchanged size six;
- dismissed membership removal and recruit membership addition;
- fresh battle conversion containing the recruit at the exact replaced slot;
- dismissed-character eligibility after replacement;
- invalid recruit, duplicate recruit, non-full roster, invalid slot, empty target, stale target, and repeated request rejection;
- full formation snapshot equality before and after every rejected operation.

The focused runner remains:

```text
Tests/Run/test_ac3_3_party_formation.gd
```

Its scope expands because `RunRoster` formation and atomic replacement are the same domain boundary. The runner name remains historical and does not imply AC3.2 is part of AC3.3.

### Scene automation

Extend the real-scene party-management runner to verify:

- replacement-mode instructions, pending card, six occupied targets, and Cancel presentation;
- existing-member drag is disabled while click inspection remains available;
- the pending card is the only drag source;
- occupied-only target feedback is distinct and identifies the dismissed member;
- the emitted payload contains exact slot, occupant ID, and recruit ID;
- invalid, empty, outside, stale, and repeated interactions emit no valid replacement intent;
- rejected refresh, cancellation, close, reconfiguration, and teardown clear transient interaction state;
- normal and placement modes retain all AC3.3 behavior.

The focused runner remains:

```text
Tests/UI/test_ac3_3_party_management.gd
```

### Integration and regression automation

Extend map/battle integration coverage to verify:

- a valid recruit remains in a full-roster Combat or Boss reward catalog beside non-recruitment options;
- an invalid or already-owned recruit remains filtered;
- confirming at capacity opens replacement mode without roster mutation or battle exit;
- Cancel restores the same selected reward and unchanged six-member formation;
- valid replacement changes exactly one slot, completes once, and exits through the existing order;
- the next battle places the recruit at the exact replaced semantic slot;
- the dismissed character becomes eligible for a later catalog when otherwise valid;
- stale target, wrong recruit ID, invalid slot, repeated request, teardown, battle exit, and run reset cannot mutate the roster;
- below-capacity placement, normal party rearrangement, AC3.1 acquisition, and AC3.3 cancellation remain unchanged.

The focused integration runner remains:

```text
Tests/Map/test_ac3_3_party_management_integration.gd
```

Existing AC3.1, AC3.3, and battle reward runners remain mandatory regression gates.

### Runtime and visual evidence

At 1152×648, use real pointer input to fill the roster, win a supported battle, confirm that recruitment remains visible, select it, and open replacement mode. Inspect a current member, drag the pending recruit over an occupied slot, confirm destructive target feedback identifies that member, then Cancel and verify the unchanged reward selection returns. Reopen replacement, complete the drop, and confirm the next battle uses the recruit at the exact replaced slot.

Run a GodotIQ visual tour after scene changes to verify that replacement instructions, pending card, all six targets, details, destructive feedback, and Cancel fit without overlap or clipping. Record runtime health and debug-console results.

## Acceptance traceability

| Requirement | Classification | Verification path | Completion gate |
|---|---|---|---|
| Full roster still permits valid recruitment | Integration/runtime | Reward catalog assertions plus live battle flow | Recruitment appears with alternatives at size six |
| Dismissal precedes acquisition completion | Domain/integration | Suspended reward and atomic replacement assertions | No mutation or completion occurs before target acceptance |
| Any member may be dismissed | Domain/UI/runtime | Slot matrix plus pointer replacement | Every occupied semantic slot is a valid target |
| Cancel returns to rewards | Integration/runtime | Restoration assertions plus pointer check | Formation unchanged and same selection restored |
| Roster remains valid | Domain | `try_replace_at()` result matrix | Exactly six members before and after success; no failure mutation |
| Exact formation is preserved | Domain/integration | Slot snapshot and next-battle assertions | Recruit occupies the dismissed member's slot |
| Dismissed character may return | Domain/integration | Membership and later eligibility assertions | Former member is eligible when otherwise valid |
| Defensive lifecycle | UI/integration | Stale, repeated, reset, exit, and teardown matrix | No unintended replacement or double completion |

## Authority and completion evidence

The authority chain is:

1. `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` for the canonical AC3.2 requirement and status.
2. This approved AC3.2 design for full-roster replacement behavior.
3. The completed AC3.3 design for shared party-management, formation, and pending-recruit contracts.
4. The AC3.2 implementation plan for executable steps and file ownership.
5. Focused tests and current GodotIQ/runtime outputs for verification.
6. Evidence files tied to one tested implementation commit.

Completion evidence will be written to:

```text
Docs/Specs/AC3/Evidence/AC3.2/2026-08-14/automated-test.log
Docs/Specs/AC3/Evidence/AC3.2/2026-08-14/manual-runtime-check.md
Docs/Specs/AC3/Evidence/AC3.2/2026-08-14/implementation-link.txt
```

The automated log records focused runner commands and PASS signatures, the full repository corpus, GodotIQ project validation/error/signal results, and the runtime gate. The manual record uses PASS/FAIL/BLOCKED entries for full-roster reward visibility, replacement presentation, click inspection, destructive target feedback, cancellation restoration, atomic completion, exact next-battle slot, and runtime health. All evidence files identify the same tested implementation commit.

Only after every gate passes may implementation change AC3.2 from `[ ]` to `[x]` and replace its manual-only verification row with an automated-and-manual contract naming the focused runners and runtime flow. AC3.1 and AC3.3 remain checked only if all their regression gates continue to pass. No later acceptance criterion is marked complete.

AC3.2 is complete only when atomic replacement, cancellation, later dismissed-character eligibility, exact formation preservation, defensive lifecycle behavior, focused and full-corpus tests, GodotIQ validation, runtime interaction, visual layout, and matching evidence all pass against one implementation commit.
