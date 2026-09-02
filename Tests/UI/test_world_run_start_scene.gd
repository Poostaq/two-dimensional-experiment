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
        _expect(not button.tooltip_text.is_empty(), "skill square %d has authoritative tooltip" % index)
        button.grab_focus()
        _expect(root.gui_get_focus_owner() == button, "skill square %d accepts keyboard focus" % index)
    var passive := launcher.get_node("%CommanderSkill3") as Button
    _expect(passive.has_theme_stylebox_override("normal"), "Banner Holder has distinct passive styling")
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
