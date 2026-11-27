extends RefCounted
## APEX 2 / 0.6.6.8.2: authoritative FIXED-TICK DISPATCHER for live race sessions.
## Physics, pit rules, weather, racecraft and historical replays remain governed by
## the verified Core 2 sporting adapter (APEX 2 1.0 has no equivalent physics).
## This class owns wall-time budgeting but NEVER skips or approximates a sport tick.
## No mutable global state; replay and camera cannot influence the sport RNG.
const STEP_SECONDS: float = 0.20
const MAX_FRAME_TICKS: int = 16
const EPSILON: float = 0.000000001

static func dispatch(session, delta: float, speed: float, observer: Callable = Callable(), frame_budget_us: int = 0, max_backlog_steps: int = 0) -> int:
	if session.race == null or not session.race.running or session.race.finished or session.first_divergence >= 0:
		return 0
	if not is_finite(delta) or not is_finite(speed) or delta < 0.0 or speed < 0.0:
		return 0
	if max_backlog_steps > 0:
		var requested: float = session.accumulator + delta * speed
		var bound: float = STEP_SECONDS * float(max_backlog_steps)
		session.cpu_limited = requested > bound + 0.000001
		session.accumulator = minf(requested, bound)
	else:
		session.cpu_limited = false
		session.accumulator += delta * speed
	var done: int = 0
	var started: int = Time.get_ticks_usec() if frame_budget_us > 0 else 0
	while session.accumulator + EPSILON >= STEP_SECONDS and done < MAX_FRAME_TICKS and not session.race.finished:
		if done > 0 and frame_budget_us > 0 and Time.get_ticks_usec() - started >= frame_budget_us:
			break
		if session.playback and session.tick >= session.end_tick:
			session.race.running = false
			break
		if not session.step_tick():
			break
		if not session.playback and observer.is_valid():
			observer.call(session.race)
		session.accumulator = maxf(0.0, session.accumulator - STEP_SECONDS)
		done += 1
	return done
