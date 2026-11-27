extends RefCounted
## Hyper adaptation of Core 2 revisions 039/040 and randomness 0.6.8.
## Counter-based domain sampling, no mutable RNG, gameplay coefficients.
const KINDS := ["MISSED_APEX","POOR_TRACTION","LOCK_UP","OVERSTEER","RUNNING_WIDE","SPIN"]
const LABELS := {"MISSED_APEX":"Erro de trajetória","POOR_TRACTION":"Perda de tração","LOCK_UP":"Travamento","OVERSTEER":"Sobresterço","RUNNING_WIDE":"Escapada","SPIN":"Rodada"}
static func sample(seed: int, actor: int, tick: int, domain: int, channel: int) -> float:
	var key := PackedByteArray(); key.resize(40)
	key.encode_s64(0,seed); key.encode_s64(8,actor); key.encode_s64(16,tick); key.encode_s64(24,domain); key.encode_s64(32,channel)
	var h := HashingContext.new(); h.start(HashingContext.HASH_SHA256); h.update(key)
	return float(h.finish().decode_u32(0))/4294967296.0
static func initial(seed: int,id: int,skill: int) -> Dictionary:
	return {"skill":skill,"reaction_ticks":1+int(sample(seed,id,0,2,1)*3.0),"error_kind":"","error_left":0,"error_total":0,"error_ref_speed":0,"error_count":0,"recovery_ticks":0,"cooldown":0,"last_cross_tick":0,"last_lap_ticks":0,"best_lap_ticks":0,"lap_times":[],"traffic_ticks":0,"blue_ticks":0,"last_radio_tick":-1000}
static func risk(car: Dictionary, water: int, radius: int, front_gap: int) -> float:
	if radius > 350000: return 0.0
	var d: Dictionary = car.dynamics; var p: Dictionary = car.driver
	var wet: float = float(water)/6000.0
	var mismatch: float = wet if str(car.tire) not in ["Chuva","Intermediário"] else maxf(0.0,0.2-wet)
	var pressure: float = clampf(1.0-float(front_gap)/45000.0,0.0,1.0)
	var wear: float = float(d.wear_micro)/1000000.0
	var pace: float = 1.6 if car.pace=="Atacar" else (0.6 if car.pace=="Conservar" else 1.0)
	return clampf(0.00032*pace*(0.8+0.9*(1.0-float(car.evolution.skill)/100.0)+0.8*float(p.risk_tolerance)/1000.0+1.2*wear*wear+0.8*pressure+1.4*wet+3.0*mismatch),0.0,0.0045)
static func choose_kind(radius: int, water: int, u: float) -> String:
	var weights: Array[float] = [3.4,2.0,2.8 if radius<110000 else 0.8,0.9+float(water)/3000.0,0.8,0.03+float(water)/30000.0]
	var total: float = 0.0
	for w in weights: total += w
	var pick: float = u*total
	for i in range(weights.size()):
		pick -= weights[i]
		if pick < 0: return KINDS[i]
	return KINDS[-1]
static func speed_fraction(e: Dictionary) -> float:
	if int(e.error_left)<=0: return 1.0
	var peak: float = float([0.12,0.20,0.28,0.33,0.42,0.55][KINDS.find(str(e.error_kind))])
	return 1.0-peak*minf(1.0,float(e.error_left)/maxf(1.0,float(e.error_total)*0.75))
static func rejoin(car: Dictionary, roster: Array, base_ticks: int, pit_ticks: int, race_laps: int) -> Array:
	var own: int = int(car.evolution.last_lap_ticks)
	if own<=0: own=base_ticks
	var cases: Array = []
	for extend in range(3):
		if int(car.laps_done)+1+extend>=race_laps: break
		var horizon: int=own*extend+pit_ticks
		var exit: float=float(car.progress_units)/1000000.0+extend
		var rank: int=1; var nearby: int=0; var known: int=0; var count: int=0
		for other in roster:
			if other.id==car.id or other.finished: continue
			count+=1
			var pace: int=int(other.evolution.last_lap_ticks)
			if pace>0: known+=1
			else: pace=base_ticks
			var delta: float=float(other.progress_units)/1000000.0+float(horizon)/maxi(1,pace)-exit
			if delta>=0: rank+=1
			if fposmod(delta,1.0)*base_ticks*0.2<3.0 or fposmod(-delta,1.0)*base_ticks*0.2<1.0: nearby+=1
		cases.append({"lap":int(car.laps_done)+1+extend,"position":rank,"nearby":nearby,"confidence":"MODERADA" if known>=maxi(1,count)*0.75 else "BAIXA"})
	return cases
static func diagnosis(car: Dictionary, water: int) -> String:
	var e: Dictionary=car.evolution
	if int(e.error_left)>0: return str(LABELS.get(e.error_kind,"Erro"))+"; recupere o ritmo."
	if int(car.pit_requested_lap)>0: return "Plano de box V%d permanece ativo." % int(car.pit_requested_lap)
	if int(e.blue_ticks)>5: return "Retardatário em proximidade física; cuidado na passagem."
	if int(e.traffic_ticks)>20: return "Tráfego sustentado; avalie espaço e temperatura."
	if int(car.dynamics.wear_micro)>450000: return "Desgaste elevado; avalie a janela de box."
	if water>1900 and car.tire not in ["Chuva","Intermediário"]: return "Pneus de seco em pista molhada; atenção à aderência."
	return "Ritmo estável; nenhuma alteração automática por esta consulta."
