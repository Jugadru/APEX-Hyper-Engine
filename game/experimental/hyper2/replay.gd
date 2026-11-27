extends RefCounted
## In-memory review, nine compressed checkpoint anchors. Never changes live race.
const K=preload("res://experimental/hyper2/kernel.gd")
const MAX_ANCHORS:=9
const PERIOD:=300
const MAX_BYTES:=128*1024*1024
var anchors:Array=[]
var commands:Array=[]
var last_tick:int=0
func attach(kernel)->void:
	anchors.clear();commands.clear();last_tick=int(kernel.state.tick);_anchor(kernel)
func _anchor(kernel)->void:
	var data:PackedByteArray=var_to_bytes(kernel.checkpoint())
	if data.is_empty() or data.size()>MAX_BYTES:return
	var compressed:PackedByteArray=data.compress(FileAccess.COMPRESSION_ZSTD)
	if compressed.is_empty():return
	anchors.append({"tick":int(kernel.state.tick),"cursor":commands.size(),"size":data.size(),"data":compressed})
	while anchors.size()>MAX_ANCHORS:
		# Remove the interior anchor whose removal creates the smallest gap.
		var victim:int=1;var best:int=2147483647
		for i in range(1,anchors.size()-1):
			var span:int=int(anchors[i+1].tick)-int(anchors[i-1].tick)
			if span<best:best=span;victim=i
		anchors.remove_at(victim)
func observed(kernel)->void:
	last_tick=int(kernel.state.tick)
	if anchors.is_empty() or (last_tick-int(anchors[-1].tick)>=PERIOD or (kernel.state.finished and last_tick!=int(anchors[-1].tick))):_anchor(kernel)
func record(command:Dictionary,tick:int)->void:
	commands.append({"tick":tick,"command":command.duplicate(true)})
func seek(tick:int):
	if anchors.is_empty() or tick<int(anchors[0].tick) or tick>last_tick:return null
	var a:Dictionary=anchors[0]
	for cp in anchors:
		if int(cp.tick)>tick:break
		a=cp
	if int(a.size)<=0 or int(a.size)>MAX_BYTES:return null
	var raw:PackedByteArray=a.data.decompress(int(a.size),FileAccess.COMPRESSION_ZSTD)
	if raw.size()!=int(a.size):return null
	var decoded:Variant=bytes_to_var(raw);var probe=K.new()
	if not decoded is Dictionary or not probe.restore(decoded):return null
	var cursor:int=int(a.cursor)
	while int(probe.state.tick)<=tick:
		while cursor<commands.size() and int(commands[cursor].tick)==int(probe.state.tick):
			if not bool(probe.submit(commands[cursor].command).accepted):return null
			cursor+=1
		if int(probe.state.tick)==tick:return probe
		if not probe.step_tick():return null
	return null
