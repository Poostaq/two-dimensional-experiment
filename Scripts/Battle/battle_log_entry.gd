class_name BattleLogEntry
extends RefCounted

var sequence_number: int
var round_number: int
var attacker_id: StringName
var receiver_id: StringName
var applied_damage: int
var receiver_hp_after: int
var caused_defeat: bool


func _init(
	entry_sequence_number: int,
	entry_round_number: int,
	result: BattleDamageResult
) -> void:
	sequence_number = entry_sequence_number
	round_number = entry_round_number
	attacker_id = result.attacker_id
	receiver_id = result.receiver_id
	applied_damage = result.applied_damage
	receiver_hp_after = result.receiver_hp_after
	caused_defeat = result.caused_defeat
