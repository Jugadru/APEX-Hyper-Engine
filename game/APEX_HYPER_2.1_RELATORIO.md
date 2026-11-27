# APEX Next Engine 2.1 — Hyper Evolution Alpha 2

## Base, escopo e rollback
Base: ZIP Alpha 1 entregue nesta conversa, preservado separadamente. Referência do Core 2: árvore GitHub `8b5755279b134b051f3d237bdbbb517f9a6a721b` (main consultada em 26/11/2026). Foram inventariados scripts, testes e documentos de evolução; a adaptação não equivale a um merge de todos os commits do Core 2. A identificação interna do Core 2 no snapshot consultado era 0.6.8; a física 0.6.9/revisão 041 ainda descrita como candidata. Nenhuma publicação ou merge realizado. A distribuição é projeto Godot, não executável. Abra `project.godot`, F5, NEXT ENGINE 2.1 / ABRIR ALPHA 2. Core 2 e Alpha 1 continuam disponíveis; saves e checkpoints da Alpha 2 separados. Backups legados permanecem válidos na respectiva engine; não se promete migração cruzada. Rollback: voltar ao ZIP Alpha 1 intacto.

## Matriz de portabilidade (funcionalidade equivalente, não identidade de código)
| Linha Core 2 | Hyper 2.1 | Estado |
|---|---|---|
| 9.0–9.9: qualidade, pneus, pit, replay, performance | Preserva modelos Alpha 1; acrescenta QA, replay e scheduler | Parcial |
| 9.10 Strategy Staff | Projeção consultiva de 3 janelas, protege plano manual, influência de staff Alpha 1 | Parcial: sem novo adiamento automático por stint |
| 9.11–9.17 largada, ultrapassagem, ritmo | Reação individual de 1–3 ticks, modelo longitudinal preexistente, corredores, veto em curvas, cronometragem de voltas | Parcial: não reproduz toda física de largada do Core 2 |
| 9.13/14 engenheiro e pista | Diagnóstico de desgaste, erro, tráfego, chuva e janelas; presets | Parcial: falta recomendação completa de acerto por pista |
| 9.15/16 performance e gaps | Fila Alpha 1 preservada, velocidade real indicada, transição sem débito de passos inteiros, tempo de volta real por ticks; gap ainda estimado | Parcial |
| 9.17.1–9.17.9 visual, HUD, preparação, menu | 3D read-only com carros e pistas originais, quatro câmeras, interface própria, acertos P1/P2 | Parcial: sem todos os retratos, HUD e correções visuais recentes |
| 9.17.10 linha ideal | Compromisso de corredor e veto de manobra | Parcial: sem trajetória ideal contínua externa/interna/externa |
| 9.17.11 aero wake | Modelo de vácuo/ar sujo Alpha 1 preservado | Já existente; sem port integral da calibração 035 |
| 9.17.12 coordenação | Máquina de fases, seleção de corredor, restrição de defesa e recuperação | Parcial: sem paridade integral do solver Core 2 |
| 9.18 acerto molhado | Dois presets independentes, influência grip/drag | Adaptado; heurístico |
| 9.19 corner battle | Veto de compromisso tardio em curvas e recuperação | Adaptado; não idêntico a 037 |
| 9.20/20.1 tráfego | Vizinho físico circular e passagem de retardatário separada de posição; projeção de tráfego | Adaptado parcialmente; sem toda política de blue flags |
| 9.21 erro | Seis tipos, risco contextual, perda limitada de velocidade, recuperação, eventos | Adaptado; coeficientes de jogo |
| 9.22 comunicação | Engenheiro consultivo, rádio texto PT, voz opcional OS | Parcial: sem fila completa de prioridade, familiaridade persistente ou áudio comprovado |
| 9.23 onze frentes | QA passivo, scheduler, replay em memória ZSTD até 9 checkpoints, 3D/2D, controles, rádio | Parcial: sem toda infraestrutura/benchmarks e ajustes de HUD/gráficos |
| 9.24 / 0.6.7 Living Factory | Reserva de destino/peça, manutenção e substituição, capacidade mecânica, custo/cancelamento/histórico, P&D Alpha 1 preservado | Adaptado; sem homologação multi-temporada |
| 0.6.8 aleatoriedade | SHA-256 com seed, ator, tick, domínio e canal; sem RNG global novo | Adaptado |
| 0.6.9 longitudinal (candidato 041) | Física longitudinal já presente na Hyper, restrições adicionais de curva, erros e setup | Não portado literalmente; não equivalência a 041 |

## Testes executados — Godot 4.7.2
Resultados nos logs em `qa/hyper2/`. As contagens são verificações internas de fixtures, não equivalem a centenas de corridas. Não somadas às 799 verificações históricas da Alpha 1.
- `test_evolution_final.log`: 15/15; seed, timing, diagnóstico sem mutação, checkpoint, recuperação.
- `test_workshop_final.log`: 20/20; conflitos, persistência, cancelamento, troca e manutenção.
- `replay_quality_corrected.log`: 16/16; comandos de pit/ritmo/auto, seek 10/120/2500/3100, 9 anchors, observador e passagem de retardatário.
- `career_final.log`: 34/34; GP real de Albert Park, 31800 ticks, 101 pontos, custos e carreira recarregada.
- `test_calendar_final.log`: 20 circuitos x 20 ticks e 12 equipes (não são 20 GPs completos).
- `monza_final.log`: 53 voltas, 24 concluíram, 48 ultrapassagens confirmadas, 48 paradas, 26092 ticks; checkpoint parity, vencedor Vettel.
- `silverstone_final.log`: 52 voltas, chuva intensa, 24 concluíram, 62 ultrapassagens confirmadas, 72 paradas, 33104 ticks; checkpoint parity, vencedor Button.
- `manual_wet_final.log`: Alonso entrada e serviço V21, sem antecipação e sem DRS no molhado; água 5000 microns.
- `test_ui_final.log`: headless, controle de velocidade e salvar/restaurar.
- `visual_final.log`: OpenGL Compatibility via llvmpipe/Xvfb 1600x900; 24 carros instanciados, hash esportivo preservado; áudio dummy por falta de dispositivo. Capturas `console.png` e `tv3d.png`.
- `menu_final.log`: menu Alpha 2, seleção e carreira. `legacy_menu_after_import.log`: menu Alpha 1 aprovado após import. `legacy_test_hyper.log`: 24/24; `legacy_test_persistence.log`: recuperação PASS.
- `editor_import_final.log`: importação concluída (exit 0, Compatibility). Primeira tentativa falhou na importação de CSV histórico como tradução; oito sidecars passaram a `importer="keep"`. Arquivos CSV e traduções históricas originais preservados.

## Falhas de desenvolvimento corrigidas e limitações
Replay inicial falhava: grid em unidades de volta → milímetros → unidades truncava uma unidade. Validador da Alpha 2 passou a aceitar somente a projeção inteira de grid, parado nos primeiros três ticks, sem relaxar checkpoints de corrida. Teste reexecutado PASS. A primeira escala 3D deformava a pista; normalização e suavização corrigidas, novo render PASS. Retestagem longa já em andamento na revisão esportiva final, correção posterior somente no validador de grid, sem mudança de movimento.
Não foram certificados: 20 GPs completos, 20 temporadas, equivalência hash Core 2, desempenho GPU física, 64x sustentado, qualidade TTS, 1920x1080, colisões/danos/SC completos, geometria de box 3D, replay em disco/exportação, toda IA de estratégia/staff/mercado. A classificação de corrida mede distância esportiva; gaps são estimados, tempo de volta tem resolução de 200ms. Curvatura e setup são aproximações, não dados físicos FIA. Não se garante balanceamento histórico. O 3D usa geometria esquemática e não mostra carros em serviço nos boxes. O modo 2D/3D é manual. Não se declara Alpha 2 equivalente ao Core 2 completo.
