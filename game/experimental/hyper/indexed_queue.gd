extends "res://experimental/apex2/command_queue.gd"
## Same authoritative command ledger and validation; only pending records are
## scanned per tick. No removal, ID reuse or change to serialized state.
var pending: Dictionary = {}

func submit(command: Dictionary, state: Dictionary) -> Dictionary:
	var outcome: Dictionary = super.submit(command, state)
	if bool(outcome.accepted):
		var id: int = int(outcome.id)
		var entry: Dictionary = records[-1]
		pending[id] = entry
	return outcome

func due(tick: int) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for entry in pending.values():
		if int(entry.at_tick) <= tick:
			list.append(entry.duplicate(true))
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.at_tick) != int(b.at_tick): return int(a.at_tick) < int(b.at_tick)
		if str(a.source) != str(b.source): return str(a.source) == "Manual"
		return int(a.id) < int(b.id))
	return list

func settle(id: int, accepted: bool, reason: String) -> void:
	if not pending.has(id): return
	var record: Dictionary = pending[id]
	record.status = "APPLIED" if accepted else "REJECTED"
	record.reason = reason
	pending.erase(id)

func restore_state(data: Dictionary) -> bool:
	if not super.restore_state(data): return false
	pending.clear()
	for record in records:
		var id: int = int(record.id)
		if str(record.status) == "PENDING": pending[id] = record
	return true
