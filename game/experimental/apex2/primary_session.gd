extends "res://scripts/core/race_replay_0660.gd"
## APEX 2 / PRIMARY CONTROL PLANE (compatibility phase).
## Inheritance maintains the full validated replay/command/telemetry protocol.
## ProductionScheduler is the new *main dispatcher*. Sporting dynamics are still
## delegated to Core 2 until APEX2 Vehicle Dynamics/AI/Pits reach parity.
const Scheduler = preload("res://experimental/apex2/production_scheduler.gd")
const ENGINE_ID: String = "APEX2_PRIMARY_COMPAT_06682"
var apex2_verified_ticks: int = 0
var apex2_dispatch_calls: int = 0

func attach(engine, modes: Dictionary = {}, staff: Dictionary = {}) -> void:
	super.attach(engine, modes, staff)
	apex2_verified_ticks = tick
	apex2_dispatch_calls = 0

func step_tick() -> bool:
	var previous_tick: int = tick
	var ok: bool = super.step_tick()
	if ok:
		if tick != previous_tick + 1:
			error = "APEX 2: a transição não avançou exatamente um tick."
			first_divergence = tick
			race.running = false
			return false
		apex2_verified_ticks = tick
	return ok

func advance(delta: float, speed: float, observer: Callable = Callable(), frame_budget_us: int = 0, max_backlog_steps: int = 0) -> int:
	apex2_dispatch_calls += 1
	return Scheduler.dispatch(self, delta, speed, observer, frame_budget_us, max_backlog_steps)

func seek(target: int) -> bool:
	var ok: bool = super.seek(target)
	if ok:
		apex2_verified_ticks = tick
	return ok

func load_live_session(recorded) -> bool:
	var ok: bool = super.load_live_session(recorded)
	if ok:
		apex2_verified_ticks = tick
	return ok

func load_data(data: Dictionary) -> bool:
	var ok: bool = super.load_data(data)
	if ok:
		apex2_verified_ticks = tick
	return ok

func runtime_contract() -> Dictionary:
	return {"id": ENGINE_ID, "primary_dispatcher": true, "step_seconds": STEP,
		"ticks": apex2_verified_ticks, "sporting_model": "CORE2_COMPATIBILITY_ADAPTER",
		"physics_replacement": false, "replay_format": "APEX_REPLAY_0660"}
