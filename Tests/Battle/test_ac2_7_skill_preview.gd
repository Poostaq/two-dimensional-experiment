class_name Ac2_7SkillPreviewTests
extends SceneTree

const ARENA_PATH := "res://Scenes/battle_arena.tscn"
const EXPECTED_PREVIEWS := {
	&"shield_bash": ["Shield Bash", CharacterSkill.Kind.ACTIVE, "Deal 7 damage.", "Closest active enemy.", "User must occupy a front-row slot.", "1 turn after use."],
	&"frontline_guard": ["Frontline Guard", CharacterSkill.Kind.PASSIVE, "Reduce the next damage taken by an adjacent ally by 3.", "Adjacent active allies.", "User must occupy a front-row slot.", "None"],
	&"quick_step": ["Quick Step", CharacterSkill.Kind.ACTIVE, "Gain 2 Speed until the end of the next turn.", "Self.", "None", "2 turns after use."],
	&"quick_strike": ["Quick Strike", CharacterSkill.Kind.ACTIVE, "Deal 5 damage.", "Closest active enemy.", "None", "None"],
	&"rally": ["Rally", CharacterSkill.Kind.ACTIVE, "Grant all active allies 2 Speed until the end of the round.", "All active allies, including the user.", "None", "2 turns after use."],
	&"evasion": ["Evasion", CharacterSkill.Kind.PASSIVE, "Prevent the first damage instance received each round.", "Self.", "None", "None"],
	&"momentum": ["Momentum", CharacterSkill.Kind.PASSIVE, "Gain 1 Speed after taking an action, lasting until battle ends.", "Self.", "User must remain active.", "None"],
	&"savage_blow": ["Savage Blow", CharacterSkill.Kind.ACTIVE, "Deal 12 damage.", "Closest active enemy.", "User must be above 50% HP.", "2 turns after use."],
	&"blood_scent": ["Blood Scent", CharacterSkill.Kind.PASSIVE, "Deal 3 additional damage to injured enemies.", "Enemies below 50% HP.", "Target must be below 50% HP.", "None"],
	&"brace": ["Brace", CharacterSkill.Kind.PASSIVE, "Reduce the first damage received each round by 2.", "Self.", "None", "None"],
	&"shadow_lunge": ["Shadow Lunge", CharacterSkill.Kind.ACTIVE, "Deal 10 damage.", "Farthest active enemy.", "User must occupy a back-row slot.", "Unavailable for the first turn of battle; none after use."],
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_structured_preview_contract()
	_test_blank_preview_rejection()
	_test_preview_duplication()
	await _test_exact_fixture_previews()
	if _failures.is_empty():
		print("AC2.7 tests passed")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_structured_preview_contract() -> void:
	var skill := CharacterSkill.create(
		&"shield_bash",
		"Shield Bash",
		CharacterSkill.Kind.ACTIVE,
		"Deal 7 damage.",
		"Closest active enemy.",
		"User must occupy a front-row slot.",
		"1 turn after use."
	)
	_expect(is_instance_valid(skill), "complete structured preview should be valid")
	if not is_instance_valid(skill):
		return
	_expect(skill.effect_text == "Deal 7 damage.", "effect text should be exact")
	_expect(skill.targeting_text == "Closest active enemy.", "targeting text should be exact")
	_expect(
		skill.requirements_text == "User must occupy a front-row slot.",
		"requirements text should be exact"
	)
	_expect(skill.cooldown_text == "1 turn after use.", "cooldown text should be exact")


func _test_blank_preview_rejection() -> void:
	var valid := ["Effect", "Target", "Requirement", "None"]
	for blank_index: int in 4:
		var fields := valid.duplicate()
		fields[blank_index] = " \t "
		var skill := CharacterSkill.create(
			&"invalid_preview",
			"Invalid Preview",
			CharacterSkill.Kind.ACTIVE,
			fields[0],
			fields[1],
			fields[2],
			fields[3]
		)
		_expect(skill == null, "blank preview field %d should be rejected" % blank_index)
	var explicit_none := CharacterSkill.create(
		&"explicit_none",
		"Explicit None",
		CharacterSkill.Kind.PASSIVE,
		"Prevent one hit.",
		"Self.",
		"None",
		"None"
	)
	_expect(is_instance_valid(explicit_none), "literal None should be valid authored content")


func _test_preview_duplication() -> void:
	var source := CharacterSkill.create(
		&"brace",
		"Brace",
		CharacterSkill.Kind.PASSIVE,
		"Reduce the first damage received each round by 2.",
		"Self.",
		"None",
		"None"
	)
	var copy := source.duplicate_skill()
	_expect(copy != source, "duplicate should be a distinct object")
	_expect(copy.effect_text == source.effect_text, "duplicate should preserve effect")
	_expect(copy.targeting_text == source.targeting_text, "duplicate should preserve targeting")
	_expect(copy.requirements_text == source.requirements_text, "duplicate should preserve requirements")
	_expect(copy.cooldown_text == source.cooldown_text, "duplicate should preserve cooldown")


func _test_exact_fixture_previews() -> void:
	var arena := await _instantiate_arena()
	_expect(is_instance_valid(arena), "battle arena should instantiate")
	if not is_instance_valid(arena):
		return
	var seen_ids: Array[StringName] = []
	var player_active := false
	var player_passive := false
	var enemy_active := false
	var enemy_passive := false
	for unit_id: StringName in [
		&"player_0", &"player_1", &"player_2", &"player_3", &"player_4", &"player_5",
		&"enemy_0", &"enemy_1", &"enemy_2", &"enemy_3", &"enemy_4", &"enemy_5",
	]:
		var unit := arena.get_unit_by_id(unit_id)
		_expect(is_instance_valid(unit), "fixture unit %s should exist" % unit_id)
		if not is_instance_valid(unit):
			continue
		for skill: CharacterSkill in unit.skills:
			seen_ids.append(skill.skill_id)
			_expect(EXPECTED_PREVIEWS.has(skill.skill_id), "unexpected fixture skill %s" % skill.skill_id)
			if not EXPECTED_PREVIEWS.has(skill.skill_id):
				continue
			var expected: Array = EXPECTED_PREVIEWS[skill.skill_id]
			_expect(_skill_preview_signature(skill) == expected, "preview mismatch for %s" % skill.skill_id)
			if unit.side == BattleUnitState.Side.PLAYER:
				player_active = player_active or skill.kind == CharacterSkill.Kind.ACTIVE
				player_passive = player_passive or skill.kind == CharacterSkill.Kind.PASSIVE
			else:
				enemy_active = enemy_active or skill.kind == CharacterSkill.Kind.ACTIVE
				enemy_passive = enemy_passive or skill.kind == CharacterSkill.Kind.PASSIVE
	_expect(seen_ids.size() == 11, "fixtures should expose exactly eleven skills")
	for expected_id: StringName in EXPECTED_PREVIEWS:
		_expect(seen_ids.has(expected_id), "fixture should contain %s" % expected_id)
	_expect(player_active and player_passive, "player fixtures should include active and passive skills")
	_expect(enemy_active and enemy_passive, "enemy fixtures should include active and passive skills")
	arena.queue_free()
	await process_frame


func _skill_preview_signature(skill: CharacterSkill) -> Array:
	return [
		skill.display_name,
		skill.kind,
		skill.effect_text,
		skill.targeting_text,
		skill.requirements_text,
		skill.cooldown_text,
	]


func _instantiate_arena() -> BattleArena:
	var packed := load(ARENA_PATH) as PackedScene
	var arena := packed.instantiate() as BattleArena if packed != null else null
	if is_instance_valid(arena):
		root.add_child(arena)
		await process_frame
	return arena


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
