extends Control
## Playable isolated experimental GP. Official championship remains independent.
const Career = preload("res://experimental/hyper2/career.gd")
const StaffMarket = preload("res://scripts/core/staff_market_0648.gd")
const Kernel = preload("res://experimental/hyper2/kernel.gd")
const Scenario = preload("res://experimental/hyper/scenario.gd")
const TrackMap = preload("res://experimental/hyper/track_map.gd")
const SAVE: String = "user://hyper_engine_21_checkpoint.bin"
const SAVE22: String = "user://hyper_engine_22_checkpoint.bin"
const SAVE23: String = "user://hyper_engine_23_checkpoint.bin"
var physics_choice: CheckBox
var dynamics_choice: CheckBox
var mega_choice: CheckBox
const SAVE30: String = "user://hyper_engine_30_checkpoint.bin"
const CAREER_SAVE30: String = "user://hyper_career_30_race_checkpoint.bin"
const Quality = preload("res://experimental/hyper2/quality.gd")
const View3D = preload("res://experimental/hyper2/view_3d.gd")
var quality = Quality.new()
var view_3d: Control
var view_window: Window
var engineer_text: Label
var k = Kernel.new()
var career = Career.new()
var career_window: Window
var career_body: VBoxContainer
var career_notice: String = ""
var checkpoint_path: String = SAVE
var telemetry: Label
var data: Dictionary = {}
var circuit: OptionButton
var weather: OptionButton
var team: OptionButton
var seed_field: SpinBox
var setup_choice: OptionButton
var setup_second: OptionButton
const Replay=preload("res://experimental/hyper2/replay.gd")
var timeline=Replay.new()
var voice_enabled:bool=false
var voice_id:String=""
var last_spoken_tick:int=-1000
var auto_pit: CheckBox
var driver: OptionButton
var compound: OptionButton
var pit_lap: SpinBox
var status: Label
var metrics: Label
var ranking: RichTextLabel
var radio: RichTextLabel
var map_view: Control
var action_bar: HFlowContainer
var pause_button: Button
var start_button: Button
var speed: float = 16.0
var running: bool = false
var accumulator: float = 0.0
var refresh: float = 0.0
var actual_speed: float = 0.0
var measured_clock: int = 0
var selected_id: int = -1
var event_cursor: int = 0
var radio_lines: Array[String] = []
var team_colors: Dictionary = {}
func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/season_2012.json"))
	var theme_local := Theme.new()
	theme_local.default_font_size = 16
	theme = theme_local
	var bg := ColorRect.new(); bg.color = Color("090d12"); bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(bg)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,20)
	add_child(margin)
	var outer := VBoxContainer.new(); outer.add_theme_constant_override("separation",10); margin.add_child(outer)
	var header := HBoxContainer.new(); outer.add_child(header)
	var heading := _label(header,"APEX  /  NEXT ENGINE 3.0",30); heading.modulate = Color("ff8126"); heading.size_flags_horizontal = SIZE_EXPAND_FILL
	_label(header,"HYPER-MEGA  •  3.0 EXPERIMENTAL",18)
	_label(outer,"LABORATÓRIO JOGÁVEL  |  GP independente • física longitudinal experimental • sem alterar a carreira oficial",16)
	var config := HFlowContainer.new(); outer.add_child(config)
	circuit = _option(config,"Circuito")
	for entry in data.tracks: circuit.add_item(str(entry.code)+" • "+str(entry.name)); circuit.set_item_metadata(circuit.item_count-1,str(entry.code))
	for i in range(circuit.item_count):
		if str(circuit.get_item_metadata(i)) == "ITA": circuit.select(i)
	weather = _option(config,"Clima")
	for w in ["Seco","Chuva intensa","Seco → chuva → seco"]: weather.add_item(w)
	team = _option(config,"Equipe")
	for t in data.teams:
		team.add_item(str(t.name)); team_colors[str(t.name)] = str(t.color)
		if str(t.name) == "Ferrari": team.select(team.item_count-1)
	setup_choice = _option(config,"Acerto P1")
	for text in ["Seco","Misto","Molhado"]: setup_choice.add_item(text)
	setup_second=_option(config,"Acerto P2")
	for text in ["Seco","Misto","Molhado"]:setup_second.add_item(text)
	_label(config,"Seed"); seed_field = SpinBox.new(); seed_field.max_value = 2147483647; seed_field.value = 2026; seed_field.custom_minimum_size.x = 110; config.add_child(seed_field)
	physics_choice=CheckBox.new(); physics_choice.text="Física 2.2 (GP livre)"; config.add_child(physics_choice)
	dynamics_choice=CheckBox.new(); dynamics_choice.text="Física 2.3 (GP livre)"; config.add_child(dynamics_choice)
	mega_choice=CheckBox.new();mega_choice.text="HYPER-MEGA 3.0";config.add_child(mega_choice)
	physics_choice.toggled.connect(func(on:bool):
		if on:dynamics_choice.set_pressed_no_signal(false);mega_choice.set_pressed_no_signal(false))
	dynamics_choice.toggled.connect(func(on:bool):
		if on:physics_choice.set_pressed_no_signal(false);mega_choice.set_pressed_no_signal(false))
	mega_choice.toggled.connect(func(on:bool):
		if on:physics_choice.set_pressed_no_signal(false);dynamics_choice.set_pressed_no_signal(false))
	start_button = _button(config,"INICIAR",_start)
	var controls := HFlowContainer.new(); outer.add_child(controls)
	pause_button = _button(controls,"PAUSAR",_pause)
	for mult in [1,5,16,32,64]: _button(controls,str(mult)+"×",_speed.bind(float(mult)))
	_button(controls,"TEMPORADA / P&D / STAFF",_open_career)
	_button(controls,"LIVING FACTORY 3.0",_open_mega_career)
	_button(controls,"SALVAR CHECKPOINT",_save)
	_button(controls,"CARREGAR",_load)
	_button(controls,"VOLTAR AO MENU",_close)
	_button(controls,"3D / TV",_open_3d)
	_button(controls,"ENGENHEIRO",_engineer_report)
	_button(controls,"QUALIDADE",_quality_report)
	_button(controls,"REPLAY",_replay_window)
	var voice:=CheckBox.new();voice.text="Voz PT (sistema)";controls.add_child(voice)
	voice.toggled.connect(func(enabled:bool):
		voice_enabled=enabled and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)
		if voice_enabled:
			var voices:PackedStringArray=DisplayServer.tts_get_voices_for_language("pt")
			voice_id=voices[0] if not voices.is_empty() else ""
			if voice_id.is_empty():status.text="Sem voz PT disponível; rádio permanece em texto."
	)
	status = _label(outer,"Selecione o circuito e inicie uma corrida experimental.")
	metrics = _label(outer,"—",20); metrics.modulate = Color("ffb26d")
	var body := HBoxContainer.new(); body.size_flags_vertical = SIZE_EXPAND_FILL; body.add_theme_constant_override("separation",14); outer.add_child(body)
	var left := VBoxContainer.new(); left.size_flags_horizontal = SIZE_EXPAND_FILL; left.size_flags_stretch_ratio = 1.4; body.add_child(left)
	_label(left,"CLASSIFICAÇÃO • fonte: kernel esportivo",20)
	_label(left,"* Intervalo estimado pela distância e velocidade atual (não cronometragem oficial).",13)
	ranking = RichTextLabel.new(); ranking.bbcode_enabled = false; ranking.add_theme_font_size_override("normal_font_size",16); ranking.size_flags_vertical = SIZE_EXPAND_FILL; ranking.scroll_active = true; left.add_child(ranking)
	var right := VBoxContainer.new(); right.size_flags_horizontal = SIZE_EXPAND_FILL; body.add_child(right)
	_label(right,"MAPA DE PISTA • projeção 2D",20)
	map_view = TrackMap.new(); map_view.size_flags_vertical = SIZE_EXPAND_FILL; map_view.custom_minimum_size.y = 220; right.add_child(map_view)
	_label(right,"RÁDIO / EVENTOS CONFIRMADOS",20)
	radio = RichTextLabel.new(); radio.size_flags_vertical = SIZE_EXPAND_FILL; radio.custom_minimum_size.y = 130; radio.scroll_following = true; right.add_child(radio)
	telemetry = _label(outer,"TELEMETRIA • selecione um piloto",15)
	telemetry.modulate = Color("ffb26d")
	action_bar = HFlowContainer.new(); outer.add_child(action_bar)
	driver = _option(action_bar,"Piloto"); driver.item_selected.connect(_select_driver)
	auto_pit = CheckBox.new(); auto_pit.text = "IA boxes (próximo GP)"; auto_pit.button_pressed = true; action_bar.add_child(auto_pit)
	for pace in ["Conservar","Normal","Atacar"]: _button(action_bar,pace,_pace.bind(pace))
	_button(action_bar,"AUTO RITMO",func():_command({"type":"set_auto"}))
	compound = _option(action_bar,"Pneu")
	_label(action_bar,"Volta"); pit_lap = SpinBox.new(); pit_lap.min_value = 1; pit_lap.max_value = 80; action_bar.add_child(pit_lap)
	_button(action_bar,"AGENDAR BOX",_pit)
	_button(action_bar,"CANCELAR BOX",_cancel)
	pause_button.disabled = true
func _label(parent: Node, value: String, font_size: int = 16) -> Label:
	var l := Label.new(); l.text = value; l.add_theme_font_size_override("font_size",font_size); parent.add_child(l); return l
func _button(parent: Node, value: String, action: Callable) -> Button:
	var b := Button.new(); b.text = value; b.custom_minimum_size.y = 38; b.pressed.connect(action); parent.add_child(b); return b
func _option(parent: Node, title: String) -> OptionButton:
	_label(parent,title); var o := OptionButton.new(); o.custom_minimum_size.y = 38; parent.add_child(o); return o
func _start() -> void:
	if k.initialized and running: status.text = "Pause antes de reiniciar o GP."; return
	var code: String = str(circuit.get_item_metadata(circuit.selected))
	var w: String = "Chuva intensa" if weather.selected == 1 else "Seco"
	var s: Dictionary = Scenario.create(code,w,int(seed_field.value),team.get_item_text(team.selected),auto_pit.button_pressed,setup_choice.selected*500)
	s.hyper22_physics=physics_choice.button_pressed
	s.hyper23_physics=dynamics_choice.button_pressed
	s.hyper30_physics=mega_choice.button_pressed
	if checkpoint_path in [SAVE,SAVE22,SAVE23,SAVE30,CAREER_SAVE30]: checkpoint_path=SAVE30 if mega_choice.button_pressed else (SAVE23 if dynamics_choice.button_pressed else (SAVE22 if physics_choice.button_pressed else SAVE))
	var selected_count:int=0
	for car in s.get("cars",[]):
		if str(car.team)==team.get_item_text(team.selected):
			if selected_count==1:s.hyper_specs[str(car.id)].wet_setup=setup_second.selected*500
			selected_count+=1
	if weather.selected == 2: s.hyper_weather = [{"tick":2500,"water":2500},{"tick":5000,"water":5000},{"tick":10000,"water":300}]
	var candidate = Kernel.new()
	if not candidate.initialize(s): status.text = "Falha ao iniciar cenário."; return
	k = candidate; _bind_session(); running = true; pause_button.text = "PAUSAR"; status.text = "GP em andamento • comandos são enfileirados para o próximo tick."
func _bind_session() -> void:
	timeline.attach(k); quality.reset(); last_spoken_tick=-1000; accumulator = 0.0; actual_speed = 0.0; measured_clock = int(k.state.clock_ms); event_cursor = 0; radio_lines.clear(); driver.clear(); compound.clear(); selected_id = -1
	for car in k.state.cars:
		if str(car.team) == str(k.state.hyper_player_team): driver.add_item(str(car.name),int(car.id))
	if driver.item_count > 0: driver.select(0); selected_id = driver.get_item_id(0)
	for c in k.state.compounds: compound.add_item(str(c))
	for track in data.tracks:
		if str(track.code) == str(k.state.track_code): map_view.configure(track.points,team_colors); break
	if is_instance_valid(view_3d): _configure_3d()
	pit_lap.max_value = int(k.state.race_laps)-1; pit_lap.value = 1
	auto_pit.set_pressed_no_signal(bool(k.state.hyper_player_pit_auto)); pause_button.disabled = false; _redraw()
func _process(delta: float) -> void:
	if not k.initialized: return
	if running and not bool(k.state.finished):
		accumulator = minf(accumulator + delta*speed,8.0)
		var start: int = Time.get_ticks_usec(); var n: int = 0
		while accumulator >= 0.2 and n < 32:
			if not k.step_tick(): running = false; break
			accumulator -= 0.2; n += 1
			quality.observe(k.state); timeline.observed(k)
			if Time.get_ticks_usec()-start > 12000: break
		if bool(k.state.finished): running = false; status.text = "GP concluído. Registre o resultado na Central Temporada." if k.state.has("hyper_career_token") else "GP concluído. Classificação do kernel disponível."; pause_button.text = "CONCLUÍDO"
	refresh += delta
	if refresh >= 0.25:
		actual_speed = float(int(k.state.clock_ms)-measured_clock)/1000.0/refresh
		measured_clock = int(k.state.clock_ms); refresh = 0.0; _redraw()
func _redraw() -> void:
	var rows: Array = k.classification()
	var leader: int = int(rows[0].laps) if not rows.is_empty() else 0
	metrics.text = "%s  |  VOLTA %d/%d  |  %d s  |  ÁGUA %.1f mm  |  %d PASSES  |  %d× alvo / %.1f× real" % [k.state.track_code,mini(leader+1,int(k.state.race_laps)),k.state.race_laps,int(k.state.clock_ms/1000),float(k.state.water_microns)/1000.0,k.state.racecraft_passes,int(speed),actual_speed]
	var lines: Array[String] = []
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var prefix: String = "▶ " if int(row.id) == selected_id else "    "
		var state_name: String = "DNF" if bool(row.retired) else ("FIM" if bool(row.finished) else _pit_label(str(row.pit)))
		var interval: String = "LÍDER" if i == 0 else ("+%d V" % [int(rows[0].laps)-int(row.laps)] if int(rows[0].laps)-int(row.laps)>1 else "%.1fs*" % (float(int(rows[0].progress)-int(row.progress))*float(k.state.lap_length_mm)/1000000.0/maxf(1000.0,float(row.speed))))
		if bool(row.finished): interval = "FIM" if not bool(row.retired) else "DNF"
		lines.append("%02d %s%s  |  V%d  |  %s  %d%%  |  %s  %d box  |  %s%s" % [i+1,prefix,row.name,row.laps,row.tire,100-int(row.wear/10000),state_name,row.stops,interval," • DRS" if bool(row.drs) else ""])
	ranking.text = "\n".join(lines); map_view.update_rows(rows,selected_id)
	if is_instance_valid(view_3d): view_3d.feed(k.state.cars,selected_id,0.25)
	var selected: Dictionary = k._lookup_car(selected_id)
	if not selected.is_empty():
		telemetry.text = "%s • %.0f km/h • %.1f kg combustível • %.1f °C pneus • %.0f kJ KERS • %s • BOX %s" % [selected.name,float(selected.dynamics.speed_mm_s)*0.0036,float(selected.dynamics.fuel_g)/1000.0,float(selected.dynamics.tire_temp_centi)/100.0,float(selected.hyper.kers_j)/1000.0,"DRS ABERTO" if selected.hyper.drs_active else "DRS FECHADO",str(selected.pit_requested_lap) if int(selected.pit_requested_lap)>0 else "—"]
		if selected.dynamics.has("powertrain_22"):
			var pt: Dictionary=selected.dynamics.powertrain_22
			telemetry.text += " • M%d / %d rpm / %.0f kW V8 / %.1f kg" % [pt.gear,pt.rpm,float(pt.v8_wheel_w)/1000.0,float(pt.mass_g)/1000.0] if selected.pit_stage=="TRACK" else " • box / motor não medido"
		if selected.dynamics.has("dynamics_23") and selected.pit_stage=="TRACK":
			var grip:Dictionary=selected.dynamics.dynamics_23
			telemetry.text += " • %s / reserva %d%% / carga F %d N" % [grip.phase,int(grip.reserve_permille)/10,int(grip.front_n)]
		if selected.has("mega_30"):
			var m:Dictionary=selected.mega_30
			telemetry.text += " • condição %d%% / dano %d%% / %s" % [int(m.health)/10,int(m.damage)/10,"SC VIRTUAL" if int(k.state.mega_control.remaining)>0 else "VERDE"]
		telemetry.text += " • última %.1fs / melhor %.1fs • %d erros" % [float(selected.evolution.last_lap_ticks)*0.2,float(selected.evolution.best_lap_ticks)*0.2,int(selected.evolution.error_count)]
	var events: Array = k.state.events
	while event_cursor < events.size():
		var ev: Dictionary = events[event_cursor]; event_cursor += 1
		if not str(ev.type) in ["hyper_pit_serviced","hyper_pit_exit","hyper_weather_change","hyper_strategy_order","hyper_retired","racecraft_overtake_confirmed","driver_intent_changed","command_rejected","race_finished","hyper_driver_error","hyper_error_recovered","hyper_error_interrupted","mega_damage","mega_repair","mega_virtual_sc","mega_green","mega_mechanical_retirement","mega_radio"]: continue
		if str(ev.type) in ["driver_intent_changed","mega_radio"] and int(ev.car_id) != selected_id: continue
		var c: Dictionary = k._lookup_car(int(ev.car_id)); var name_text: String = str(c.get("name","DIREÇÃO"))
		var msg:String=_radio_text(ev)
		radio_lines.append("%ds • %s • %s" % [int(ev.tick)*200/1000,name_text,msg])
		if voice_enabled and not voice_id.is_empty() and int(ev.car_id)==selected_id and speed<=5.0 and int(ev.tick)-last_spoken_tick>=50 and not DisplayServer.tts_is_speaking() and str(ev.type) in ["hyper_driver_error","hyper_pit_serviced","hyper_strategy_order","driver_intent_changed","mega_radio"]:
			DisplayServer.tts_speak(msg,voice_id,75,1.0,1.0);last_spoken_tick=int(ev.tick)
		if radio_lines.size() > 30: radio_lines.pop_front()
	radio.text = "\n".join(radio_lines)
func _pause() -> void:
	if not k.initialized or bool(k.state.finished): return
	running = not running; pause_button.text = "PAUSAR" if running else "RETOMAR"
func _speed(value: float) -> void:
	if value<speed: accumulator=fposmod(accumulator,0.2)
	speed=value
func _select_driver(index: int) -> void: selected_id = driver.get_item_id(index)
func _command(order: Dictionary) -> void:
	if not k.initialized or selected_id < 0: return
	order.car_id = selected_id; order.source = "Manual"
	var outcome: Dictionary = k.submit(order)
	if bool(outcome.accepted):timeline.record(order,int(k.state.tick))
	status.text = "Comando recebido: " + str(outcome.reason)
func _pace(value: String) -> void: _command({"type":"set_pace","pace":value})
func _pit() -> void:
	if compound.selected < 0: return
	_command({"type":"schedule_pit","requested_lap":int(pit_lap.value),"compound":compound.get_item_text(compound.selected),"allow_double_stack":true})
func _cancel() -> void: _command({"type":"cancel_pit"})
func _save() -> void:
	if not k.initialized: return
	if checkpoint_path in [SAVE,SAVE22,SAVE23,SAVE30,CAREER_SAVE30]: checkpoint_path=SAVE30 if int(k.state.hyper_evolution_revision)==Kernel.MEGA_REV else (SAVE23 if int(k.state.hyper_evolution_revision)==Kernel.DYNAMICS_REV else (SAVE22 if int(k.state.hyper_evolution_revision)==Kernel.PHYSICS_REV else SAVE))
	if checkpoint_path==SAVE30 and k.state.has("hyper_career_token"):checkpoint_path=CAREER_SAVE30
	if checkpoint_path==SAVE30:
		var prior=_read_checkpoint(SAVE30)
		if prior!=null and prior.state.has("hyper_career_token"):
			var moved=_read_checkpoint(CAREER_SAVE30)
			if moved==null or str(moved.state.get("hyper_career_token",""))!=str(prior.state.hyper_career_token) or int(moved.state.tick)<int(prior.state.tick):
				status.text="Checkpoint antigo de carreira protegido. Abra Living Factory e salve a etapa separadamente.";return
	var f := FileAccess.open(checkpoint_path+".tmp",FileAccess.WRITE)
	if f == null: status.text = "Falha ao abrir arquivo de checkpoint."; return
	f.store_var(k.checkpoint(),false); f.flush(); var write_error: Error = f.get_error(); f.close()
	if write_error != OK: status.text = "Falha de escrita. Checkpoint anterior preservado."; return
	var a: String = ProjectSettings.globalize_path(checkpoint_path)
	if FileAccess.file_exists(checkpoint_path) and _read_checkpoint(checkpoint_path) != null:
		if DirAccess.copy_absolute(a,a+".bak") != OK: status.text = "Backup falhou. Checkpoint original preservado."; return
	var result: Error = DirAccess.rename_absolute(a+".tmp",a)
	status.text = "Checkpoint gravado (Hyper separado)." if result == OK else "Falha ao substituir checkpoint."
func _read_checkpoint(path: String):
	var f := FileAccess.open(path,FileAccess.READ)
	if f == null: return null
	if f.get_length() < 8 or f.get_length() > 200000000: f.close(); return null
	var stored_size: int = int(f.get_32())
	if stored_size != f.get_length()-4: f.close(); return null
	f.seek(0)
	var saved: Variant = f.get_var(false); f.close()
	var candidate = Kernel.new()
	if not saved is Dictionary or not candidate.restore(saved): return null
	var expected_rev:int=5 if path in [SAVE30,SAVE30+".bak",CAREER_SAVE30,CAREER_SAVE30+".bak"] else (4 if path in [SAVE23,SAVE23+".bak"] else (3 if path in [SAVE22,SAVE22+".bak"] else (2 if path in [SAVE,SAVE+".bak"] else 0)))
	if expected_rev!=0 and int(candidate.state.hyper_evolution_revision)!=expected_rev: return null
	if path in [CAREER_SAVE30,CAREER_SAVE30+".bak"] and not candidate.state.has("hyper_career_token"):return null
	return candidate
func _load() -> void:
	if checkpoint_path in [SAVE,SAVE22,SAVE23,SAVE30,CAREER_SAVE30]: checkpoint_path=SAVE30 if mega_choice.button_pressed else (SAVE23 if dynamics_choice.button_pressed else (SAVE22 if physics_choice.button_pressed else SAVE))
	var candidate = _read_checkpoint(checkpoint_path)
	var from_backup: bool = false
	if candidate == null:
		candidate = _read_checkpoint(checkpoint_path+".bak"); from_backup = candidate != null
	if candidate == null: status.text = "Checkpoint ausente, inválido ou incompatível."; return
	if checkpoint_path==SAVE30 and candidate.state.has("hyper_career_token"):status.text="Este é um checkpoint de carreira. Abra Living Factory 3.0.";return
	k = candidate; physics_choice.set_pressed_no_signal(int(k.state.hyper_evolution_revision)==Kernel.PHYSICS_REV); dynamics_choice.set_pressed_no_signal(int(k.state.hyper_evolution_revision)==Kernel.DYNAMICS_REV); mega_choice.set_pressed_no_signal(int(k.state.hyper_evolution_revision)==Kernel.MEGA_REV); running = false; _bind_session(); pause_button.text = "RETOMAR"; status.text = "Checkpoint restaurado do backup." if from_backup else "Checkpoint restaurado."
func _close() -> void:
	if get_parent() is Window and get_parent() != get_tree().root: get_parent().queue_free()
	else: get_tree().change_scene_to_file("res://scenes/main.tscn")

func _pit_label(value: String) -> String:
	return str({"TRACK":"PISTA","ENTRY_OBSERVED":"ENTRADA","PIT_IN":"ENTRADA","PIT_WAIT":"FILA","PIT_SERVICE":"SERVIÇO","PIT_OUT":"SAÍDA"}.get(value,value))
func _radio_text(ev: Dictionary) -> String:
	if str(ev.type)=="mega_radio":return str({"DAMAGE":"Piloto: sinto dano aerodinâmico.","RELIABILITY":"Engenheiro: condição mecânica crítica.","FUEL":"Engenheiro: atenção ao combustível.","TYRES":"Piloto: pneus perderam rendimento.","TRAFFIC":"Piloto: preso no tráfego."}.get(str(ev.get("kind","")),"Atenção."))
	if str(ev.type) in ["mega_damage","mega_repair","mega_virtual_sc","mega_green","mega_mechanical_retirement"]:return str({"mega_damage":"Dano identificado.","mega_repair":"Reparo parcial no box.","mega_virtual_sc":"Neutralização virtual; sem novo ataque.","mega_green":"Bandeira verde.","mega_mechanical_retirement":"Abandono mecânico."}[str(ev.type)])
	var messages: Dictionary = {"hyper_pit_serviced":"Pneus trocados: "+str(ev.get("compound","")),"hyper_pit_exit":"Retorno à pista.","hyper_weather_change":"Mudança de água na pista: "+str(ev.get("water_microns",0))+" μm.","hyper_strategy_order":"Estratégia solicita box: "+str(ev.get("compound","")),"hyper_retired":"Abandono: falta de combustível.","racecraft_overtake_confirmed":"Ultrapassagem confirmada.","command_rejected":"Ordem rejeitada: "+str(ev.get("reason","")),"race_finished":"Bandeirada final."}
	if str(ev.type) in ["hyper_driver_error","hyper_error_recovered","hyper_error_interrupted"]:
		return str({"hyper_driver_error":"Piloto com erro: ","hyper_error_recovered":"Recuperação concluída: ","hyper_error_interrupted":"Recuperação interrompida: "}[str(ev.type)])+str(Kernel.Intelligence.LABELS.get(str(ev.get("kind","")),"Erro"))
	if str(ev.type) == "driver_intent_changed":
		return str({"stable_running":"Piloto: ritmo estável.","slower_car_ahead":"Piloto: tenho ritmo para atacar o carro da frente.","faster_car_behind":"Piloto: carro mais rápido atrás; vou defender.","tire_worn":"Piloto: estou sentindo o desgaste dos pneus.","tire_overheated":"Piloto: pneus quentes, vou conservar.","fuel_low":"Engenheiro: combustível baixo, conserve.","driver_fatigue":"Piloto: preciso reduzir o esforço."}.get(str(ev.get("reason","")),"Piloto: intenção atualizada."))
	return str(messages.get(str(ev.type),str(ev.type)))
func _open_mega_career()->void:
	if is_instance_valid(career_window):return
	career=Career.new("user://hyper_career_30.bin",true);_career_window()
func _open_career() -> void:
	if is_instance_valid(career_window): return
	career=Career.new();_career_window()
func _career_window()->void:
	career_window = Window.new(); career_window.title = "APEX Hyper • Central de Temporada"; career_window.size = Vector2i(1000,750); career_window.min_size = Vector2i(850,600)
	career_window.transient = true
	add_child(career_window)
	var scroll := ScrollContainer.new(); scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; career_window.add_child(scroll)
	career_body = VBoxContainer.new(); career_body.size_flags_horizontal = SIZE_EXPAND_FILL; career_body.add_theme_constant_override("separation",10); scroll.add_child(career_body)
	career_window.close_requested.connect(func(): career_window.queue_free())
	_career_refresh(); career_window.popup_centered()
func _career_refresh() -> void:
	if not is_instance_valid(career_body): return
	for child in career_body.get_children(): career_body.remove_child(child); child.queue_free()
	var title_label := _label(career_body,"CENTRAL DE TEMPORADA 2012 / HYPER",27); title_label.modulate = Color("ff8126")
	_label(career_body,career_notice if not career_notice.is_empty() else "Carreira independente • dados fictícios de gestão • 20 etapas.")
	if career.recovered_backup: _label(career_body,"Atenção: carreira recuperada do backup anterior.")
	if not career.active():
		if not career.state.is_empty(): _label(career_body,"Temporada anterior concluída. Campeão: "+str(career.standings(false)[0].name))
		_button(career_body,"NOVA TEMPORADA • "+team.get_item_text(team.selected),_career_new)
		return
	var s: Dictionary = career.state
	_label(career_body,"%s   |   ETAPA %d/20 • %s   |   ORÇAMENTO R$ %.2f mi   |   %d dias disponíveis" % [s.team,int(s.round)+1,s.calendar[int(s.round)],float(s.budget)/1000000.0,s.days_left],19)
	var actions := HFlowContainer.new(); career_body.add_child(actions)
	_button(actions,"ABRIR ETAPA",_career_gp)
	_button(actions,"REGISTRAR RESULTADO",_career_record)
	_button(actions,"AVANÇAR 1 DIA",func(): _career_action("Dia avançado." if career.advance_days(1) else "Sem dias disponíveis ou GP ativo."))
	_button(actions,"AVANÇAR ATÉ O GP",func(): _career_action("Calendário avançado." if career.advance_days(int(career.state.days_left)) else "Sem dias disponíveis ou GP ativo."))
	if career.locked(): _label(career_body,"GP reservado: engenharia e contratos bloqueados até registro da bandeirada.")
	if career.mega_mode:
		var factory:Dictionary=career.factory_report()
		_label(career_body,"LIVING FACTORY 3.0 • %d instaladas / %d reservas / %d manutenção / %d ordens / %d projetos" % [factory.installed,factory.spares,factory.maintenance,factory.work_pending,factory.projects_active],16)
	_label(career_body,"ENGENHARIA • projetos, protótipos, testes, fabricação e instalação",20)
	var p_row := HFlowContainer.new(); career_body.add_child(p_row)
	var family := _option(p_row,"Família")
	for item in Career.FAMILIES: family.add_item(item)
	var focus := _option(p_row,"Foco")
	for item in ["equilibrado","desempenho","durabilidade"]: focus.add_item(item)
	_button(p_row,"INICIAR P&D",func(): _career_action(career.start_project(family.get_item_text(family.selected),focus.get_item_text(focus.selected))))
	for id in s.projects:
		var project: Dictionary = s.projects[id]
		var line := HFlowContainer.new(); career_body.add_child(line)
		_label(line,"%s • %s r%d • %s • %s (%d dia[s])" % [id,project.family,project.level,project.focus,Career.STAGES[int(project.stage)],project.remaining])
		if int(project.stage)==4: _button(line,"INSTALAR KIT",func(): _career_action("Kit instalado." if career.install(str(id)) else "Instalação rejeitada."))
	var parts: Array[String] = []
	for slot in s.slots:
		var part: Dictionary = s.parts[s.slots[slot]]
		parts.append("%s • %s • r%d • %d km • condição %d%%" % [slot,s.slots[slot],part.level,part.km,part.condition])
	_label(career_body,"PEÇAS INSTALADAS
"+"
".join(parts),14)
	_label(career_body,"OFICINA • reservas de destino e peça / capacidade: 1 ordem por dia",20)
	var work_row:=HFlowContainer.new(); career_body.add_child(work_row)
	var slot_pick:=_option(work_row,"Slot")
	for slot in s.slots: slot_pick.add_item(str(slot))
	var spare_pick:=_option(work_row,"Reserva")
	var populate:=func():
		spare_pick.clear()
		for id in career.available_spares(slot_pick.get_item_text(slot_pick.selected)): spare_pick.add_item(str(id))
	slot_pick.item_selected.connect(func(_index:int):populate.call()); populate.call()
	_button(work_row,"MANUTENÇÃO",func():_career_action("Ordem criada." if career.start_work(slot_pick.get_item_text(slot_pick.selected),"MAINTENANCE") else "Ordem rejeitada: condição, reserva ou saldo."))
	_button(work_row,"SUBSTITUIR",func():_career_action("Ordem criada." if spare_pick.selected>=0 and career.start_work(slot_pick.get_item_text(slot_pick.selected),"REPLACE",spare_pick.get_item_text(spare_pick.selected)) else "Ordem rejeitada: reserva indisponível ou slot ocupado."))
	for id in s.work_orders:
		var work:Dictionary=s.work_orders[id]; var line:=HFlowContainer.new(); career_body.add_child(line)
		_label(line,"%s • %s • %s • %s • %d dias" % [id,work.kind,work.slot,work.status,work.remaining],14)
		if work.status=="PENDING": _button(line,"CANCELAR",func():_career_action("Ordem cancelada." if career.cancel_work(str(id)) else "Cancelamento rejeitado."))
	_label(career_body,"STAFF • contrato de 8 GPs, salários e especialidades",20)
	var hire_row := HFlowContainer.new(); career_body.add_child(hire_row)
	var candidates := _option(hire_row,"Candidato")
	for role in StaffMarket.ROLES:
		for person in StaffMarket.MARKET[role]:
			candidates.add_item("%s • %s • %d • R$ %.2f mi" % [role,person.name,person.skill,float(person.signing)/1000000.0]); candidates.set_item_metadata(candidates.item_count-1,[role,person.id])
	_button(hire_row,"CONTRATAR",func(): var pair: Array = candidates.get_item_metadata(candidates.selected); _career_action(career.hire(str(pair[0]),str(pair[1]))))
	for role in s.staff_roster:
		var person: Dictionary = s.staff_roster[role]
		var line := HFlowContainer.new(); career_body.add_child(line)
		_label(line,"%s • %s • %d GPs • R$ %d/GP" % [role,person.name,person.remaining_gps,person.salary]); _button(line,"RESCINDIR",func(): _career_action(career.release(str(role))))
	_label(career_body,"CAMPEONATO • pilotos / construtores",20)
	var columns := HBoxContainer.new(); career_body.add_child(columns)
	var driver_rows: Array[String] = []; var team_rows: Array[String] = []
	for row in career.standings(false): driver_rows.append("%s  •  %d" % [row.name,row.points])
	for row in career.standings(true): team_rows.append("%s  •  %d" % [row.name,row.points])
	var a := _label(columns,"
".join(driver_rows),14); a.size_flags_horizontal = SIZE_EXPAND_FILL
	_label(columns,"
".join(team_rows),14)
func _career_action(message: String) -> void:
	career_notice = message; _career_refresh()
func _career_new() -> void:
	_career_action("Temporada criada." if career.create(team.get_item_text(team.selected),int(seed_field.value),data) else "Não foi possível criar temporada.")
func _career_gp() -> void:
	if running: _career_action("Pause o GP atual primeiro."); return
	if k.initialized and k.state.has("hyper_career_token") and career.locked() and str(k.state.hyper_career_token)==str(career.state.active_scenario.hyper_career_token):
		career_window.queue_free(); return
	var w: String = weather.get_item_text(weather.selected)
	var s: Dictionary = career.prepare(w,auto_pit.button_pressed,setup_choice.selected*500,setup_second.selected*500)
	physics_choice.set_pressed_no_signal(false)
	dynamics_choice.set_pressed_no_signal(false)
	mega_choice.set_pressed_no_signal(career.mega_mode)
	if checkpoint_path in [SAVE,SAVE22,SAVE23,SAVE30,CAREER_SAVE30]: checkpoint_path=CAREER_SAVE30 if career.mega_mode else SAVE
	if career.mega_mode and not s.is_empty():
		var resumed=_reserved_mega_checkpoint(s)
		if resumed!=null:
			k=resumed;running=false;_bind_session();pause_button.text="RETOMAR";status.text="Etapa reservada restaurada.";career_window.queue_free();return
	var candidate = Kernel.new()
	if s.is_empty() or not candidate.initialize(s): _career_action("Falha ao preparar etapa."); return
	k = candidate; _bind_session(); running = true; pause_button.text = "PAUSAR"; status.text = "Etapa oficial da carreira Hyper em andamento."; career_window.queue_free()
func _reserved_mega_checkpoint(s:Dictionary):
	# Prefer the newest matching reserved-race checkpoint; legacy candidate
	# files can be read but never mistaken for a different reservation.
	var best=null
	for path in [CAREER_SAVE30,CAREER_SAVE30+".bak",SAVE30,SAVE30+".bak"]:
		var candidate=_read_checkpoint(path)
		if candidate==null:continue
		var st:Dictionary=candidate.state
		if str(st.get("hyper_career_token",""))!=str(s.get("hyper_career_token","")) or not st.has("hyper_career_token"):continue
		if int(st.hyper_evolution_revision)!=Kernel.MEGA_REV or int(st.seed)!=int(s.seed) or str(st.track_code)!=str(s.track_code) or str(st.hyper_player_team)!=str(s.hyper_player_team):continue
		if int(st.race_laps)!=int(s.race_laps) or int(st.lap_length_mm)!=int(s.lap_length_mm):continue
		if best==null or int(st.tick)>int(best.state.tick):best=candidate
	return best
func _career_record() -> void:
	_career_action("Resultado registrado e folha/orçamento atualizados." if career.commit(k) else "Somente uma bandeirada válida da etapa reservada pode ser registrada.")

func _engineer_report()->void:
	if not k.initialized or selected_id<0: return
	var report: Dictionary=k.strategy_report(selected_id)
	var lines: Array[String]=[str(report.diagnosis),"Projeção aproximada; não altera ordens."]
	for item in report.cases: lines.append("V%d: P%d • %d carros próximos • %s" % [item.lap,item.position,item.nearby,item.confidence])
	if not report.get("ranked",[]).is_empty():
		var best:Dictionary=report.ranked[0]
		lines.append("VSE: V%d • score %d (estimativa; não envia ordem)" % [best.lap,best.score])
	_show_info("Race Engineer / Pit Wall", "\n".join(lines))
func _quality_report()->void:
	var r: Dictionary=quality.report()
	_show_info("Race Quality Center", "Ticks observados: %d\nOcorrências: %s\nA ausência de alertas não certifica a física." % [r.observed_ticks,JSON.stringify(r.findings)])
func _show_info(title_text:String,body_text:String)->void:
	var dialog:=AcceptDialog.new(); dialog.title=title_text; dialog.dialog_text=body_text; add_child(dialog); dialog.confirmed.connect(dialog.queue_free); dialog.close_requested.connect(dialog.queue_free); dialog.popup_centered(Vector2i(610,220))
func _open_3d()->void:
	if not k.initialized: status.text="Inicie um GP primeiro."; return
	if is_instance_valid(view_window): return
	view_window=Window.new(); view_window.title="APEX Hyper — TV 3D (boxes fora da projeção)"; view_window.size=Vector2i(1100,700); add_child(view_window)
	var outer:=VBoxContainer.new(); outer.set_anchors_and_offsets_preset(PRESET_FULL_RECT); view_window.add_child(outer)
	var tools:=HBoxContainer.new(); outer.add_child(tools)
	for style in ["aerial","chase","trackside","director"]: _button(tools,style.to_upper(),func(): view_3d.camera_style=style)
	view_3d=View3D.new(); view_3d.size_flags_vertical=SIZE_EXPAND_FILL; outer.add_child(view_3d)
	view_window.close_requested.connect(view_window.queue_free)
	view_window.popup_centered(); _configure_3d()
func _configure_3d()->void:
	for t in data.tracks:
		if str(t.code)==str(k.state.track_code): view_3d.configure(t.points,str(t.name),data.teams,team_colors); break
	view_3d.feed(k.state.cars,selected_id)

func _replay_window()->void:
	if not k.initialized or timeline.anchors.is_empty():return
	running=false;pause_button.text="RETOMAR"
	var dialog:=Window.new();dialog.title="Replay Hyper 2.1 — revisão em memória";dialog.size=Vector2i(950,700);add_child(dialog)
	var body:=VBoxContainer.new();body.set_anchors_and_offsets_preset(PRESET_FULL_RECT);dialog.add_child(body)
	_label(body,"Revisão independente: sem alterar o GP ou a carreira. Até 9 checkpoints comprimidos.",16)
	var row:=HBoxContainer.new();body.add_child(row)
	var tick:=SpinBox.new();tick.min_value=int(timeline.anchors[0].tick);tick.max_value=timeline.last_tick;tick.value=timeline.last_tick;row.add_child(tick)
	var report:=RichTextLabel.new();report.size_flags_vertical=SIZE_EXPAND_FILL;body.add_child(report)
	var seek:=func():
		var copy=timeline.seek(int(tick.value))
		if copy==null:report.text="Falha de restauração ou comando divergente.";return
		var lines:Array[String]=["Tick %d • %s" % [copy.state.tick,copy.sporting_hash()]]
		for item in copy.classification():lines.append("%s • V%d • %s • %d boxes" % [item.name,item.laps,item.tire,item.stops])
		report.text="\n".join(lines)
	_button(row,"RECONSTRUIR TICK",seek);dialog.close_requested.connect(dialog.queue_free);dialog.popup_centered();seek.call()
