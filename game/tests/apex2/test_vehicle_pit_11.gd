extends SceneTree
const Adapter = preload("res://experimental/apex2/scenario_adapter.gd")
const Kernel = preload("res://experimental/apex2/vehicle_kernel_11.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scenario: Dictionary = Adapter.create_pair("BEL","Chuva intensa",1133).scenario
	scenario.cars = [scenario.cars[0].duplicate(true)] # Isolate a single car for this V21 boundary test.
	var k = Kernel.new(); assert(k.initialize(scenario))
	var id: int = int(scenario.cars[0].id)
	var request: Dictionary = {"type":"schedule_pit", "source":"Manual", "car_id":id, "requested_lap":21, "compound":str(scenario.compounds[-1])}
	assert(bool(k.submit(request).accepted))
	var ai: Dictionary = {"type":"order_pit", "source":"AI", "car_id":id, "compound":str(scenario.compounds[-1])}
	assert(not bool(k.submit(ai).accepted))
	var crossing_tick: int = -1
	for i in range(55000):
		assert(k.step_tick())
		var c: Dictionary = k.state.cars[0]
		if int(c.laps_done) < 20:
			assert(int(c.pit_entry_tick) == -1)
		if int(c.pit_entry_tick) >= 0:
			assert(int(c.laps_done) == 20 and int(c.pit_requested_lap) == 21)
			crossing_tick = int(k.state.tick)
			break
	assert(crossing_tick > 0)
	var entries: int = 0
	for event in k.state.events:
		if str(event.type) == "pit_entry_boundary":
			entries += 1
			assert(int(event.requested_lap) == 21)
	assert(entries == 1)
	var replay = Kernel.new()
	assert(replay.restore(k.checkpoint()))
	assert(replay.sporting_hash() == k.sporting_hash())
	print("APEX2_VEHICLE_PIT_V21_PASS crossing_tick=",crossing_tick," hash=",k.sporting_hash())
	quit(0)
