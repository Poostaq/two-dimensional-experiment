# Formation Movement

## Purpose

This document defines movement inside one six-character battle formation. Movement never crosses from one side's formation into the opposing side.

## Ring Topology

The six slots form one ring:

```text
Back top     1 ----- 6  Front top
             |       |
Back middle  2       5  Front middle
             |       |
Back bottom  3 ----- 4  Front bottom
```

Canonical clockwise order is `back_top -> back_middle -> back_bottom -> front_bottom -> front_middle -> front_top -> back_top`. Counterclockwise movement follows the reverse order. `Neighbor` always means an adjacent slot on this ring, not orthogonal grid adjacency.

## Move Range

- **Move 1:** Reach either immediate neighbor.
- **Move 2:** Reach either neighbor of a neighbor.
- **Move 3:** Reach any slot. The maximum shortest distance on the six-slot ring is three.
- A unit may choose a closer destination than its maximum Move value.
- At distance three, clockwise and counterclockwise paths are equally short. The player chooses the path before confirmation because each path shifts different occupants.

## Occupied-Path Rotation

Moving into an occupied destination does not fail. The mover takes the destination, and every occupant along the selected path shifts one slot toward the mover's origin.

For path `[origin, step 1, step 2, destination]`, the mover takes `destination`, the former destination occupant moves to `step 2`, the former `step 2` occupant moves to `step 1`, and the former `step 1` occupant moves to `origin`. The same rule works for shorter paths. Empty slots propagate normally; no character is invented or removed.

### Example: Front Bottom to Back Top

Characters 1-3 fill the back column top to bottom; characters 4-6 fill the front column top to bottom. Character 6 moves through `front_bottom -> back_bottom -> back_middle -> back_top`. Character 6 takes back top. Character 1 shifts to back middle, Character 2 to back bottom, and Character 3 to front bottom.

### Example: Front Top to Back Bottom

Character 4 moves through `front_top -> front_middle -> front_bottom -> back_bottom`. Character 4 takes back bottom. Character 3 shifts to front bottom, Character 6 to front middle, and Character 5 to front top.

## Swap

A skill or Default Swap that explicitly says `swap` exchanges exactly two characters. It ignores intermediate occupants and does not rotate a path. An effect uses either rotation or swap semantics, never both.

## Validation and Atomicity

Before confirmation, validate the actor and side, origin and destination, Move limit, selected direction, displayed path, every shifted occupant, battle revision, occupancy, and defeat state. If validation fails, reject the entire action: no movement, damage, status, Advantage change, cooldown, or history entry occurs.

The successful rotation is one atomic transition and one logical history record. Defeated units are not active occupants; their slots behave as empty. A changed occupancy after preview requires revalidation rather than silent path changes.

## Skill Authoring Requirements

Every movement effect declares mover, affected side, maximum Move 1-3, direction choice, rotation or swap semantics, whether secondary effects evaluate before or after movement, failure text, and combat-log text.

