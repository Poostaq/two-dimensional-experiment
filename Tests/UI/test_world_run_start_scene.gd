class_name WorldRunStartSceneTests
extends SceneTree

const SCENE_PATH := "res://Scenes/world_run_start.tscn"
const REQUIRED_UNIQUE_NODES: Array[StringName] = [
    &"ContinueButton",
    &"StartNewRunButton",
    &"ExitButton",
    &"SeedInput",
    &"CommanderPortrait",
    &"PreviousCommanderButton",
    &"NextCommanderButton",
    &"CommanderNameLabel",
    &"CommanderTitleLabel",
    &"CommanderSummaryLabel",
    &"CommanderRootClassLabel",
    &"CommanderSkill0",
    &"CommanderSkill1",
    &"CommanderSkill2",
    &"CommanderSkill3",
    &"CommanderSkillTooltip",
    &"CommanderSkillTooltipName",
    &"CommanderSkillTooltipBody",
    &"BeginButton",
    &"BackButton",
    &"OverwriteConfirmButton",
    &"OverwriteCancelButton",
    &"FailureHost",
    &"WorldHost",
]

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    if not ResourceLoader.exists(SCENE_PATH):
        _fail("production run-start scene is missing")
        _finish()
        return
    var packed := load(SCENE_PATH) as PackedScene
    var launcher := packed.instantiate() as Control
    _expect(is_instance_valid(launcher), "run-start scene instantiates")
    if not is_instance_valid(launcher):
        _finish()
        return
    var all_required_nodes_exist: bool = true
    for node_name: StringName in REQUIRED_UNIQUE_NODES:
        var node := launcher.get_node_or_null(NodePath("%" + String(node_name)))
        var exists: bool = is_instance_valid(node)
        all_required_nodes_exist = all_required_nodes_exist and exists
        _expect(exists, "unique node %s exists" % node_name)
    var main_screen := launcher.get_node_or_null("%MainScreen") as Control
    var new_run_screen := launcher.get_node_or_null("%NewRunScreen") as Control
    var overwrite_screen := launcher.get_node_or_null("%OverwriteScreen") as Control
    var continue_button := launcher.get_node_or_null("%ContinueButton") as Button
    _expect(is_instance_valid(main_screen) and main_screen.visible, "main screen is initially visible")
    _expect(is_instance_valid(new_run_screen) and not new_run_screen.visible, "seed controls are initially hidden")
    _expect(
        is_instance_valid(overwrite_screen) and not overwrite_screen.visible,
        "overwrite confirmation is initially hidden"
    )
    _expect(
        is_instance_valid(continue_button) and continue_button.disabled,
        "Continue is initially disabled without a validated save"
    )
    _expect(launcher.get_script() != null, "launcher logic is attached")
    _expect(
        launcher.get("_world_factory") is PackedScene,
        "launcher defaults to the production world factory"
    )
    _expect(
        launcher.mouse_filter == Control.MOUSE_FILTER_IGNORE,
        "launcher root leaves world clicks unhandled"
    )
    var new_run_center := launcher.get_node_or_null("NewRunCenter") as Control
    var failure_host := launcher.get_node_or_null("%FailureHost") as Control
    _expect(
        is_instance_valid(new_run_center)
        and new_run_center.mouse_filter == Control.MOUSE_FILTER_IGNORE,
        "hidden new-run layer does not intercept main-menu input"
    )
    _expect(
        is_instance_valid(failure_host)
        and failure_host.mouse_filter == Control.MOUSE_FILTER_IGNORE,
        "empty failure host does not intercept launcher input"
    )
    if not all_required_nodes_exist:
        launcher.free()
        _finish()
        return
    root.add_child(launcher)
    await process_frame
    launcher.call("open_new_run")
    await process_frame
    var previous := launcher.get_node("%PreviousCommanderButton") as Button
    var next := launcher.get_node("%NextCommanderButton") as Button
    var portrait := launcher.get_node("%CommanderPortrait") as TextureRect
    var seed := launcher.get_node("%SeedInput") as LineEdit
    var begin := launcher.get_node("%BeginButton") as Button
    _expect(previous.disabled and next.disabled, "single-entry carousel arrows are disabled")
    _expect(portrait.texture != null, "portrait uses an embedded placeholder texture")
    _expect(begin.text == "Begin", "final action is Begin")
    _expect(seed.global_position.y < begin.global_position.y, "seed input precedes Begin in setup flow")
    var expected_texts: Array[String] = ["ST", "PB", "BN", "BH"]
    for index: int in expected_texts.size():
        var button := launcher.get_node(NodePath("%CommanderSkill" + str(index))) as Button
        _expect(button.text == expected_texts[index], "skill square %d uses expected abbreviation" % index)
        _expect(button.focus_mode == Control.FOCUS_ALL, "skill square %d is keyboard focusable" % index)
        button.grab_focus()
        _expect(root.gui_get_focus_owner() == button, "skill square %d accepts keyboard focus" % index)
    var arrow_border := previous.get_theme_stylebox("disabled") as StyleBoxFlat
    _expect(previous.focus_mode == Control.FOCUS_NONE, "disabled previous arrow rejects keyboard focus")
    _expect(next.focus_mode == Control.FOCUS_NONE, "disabled next arrow rejects keyboard focus")
    _expect(
        is_instance_valid(arrow_border) and arrow_border.border_width_left == 2,
        "disabled carousel arrows retain a two-pixel border"
    )
    var active_style := (
        launcher.get_node("%CommanderSkill0").get_theme_stylebox("normal") as StyleBoxFlat
    )
    var passive := launcher.get_node("%CommanderSkill3") as Button
    var passive_style := passive.get_theme_stylebox("normal") as StyleBoxFlat
    _expect(
        is_instance_valid(active_style) and active_style.border_width_left == 2,
        "active skill has grey border"
    )
    _expect(
        is_instance_valid(passive_style) and passive_style.border_width_left == 2,
        "passive has matching border weight"
    )
    _expect(
        active_style.border_color != passive_style.border_color,
        "passive retains distinct gold accent"
    )
    _expect(
        launcher.get_node("%BackButton").has_theme_stylebox_override("normal"),
        "Back has screen border styling"
    )
    _expect(begin.has_theme_stylebox_override("normal"), "Begin has screen border styling")
    var tooltip := launcher.get_node("%CommanderSkillTooltip") as PanelContainer
    var tooltip_name := launcher.get_node("%CommanderSkillTooltipName") as Label
    var tooltip_body := launcher.get_node("%CommanderSkillTooltipBody") as Label
    var first_skill := launcher.get_node("%CommanderSkill0") as Button
    launcher.call("_show_commander_skill_tooltip", 0, first_skill)
    _expect(tooltip.visible, "hover handler shows tooltip without delay")
    _expect(not tooltip_name.text.is_empty(), "tooltip shows the skill name")
    _expect(
        tooltip_body.text.contains("Cooldown: 1 turn"),
        "cooldown uses readable singular wording"
    )
    _expect(tooltip_body.text.contains("Target:"), "target line always has its prefix")
    _expect(
        tooltip_body.autowrap_mode != TextServer.AUTOWRAP_OFF,
        "tooltip body wraps"
    )
    _expect(tooltip.custom_minimum_size.x == 340.0, "tooltip width is capped at 340 pixels")
    _expect(
        tooltip_name.get_theme_font_size("font_size")
        == tooltip_body.get_theme_font_size("font_size") + 2,
        "tooltip name is two points larger than body copy"
    )
    var second_skill := launcher.get_node("%CommanderSkill1") as Button
    launcher.call("_show_commander_skill_tooltip", 0, first_skill)
    launcher.call("_show_commander_skill_tooltip", 1, second_skill)
    launcher.call("_hide_commander_skill_tooltip", first_skill)
    _expect(tooltip.visible, "stale exit cannot hide the newer tooltip target")
    await process_frame
    var viewport_size := launcher.get_viewport_rect().size
    _expect(
        tooltip.global_position.x >= 8.0 and tooltip.global_position.y >= 8.0,
        "tooltip respects top-left viewport margin"
    )
    _expect(
        tooltip.global_position.x + tooltip.size.x <= viewport_size.x - 8.0,
        "tooltip clamps to viewport right margin"
    )
    _expect(
        tooltip.global_position.y + tooltip.size.y <= viewport_size.y - 8.0,
        "tooltip clamps to viewport bottom margin"
    )
    launcher.call("_hide_commander_skill_tooltip", second_skill)
    _expect(not tooltip.visible, "active target exit hides tooltip")
    var selected_before: StringName = launcher.call("get_selected_commander_id")
    previous.emit_signal("pressed")
    next.emit_signal("pressed")
    _expect(launcher.call("get_selected_commander_id") == selected_before, "disabled arrows do not change selection")
    launcher.queue_free()
    await process_frame
    _finish()


func _expect(condition: bool, message: String) -> void:
    if not condition:
        _fail(message)


func _fail(message: String) -> void:
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_run_start_scene")
    quit(1 if _failures > 0 else 0)
