class_name Ac2_5RewardSelectionTests
extends SceneTree

const CATALOG_PATH := "res://Scripts/Battle/battle_reward_catalog.gd"
const ARENA_PATH := "res://Scenes/battle_arena.tscn"
const EXPECTED_TEST_COUNT := 15

var _failures: Array[String] = []
var _catalog_script: GDScript
var _signal_events: Array[String] = []
var _confirmed_reward_id: StringName = &""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_catalog_script = load(CATALOG_PATH) as GDScript if ResourceLoader.exists(CATALOG_PATH) else null
	_test_combat_catalog_is_fixed()
	_test_boss_catalog_is_fixed_and_distinct()
	_test_unsupported_catalog_is_empty()
	_test_catalog_returns_fresh_instances()
	await _test_reward_ui_starts_hidden()
	await _test_combat_victory_shows_options()
	await _test_boss_victory_shows_options()
	await _test_defeat_never_shows_rewards()
	await _test_selection_replaces_and_gates_confirm()
	await _test_confirm_emits_ordered_once_and_cleans()
	await _test_debug_exit_cleans_without_reward()
	await _test_reconfigure_clears_reward_state()
	await _test_unsupported_victory_shows_empty_state()
	await _test_reward_layout_fits_viewport()
	await _test_new_battle_instance_is_clean()
	_report()
	quit(1 if not _failures.is_empty() else 0)


func _options_for(event_type: String) -> Array:
	if _catalog_script == null:
		return []
	return _catalog_script.call("get_options_for", event_type) as Array


func _test_combat_catalog_is_fixed() -> void:
	var options := _options_for("combat")
	_assert(
		_signature(options) == [
			[&"combat_recruit_scout", 0, "Recruit Scout", "Recruit a Scout after this battle."],
			[&"combat_money_100", 1, "100 Money", "Take 100 money for this run."],
			[&"combat_supply_cache", 2, "Supply Cache", "Take a cache of practical supplies."],
		],
		"Combat catalog is fixed",
		"expected the exact three Combat rewards"
	)


func _test_boss_catalog_is_fixed_and_distinct() -> void:
	var options := _options_for("boss")
	_assert(
		_signature(options) == [
			[&"boss_recruit_champion", 0, "Recruit Champion", "Recruit a Champion after this boss battle."],
			[&"boss_money_250", 1, "250 Money", "Take 250 money for this run."],
			[&"boss_rare_relic", 2, "Rare Relic", "Take a rare relic from the defeated boss."],
		] and _signature(options) != _signature(_options_for("combat")),
		"Boss catalog is fixed and distinct",
		"expected the exact three Boss rewards"
	)


func _test_unsupported_catalog_is_empty() -> void:
	_assert(_options_for("safe").is_empty(), "Unsupported catalog is empty", "Safe must not invent rewards")


func _test_catalog_returns_fresh_instances() -> void:
	var first := _options_for("combat")
	var second := _options_for("combat")
	_assert(
		first.size() == 3 and second.size() == 3 and first[0] != second[0],
		"Catalog returns fresh instances",
		"reward objects must not leak between battles"
	)


func _test_reward_ui_starts_hidden() -> void:
	var arena := await _instantiate_arena()
	_assert(_is_clean(arena), "Reward UI starts hidden", "new arena must have no reward state")
	_free_arena(arena)


func _test_combat_victory_shows_options() -> void:
	var arena := await _victory_arena("combat")
	var options := arena.call("get_reward_options") as Array
	_assert(
		_panel(arena).visible and options.size() == 3 and options[0].reward_id == &"combat_recruit_scout",
		"Combat victory shows options",
		"expected visible Combat rewards"
	)
	_free_arena(arena)


func _test_boss_victory_shows_options() -> void:
	var arena := await _victory_arena("boss")
	var options := arena.call("get_reward_options") as Array
	_assert(
		_panel(arena).visible and options.size() == 3 and options[0].reward_id == &"boss_recruit_champion",
		"Boss victory shows options",
		"expected visible Boss rewards"
	)
	_free_arena(arena)


func _test_defeat_never_shows_rewards() -> void:
	var arena := await _defeat_arena("combat")
	_assert(
		not _panel(arena).visible and (arena.call("get_reward_options") as Array).is_empty(),
		"Defeat never shows rewards",
		"defeat must remain reward-free"
	)
	_free_arena(arena)


func _test_selection_replaces_and_gates_confirm() -> void:
	var arena := await _victory_arena("combat")
	var confirm := arena.get_node_or_null("%ConfirmRewardButton") as Button
	var initially_disabled := confirm.disabled
	arena.call("select_reward", &"combat_recruit_scout")
	var scout_description := (arena.get_node_or_null("%RewardDescriptionLabel") as Label).text
	arena.call("select_reward", &"combat_money_100")
	var selected: Variant = arena.call("get_selected_reward")
	_assert(
		initially_disabled and not confirm.disabled
		and scout_description == "Recruit a Scout after this battle."
		and selected != null and selected.reward_id == &"combat_money_100"
		and (arena.get_node_or_null("%RewardDescriptionLabel") as Label).text == "Take 100 money for this run.",
		"Selection replaces and gates Confirm",
		"selection must be explicit and replaceable"
	)
	_free_arena(arena)


func _test_confirm_emits_ordered_once_and_cleans() -> void:
	var arena := await _victory_arena("combat")
	_reset_signal_capture()
	arena.reward_confirmed.connect(_on_reward_confirmed)
	arena.exit_requested.connect(_on_exit_requested)
	arena.call("select_reward", &"combat_supply_cache")
	arena.call("confirm_reward_selection")
	arena.call("confirm_reward_selection")
	_assert(
		_signal_events == ["reward", "exit"] and _confirmed_reward_id == &"combat_supply_cache" and _is_clean(arena),
		"Confirm emits ordered once and cleans",
		"expected one typed reward before one exit and immediate cleanup"
	)
	_free_arena(arena)


func _test_debug_exit_cleans_without_reward() -> void:
	var arena := await _victory_arena("combat")
	_reset_signal_capture()
	arena.reward_confirmed.connect(_on_reward_confirmed)
	arena.exit_requested.connect(_on_exit_requested)
	arena.call("select_reward", &"combat_recruit_scout")
	arena.call("_on_exit_debug_pressed")
	await process_frame
	_assert(
		_signal_events == ["exit"] and _confirmed_reward_id == &"" and _is_clean(arena),
		"Debug exit cleans without reward",
		"debug exit must never confirm a reward"
	)
	_free_arena(arena)


func _test_reconfigure_clears_reward_state() -> void:
	var arena := await _victory_arena("combat")
	arena.call("select_reward", &"combat_money_100")
	arena.call("configure_units", _fresh_units())
	_assert(_is_clean(arena), "Reconfigure clears reward state", "reused arena must reset rewards")
	_free_arena(arena)


func _test_unsupported_victory_shows_empty_state() -> void:
	var arena := await _instantiate_arena()
	arena.call("configure", Vector2i.ZERO, "combat")
	arena.set("encounter_type", "safe")
	arena.call("configure_units", _victory_units())
	arena.call("perform_debug_damage")
	var empty_label := arena.get_node_or_null("%RewardEmptyStateLabel") as Label
	var confirm := arena.get_node_or_null("%ConfirmRewardButton") as Button
	_assert(
		_panel(arena).visible and (arena.call("get_reward_options") as Array).is_empty()
		and empty_label.visible and empty_label.text == "No rewards available" and confirm.disabled,
		"Unsupported victory shows empty state",
		"unsupported victory must be explicit and non-actionable"
	)
	_free_arena(arena)


func _test_reward_layout_fits_viewport() -> void:
	var arena := await _victory_arena("combat")
	await process_frame
	var main_vbox := arena.get_node_or_null("Margin/VBox") as Control
	var overlay := arena.get_node_or_null("%RewardOverlay") as Control
	var confirm := arena.get_node_or_null("%ConfirmRewardButton") as Button
	var option_button := (arena.get_node_or_null("%RewardOptions") as Container).get_child(0) as Button
	_assert(
		main_vbox != null and not main_vbox.is_ancestor_of(_panel(arena))
		and overlay != null and overlay.position == Vector2.ZERO and overlay.size == arena.size
		and _panel(arena).custom_minimum_size.x >= 320.0
		and confirm.custom_minimum_size.y >= 48.0 and option_button.custom_minimum_size.y >= 48.0,
		"Reward layout fits viewport",
		"reward overlay must not participate in the main battle VBox layout"
	)
	_free_arena(arena)


func _test_new_battle_instance_is_clean() -> void:
	var first := await _victory_arena("combat")
	first.call("select_reward", &"combat_recruit_scout")
	first.call("confirm_reward_selection")
	_free_arena(first)
	await process_frame
	var second := await _instantiate_arena()
	_assert(_is_clean(second), "New battle instance is clean", "reward UI must not leak between fights")
	_free_arena(second)


func _instantiate_arena() -> Control:
	var packed := load(ARENA_PATH) as PackedScene
	var arena := packed.instantiate() as Control if packed != null else null
	if is_instance_valid(arena):
		root.add_child(arena)
		await process_frame
	return arena


func _victory_arena(event_type: String) -> Control:
	var arena := await _instantiate_arena()
	arena.call("configure", Vector2i.ZERO, event_type)
	arena.call("configure_units", _victory_units())
	arena.call("perform_debug_damage")
	return arena


func _defeat_arena(event_type: String) -> Control:
	var arena := await _instantiate_arena()
	arena.call("configure", Vector2i.ZERO, event_type)
	arena.call("configure_units", _defeat_units())
	arena.call("perform_debug_damage")
	return arena


func _victory_units() -> Array[BattleUnitState]:
	var player := BattleUnitState.new(&"player", "Player", BattleUnitState.Side.PLAYER, 0, 9)
	var enemy := BattleUnitState.new(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 8)
	enemy.current_hp = 6
	return [player, enemy]


func _defeat_units() -> Array[BattleUnitState]:
	var enemy := BattleUnitState.new(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 9)
	var player := BattleUnitState.new(&"player", "Player", BattleUnitState.Side.PLAYER, 0, 8)
	player.current_hp = 6
	return [enemy, player]


func _fresh_units() -> Array[BattleUnitState]:
	return [
		BattleUnitState.new(&"fresh_player", "Fresh Player", BattleUnitState.Side.PLAYER, 0, 9),
		BattleUnitState.new(&"fresh_enemy", "Fresh Enemy", BattleUnitState.Side.ENEMY, 0, 8),
	]


func _panel(arena: Control) -> Control:
	return arena.get_node_or_null("%RewardPanel") as Control


func _is_clean(arena: Control) -> bool:
	if not is_instance_valid(arena):
		return false
	var panel := _panel(arena)
	var options := arena.get_node_or_null("%RewardOptions") as Container
	var description := arena.get_node_or_null("%RewardDescriptionLabel") as Label
	var confirm := arena.get_node_or_null("%ConfirmRewardButton") as Button
	return panel != null and not panel.visible and options != null and options.get_child_count() == 0 \
		and description != null and description.text.is_empty() and confirm != null and confirm.disabled \
		and (arena.call("get_reward_options") as Array).is_empty() and arena.call("get_selected_reward") == null


func _signature(options: Array) -> Array:
	var result: Array = []
	for option: Variant in options:
		result.append([option.reward_id, int(option.kind), option.title, option.description])
	return result


func _reset_signal_capture() -> void:
	_signal_events.clear()
	_confirmed_reward_id = &""


func _on_reward_confirmed(option: BattleRewardOption) -> void:
	_signal_events.append("reward")
	_confirmed_reward_id = option.reward_id


func _on_exit_requested() -> void:
	_signal_events.append("exit")


func _free_arena(arena: Control) -> void:
	if is_instance_valid(arena):
		arena.queue_free()


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	if _failures.is_empty():
		print("AC2.5 reward selection tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
