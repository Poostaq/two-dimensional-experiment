# Copilot Instructions for GDScript

## Code Style

### Indentation
- Use tabs for indentation, not spaces.

### Type System
- Always use explicit static types. Never rely on type inference.
- Variables: `var player_id: int = 0`
- Function returns: `func get_player_id() -> int:`
- Constants: `const MOVE_SPEED: float = 5.0`
- Replace all magic numbers and strings with named constants.

### Node References
- Use `@onready` with explicit type annotations and node path syntax.
- Example: `@onready var collision_shape: CollisionShape3D = $CollisionShape3D`
- Always specify the full type name (e.g., `CollisionShape3D`, never inferred types).
- This ensures type safety, performance (nodes are cached), and self-documenting code.

### Naming Conventions
- `snake_case` for functions and variables: `var player_position`, `func calculate_damage()`
- `PascalCase` for classes and types: `class PlayerController`, `enum GameState`
- Prefix private functions with underscore: `func _process_input() -> void:`

## Code Organization

### Variable Declaration Order
1. Signals
2. Const declarations
3. @export variables
4. @onready variables
5. Regular var declarations

### Function Declaration Order
1. Built-in lifecycle functions (_ready, _process, _physics_process, etc.)
2. Private functions (prefixed with underscore)
3. Public functions

## Control Flow

- Use null checks and early returns instead of nested conditionals.
- Use guard clauses to exit early.
- Example:
  ```gdscript
  # Bad: Nested conditionals
  func process_player(player: Node) -> void:
      if player != null:
          if player.is_alive():
              if player.has_weapon():
                  player.attack()
  
  # Good: Early returns
  func process_player(player: Node) -> void:
      if player == null:
          return
      if not player.is_alive():
          return
      if not player.has_weapon():
          return
      player.attack()
  ```

## Error Handling

- Use explicit error handling. Never fail silently.
- Print errors or emit signals when issues occur.
- Example:
  ```gdscript
  func load_config(path: String) -> bool:
      if not FileAccess.file_exists(path):
          push_error("Config file not found: " + path)
          return false
      # Load config...
      return true
  ```

## Data Structures

### Typed Classes vs Dictionaries
- Always use typed classes (`Resource` or `RefCounted`) instead of untyped dictionaries for data structures.
- Provides type safety, IDE autocomplete, and proper type inference.
- Use for: data transfer objects, configuration objects, state containers.

#### Data Transfer Objects
- Use `Resource` or `RefCounted` classes instead of dictionaries to pass data between nodes.
- Extend `Resource` for serialization/saving, or `RefCounted` for lightweight data objects.
- Example:
  ```gdscript
  class_name PlayerData
  extends Resource
  
  var player_name: String = ""
  var health: int = 100
  var position: Vector3 = Vector3.ZERO
  
  func _init(name: String = "", hp: int = 100, pos: Vector3 = Vector3.ZERO) -> void:
      player_name = name
      health = hp
      position = pos
  ```
- Usage:
  ```gdscript
  # Bad: Untyped dictionary
  func get_player_info() -> Dictionary:
      return {"name": "Player", "health": 100, "position": Vector3.ZERO}
  
  # Good: Typed class
  func get_player_info() -> PlayerData:
      return PlayerData.new("Player", 100, Vector3.ZERO)
  ```

### Abstract Base Classes
- Use `@abstract` for base classes that define shared behavior but cannot be directly instantiated.
- Abstract classes must extend a Godot type (Node, CharacterBody3D, etc.) and are for inheritance only.
- Example:
  ```gdscript
  @abstract
  class_name Character
  extends CharacterBody3D
  
  @export var health: int = 100
  @export var speed: float = 5.0
  @export var acc: float = 2.5  ## acceleration
  @export var dec: float = 5.0  ## deceleration
  ```
- Extend in child classes:
  ```gdscript
  class_name Player
  extends Character
  
  @export var stamina: float = 100.0
  ```

## Code Architecture

### Composition Over Inheritance
- Use composition and component-based architecture instead of deep inheritance hierarchies.
- Attach scripts as components to nodes rather than creating complex base classes.
- Keep inheritance chains shallow (1-2 levels maximum).

### Loose Coupling
- Avoid tight coupling between systems and scripts.
- Use signals and event buses for communication between unrelated systems.
- Pass dependencies explicitly through function parameters or autoloads.
- Minimize direct node references. Use node paths or signals instead.

### Modularity
- Keep scripts focused on a single responsibility.
- Split large functionality into separate scripts/components.
- Organize code:
  - `systems/` - Cross-cutting concerns and managers
  - `autoloads/` - Global services used by multiple systems

## Code Patterns

### Event Bus Signals
- Use public signals (no underscore prefix) in event bus systems.
- Provide wrapper functions to emit signals. Never emit signals directly from external code.
- Cache values as private variables with getter functions when needed.
- Example:
  ```gdscript
  signal player_moved(position: Vector3)
  var _current_player_position: Vector3 = Vector3.ZERO
  
  func emit_player_moved(position: Vector3) -> void:
      _current_player_position = position
      player_moved.emit(position)
  
  func get_player_position() -> Vector3:
      return _current_player_position
  ```
- This provides encapsulation, validation hooks, and a clear API surface.

## Documentation

### Code Comments
- Avoid excessive documentation.
- Use self-documenting variable and function names.
- Only comment non-obvious logic or complex algorithms.

### Markdown Files
- Do not generate documentation (.md) files unless explicitly requested.

### UID Files
- Never manually create or edit Godot .uid files (`*.tscn.uid`, `*.gd.uid`, etc.).
- The Godot editor automatically manages these files.
- Manual editing causes conflicts and inconsistent asset metadata.

## Project-Specific Rules (Druid Survival Prototype)

### Architecture Boundaries

- Managers own global logic:
  - WorldManager → setup/config only
  - ChunkManager → chunk loading/unloading
  - TimeManager → time state
  - SpawnManager → spawn rules (data only)
  - SaveManager → persistence only

- WorldChunk owns ONLY local content:
  - builds visuals
  - spawns interactables
  - spawns fauna

- Never move logic from managers into WorldChunk.
- Never put global logic inside gameplay nodes.

---

### Deterministic Generation

- All procedural generation must be deterministic:
  - based on world seed + chunk coordinates
- Do NOT use uncontrolled random calls.
- Use `RandomNumberGenerator` with explicit seed.

---

### Performance Constraints

- Target: low to mid-range PC
- Avoid large numbers of active Nodes
- Use `MultiMeshInstance3D` for repeated decorative objects
- Only nearby chunks may contain active gameplay objects

Forbidden:
- Spawning entire world at once
- Running logic on distant chunks
- Keeping distant AI active

---

### Spawn System Rules

- SpawnManager returns data (spawn plan), NOT nodes
- WorldChunk performs instantiation

- Do NOT hardcode spawn logic inside WorldChunk
- Use Resource-based spawn definitions

---

### Code Safety Rules

- Do NOT modify unrelated files
- Do NOT refactor architecture unless explicitly asked
- Follow existing project structure

---

### Code Quality (Project Requirement)

- Code must be readable by a junior developer
- Prefer explicit logic over compact/clever solutions unless it significantly reduces code performance and/or size
- Use small, well-named functions

<!-- GODOTIQ RULES START -->
<!-- godotiq-rules-version: 0.5.15 -->
# GodotIQ — Core Rules

You have GodotIQ MCP tools (`godotiq_*`). ALWAYS prefer them over raw file operations on Godot files.

- **DO NOT** read `.tscn`/`.gd`/`.tres` directly with `Read`/`cat` — `file_context`, `scene_map` and `script_ops` return structured data with cross-references, transforms and signal wiring that raw text cannot provide.
- **DO NOT** grep for signal connections or function callers — `dependency_graph` / `signal_map` trace the complete graph in one call.
- **DO NOT** hand-calculate positions or guess scales — `placement` / `suggest_scale` return validated suggestions.
- **DO NOT** build the world in code: terrain, structures and decorations belong in `.tscn` via `build_scene`/`node_ops`; only game logic belongs in scripts.
- **DO NOT** write `.tscn`/`.gd` behind a running editor with native file tools — GodotIQ's write tools detect the editor and route safely; raw writes risk stale-buffer overwrites and UID corruption.

## Branch and Commit Workflow

When starting code work, agents must first update the default integration branch from origin, then create a dedicated task branch for the change.

- Use `main` in this repository; use `master` only in repositories where that is the default integration branch.
- Do not carry unrelated local changes onto the task branch. Stash or use an isolated worktree when needed.
- Commit the completed code change on the task branch with only relevant files staged.
- Push the branch when the user asks for remote handoff or review.

## Mandatory Workflows

1. **Session start:** `project_summary(detail="brief")` FIRST — architecture, autoloads, counts in ~500 chars.
2. **Before editing any file:** `file_context(file, detail="brief")`; for signature/signal changes also `impact_check(file, action, target)`. NEVER modify a `.gd` without `file_context` first.
3. **3D scene work:** `scene_map(focus, radius, detail="brief")` → `placement` for positions → `build_scene` (batches: grid/line/scatter) or `node_ops(validate=true)` → `save_scene()` → self-verify with `explore`/`spatial_audit`.
4. **Visual QA after scene work:** `explore(mode="tour")` — describe each screenshot, fix issues, tour again; `explore(mode="inspect", positions=[...])` for close-ups.
5. **After every code change:** `validate(target=file, detail="brief")` for Pro convention checks, then `check_errors(scope=file)` for compilation/parser errors. One script, one validate/check cycle — never batch five scripts then debug.
6. **Multi-file refactor:** `impact_check` BEFORE changing; `validate(target="project")` baseline before/after; then `check_errors(scope="project")` and `signal_map(find="orphans")`.
7. **Testing/debugging:** `run(action="play")` → `verify_project_runs()` → `read_debug_console()` for errors → `state_inspect` for values (cheap, preferred) → `verify_motion` for movement → `screenshot(scale=0.25, quality=0.3)` only when visuals changed (expensive) → `run(action="stop")`.

## Token Efficiency

- Default to `detail="brief"`; full payloads can emit 50k–140k chars and crash the session.
- Always filter: `focus`+`radius` (scene_map), `path_filter` (asset_registry), `scope="file:..."` (signal_map).
- Prefer `state_inspect` (~200 chars) over `screenshot` (10k+) when you need data, not pixels; max 1 screenshot per verification point.
- Batch: one `build_scene` or one `exec` loop beats 20 single `node_ops`; group edits → one `save_scene` → one verification cycle.
- Act on tool responses immediately; every bridge response carries `_editor_state` (open_scene, game_running, recent_errors) — react to it.

## Error Recovery

| Error | Action |
|---|---|
| `GAME_NOT_RUNNING` | `run(action="play")` |
| `RUNTIME_NOT_ATTACHED` | game playing but runtime tools unavailable: `run(action="stop")` then `play` to retry the handshake; if persistent, check the addon is enabled |
| `NO_GAME_SESSION` | restart the game with `run` |
| `NODE_NOT_FOUND` | `scene_tree(detail="brief")` to find the correct name |
| `ADDON_NOT_CONNECTED` | enable the GodotIQ addon in the Godot editor |
| `BLOCKED_EDITOR_OPEN` | the editor is open: use bridge ops (`node_ops`/`script_ops`/`save_scene`) instead of direct disk writes |
| `TIMEOUT` | wait, check `state_inspect`; truly dead → `run(action="stop")`, retry |
| `SCRIPT_ERRORS` | `check_errors(scope="scene")`, fix the scripts, rerun |
| `BLOCKED` (node_ops) | read the `validation` array, adjust position/scale |
| `NO_SCENE` / `PARENT_NOT_FOUND` / `NO_NODES` (build_scene) | open a scene / fix or create the parent / pass exactly one mode with valid data |
| Partial success (build_scene) | check `errors`, retry only the failed items |
| explore timeout / 0 screenshots | game must be running: `run(action="play")`, retry; partial results are valid — check `areas_inspected` |
| screenshot metadata but NO visible image | your client does not forward MCP images: retry with `delivery="legacy"` |

## Conventions

- GDScript: `snake_case.gd` files, `PascalCase` classes, type hints everywhere (`var hp: int = 0`, `-> void`), `@onready` for node refs, `is_instance_valid()` for null checks.
- `node_ops` paths are relative to the scene root: `"Entities/Worker_1"`, not `"Main/Entities/Worker_1"`.
- Scripts created this session: reference with `load()`, not `preload()`.

**Full reference:** `GODOTIQ_RULES.md` in the project root — read the relevant section before non-trivial work (3D building patterns, Godot quirks, verification recipes, spatial validation, per-tool reference).
<!-- GODOTIQ RULES END -->
