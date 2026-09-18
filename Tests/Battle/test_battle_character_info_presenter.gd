class_name BattleCharacterInfoPresenterTests
extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	var unit := BattleUnitState.new(&"test", "Test", BattleUnitState.Side.PLAYER, 0, 8, 20, [], 7, 3)
	_assert(unit.has_method("get_character_info_snapshot"), "unit exposes detached character snapshot")
	var path: String = "res://Scripts/UI/battle_character_info_presenter.gd"
	_assert(ResourceLoader.exists(path), "detached presenter exists")
	if unit.has_method("get_character_info_snapshot") and ResourceLoader.exists(path):
		_test_information(unit, load(path))
	for failure: String in _failures:
		print("FAILED: " + failure)
	if _failures.is_empty():
		print("Character information presenter: PASS")
	quit(0 if _failures.is_empty() else 1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _test_information(unit: BattleUnitState, presenter: Script) -> void:
	var passive := CharacterSkill.new(&"passive", "Watchful", CharacterSkill.Kind.PASSIVE,
		"React after an ally is hit.", "Self.", "While above half HP.", "Once per round.")
	unit.set_skills([passive])
	unit.add_speed_modifier(&"haste", 2, BattleUnitState.ModifierExpiry.NEXT_ACTION, 2)
	unit.add_speed_modifier(&"slow", -2, BattleUnitState.ModifierExpiry.CURRENT_ROUND, 1, 3)
	unit.add_armor(4)
	var source: RefCounted = load("res://Scripts/Battle/battle_keyword_source.gd").create(&"enemy", &"mark", 12)
	unit.apply_advantage(source, 3)
	unit.apply_snared(source, 3, true)
	unit.apply_bleed(source, 2)
	unit.apply_bleed(source, 2)
	var second: RefCounted = load("res://Scripts/Battle/battle_keyword_source.gd").create(&"other", &"cut", 5)
	unit.apply_bleed(second, 1)
	var record: Dictionary = unit.call("get_character_info_snapshot", 3)
	_assert(_primitives_only(record), "snapshot contains no live objects")
	_test_structured_effects(record, presenter)
	var before: Dictionary = record.duplicate(true)
	var info: Dictionary = presenter.present(record, {"phase": "resolving", "round_number": 3})
	_assert(record == before, "presenter never mutates input")
	_assert(info.speed_text == "8", "opposing speed modifiers cancel only in total")
	_assert(info.buffs_text.contains("+2") and info.debuffs_text.contains("-2"), "individual opposing speed effects remain visible")
	_assert(info.buffs_text.contains("2 affected-unit actions"), "speed uses affected-unit action expiry")
	_assert(info.debuffs_text.contains("end of round 3"), "round expiry is not generic turns")
	_assert(info.armor_text.contains("4") and info.buffs_text.contains("Consumed"), "armor amount and consumption")
	_assert(not info.defense_text.contains("%") and info.defense_text.contains("3"), "defense is flat, not percent")
	_assert(info.defense_description.contains("minimum of 1"), "defense explains minimum damage")
	_assert(info.debuffs_text.contains("Advantage rider") and info.debuffs_text.contains("Default Attack"), "Advantage has its actual consumption rules")
	_assert(info.debuffs_text.contains("2 stacks") and info.debuffs_text.contains("6 damage"), "Bleed stacks and damage remain distinct")
	_assert(info.debuffs_text.contains("1 affected-unit action"), "each Bleed source retains duration")
	_assert(info.passives_text.contains("React after an ally is hit.") and info.passives_text.contains("While above half HP.") and info.passives_text.contains("Once per round."), "passive metadata is complete")
	_assert(info.state_text.contains("resolving"), "committed resolving state is labeled")
	info.buffs[0].description = "changed"
	info.passives[0].name = "changed"
	_assert(record == before, "presenter defensively copies nested fields")
	record.buffs[0].description = "changed"
	unit.current_hp = 0
	unit.spend_armor(4)
	_assert(before.current_hp == 20 and before.armor == 4, "snapshot survives later simulation mutations")
	var expired: Dictionary = unit.call("get_character_info_snapshot", 4)
	_assert(not str(expired.debuffs).contains("Advantage"), "expired keyword absent from snapshot")
	_assert(is_instance_valid(unit.get("_advantage_source")), "capture does not lazily expire live keywords")
	_assert(is_instance_valid(unit.get("_snared_source")), "capture does not lazily expire live Snared")
	var empty := BattleUnitState.new(&"empty", "Empty", 0, 0, 5)
	var empty_info: Dictionary = presenter.present(empty.call("get_character_info_snapshot", 1), {})
	_assert(empty_info.buffs_text == "None" and empty_info.debuffs_text == "None" and empty_info.passives_text == "None", "empty groups explicitly show None")
	unit.consume_snared_follow_up(3)
	var consumed: Dictionary = presenter.present(unit.call("get_character_info_snapshot", 3), {"round_number": 3})
	_assert(consumed.debuffs_text.contains("Snared") and not consumed.debuffs_text.contains("next eligible direct hit"), "consumed follow-up removes only its description, preserving Snared")
	_assert(info.debuffs_text.contains("next eligible direct hit"), "old presented record retains captured armed state")
	unit.clear_battle_local_state()

func _test_structured_effects(record: Dictionary, presenter: Script) -> void:
	for group: String in ["buffs", "debuffs"]:
		for effect: Dictionary in record.get(group, []):
			_assert(effect.has("expiry_mode") and effect.has("expiry_value"), "all effects carry structured expiry")
			if effect.get("id") in [&"advantage", &"snared"]:
				_assert(effect.get("source_unit_id") == &"enemy" and effect.get("source_skill_id") == &"mark", "keyword source identity captured")
				_assert(effect.get("expiry_round") == 3, "keyword absolute expiry round captured")
			if effect.get("id") == &"snared":
				_assert(effect.get("follow_up_armed", false), "Snared follow-up captured")
			if effect.get("id") == &"bleed":
				_assert(effect.get("remaining_actions", 0) > 0, "Bleed action count captured")
	var info: Dictionary = presenter.present(record, {"resolution_in_progress": true, "phase": "player_turn", "round_number": 3})
	_assert(info.state_text.contains("resolving"), "canonical envelope resolution flag respected")
	_assert(info.debuffs_text.contains("next eligible direct hit") and info.debuffs_text.contains("Advantage"), "armed Snared follow-up explained")
	var detached: Dictionary = record.duplicate(true)
	for group: String in ["buffs", "debuffs"]:
		for effect: Dictionary in detached.get(group, []):
			effect["expiry"] = "deliberately stale"
	var derived: Dictionary = presenter.present(detached, {"round_number": 3})
	_assert(not derived.debuffs_text.contains("deliberately stale"), "duration is derived from structured expiry")
	_assert(derived.debuffs_text.contains("this round"), "duration is relative to captured envelope round")


func _primitives_only(value: Variant) -> bool:
	if value is Object:
		return false
	if value is Dictionary:
		for key: Variant in value:
			if not _primitives_only(key) or not _primitives_only(value[key]):
				return false
	if value is Array:
		for entry: Variant in value:
			if not _primitives_only(entry):
				return false
	return true
