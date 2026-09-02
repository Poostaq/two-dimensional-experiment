# AC6.5 Commander Screen Polish Design

## Scope

Polish the accepted AC6.5 New Run commander-selection screen without changing its layout, commander-selection flow, seed handling, or run-start behavior.

## Visual Styling

- Add clearly visible two-pixel light grey borders to the screen's buttons, using the existing UI palette token for the light grey border.
- Give the previous and next carousel buttons the brightest treatment, including their disabled state while Brakka is the only commander.
- Give the three active-skill squares a restrained grey border that accents their silhouette without competing with their icons.
- Retain a distinct treatment for the commander passive using the existing passive-gold UI palette token while matching the active skills' border weight.
- Style Back and Begin consistently with the screen, with Begin remaining the primary action.

## Skill Tooltips

The New Run screen will own a dedicated tooltip panel rather than use Godot's delayed native tooltip. A skill button's `mouse_entered` signal will populate and reveal the panel immediately; `mouse_exited` will hide it. Keyboard focus will use the same show/hide behavior for accessibility.

The tooltip will:

- use a fixed maximum width of 340 pixels;
- wrap body text within that width;
- render the skill name at 18 points and body copy at 16 points;
- normalize compact cooldown text to `Cooldown: N turn` or `Cooldown: N turns`;
- prefix targeting copy with `Target:` in every case;
- remain non-interactive so it cannot interfere with button hover handling;
- anchor to the active skill button's outer bounds with a fixed offset, then clamp its panel rectangle to the viewport bounds using an eight-pixel margin.

Pointer hover and keyboard focus use the same tooltip state. If both are active, the most recently activated target wins; pointer hover may be suppressed when focus enters. Leaving or unfocusing a button hides the tooltip only when that button is still the active tooltip target, so an older exit event cannot dismiss a newer target's tooltip.

The existing skill data remains authoritative. Formatting is presentation-only and does not alter `CharacterSkill` resources or battle behavior.

## Ownership

- Modify `Scenes/world_run_start.tscn` to add the tooltip presentation nodes and button style overrides.
- Modify `Scripts/Run/world_production_launcher.gd` to format, position, show, and hide the immediate tooltip.
- Modify `Tests/UI/test_world_run_start_scene.gd` to verify tooltip formatting and presentation constraints plus required button borders.
- Do not introduce a global tooltip-delay setting or a reusable tooltip class for this four-button, screen-specific requirement.
- Keep disabled carousel arrows non-interactive: they must reject pointer and keyboard activation and emit no input while retaining their emphasized disabled styling.

## Verification

Automated UI-scene coverage will verify:

- all skill buttons have visible borders, with the passive retaining a distinct treatment;
- carousel buttons have a visible border in their disabled state;
- the tooltip becomes visible synchronously when its hover handler runs;
- cooldown and target text use the required readable labels;
- the title font is two points larger than the body font;
- tooltip width is capped and body wrapping is enabled.

Manual runtime verification will open New Run, hover each Brakka skill, confirm immediate appearance and disappearance, inspect wrapping and viewport placement, and visually check button borders at the supported window size.

## Out of Scope

- Changes to commander mechanics or skill values.
- Replacing Brakka's current portrait placeholder.
- Adding additional commanders or enabling the carousel buttons.
- Restyling tooltips elsewhere in the game.
