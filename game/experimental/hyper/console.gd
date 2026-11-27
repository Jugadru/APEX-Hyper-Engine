extends Control
## Playable isolated experimental GP. Official championship remains independent.
const Career = preload("res://experimental/hyper/career.gd")
const StaffMarket = preload("res://scripts/core/staff_market_0648.gd")
const Kernel = preload("res://experimental/hyper/kernel.gd")
const Scenario = preload("res://experimental/hyper/scenario.gd")
const TrackMap = preload("res://experimental/hyper/track_map.gd")
const SAVE: String = "user://hyper_engine_20_checkpoint.bin"
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
	var heading := _label(header,"APEX  /  NEXT ENGINE 2.0",30); heading.modulate = Color("ff8126"); heading.size_flags_horizontal = SIZE_EXPAND_FILL
	_label(header,"HYPER EVOLUTION  •  ALPHA 1",18)
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
	setup_choice = _option(config,"Acerto")
	for text in ["Seco","Misto","Molhado"]: setup_choice.add_item(text)
	_label(config,"Seed"); seed_field = SpinBox.new(); seed_field.max_value = 2147483647; seed_field.value = 2026; seed_field.custom_minimum_size.x = 110; config.add_child(seed_field)
	start_button = _button(config,"INICIAR",_start)
	var controls := HFlowContainer.new(); outer.add_child(controls)
	pause_button = _button(controls,"PAUSAR",_pause)
	for mult in [1,5,16,32,64]: _button(controls,str(mult)+"×",_speed.bind(float(mult)))
	_button(controls,"TEMPORADA / P&D / STAFF",_open_career)
	_button(controls,"SALVAR CHECKPOINT",_save)
	_button(controls,"CARREGAR",_load)
	_button(controls,"VOLTAR AO MENU",_close)
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
	if weather.selected == 2: s.hyper_weather = [{"tick":2500,"water":2500},{"tick":5000,"water":5000},{"tick":10000,"water":300}]
	var candidate = Kernel.new()
	if not candidate.initialize(s): status.text = "Falha ao iniciar cenário."; return
	k = candidate; _bind_session(); running = true; pause_button.text = "PAUSAR"; status.text = "GP em andamento • comandos são enfileirados para o próximo tick."
func _bind_session() -> void:
	accumulator = 0.0; actual_speed = 0.0; measured_clock = int(k.state.clock_ms); event_cursor = 0; radio_lines.clear(); driver.clear(); compound.clear(); selected_id = -1
	for car in k.state.cars:
		if str(car.team) == str(k.state.hyper_player_team): driver.add_item(str(car.name),int(car.id))
	if driver.item_count > 0: driver.select(0); selected_id = driver.get_item_id(0)
	for c in k.state.compounds: compound.add_item(str(c))
	for track in data.tracks:
		if str(track.code) == str(k.state.track_code): map_view.configure(track.points,team_colors); break
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
	var selected: Dictionary = k._lookup_car(selected_id)
	if not selected.is_empty():
		telemetry.text = "%s • %.0f km/h • %.1f kg combustível • %.1f °C pneus • %.0f kJ KERS • %s • BOX %s" % [selected.name,float(selected.dynamics.speed_mm_s)*0.0036,float(selected.dynamics.fuel_g)/1000.0,float(selected.dynamics.tire_temp_centi)/100.0,float(selected.hyper.kers_j)/1000.0,"DRS ABERTO" if selected.hyper.drs_active else "DRS FECHADO",str(selected.pit_requested_lap) if int(selected.pit_requested_lap)>0 else "—"]
	var events: Array = k.state.events
	while event_cursor < events.size():
		var ev: Dictionary = events[event_cursor]; event_cursor += 1
		if not str(ev.type) in ["hyper_pit_serviced","hyper_pit_exit","hyper_weather_change","hyper_strategy_order","hyper_retired","racecraft_overtake_confirmed","driver_intent_changed","command_rejected","race_finished"]: continue
		if str(ev.type) == "driver_intent_changed" and int(ev.car_id) != selected_id: continue
		var c: Dictionary = k._lookup_car(int(ev.car_id)); var name_text: String = str(c.get("name","DIREÇÃO"))
		radio_lines.append("%ds • %s • %s" % [int(ev.tick)*200/1000,name_text,_radio_text(ev)])
		if radio_lines.size() > 30: radio_lines.pop_front()
	radio.text = "\n".join(radio_lines)
func _pause() -> void:
	if not k.initialized or bool(k.state.finished): return
	running = not running; pause_button.text = "PAUSAR" if running else "RETOMAR"
func _speed(value: float) -> void: speed = value
func _select_driver(index: int) -> void: selected_id = driver.get_item_id(index)
func _command(order: Dictionary) -> void:
	if not k.initialized or selected_id < 0: return
	order.car_id = selected_id; order.source = "Manual"
	var outcome: Dictionary = k.submit(order)
	status.text = "Comando recebido: " + str(outcome.reason)
func _pace(value: String) -> void: _command({"type":"set_pace","pace":value})
func _pit() -> void:
	if compound.selected < 0: return
	_command({"type":"schedule_pit","requested_lap":int(pit_lap.value),"compound":compound.get_item_text(compound.selected),"allow_double_stack":true})
func _cancel() -> void: _command({"type":"cancel_pit"})
func _save() -> void:
	if not k.initialized: return
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
	return candidate
func _load() -> void:
	var candidate = _read_checkpoint(checkpoint_path)
	var from_backup: bool = false
	if candidate == null:
		candidate = _read_checkpoint(checkpoint_path+".bak"); from_backup = candidate != null
	if candidate == null: status.text = "Checkpoint ausente, inválido ou incompatível."; return
	k = candidate; running = false; _bind_session(); pause_button.text = "RETOMAR"; status.text = "Checkpoint restaurado do backup." if from_backup else "Checkpoint restaurado."
func _close() -> void:
	if get_parent() is Window and get_parent() != get_tree().root: get_parent().queue_free()
	else: get_tree().change_scene_to_file("res://scenes/main.tscn")

func _pit_label(value: String) -> String:
	return str({"TRACK":"PISTA","ENTRY_OBSERVED":"ENTRADA","PIT_IN":"ENTRADA","PIT_WAIT":"FILA","PIT_SERVICE":"SERVIÇO","PIT_OUT":"SAÍDA"}.get(value,value))
func _radio_text(ev: Dictionary) -> String:
	var messages: Dictionary = {"hyper_pit_serviced":"Pneus trocados: "+str(ev.get("compound","")),"hyper_pit_exit":"Retorno à pista.","hyper_weather_change":"Mudança de água na pista: "+str(ev.get("water_microns",0))+" μm.","hyper_strategy_order":"Estratégia solicita box: "+str(ev.get("compound","")),"hyper_retired":"Abandono: falta de combustível.","racecraft_overtake_confirmed":"Ultrapassagem confirmada.","command_rejected":"Ordem rejeitada: "+str(ev.get("reason","")),"race_finished":"Bandeirada final."}
	if str(ev.type) == "driver_intent_changed":
		return str({"stable_running":"Piloto: ritmo estável.","slower_car_ahead":"Piloto: tenho ritmo para atacar o carro da frente.","faster_car_behind":"Piloto: carro mais rápido atrás; vou defender.","tire_worn":"Piloto: estou sentindo o desgaste dos pneus.","tire_overheated":"Piloto: pneus quentes, vou conservar.","fuel_low":"Engenheiro: combustível baixo, conserve.","driver_fatigue":"Piloto: preciso reduzir o esforço."}.get(str(ev.get("reason","")),"Piloto: intenção atualizada."))
	return str(messages.get(str(ev.type),str(ev.type)))
func _open_career() -> void:
	if is_instance_valid(career_window): return
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
		parts.append("%s • %s • r%d • %d km" % [slot,s.slots[slot],part.level,part.km])
	_label(career_body,"PEÇAS INSTALADAS
"+"
".join(parts),14)
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
	var s: Dictionary = career.prepare(w,auto_pit.button_pressed,setup_choice.selected*500)
	var candidate = Kernel.new()
	if s.is_empty() or not candidate.initialize(s): _career_action("Falha ao preparar etapa."); return
	k = candidate; _bind_session(); running = true; pause_button.text = "PAUSAR"; status.text = "Etapa oficial da carreira Hyper em andamento."; career_window.queue_free()
func _career_record() -> void:
	_career_action("Resultado registrado e folha/orçamento atualizados." if career.commit(k) else "Somente uma bandeirada válida da etapa reservada pode ser registrada.")
