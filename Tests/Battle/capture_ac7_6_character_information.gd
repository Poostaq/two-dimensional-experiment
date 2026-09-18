class_name CaptureAc7_6CharacterInformation
extends SceneTree

const EVIDENCE: String = "res://Docs/Specs/AC7/Evidence/AC7.6/"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)

func _run() -> void:
	var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	root.add_child(arena)
	await _settle()
	var bar: Control = arena.get_node("%BattleActionBar")
	var panel: Control = arena.get_node("%BattleCharacterInfoPanel")
	var drawer: Control = arena.get_node("%BattleDebugDrawer")
	for width: int in [1152, 1024, 1920]:
		var height: int = 1080 if width == 1920 else 648
		root.content_scale_size = Vector2i(width, height)
		root.size = Vector2i(width, height)
		var definition: RunCharacter = RunCharacterCatalog.create_by_class_id(&"brakka_rustbanner")
		if not is_instance_valid(definition):
			print("FAILED: Brakka fixture missing")
			quit(1)
			return
		var actor := BattleUnitState.new(&"hero", "Brakka Rustbanner", 0, 0, 10, 40, definition.get_skills())
		var ally := BattleUnitState.new(&"ally", "Wirefang", 0, 3, 9, 30)
		var enemy := BattleUnitState.new(&"enemy", "Ironhide Raider", 1, 0, 5, 60)
		arena.configure_units([actor, ally, enemy])
		await _settle()
		var rows: HBoxContainer = bar.get_node("%SkillInspectorSkills")
		var skill: Button = rows.get_child(0)
		await _move(skill.get_global_rect().get_center())
		check((bar.get_node("%SkillTooltipPanel") as Control).visible, "real hover tooltip")
		await _capture("skills-%d.png" % width)
		await _click(bar.get_node("%DefaultAttackButton"))
		var before: Dictionary = arena.get_skill_presentation_snapshot()
		var mode: int = arena.get("_default_action_mode")
		await _click(arena.get_enemy_slots()[0], MOUSE_BUTTON_RIGHT)
		check(panel.visible and arena.get_character_info_snapshot().get("requested_unit_id") == &"enemy", "right click opens enemy")
		check(arena.get_skill_presentation_snapshot() == before and int(arena.get("_default_action_mode")) == mode, "inspection preserves targeting")
		await _capture("input-overlap-%d.png" % width)
		arena.close_character_info(false)
		actor.add_armor(3)
		actor.add_speed_modifier(&"rally", 3, BattleUnitState.ModifierExpiry.NEXT_ACTION, 2, 1)
		actor.add_speed_modifier(&"slow", -2, BattleUnitState.ModifierExpiry.CURRENT_ROUND, 1, 1)
		var source: RefCounted = load("res://Scripts/Battle/battle_keyword_source.gd").create(&"enemy", &"trap", 1)
		actor.apply_snared(source, 1, true)
		actor.apply_bleed(source, 2)
		arena.notify_authoritative_battle_change()
		await _click(arena.get_player_slots()[0], MOUSE_BUTTON_RIGHT)
		check(panel.visible, "right click ally")
		check((panel.get_node("%Buffs") as Label).text.contains("Speed") and (panel.get_node("%Debuffs") as Label).text.contains("Bleed"), "effects visible")
		await _capture("character-effects-%d.png" % width)
		var scroll: ScrollContainer = panel.get_node("%InfoScroll")
		var wheel := InputEventMouseButton.new()
		wheel.position = scroll.get_global_rect().get_center()
		wheel.global_position = wheel.position
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		root.push_input(wheel)
		await _settle()
		check(scroll.scroll_vertical > 0, "panel accepts actual wheel scrolling")
		scroll.ensure_control_visible(panel.get_node("%Passives"))
		await _settle()
		check((panel.get_node("%Passives") as Label).text.contains("Banner"), "passive description displayed")
		await _capture("character-passives-%d.png" % width)
		drawer.set_open(true)
		await _settle()
		await _capture("drawer-info-overlap-%d.png" % width)
		_key(KEY_ESCAPE)
		await _settle()
		check(not panel.visible and drawer.is_open(), "Escape closes information before drawer")
		_key(KEY_ESCAPE)
		await _settle()
		check(not drawer.is_open(), "second Escape closes drawer")
		_key(KEY_ESCAPE)
		await _settle()
		check(int(arena.get("_default_action_mode")) == 0, "third Escape clears action")
		# Passive-only roster: defaults remain, active row is empty.
		var passive := CharacterSkill.new(&"steady", "Steady Hands", CharacterSkill.Kind.PASSIVE, "A passive description that remains readable without occupying an action button.", "Self.", "Always.", "None")
		actor.set_skills([passive])
		arena.configure_units([actor, ally, enemy])
		arena.open_character_info(&"hero")
		await _settle()
		check(rows.get_child_count() == 0 and not (bar.get_node("%DefaultAttackButton") as Button).disabled, "passive only preserves defaults")
		await _capture("passive-only-%d.png" % width)
	arena.queue_free()
	await process_frame
	for failure: String in failures:
		print("FAILED: " + failure)
	print("AC7.6 rendered input/layout QA: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _settle() -> void:
	for frame: int in 6:
		await process_frame
	await create_timer(0.2).timeout

func _capture(filename: String) -> void:
	await _settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(EVIDENCE + filename) == OK, "saved " + filename)

func _move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event)
	await _settle()

func _click(control: Control, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	await _move(point)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = pressed
		root.push_input(event)
		await process_frame
	await _settle()

func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event)
