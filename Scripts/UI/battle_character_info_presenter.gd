class_name BattleCharacterInfoPresenter
extends RefCounted

# The arena supplies a committed primitive record, never a live unit.
static func present(record: Dictionary, context: Dictionary = {}) -> Dictionary:
	if record.is_empty():
		return {}
	var result: Dictionary = record.duplicate(true)
	result["role"] = str(record.get("role", "Combatant"))
	result["hp_text"] = "%d / %d HP" % [int(record.get("current_hp", 0)), int(record.get("max_hp", 0))]
	var speed: int = int(record.get("effective_speed", 0))
	var base_speed: int = int(record.get("base_speed", speed))
	result["speed_text"] = str(speed) if speed == base_speed else "%d (base %d, %+d)" % [speed, base_speed, speed - base_speed]
	result["damage_text"] = "%d base attack power" % int(record.get("power", 0))
	result["damage_description"] = "Skills and target defenses affect final damage."
	result["defense_text"] = "%d flat physical defense" % int(record.get("defense", 0))
	result["defense_description"] = "Reduces physical damage by this flat amount, to a minimum of 1 before Armor."
	result["armor_text"] = "%d Armor" % int(record.get("armor", 0))
	result["state_text"] = "Active" if bool(record.get("active", false)) else "Defeated"
	if str(context.get("phase", "")) == "resolving" or bool(context.get("resolution_in_progress", context.get("resolving", false))):
		result["state_text"] += " — Showing last committed state while resolving"
	var captured_round: int = int(context.get("round_number", 0))
	result["buffs_text"] = _effects_text(result.get("buffs", []), captured_round)
	result["debuffs_text"] = _effects_text(result.get("debuffs", []), captured_round)
	var passive_lines: PackedStringArray = []
	for passive: Dictionary in record.get("passives", []):
		passive_lines.append("%s\n%s" % [passive.get("name", ""), passive.get("description", "")])
	result["passives_text"] = "None" if passive_lines.is_empty() else "\n\n".join(passive_lines)
	return result


static func _effects_text(effects: Array, captured_round: int) -> String:
	var lines: PackedStringArray = []
	for effect: Dictionary in effects:
		effect["expiry"] = _expiry_text(effect, captured_round)
		if effect.get("id") == &"snared" and bool(effect.get("follow_up_armed", false)):
			effect["description"] = str(effect.get("description", "")) + " The next eligible direct hit by an ally of the source applies Advantage and consumes this follow-up."
		lines.append("%s: %s\n%s" % [
			effect.get("label", ""), effect.get("description", ""), effect["expiry"],
		])
	return "None" if lines.is_empty() else "\n\n".join(lines)


static func _expiry_text(effect: Dictionary, captured_round: int) -> String:
	var value: int = int(effect.get("expiry_value", 0))
	match StringName(effect.get("expiry_mode", &"")):
		&"actions":
			return "%d affected-unit action%s remaining." % [value, "" if value == 1 else "s"]
		&"consumption":
			return "Consumed as it absorbs physical damage."
		&"round_end", &"consumption_or_round_end":
			var prefix: String = "Consumed by an eligible skill, or expires" if effect.get("expiry_mode") == &"consumption_or_round_end" else "Expires"
			var relative: String = " (this round)" if captured_round == value else ""
			return "%s at end of round %d%s." % [prefix, value, relative]
	return str(effect.get("expiry", ""))
