class_name BattleResultRecord
extends RefCounted

const RECEIPT_KEYS: Array[String] = ["battle_id", "encounter_type", "encounter_coord", "outcome", "enemy_ids", "defeated_enemy_ids", "terminal_player_health", "earned_gold"]

var _type: String = ""
var _coord: Vector2i = Vector2i.ZERO
var _enemies: Dictionary = {}
var _players: Dictionary = {}
var _defeated: Dictionary = {}
var _receipt: Dictionary = {}

static func encounter_id(type: String, coord: Vector2i) -> String:
	if type == "boss":
		return "boss"
	if type == "combat":
		return "combat:%d:%d" % [coord.x, coord.y]
	return ""

static func capture(type: String, coord: Vector2i, units: Array[BattleUnitState]) -> RefCounted:
	if encounter_id(type, coord).is_empty():
		return null
	var script: Script = load("res://Scripts/Battle/battle_result_record.gd")
	var record: RefCounted = script.new()
	record._type = type
	record._coord = coord
	var seen: Dictionary = {}
	for unit: BattleUnitState in units:
		if not is_instance_valid(unit):
			return null
		var id: String = String(unit.unit_id)
		if not _valid_id(id) or seen.has(id) or unit.max_hp <= 0 or unit.current_hp < 0 or unit.current_hp > unit.max_hp:
			return null
		seen[id] = true
		if unit.side == BattleUnitState.Side.ENEMY:
			record._enemies[id] = unit
		elif unit.side == BattleUnitState.Side.PLAYER:
			record._players[id] = unit
		else:
			return null
	return record

func observe_defeat(unit: BattleUnitState, hp_before: int) -> void:
	if not _receipt.is_empty() or not is_instance_valid(unit) or hp_before <= 0 or unit.current_hp > 0:
		return
	for id: String in _enemies:
		if _enemies[id] == unit:
			_defeated[id] = true
			return

func freeze(outcome: BattleOutcome.Type) -> Dictionary:
	if not _receipt.is_empty():
		return get_receipt()
	if outcome not in [BattleOutcome.Type.VICTORY, BattleOutcome.Type.DEFEAT]:
		return {}
	var enemies: Array = _enemies.keys()
	enemies.sort()
	var defeated: Array = _defeated.keys()
	defeated.sort()
	var player_ids: Array = _players.keys()
	player_ids.sort()
	var health: Array = []
	for id: String in player_ids:
		var unit: BattleUnitState = _players[id]
		health.append({"character_id": id, "final_hp": unit.current_hp, "max_hp": unit.max_hp})
	var ids: Array[StringName] = []
	for id: String in defeated:
		ids.append(StringName(id))
	var economy: Script = load("res://Scripts/Run/run_economy_rules.gd")
	var candidate: Dictionary = {
		"battle_id": encounter_id(_type, _coord), "encounter_type": _type,
		"encounter_coord": [_coord.x, _coord.y],
		"outcome": "victory" if outcome == BattleOutcome.Type.VICTORY else "defeat",
		"enemy_ids": enemies, "defeated_enemy_ids": defeated,
		"terminal_player_health": health, "earned_gold": economy.victory_gold(outcome, ids),
	}
	if validate_receipt(candidate):
		_receipt = candidate
	return get_receipt()

func get_receipt() -> Dictionary:
	return _receipt.duplicate(true)

static func _valid_id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value == value.strip_edges()

static func _sorted_ids(value: Variant) -> bool:
	if not value is Array:
		return false
	var previous: String = ""
	for id: Variant in value:
		if not _valid_id(id) or (not previous.is_empty() and previous >= id):
			return false
		previous = id
	return true

static func _integer(value: Variant) -> bool:
	if value is int:
		return value >= -9007199254740991 and value <= 9007199254740991
	return value is float and is_finite(value) and value == floor(value) and abs(value) <= 9007199254740991.0

static func validate_receipt(value: Variant) -> bool:
	if not value is Dictionary or value.size() != RECEIPT_KEYS.size():
		return false
	for key: String in RECEIPT_KEYS:
		if not value.has(key):
			return false
	if not value.encounter_type is String or value.encounter_type not in ["combat", "boss"]:
		return false
	var coord: Variant = value.encounter_coord
	if not coord is Array or coord.size() != 2 or not _integer(coord[0]) or not _integer(coord[1]):
		return false
	if coord[0] < -2147483648 or coord[0] > 2147483647 or coord[1] < -2147483648 or coord[1] > 2147483647:
		return false
	if not value.battle_id is String or value.battle_id != encounter_id(value.encounter_type, Vector2i(coord[0], coord[1])):
		return false
	if not value.outcome is String or value.outcome not in ["victory", "defeat"]:
		return false
	if not _sorted_ids(value.enemy_ids) or not _sorted_ids(value.defeated_enemy_ids):
		return false
	for id: String in value.defeated_enemy_ids:
		if not value.enemy_ids.has(id):
			return false
	if not value.terminal_player_health is Array:
		return false
	var previous: String = ""
	for row: Variant in value.terminal_player_health:
		if not row is Dictionary or row.size() != 3 or not row.has_all(["character_id", "final_hp", "max_hp"]):
			return false
		if not _valid_id(row.character_id) or (not previous.is_empty() and previous >= row.character_id) or value.enemy_ids.has(row.character_id):
			return false
		if not _integer(row.final_hp) or not _integer(row.max_hp) or row.max_hp <= 0 or row.final_hp < 0 or row.final_hp > row.max_hp:
			return false
		previous = row.character_id
	if not _integer(value.earned_gold):
		return false
	var expected: int = value.defeated_enemy_ids.size() * 50 if value.outcome == "victory" else 0
	return value.earned_gold == expected

static func canonical_key(receipt: Dictionary) -> String:
	if not validate_receipt(receipt):
		return ""
	var tuple: Array = []
	for key: String in RECEIPT_KEYS:
		if key == "terminal_player_health":
			var rows: Array = []
			for row: Dictionary in receipt[key]:
				rows.append([row.character_id, int(row.final_hp), int(row.max_hp)])
			tuple.append(rows)
		elif key == "encounter_coord":
			tuple.append([int(receipt[key][0]), int(receipt[key][1])])
		elif key == "earned_gold":
			tuple.append(int(receipt[key]))
		else:
			tuple.append(receipt[key])
	return JSON.stringify(tuple)
