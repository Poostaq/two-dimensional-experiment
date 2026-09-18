class_name BattleCharacterInfoPanelTests
extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
func _run() -> void:
	var path: String = "res://Scenes/UI/battle_character_info_panel.tscn"
	check(ResourceLoader.exists(path), "authored character information panel exists")
	if ResourceLoader.exists(path):
		var panel: Control = load(path).instantiate()
		root.add_child(panel)
		await process_frame
		var view: Dictionary = {"display_name":"Test", "role":"Combatant", "current_hp":12, "max_hp":20, "hp_text":"12 / 20", "speed_text":"10", "damage_text":"7", "defense_text":"2", "state_text":"", "armor_text":"3", "buffs_text":"None", "debuffs_text":"None", "passives_text":"Very long passive description. ".repeat(60)}
		var token: Array = [1,1,1,&"test"]
		panel.call("render", view, token, false)
		panel.call("open_panel")
		await create_timer(0.22).timeout
		check(panel.visible and panel.position.x >= 0, "panel slides in from left")
		check(panel.size.x <= 340, "panel width bounded")
		check((panel.get_node("%CharacterName") as Label).text == "Test", "identity rendered")
		check((panel.get_node("%InfoScroll") as ScrollContainer).get_v_scroll_bar().max_value > 0, "long content scrolls")
		(panel.get_node("%InfoScroll") as ScrollContainer).scroll_vertical = 100
		panel.call("close_panel")
		check((panel.get_node("%InfoScroll") as ScrollContainer).scroll_vertical == 0, "closing resets scroll for next character")
		check(not panel.visible, "close immediately stops interception")
		panel.call("render", view, [1,2,2,&"other"], true)
		panel.call("open_panel")
		panel.call("close_panel")
		await create_timer(0.22).timeout
		check(not panel.visible, "old animation cannot reopen")
		panel.queue_free()
		await process_frame
	for failure: String in failures:
		print("FAILED: " + failure)
	if failures.is_empty():
		print("AC7.6 character info panel: PASS")
	quit(0 if failures.is_empty() else 1)
