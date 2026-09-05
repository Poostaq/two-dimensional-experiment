# AC3.4 Manual Runtime Check

Date: 2026-09-05  
Scene: `res://Scenes/battle_arena.tscn`  
Viewport: 1152×648

| Check | Result | Evidence |
|---|---|---|
| Four character-specific skills coexist with separate Attack and Swap controls | PASS | GodotIQ tour and UI map show four skill buttons plus the dedicated Default actions region. |
| Default-action controls are readable and do not overlap the skill panel | PASS | Overview capture shows the action strip occupying the right half of the inspector row. |
| Attack and Swap meet the minimum pointer target height | PASS | Controls use a 48 px minimum height. |
| Attack preview and confirmation use the existing atomic transaction | PASS | Focused runner verifies no preview mutation, correct Power-versus-Defense damage, typed history, and one turn advance. |
| Swap accepts an adjacent active ally and rejects a non-adjacent ally | PASS | Focused runner verifies exact slot exchange and mutation-free rejection. |
| Action state clears on a turn change | PASS | RED/GREEN lifecycle case passes in the focused runner. |
| Current scene starts without failing runtime or script errors | PASS | GodotIQ `verify_project_runs(scene="current", check_scope="project")` returned PASS with zero captured errors. |

Overall: PASS. AC3.4 has automated integration coverage, retained domain coverage, visual evidence, and a clean runtime startup gate.
