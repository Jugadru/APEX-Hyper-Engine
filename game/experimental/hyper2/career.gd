extends RefCounted
## Independent 2012 career, single atomic state. Original careers remain untouched.
## Uses existing fictitious staff market/contracts and rival development modules.
const Kernel = preload("res://experimental/hyper2/kernel.gd")
const Scenario = preload("res://experimental/hyper/scenario.gd")
const Staff = preload("res://scripts/core/staff_market_0648.gd")
const Contracts = preload("res://scripts/core/staff_contracts.gd")
const Soul = preload("res://scripts/core/staff_soul_0650.gd")
const Rivals = preload("res://scripts/core/rival_development_0642.gd")
const POINTS: Array[int] = [25,18,15,12,10,8,6,4,2,1]
const FAMILIES: Array[String] = ["Motor","Asa","Chassi"]
const COSTS: Dictionary = {"Motor":1800000,"Asa":1500000,"Chassi":1300000}
const STAGES: Array[String] = ["PROJETO","PROTÓTIPO","TESTE","FABRICAÇÃO","PRONTO","INSTALADO"]
var state: Dictionary = {}
var save_path: String
var recovered_backup: bool = false
const WORK_COST: int=90000
const WORK_DAYS: int=2
func _init(path: String = "user://hyper_career_21.bin") -> void:
	save_path = path
	load_save()
func _hash(value: Dictionary) -> String:
	var ctx := HashingContext.new(); ctx.start(HashingContext.HASH_SHA256); ctx.update(var_to_bytes(Kernel.canonical(value))); return ctx.finish().hex_encode()
func _write(candidate: Dictionary) -> bool:
	if not _valid(candidate): return false
	var f := FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if f == null: return false
	f.store_var({"payload":candidate,"hash":_hash(candidate)},false); f.flush(); var err: Error = f.get_error(); f.close()
	if err != OK: return false
	var absolute: String = ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path) and not _read_save(save_path).is_empty() and DirAccess.copy_absolute(absolute,absolute+".bak") != OK: return false
	if DirAccess.rename_absolute(absolute+".tmp",absolute) != OK: return false
	state = candidate; return true
func load_save() -> bool:
	var primary: Dictionary = _read_save(save_path)
	recovered_backup = false
	if primary.is_empty():
		primary = _read_save(save_path+".bak")
		recovered_backup = not primary.is_empty()
	if primary.is_empty(): return false
	state = primary; return true
func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var f := FileAccess.open(path,FileAccess.READ)
	if f == null: return {}
	if f.get_length() < 8 or f.get_length() > 20000000: f.close(); return {}
	var stored_size: int = int(f.get_32())
	if stored_size != f.get_length()-4: f.close(); return {}
	f.seek(0)
	var v: Variant = f.get_var(false); f.close()
	if not v is Dictionary or not v.get("payload") is Dictionary: return {}
	if not _valid(v.payload) or str(v.get("hash","")) != _hash(v.payload): return {}
	return v.payload
func _valid(s: Dictionary) -> bool:
	if int(s.get("schema",0)) != 2 or not s.has_all(["team","seed","serial","round","calendar","drivers","constructors","results","budget","staff_roster","staff_payroll_keys","staff_log","staff_soul","rivals","parts","slots","projects","days_left","next_id","active_scenario"]): return false
	if not s.calendar is Array or not s.results is Array or not s.parts is Dictionary or not s.slots is Dictionary or not s.projects is Dictionary or not s.drivers is Dictionary or not s.constructors is Dictionary or not s.active_scenario is Dictionary: return false
	if s.calendar.size() != 20 or s.drivers.size() != 24 or s.constructors.size() != 12 or int(s.round) != s.results.size() or int(s.round) > 20 or int(s.days_left) < 0 or int(s.days_left) > 14: return false
	var occupied: Dictionary = {}
	for slot in s.slots:
		var id: String = str(s.slots[slot])
		if not s.parts.has(id) or occupied.has(id): return false
		var part: Dictionary = s.parts[id]
		if str(part.get("slot","")) != str(slot) or not str(part.get("family","")) in FAMILIES: return false
		occupied[id] = true
	if not s.get("work_orders") is Dictionary: return false
	var reserved_slots: Dictionary={}; var reserved_parts: Dictionary={}
	for part_id in s.parts:
		var part: Dictionary=s.parts[part_id]
		if not part.has_all(["family","level","focus","km","slot","condition","maintenance_count"]) or not str(part.family) in FAMILIES or int(part.km)<0 or int(part.condition)<0 or int(part.condition)>100 or int(part.maintenance_count)<0: return false
		if not str(part.slot).is_empty() and str(s.slots.get(str(part.slot),""))!=str(part_id): return false
	for work_id in s.work_orders:
		var work: Dictionary=s.work_orders[work_id]
		if not work.has_all(["slot","old_part","new_part","kind","status","remaining","cost"]) or not str(work.status) in ["PENDING","COMPLETE","CANCELLED"] or not str(work.kind) in ["MAINTENANCE","REPLACE"]: return false
		if work.status!="PENDING": continue
		if not s.slots.has(work.slot) or str(s.slots[work.slot])!=str(work.old_part) or reserved_slots.has(work.slot) or int(work.remaining)<=0 or int(work.remaining)>WORK_DAYS: return false
		reserved_slots[work.slot]=true
		if work.kind=="REPLACE":
			if not s.parts.has(work.new_part) or not str(s.parts[work.new_part].slot).is_empty() or reserved_parts.has(work.new_part) or s.parts[work.new_part].family!=s.parts[work.old_part].family: return false
			reserved_parts[work.new_part]=true
	return s.slots.size() == 6 and s.constructors.has(s.team)
func active() -> bool: return not state.is_empty() and int(state.round) < 20
func locked() -> bool: return not state.is_empty() and not state.active_scenario.is_empty()
func create(team: String, seed_value: int, data: Dictionary) -> bool:
	if active() or seed_value < 0 or data.tracks.size() != 20 or data.teams.size() != 12: return false
	var archive: Array = state.get("archive",[]).duplicate(true)
	if not state.is_empty() and int(state.round)==20:
		archive.append({"serial":int(state.serial),"team":str(state.team),"drivers":state.drivers.duplicate(true),"constructors":state.constructors.duplicate(true),"results":state.results.duplicate(true)})
		if archive.size()>20: archive.pop_front()
	var s: Dictionary = {"archive":archive,"schema":2,"work_orders":{},"serial":int(state.get("serial",0))+1,"team":team,"seed":seed_value,"round":0,"calendar":[],"drivers":{},"constructors":{},"results":[],"budget":12000000,"staff_roster":{},"staff_payroll_keys":{},"staff_log":[],"staff_soul":{},"rivals":Rivals.create(data.teams,team),"parts":{},"slots":{},"projects":{},"days_left":14,"next_id":1,"active_scenario":{}}
	for track in data.tracks: s.calendar.append(str(track.code))
	for t in data.teams:
		s.constructors[str(t.name)] = 0
		for d in t.drivers:
			s.drivers[str(d.name)] = {"team":str(t.name),"points":0}
			if str(t.name) == team:
				for family in FAMILIES:
					var id: String = _new_id(s,"P")
					var slot: String = str(d.name)+":"+family
					s.parts[id] = {"family":family,"level":0,"focus":"equilibrado","km":0,"condition":100,"maintenance_count":0,"slot":slot}
					s.slots[slot] = id
	for family in FAMILIES:
		var spare: String=_new_id(s,"P")
		s.parts[spare]={"family":family,"level":0,"focus":"equilibrado","km":0,"condition":100,"maintenance_count":0,"slot":""}
	Soul.ensure(s)
	return _write(s)
func _new_id(s: Dictionary, prefix: String) -> String:
	var id: String = "%s-%06d" % [prefix,int(s.next_id)]; s.next_id = int(s.next_id)+1; return id
func hire(role: String, candidate_id: String) -> String:
	if not active() or locked(): return "Departamento bloqueado durante o GP."
	var candidate: Dictionary = Staff.candidate(role,candidate_id)
	if candidate.is_empty(): return "Candidato inválido."
	var s: Dictionary = state.duplicate(true)
	var result: Dictionary = Contracts.hire(s,role,candidate,int(s.serial),int(s.round))
	if not bool(result.changed): return str(result.message)
	return str(result.message) if _write(s) else "Falha de persistência."
func release(role: String) -> String:
	if not active() or locked(): return "Departamento bloqueado durante o GP."
	var s: Dictionary = state.duplicate(true); var result: Dictionary = Contracts.release(s,role)
	if not bool(result.changed): return str(result.message)
	return str(result.message) if _write(s) else "Falha de persistência."
func start_project(family: String, focus: String) -> String:
	if not active() or locked() or not family in FAMILIES or not focus in ["equilibrado","desempenho","durabilidade"]: return "Projeto indisponível."
	var s: Dictionary = state.duplicate(true)
	var level: int = 0
	for project in s.projects.values():
		if str(project.family) == family and int(project.stage) < 5: return "Já há um projeto desta família."
	for p in s.parts.values():
		if str(p.family) == family: level = maxi(level,int(p.level))
	if level >= 3: return "Família no limite experimental de três revisões."
	var cost: int = int(COSTS[family])*(level+1)
	if int(s.budget) < cost: return "Saldo insuficiente."
	var id: String = _new_id(s,"RD")
	var role: String = "Chefe de Aerodinâmica" if family == "Asa" else "Engenheiro"
	var skill: int = int(s.staff_roster.get(role,{}).get("skill",50))
	var durations: Array = [2,3,2,4] if skill < 75 else [2,2,2,3]
	s.budget = int(s.budget)-cost
	s.projects[id] = {"family":family,"focus":focus,"level":level+1,"stage":0,"remaining":int(durations[0]),"durations":durations,"cost":cost,"kit":[]}
	return "Projeto "+id+" iniciado." if _write(s) else "Falha de persistência."
func advance_days(days: int) -> bool:
	if not active() or locked() or days <= 0 or days > int(state.days_left): return false
	var s: Dictionary = state.duplicate(true)
	for day in range(days):
		s.days_left = int(s.days_left)-1
		var busy: Dictionary = {}
		var ids: Array = s.projects.keys(); ids.sort()
		for id in ids:
			var p: Dictionary = s.projects[id]
			if int(p.stage) >= 4: continue
			var department: String = "Fábrica" if int(p.stage) == 3 else ("Aerodinâmica" if str(p.family) == "Asa" else "Engenharia")
			if busy.has(department): continue
			busy[department] = true
			p.remaining = int(p.remaining)-1
			if int(p.remaining) > 0: continue
			p.stage = int(p.stage)+1
			if int(p.stage) < 4: p.remaining = int(p.durations[int(p.stage)])
			else:
				for i in range(2):
					var part_id: String = _new_id(s,"P")
					s.parts[part_id] = {"family":str(p.family),"level":int(p.level),"focus":str(p.focus),"km":0,"condition":100,"maintenance_count":0,"slot":""}
					p.kit.append(part_id)
		_work_day(s)
	return _write(s)
func install(id: String) -> bool:
	if not active() or locked() or not state.projects.has(id) or int(state.projects[id].stage) != 4: return false
	var s: Dictionary = state.duplicate(true); var project: Dictionary = s.projects[id]
	var slots: Array = []
	for slot in s.slots:
		if str(s.parts[s.slots[slot]].family) == str(project.family): slots.append(slot)
	slots.sort()
	if slots.size() != 2 or project.kit.size() != 2: return false
	for slot in slots:
		if _reserved_slot(s,str(slot)): return false
	for i in range(2):
		var part_id: String = str(project.kit[i])
		if not s.parts.has(part_id) or not str(s.parts[part_id].slot).is_empty(): return false
		s.parts[s.slots[slots[i]]].slot = ""
		s.parts[part_id].slot = slots[i]; s.slots[slots[i]] = part_id
	project.stage = 5
	return _write(s)
func _levels_for(name: String, team: String) -> Dictionary:
	if team != str(state.team): return state.rivals.get(team,{}).get("levels",{}).duplicate(true)
	var levels: Dictionary = {}
	for family in FAMILIES:
		var p: Dictionary = state.parts[state.slots[name+":"+family]]
		levels[family] = int(p.level)
		levels[family+"_focus"] = str(p.focus)
		levels[family+"_km"] = int(p.km)
		levels[family+"_condition"] = int(p.condition)
	return levels
func prepare(weather: String, auto_pit: bool, setup_wet: int, second_setup: int=-1) -> Dictionary:
	if not active(): return {}
	if locked(): return state.active_scenario.duplicate(true)
	var code: String = str(state.calendar[int(state.round)])
	var seed_value: int = int(state.seed)+int(state.round)*7919
	var scenario: Dictionary = Scenario.create(code,"Seco" if weather=="Seco → chuva → seco" else weather,seed_value,str(state.team),auto_pit,setup_wet)
	if scenario.is_empty(): return {}
	if weather=="Seco → chuva → seco": scenario.hyper_weather = [{"tick":2500,"water":2500},{"tick":5000,"water":5000},{"tick":10000,"water":300}]
	if second_setup>=0:
		var index:int=0
		for car in scenario.cars:
			if str(car.team)==str(state.team):
				if index==1:scenario.hyper_specs[str(car.id)].wet_setup=clampi(second_setup,0,1000)
				index+=1
	scenario.hyper_career_token = "%d:%d:%d" % [state.serial,state.round,seed_value]
	for car in scenario.cars:
		var level: Dictionary = _levels_for(str(car.name),str(car.team))
		var spec: Dictionary = scenario.hyper_specs[str(car.id)]
		var motor: int = int(level.get("Motor",0)); var wing: int = int(level.get("Asa",0)); var chassis: int = int(level.get("Chassi",0))
		var motor_focus: String = str(level.get("Motor_focus","equilibrado")); var wing_focus: String = str(level.get("Asa_focus","equilibrado"))
		var chassis_focus: String = str(level.get("Chassi_focus","equilibrado"))
		var km: int = int(level.get("Motor_km",0))
		var fatigue: int = mini(15000,km*(3 if motor_focus == "durabilidade" else (8 if motor_focus == "desempenho" else 6)))
		spec.power = int(spec.power)+motor*(5500 if motor_focus == "desempenho" else 3500)-fatigue-70*(100-int(level.get("Motor_condition",100)))
		spec.downforce = int(spec.downforce)+wing*(38 if wing_focus == "desempenho" else (18 if wing_focus == "durabilidade" else 25))+chassis*(14 if chassis_focus == "desempenho" else 10)
		spec.drag = int(spec.drag)+wing*(10 if wing_focus == "desempenho" else (2 if wing_focus == "durabilidade" else 4))-chassis*(7 if chassis_focus == "desempenho" else 5)
		spec.downforce = int(spec.downforce)-mini(80,int(level.get("Asa_km",0))/(25 if wing_focus == "durabilidade" else 15))
		spec.drag = int(spec.drag)+mini(30,int(level.get("Chassi_km",0))/(60 if chassis_focus == "durabilidade" else 35))
		spec.downforce-=2*(100-int(level.get("Asa_condition",100)))
		spec.drag+=int((100-int(level.get("Chassi_condition",100)))/4)
		if str(car.team) == str(state.team):
			var mechanic: int = int(state.staff_roster.get("Chefe de Mecânica",{}).get("skill",50))
			spec.service_ticks = clampi(17-int(mechanic/15),10,17)
			spec.strategy_interval = 50 if int(state.staff_roster.get("Estrategista",{}).get("skill",50)) >= 75 else 100
	var candidate: Dictionary = state.duplicate(true); candidate.active_scenario = scenario.duplicate(true)
	return scenario if _write(candidate) else {}
func commit(kernel) -> bool:
	if not active() or not locked() or not kernel.initialized or not bool(kernel.state.finished): return false
	var scenario: Dictionary = state.active_scenario
	if str(kernel.state.get("hyper_career_token","")) != str(scenario.hyper_career_token) or str(kernel.state.track_code) != str(scenario.track_code) or int(kernel.state.seed) != int(scenario.seed) or int(kernel.state.race_laps) != int(scenario.race_laps) or int(kernel.state.lap_length_mm) != int(scenario.lap_length_mm) or str(kernel.state.hyper_player_team) != str(state.team): return false
	var rows: Array = kernel.classification()
	if rows.size() != 24: return false
	var s: Dictionary = state.duplicate(true); var seen: Dictionary = {}; var result_rows: Array = []; var team_points: int = 0; var best: int = 24
	var winner_laps: int = int(rows[0].laps)
	for i in range(rows.size()):
		var row: Dictionary = rows[i]; var name: String = str(row.name)
		if seen.has(name) or not s.drivers.has(name) or str(s.drivers[name].team) != str(row.team): return false
		seen[name] = true
		var classified: bool = int(row.laps) >= int(floor(float(winner_laps)*0.9)) and winner_laps > 0
		var points: int = POINTS[i] if classified and i < POINTS.size() else 0
		s.drivers[name].points = int(s.drivers[name].points)+points
		s.constructors[str(row.team)] = int(s.constructors[str(row.team)])+points
		result_rows.append({"position":i+1,"name":name,"team":str(row.team),"points":points,"laps":int(row.laps),"retired":bool(row.retired),"classified":classified,"stops":int(row.stops)})
		if str(row.team) == str(s.team):
			team_points += points; best = mini(best,i+1)
			var distance_km: int = maxi(0,int(int(row.progress)*int(kernel.state.lap_length_mm)/1000000000000))
			for family in FAMILIES:
				var part: Dictionary = s.parts[s.slots[name+":"+family]]; part.km = int(part.km)+distance_km
				part.condition=maxi(0,int(part.condition)-int(distance_km/(70 if part.focus=="durabilidade" else 45)))
	var round_number: int = int(s.round)+1
	var revenue: int = 850000 + team_points*25000
	s.budget = int(s.budget)+revenue
	var payroll: Dictionary = Contracts.settle_round(s,int(s.serial),round_number)
	Soul.settle_round(s,int(s.serial),round_number,best)
	s.rivals = Rivals.advance(s.rivals,round_number,int(s.seed),s.constructors,str(s.team))
	s.results.append({"round":round_number,"track":str(scenario.track_code),"hash":kernel.sporting_hash(),"rows":result_rows,"revenue":revenue,"payroll":int(payroll.paid)})
	s.round = round_number; s.days_left = 14; s.active_scenario = {}
	return _write(s)
func standings(constructors: bool) -> Array:
	var rows: Array = []
	if state.is_empty(): return rows
	var values: Dictionary = state.constructors if constructors else state.drivers
	for name in values:
		rows.append({"name":str(name),"points":int(values[name]) if constructors else int(values[name].points)})
	rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return str(a.name)<str(b.name) if int(a.points)==int(b.points) else int(a.points)>int(b.points))
	return rows

func _reserved_slot(s:Dictionary,slot:String)->bool:
	for work in s.work_orders.values():
		if work.status=="PENDING" and str(work.slot)==slot: return true
	return false
func available_spares(slot:String)->Array:
	var result:Array=[]
	if not state.get("slots",{}).has(slot): return result
	var reserved:Dictionary={}
	for work in state.work_orders.values():
		if work.status=="PENDING": reserved[str(work.new_part)]=true
	for project in state.projects.values():
		if int(project.stage)==4:
			for id in project.kit: reserved[str(id)]=true
	for id in state.parts:
		var part:Dictionary=state.parts[id]
		if not reserved.has(str(id)) and str(part.slot).is_empty() and part.family==state.parts[state.slots[slot]].family and int(part.condition)>0: result.append(str(id))
	result.sort(); return result
func start_work(slot:String,kind:String,new_part:String="")->bool:
	if not active() or locked() or not state.slots.has(slot) or _reserved_slot(state,slot) or not kind in ["MAINTENANCE","REPLACE"]: return false
	if kind=="REPLACE" and not new_part in available_spares(slot): return false
	var old:Dictionary=state.parts[state.slots[slot]]
	if kind=="MAINTENANCE" and int(old.condition)>=maxi(30,100-int(old.maintenance_count)*5): return false
	var cost:int=WORK_COST if kind=="MAINTENANCE" else 45000
	if int(state.budget)<cost: return false
	var s:Dictionary=state.duplicate(true); var id:String=_new_id(s,"WO")
	s.budget=int(s.budget)-cost
	s.work_orders[id]={"slot":slot,"old_part":str(s.slots[slot]),"new_part":new_part if kind=="REPLACE" else "","kind":kind,"status":"PENDING","remaining":WORK_DAYS,"cost":cost}
	return _write(s)
func cancel_work(id:String)->bool:
	if not active() or locked() or not state.work_orders.has(id) or state.work_orders[id].status!="PENDING": return false
	var s:Dictionary=state.duplicate(true); var work:Dictionary=s.work_orders[id]
	s.budget=int(s.budget)+int(int(work.cost)*int(work.remaining)/WORK_DAYS); work.status="CANCELLED"
	return _write(s)
func _work_day(s:Dictionary)->void:
	# One mechanic resource. Pending work holds both its slot and spare; no duplicate installation.
	var ids:Array=s.work_orders.keys(); ids.sort()
	for id in ids:
		var work:Dictionary=s.work_orders[id]
		if work.status!="PENDING": continue
		if str(s.slots.get(work.slot,""))!=str(work.old_part): continue
		work.remaining=int(work.remaining)-1
		if int(work.remaining)==0:
			if work.kind=="MAINTENANCE":
				var part:Dictionary=s.parts[work.old_part]; part.maintenance_count=int(part.maintenance_count)+1
				part.condition=maxi(int(part.condition),mini(int(part.condition)+25,maxi(30,100-int(part.maintenance_count)*5)))
			else:
				s.parts[work.old_part].slot=""; s.parts[work.new_part].slot=work.slot; s.slots[work.slot]=work.new_part
			work.status="COMPLETE"
		break
