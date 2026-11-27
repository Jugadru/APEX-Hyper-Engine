extends SceneTree
const Resolver = preload("res://experimental/apex2/racecraft_resolver.gd")
const Kernel = preload("res://experimental/apex2/racecraft_kernel_13.gd")
const Adapter = preload("res://experimental/apex2/scenario_adapter.gd")
const Vehicle = preload("res://experimental/apex2/vehicle_dynamics.gd")
var checks: int = 0
var problems: Array[String] = []
func check(condition: bool, name: String) -> void:
	checks += 1
	if not condition:
		problems.append(name)
		printerr("APEX2_RACECRAFT_13_FAIL ", name)
func _initialize() -> void: call_deferred("run")
func car(id: int, mm: int, mm_s: int, intent: String) -> Dictionary:
	return {"id": id, "finished": false, "pit_stage": "TRACK", "driver": {"intent": intent}, "dynamics": {"distance_mm": mm, "speed_mm_s": mm_s}, "racecraft": Resolver.initial_state()}
func run() -> void:
	var profile: Array = [{"start_mm": 0, "radius_mm": 300000}]
	var roster: Array = [car(1, 100000, 93000, "PREPARE_ATTACK"), car(2, 125000, 60000, "COVER_THREAT"), car(3, 7000, 68000, "HOLD")]
	var first: Dictionary = Resolver.plan(roster, profile, 5000000, 1)
	check(str(first.states[1].phase) == "APPROACH", "real closing starts approach")
	check(roster[0].racecraft.phase == "CRUISE", "resolver is side-effect-free")
	roster[0].racecraft = first.states[1]
	var second: Dictionary = Resolver.plan(roster, profile, 5000000, 2)
	check(str(second.states[1].phase) == "PREPARE", "driver intent promotes preparation")
	roster[0].racecraft = second.states[1]
	var third: Dictionary = Resolver.plan(roster, profile, 5000000, 3)
	check(str(third.states[1].phase) == "ATTACK", "clear corridor enables attack")
	check(str(third.states[1].lane) != "CENTER", "attacker chooses lateral corridor")
	check(int(third.states[1].attempts) == 1, "attempt counted once")
	check(str(third.states[2].lane) != str(third.states[1].lane), "defender and attacker use different corridors")
	roster[0].racecraft = third.states[1]
	roster[1].racecraft = third.states[2]
	roster[0].dynamics.distance_mm = 121000
	var fourth: Dictionary = Resolver.plan(roster, profile, 5000000, 4)
	check(str(fourth.states[1].phase) == "SIDE_BY_SIDE", "side by side follows measured 4 m longitudinal proximity")
	check(int(fourth.speed_caps[1]) == Resolver.MAX_V_MM_S, "alternate corridor has no artificial engine boost or brake")
	var same_lane: Array = [car(1, 100000, 90000, "HOLD"), car(2, 108000, 50000, "HOLD")]
	var follow: Dictionary = Resolver.plan(same_lane, profile, 5000000, 1)
	check(int(follow.speed_caps[1]) <= 50000, "same-lane close follower receives braking envelope")
	check(int(follow.speed_caps[2]) == Resolver.MAX_V_MM_S, "leader is never slowed by following car")
	var restricted: Array = [{"start_mm":0,"radius_mm":40000}]
	var no_corridor: Dictionary = Resolver.plan([car(1, 100000, 90000, "PREPARE_ATTACK"), car(2, 124000, 60000, "HOLD")], restricted, 5000000, 1)
	check(str(no_corridor.states[1].phase) == "APPROACH", "narrow corner allows approach but not immediate side-step")
	var scenario: Dictionary = Adapter.create_pair("ITA", "Seco", 1303).scenario
	var kernel = Kernel.new()
	check(kernel.initialize(scenario), "kernel initializes full 24-car field")
	check(kernel.state.cars.size() == 24 and str(kernel.state.racecraft_model) == Kernel.RACECRAFT_TAG, "correct independent racecraft tag")
	check(kernel.step_ticks(70) == 70, "kernel advances vehicle + driver + resolver")
	check(int(kernel.state.racecraft_last_tick) == 70, "resolver runs on simulation tick")
	var cp: Dictionary = kernel.checkpoint()
	var other = Kernel.new()
	check(other.restore(cp), "checkpoint restores full duel state")
	check(other.sporting_hash() == kernel.sporting_hash(), "checkpoint hash reproducible")
	check(other.step_ticks(50) == 50 and kernel.step_ticks(50) == 50, "restored and original can advance")
	check(other.sporting_hash() == kernel.sporting_hash(), "restoration replay parity")
	var wrong: Dictionary = kernel.checkpoint()
	wrong.state.cars[0].racecraft.lane = "AIRBORNE"
	var before: String = kernel.sporting_hash()
	check(not kernel.restore(wrong), "invalid lane rejected")
	check(before == kernel.sporting_hash(), "failed restore does not mutate original")
	var wet = Kernel.new()
	var belgium: Dictionary = Adapter.create_pair("BEL", "Chuva intensa", 1303).scenario
	check(wet.initialize(belgium), "rain scenario initializes")
	var manual_id: int = int(wet.state.cars[0].id)
	check(bool(wet.submit({"type":"schedule_pit", "source":"Manual", "car_id":manual_id, "requested_lap":21, "compound":str(belgium.compounds[-1])}).accepted), "V21 manual accepted")
	check(not bool(wet.submit({"type":"order_pit", "source":"AI", "car_id":manual_id, "compound":str(belgium.compounds[-1])}).accepted), "AI cannot preempt V21")
	check(wet.step_ticks(500) == 500, "wet race advances")
	check(int(wet.state.cars[0].pit_requested_lap) == 21 and int(wet.state.cars[0].pit_entry_tick) == -1, "manual V21 not brought forward")
	# Controlled, reproducible legitimate longitudinal crossover: no place swap.
	var duel = Kernel.new()
	check(duel.initialize(scenario), "duel fixture created")
	var overtaker: Dictionary = duel.state.cars[0]
	var defender: Dictionary = duel.state.cars[1]
	var lap_length: int = int(duel.state.lap_length_mm)
	var base_mm: int = 400000
	overtaker.dynamics.distance_mm = base_mm
	overtaker.dynamics.speed_mm_s = 100000
	overtaker.progress_units = int(base_mm * duel.LAP_UNITS / lap_length)
	defender.dynamics.distance_mm = base_mm + 1000
	defender.dynamics.speed_mm_s = 55000
	defender.progress_units = int((base_mm + 1000) * duel.LAP_UNITS / lap_length)
	overtaker.racecraft.phase = "ATTACK"
	overtaker.racecraft.target_id = int(defender.id)
	overtaker.racecraft.lane = "LEFT"
	overtaker.racecraft.phase_tick = 0
	var before_gap: int = int(overtaker.dynamics.distance_mm) - int(defender.dynamics.distance_mm)
	check(before_gap < 0, "duel setup starts behind defender")
	check(duel.step_tick(), "duel fixture progresses by actual physics")
	var after_gap: int = int(overtaker.dynamics.distance_mm) - int(defender.dynamics.distance_mm)
	check(after_gap > 2500, "longitudinal crossover physically computed")
	var overtake_count: int = 0
	for ev in duel.state.events:
		if str(ev.type) == "racecraft_overtake_confirmed" and int(ev.car_id) == int(overtaker.id):
			overtake_count += 1
			check(int(ev.defender_id) == int(defender.id) and int(ev.gap_mm) == after_gap, "confirmed pass uses actual measured gap")
	check(overtake_count == 1 and int(duel.state.racecraft_passes) == 1, "confirmed pass emitted exactly once")
	check(str(overtaker.racecraft.phase) == "RECOVER", "passed car returns to racing lane")
	check(duel.step_tick() and int(duel.state.racecraft_passes) == 1, "pass confirmation not duplicated")
	var id_b: int = int(kernel.state.cars[1].id)
	for event in kernel.state.events:
		if str(event.type) == "racecraft_overtake_confirmed":
			var winner: Dictionary = kernel._lookup_car(int(event.car_id))
			var loser: Dictionary = kernel._lookup_car(int(event.defender_id))
			check(int(winner.dynamics.distance_mm) != int(loser.dynamics.distance_mm) or int(event.gap_mm) > 0, "overtake report grounded in movement")
	var ok: bool = problems.is_empty()
	print("APEX2_RACECRAFT_13_%s checks=%d problems=%s" % ["PASS" if ok else "FAIL", checks, str(problems)])
	quit(0 if ok else 1)
