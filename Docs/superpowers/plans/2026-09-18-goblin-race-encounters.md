# Goblin Race Encounters Implementation Plan

> Use superpowers:subagent-driven-development for independent combat rules and catalog work, with integration and review in the primary workspace.

**Goal:** Play goblins against three synergistic two-enemy race teams.

**Architecture:** Catalogs own unit and skill definitions. Shared rules resolve conditional damage and Armor breaking without preview mutation. BattleArena owns enemy action transactions and lifecycle. Stable encounter indices select fresh teams.

**Tech Stack:** Godot 4, typed GDScript, headless SceneTree tests, GodotIQ.

## Tasks

- [ ] Add failing `Tests/Battle/test_enemy_skill_rules.gd` cases for Armor stripping, bypass, same-round Armor loss, status and movement conditions. Extend the shared condition/effect/resolver/history/plan/damage modules to pass them. Validate/check each edited script.
- [ ] Add failing `Tests/Battle/test_debug_encounter_catalog.gd` cases for three exact two-unit teams, fresh state, full authored kits, targeting, and legal combo choices. Implement `debug_encounter_catalog.gd` and `enemy_action_selector.gd` with `create_enemies(index)` and `choose_action(actor, units, round, revision, history, records)`.
- [ ] Add integration assertions before changing starters and arena defaults. Use existing goblin catalog objects for the three starters, preserving legacy starter IDs for saved formations. Replace default arena fixtures with roster units and selected enemy catalog units.
- [ ] Connect stable coordinate-derived world encounter selection and exported standalone index. Add guarded enemy turn scheduling that pauses for preparation, rewards, and explicit fixture configuration; submit skills through ordinary confirmation and use Default Attack as fallback.
- [ ] Run new tests and affected combat/run/world tests with `godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/<runner>.gd`. Isolate historical debug fixtures in test-only helpers when old tests intentionally exercise their old skills.
- [ ] Review implementation against approved design; run GodotIQ validation, parser checks, runtime play/verify/console/state inspection and visual check. Record evidence, restore unrelated drawer edit, and commit only relevant changes on the task branch.
