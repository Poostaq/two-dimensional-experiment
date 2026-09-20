# AC8.5 rendered interaction evidence

Rendered Godot 4.7.2 D3D12 runs at 1280x720 and 1920x1080 passed with exit 0, the required PASS marker, and no ERROR output. Logs: rendered-1280.log and rendered-1920.log. Runner: Tests/WorldMap/capture_ac8_5_town_recruitment.gd.

Each run creates a valid golden-alpha town session with 500g, serializes it into an isolated user://ac8-5-rendered-<width>.json repository, injects that repository into the production world_run_start.tscn launcher, and clicks the real Continue button. Disposable save files are removed after success.

Verified actual viewport input:
- Pointer Continue, HUD Recruit, Close, class offer, and Cancel Placement.
- Tab changes focus within town; Enter chooses a recruit; Escape closes town.
- Wheel, right key, and pointer drag outside the card do not alter camera position or zoom.
- Close, Escape and placement cancellation preserve the full durable state; cancellation and Close preserve save bytes.
- Pointer press/motion/release starts Godot GUI drag on Scrapbroker and drops into empty Slot 5. Full durable-state equality proves only gold (500 to 0), Slot 5, and recruit HP change; moves, boss and other fields stay identical.
- A fresh production launcher clicks Continue, reopens Recruit, preserves purchased state and save bytes, and does not charge again.

Visual inspection of all twelve PNGs:
- rendered-hud-<width>.png: Recruit is visible and unobstructed, clear of minimap and Debug. At 1920 it follows the existing fixed HUD extent rather than the viewport right edge; no overlap or interaction issue.
- rendered-rich-<width>.png: centered contained card, readable Goblin Recruitment heading and 500g wallet, four full-width offers showing 500g, visible Close. At 720p the card has 90px vertical margins; at 1080p it remains centered with ample margins.
- rendered-placement-<width>.png: six slots and three occupied front-row cards are readable; pending Scrapbroker and Cancel Placement remain onscreen. Existing party layout expands horizontally and leaves open central space at 1080p.
- rendered-poor-<width>.png: wallet 0g, purchased Scrapbroker absent from offers and visible in the HUD back row; three disabled offers state Requires 500g; Close receives visible focus.
- rendered-continued-<width>.png: same poor state after fresh launcher Continue, with no missing or clipped controls.
- rendered-empty-fixture-<width>.png: No eligible recruits available message and Close are visible. This is explicitly a presentation-only empty-array configure fixture after the real flow; it does not claim a naturally exhausted roster and the runner verifies durable state and save bytes remain unchanged.

The first real-pointer run found Recruit hidden behind the minimap. The UI owner corrected its scene placement; the complete flow was rerun successfully at both sizes. No outstanding AC8.5 interaction or clipping defect was found in these captures.

Reproduce using the repository Godot executable with --path . --quit-after 1800 --script res://Tests/WorldMap/capture_ac8_5_town_recruitment.gd -- --width=1280 (repeat with 1920). Run without --headless. The recorded executions used Python subprocess.run with an external 120-second timeout and asserted exit 0, PASS marker, and absence of ERROR.
