class_name QuartermasterCacheRules
extends RefCounted

const BRAKKA_ID := &"brakka_rustbanner"
const MOVES_PER_CACHE := 4


static func after_accepted_move(
	commander_id: StringName,
	progress: int,
	ready: bool
) -> Dictionary:
	if progress < 0 or progress >= MOVES_PER_CACHE:
		return {}
	if commander_id != BRAKKA_ID or ready:
		return {"progress": progress, "ready": ready}
	var next_progress: int = progress + 1
	if next_progress >= MOVES_PER_CACHE:
		return {"progress": 0, "ready": true}
	return {"progress": next_progress, "ready": false}


static func after_consumption(was_ready: bool) -> Dictionary:
	if not was_ready:
		return {}
	return {"progress": 0, "ready": false}
