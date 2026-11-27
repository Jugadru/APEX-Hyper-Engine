extends SceneTree
## Experimental longevity test; NOT a claim of a calibrated complete F1 GP.
const Adapter = preload("res://experimental/apex2/scenario_adapter.gd")
const Kernel = preload("res://experimental/apex2/driver_kernel_12.gd")
const Queue = preload("res://experimental/apex2/command_queue.gd")
var checks: int = 0
var errors: Array[String] = []
func ck(value: bool, name: String) -> void:
	checks += 1
	if not value: errors.append(name); printerr("APEX2_DRIVER_STRESS_FAIL ", name)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scenario: Dictionary = Adapter.create_pair("ITA", "Seco", 1202).scenario
	var k = Kernel.new()
	ck(k.initialize(scenario), "long session initialize")
	var advanced: int = k.step_ticks(10000)
	ck(advanced == 10000, "10000 sporting ticks without early termination")
	ck(k.state.cars.size() == 24, "stable grid")
	ck(k.queue.records.size() < Queue.MAX_COMMANDS, "queue stays within capacity")
	var ordered: bool = true
	var last: int = 0
	for event in k.state.events:
		if int(event.id) <= last: ordered = false
		last = int(event.id)
	ck(ordered and last == int(k.state.event_serial), "stable events and serial")
	var bounded: bool = true
	for c in k.state.cars:
		if int(c.driver.fatigue) < 0 or int(c.driver.fatigue) > 1000 or int(c.driver.confidence) < 0 or int(c.driver.confidence) > 1000:
			bounded = false
	ck(bounded, "psychological state remains bounded")
	var saved: Dictionary = k.checkpoint()
	var replay = Kernel.new()
	ck(replay.restore(saved), "long checkpoint restore")
	ck(replay.sporting_hash() == k.sporting_hash(), "long checkpoint hash")
	ck(k.step_ticks(80) == 80 and replay.step_ticks(80) == 80, "post checkpoint continuation")
	ck(k.sporting_hash() == replay.sporting_hash(), "long deterministic continuation")
	var ok: bool = errors.is_empty()
	print("APEX2_DRIVER_STRESS_12_%s checks=%d ticks=%d events=%d commands=%d errors=%s" % ["PASS" if ok else "FAIL", checks, advanced, k.state.events.size(), k.queue.records.size(), str(errors)])
	quit(0 if ok else 1)
