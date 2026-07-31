class_name BattleRewardOption
extends RefCounted

enum Kind {
	RECRUITMENT,
	MONEY,
	ITEM,
}

var reward_id: StringName
var kind: Kind
var title: String
var description: String


func _init(
	id: StringName,
	reward_kind: Kind,
	reward_title: String,
	reward_description: String
) -> void:
	reward_id = id
	kind = reward_kind
	title = reward_title
	description = reward_description
