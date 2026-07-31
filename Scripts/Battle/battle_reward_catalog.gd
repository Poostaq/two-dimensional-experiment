class_name BattleRewardCatalog
extends RefCounted


static func get_options_for(event_type: String) -> Array[BattleRewardOption]:
	match event_type:
		HexMapModel.ENCOUNTER_COMBAT:
			return [
				BattleRewardOption.new(&"combat_recruit_scout", BattleRewardOption.Kind.RECRUITMENT, "Recruit Scout", "Recruit a Scout after this battle."),
				BattleRewardOption.new(&"combat_money_100", BattleRewardOption.Kind.MONEY, "100 Money", "Take 100 money for this run."),
				BattleRewardOption.new(&"combat_supply_cache", BattleRewardOption.Kind.ITEM, "Supply Cache", "Take a cache of practical supplies."),
			]
		HexMapModel.ENCOUNTER_BOSS:
			return [
				BattleRewardOption.new(&"boss_recruit_champion", BattleRewardOption.Kind.RECRUITMENT, "Recruit Champion", "Recruit a Champion after this boss battle."),
				BattleRewardOption.new(&"boss_money_250", BattleRewardOption.Kind.MONEY, "250 Money", "Take 250 money for this run."),
				BattleRewardOption.new(&"boss_rare_relic", BattleRewardOption.Kind.ITEM, "Rare Relic", "Take a rare relic from the defeated boss."),
			]
		_:
			return []
