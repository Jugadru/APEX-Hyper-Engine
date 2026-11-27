extends SceneTree
const Legacy = preload("res://experimental/apex2/command_queue.gd")
const Indexed = preload("res://experimental/hyper/indexed_queue.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var records: Array = []
	for id in range(1,3001):
		records.append({"id":id,"type":"set_pace","source":"Manual","car_id":1,"team":"Ferrari","at_tick":id+1,"created_tick":id,"status":"APPLIED" if id<3000 else "PENDING","reason":"ok","requested_lap":0,"compound":"","pace":"Normal","allow_double_stack":false})
	var state: Dictionary = {"schema":1,"sequence":3000,"records":records}
	var a = Legacy.new(); var b = Indexed.new()
	if not a.restore_state(state) or not b.restore_state(state): quit(1); return
	var begin: int = Time.get_ticks_usec()
	var n: int = 5000
	var ref_count: int = 0
	for i in range(n): ref_count += a.due(i).size()
	var legacy_us: int = Time.get_ticks_usec()-begin
	begin = Time.get_ticks_usec(); var new_count: int = 0
	for i in range(n): new_count += b.due(i).size()
	var indexed_us: int = Time.get_ticks_usec()-begin
	var ok: bool = ref_count==new_count and a.due(3001)==b.due(3001)
	a.settle(3000,true,"executed"); b.settle(3000,true,"executed")
	ok = ok and a.export_state()==b.export_state() and b.due(5000).is_empty()
	print("HYPER_QUEUE_BENCH ",JSON.stringify({"status":"PASS" if ok else "FAIL","records":3000,"calls":n,"legacy_us":legacy_us,"indexed_us":indexed_us,"identical_due_and_export":ok}))
	quit(0 if ok else 1)
