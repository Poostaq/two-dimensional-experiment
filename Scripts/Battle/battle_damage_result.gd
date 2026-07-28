class_name BattleDamageResult
extends RefCounted

var attacker_id: StringName
var receiver_id: StringName
var requested_damage: int
var applied_damage: int
var receiver_hp_after: int
var caused_defeat: bool


func _init(
	result_attacker_id: StringName,
	result_receiver_id: StringName,
	result_requested_damage: int,
	result_applied_damage: int,
	result_receiver_hp_after: int,
	result_caused_defeat: bool
) -> void:
	attacker_id = result_attacker_id
	receiver_id = result_receiver_id
	requested_damage = result_requested_damage
	applied_damage = result_applied_damage
	receiver_hp_after = result_receiver_hp_after
	caused_defeat = result_caused_defeat
