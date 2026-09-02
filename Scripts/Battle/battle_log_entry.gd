class_name BattleLogEntry
extends RefCounted

enum Kind {
	DAMAGE,
	MESSAGE,
}

var kind: Kind:
	get:
		return _kind
var message_text: String:
	get:
		return _message_text

var sequence_number: int
var round_number: int
var attacker_id: StringName
var receiver_id: StringName
var applied_damage: int
var receiver_hp_after: int
var caused_defeat: bool

var _kind: Kind = Kind.DAMAGE
var _message_text: String = ""


func _init(
	entry_sequence_number: int,
	entry_round_number: int,
	result: BattleDamageResult,
	entry_message_text: String = ""
) -> void:
	sequence_number = entry_sequence_number
	round_number = entry_round_number
	if is_instance_valid(result):
		_kind = Kind.DAMAGE
		attacker_id = result.attacker_id
		receiver_id = result.receiver_id
		applied_damage = result.applied_damage
		receiver_hp_after = result.receiver_hp_after
		caused_defeat = result.caused_defeat
		return
	if not entry_message_text.is_empty():
		_kind = Kind.MESSAGE
		_message_text = entry_message_text
		return
	push_error("BattleLogEntry requires damage result or nonempty message text.")


static func message(
	entry_sequence_number: int,
	entry_round_number: int,
	entry_message_text: String
) -> BattleLogEntry:
	if (
		entry_sequence_number < 1
		or entry_round_number < 1
		or entry_message_text.is_empty()
	):
		return null
	var entry_script: Script = load("res://Scripts/Battle/battle_log_entry.gd") as Script
	return entry_script.new(
		entry_sequence_number,
		entry_round_number,
		null,
		entry_message_text
	) as BattleLogEntry
