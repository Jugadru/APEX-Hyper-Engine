extends SceneTree
const C=preload("res://experimental/hyper2/career.gd")
var fails:Array[String]=[]
var checks:int=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok: fails.append(label); printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var path: String="user://hyper2_qa_workshop.bin"
	for ext in ["",".bak",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+ext))
	var c=C.new(path); var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/season_2012.json"))
	ck(c.create("Ferrari",2026,data),"create")
	ck(c.state.parts.size()==9 and c.state.slots.size()==6,"inventory and spares")
	var slots:Array=c.state.slots.keys(); slots.sort(); var first:String=str(slots[0]); var second:String=""
	for slot in slots:
		if slot!=first and c.state.parts[c.state.slots[slot]].family==c.state.parts[c.state.slots[first]].family: second=slot
	var spare:String=str(c.available_spares(first)[0]); var before:String=c._hash(c.state)
	ck(c.start_work(first,"REPLACE",spare),"reserve")
	ck(not c.start_work(first,"REPLACE",spare),"slot locked")
	ck(not c.start_work(second,"REPLACE",spare),"part locked")
	ck(c.available_spares(second).is_empty(),"spare hidden")
	var id:String=str(c.state.work_orders.keys()[0]); var reserved_hash:String=c._hash(c.state)
	var r=C.new(path); ck(r._hash(r.state)==reserved_hash,"persist reservation")
	ck(r.advance_days(1),"one day"); ck(r.state.work_orders[id].remaining==1,"work not instant")
	ck(r.cancel_work(id),"cancel"); ck(spare in r.available_spares(second),"release spare")
	ck(r.start_work(second,"REPLACE",spare),"reserve released spare")
	var old:String=str(r.state.slots[second]); ck(r.advance_days(2),"work complete")
	ck(r.state.slots[second]==spare and r.state.parts[old].slot=="","swap atomically")
	ck(r.state.budget<12000000 and r._hash(r.state)!=before,"cost applied")
	var modified:Dictionary=r.state.duplicate(true); modified.parts[spare].condition=55; modified.parts[spare].km=500
	ck(r._write(modified),"controlled worn part fixture")
	ck(r.start_work(second,"MAINTENANCE"),"maintenance order")
	ck(r.advance_days(2),"maintenance complete")
	ck(r.state.parts[spare].condition==80 and r.state.parts[spare].km==500,"condition improves without odometer reset")
	ck(r.state.parts[spare].maintenance_count==1,"maintenance count")
	print("WORKSHOP ",JSON.stringify({"checks":checks,"failures":fails}));quit(0 if fails.is_empty() else 1)
