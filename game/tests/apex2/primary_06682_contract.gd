extends SceneTree
## APEX 2 production path vs Core 2: same inputs, commands, fixed ticks, hashes.
const Adapter = preload("res://experimental/apex2/scenario_adapter.gd")
const Factory = preload("res://experimental/apex2/session_factory.gd")
const Original = preload("res://scripts/core/race_replay_0660.gd")
const Primary = preload("res://experimental/apex2/primary_session.gd")
var count: int = 0
var problems: Array[String] = []

func assert_ok(value: bool, description: String) -> void:
	count += 1
	if not value:
		problems.append(description)
		printerr("APEX2_PRIMARY_FAIL: ", description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	ProjectSettings.set_setting("apex2/primary_controller", true)
	var expected: Dictionary = {"GBR":"Seco", "BEL":"Chuva intensa", "ITA":"Seco", "SIN":"Chuva intensa"}
	for code in expected:
		var left: Dictionary = Adapter.create_pair(code, expected[code], 6701)
		var right: Dictionary = Adapter.create_pair(code, expected[code], 6701)
		assert_ok(not left.is_empty() and not right.is_empty(), "base scenario %s" % code)
		if left.is_empty() or right.is_empty(): continue
		var a = Factory.create(left.core, {}, {})
		var b = Original.new()
		b.attach(right.core, {}, {})
		assert_ok(a is Primary, "%s uses APEX2 dispatcher as PRIMARY" % code)
		assert_ok(a.runtime_contract().sporting_model == "CORE2_COMPATIBILITY_ADAPTER", "no false claim of physics replacement")
		assert_ok(left.core.cars == right.core.cars, "%s identical initial grid" % code)
		left.core.running = true
		right.core.running = true
		var driver_id: int = int(left.core.player_cars()[0].id)
		var tire: String = str(left.core.available_pit_compounds()[1])
		if code == "BEL":
			assert_ok(left.core.schedule_pit(driver_id, tire, 21), "manual V21 queued primary")
			assert_ok(right.core.schedule_pit(driver_id, tire, 21), "manual V21 queued legacy")
		for tick_i in range(220):
			# 10 narrow visual frames vs one full frame must have same sporting result.
			for frame in range(10):
				a.advance(0.02, 1.0)
			b.advance(0.20, 1.0)
			if tick_i in [0, 25, 99, 219]:
				assert_ok(a.tick == b.tick, "%s tick %d" % [code,tick_i])
				assert_ok(a.hashes[-1] == b.hashes[-1], "%s sporting hash tick %d" % [code,tick_i])
		assert_ok(a.tick == 220 and b.tick == 220, "%s 220 ticks" % code)
		assert_ok(a.commands == b.commands and a.hashes == b.hashes, "%s command log and every hash" % code)
		assert_ok(a.apex2_verified_ticks == 220, "%s APEX2 verification counter" % code)
		if code == "BEL":
			assert_ok(int(left.core.player_cars()[0].pit_scheduled_lap) == 21, "rain cannot preempt manual V21")
			assert_ok(not bool(left.core.player_cars()[0].pit_request), "no early pit")
		# Legacy replay watcher must be able to fork from APEX2 recorder.
		var viewer = Original.new()
		assert_ok(viewer.load_live_session(a), "%s legacy viewer accepts APEX2 recording" % code)
		assert_ok(viewer.seek(110), "%s seek 110" % code)
		var apex_viewer = Primary.new()
		assert_ok(apex_viewer.load_live_session(a), "%s Next playback viewer accepts live recording" % code)
		assert_ok(apex_viewer.seek(220) and apex_viewer.apex2_verified_ticks == 220, "%s Next playback full hashes" % code)
		assert_ok(a.tick == 220 and a.hashes == b.hashes, "%s observer does not mutate live race" % code)
		print("APEX2_PRIMARY_SCENARIO_PASS ", code, " ticks=", a.tick, " hash=", str(a.hashes[-1]))
	ProjectSettings.set_setting("apex2/primary_controller", false)
	var backup: Dictionary = Adapter.create_pair("ITA", "Seco", 6701)
	var restored = Factory.create(backup.core)
	assert_ok(not restored is Primary, "rollback uses Core2 session")
	ProjectSettings.set_setting("apex2/primary_controller", true)
	assert_ok(Factory.primary_enabled(), "primary setting restored")
	print("APEX2_PRIMARY_CONTRACT_%s checks=%d problems=%s" % ["PASS" if problems.is_empty() else "FAIL", count, str(problems)])
	quit(0 if problems.is_empty() else 1)
