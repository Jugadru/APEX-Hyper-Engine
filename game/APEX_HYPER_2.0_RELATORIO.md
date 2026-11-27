# APEX Next Engine 2.0 — Hyper Evolution Alpha 1

**Data:** 26/11/2026  
**Base:** release `NEXT_ENGINE` do repositório Jugadru/APEX-Simulation, ZIP `APEX_MOTORSPORT_MANAGER_APEX2_NEXT_ENGINE_1.3_RACECRAFT_EXPERIMENTAL_COMPLETO.zip`.  
**SHA-256 de entrada:** `011ef97af4dca131537b12d0ffc96464aadd5abb439ece0f98a20713061d2213`. Confere com o digest do asset publicado no GitHub.  
**Ambiente:** Godot 4.7.2.stable.official.ed1daf0bf, Linux; testes gráficos por Xvfb e Mesa llvmpipe/OpenGL Compatibility.

## 1. Decisão arquitetural e preservação

A tag Git do repositório contém código identificado como Next Engine 1.0; o ZIP original entregue pelo usuário contém efetivamente a 1.3 (Vehicle Dynamics 1.1, Driver Brain 1.2 e Racecraft Resolver 1.3). A fonte da implementação foi o ZIP, não a árvore antiga da tag. O Core 2 continua como modo oficial e a nova engine fica isolada em `experimental/hyper/`, com seu próprio estado, interface, checkpoint e carreira. O `project.godot` original não foi alterado.

Apenas dois arquivos pré-existentes foram modificados: `experimental/apex2/vehicle_dynamics.gd` (caminhos condicionados à presença do estado Hyper, mantendo o modelo legado) e `scripts/apex_front_menu.gd` (entrada experimental no menu e identificação no rodapé). Nenhum arquivo original foi removido. O ZIP de entrada fica preservado e não houve publicação, merge ou substituição da release GitHub.

## 2. Implementação

| Módulo | Responsabilidade / efeito |
|---|---|
| `hyper/kernel.gd` | Avanço determinístico de 200 ms herdado; integração da aerodinâmica, tráfego, estratégia, pit service, KERS, DRS, classificação, checkpoints e cenário de carreira |
| `hyper/traffic.gd` | Máquina de estados 1.3 refinada; índice de distâncias, tráfego circular, corredores, recuperação somente se centro livre, bloqueio de disputas concorrentes, caps de velocidade |
| `hyper/environment.gd` | Clima programável, wake em reta/curva, estratégia de compostos, autorização DRS por janela e gap aproximados |
| `hyper/indexed_queue.gd` | Mantém ledger e validação original; indexa apenas comandos pendentes para consulta por tick |
| `hyper/scenario.gd` | Adapta 20 circuitos e 12 equipes originais; especificações técnicas por rating, acerto, zonas DRS aproximadas |
| `hyper/career.gd` | Campeonato 2012 isolado, pontos, orçamento fictício, contratos e Soul Staff reaproveitados, rivais, componentes físicos, projetos, fabricação, instalação, quilometragem, transações e backups |
| `hyper/console.gd` + `console.tscn` | Interface jogável, menu de temporada, pit wall, ritmo, telemetria, eventos, save/load e controles de velocidade |
| `hyper/track_map.gd` | Mapa 2D passivo baseado no progresso oficial; sem influência esportiva |

### Física e corrida

- O erro de unidade no consumo herdado da 1.1–1.3 provocava consumo mil vezes maior do que a conversão correta. A Hyper usa escala 1.000 no numerador de energia em vez de 1.000.000, preservando o caminho anterior para versões legadas. A força de rolamento/arrasto também pode desacelerar carro sem tração na Hyper.
- Wake reduz arrasto em retas e downforce em curvas, de acordo com distância, alinhamento de corredor e raio sintético. KERS usa orçamento aproximado de 400 kJ por volta e potência de até 60 kW. DRS é condicionado a pelo menos duas voltas completas, pista seca e detecção de gap estimado de até 1 s nas zonas de gameplay herdadas.
- O modelo de pneus continua baseado na física simplificada existente. Recalibração inicial reduz taxa nominal de desgaste Hyper para 55% da antiga nos secos e 42% nos pneus de chuva; os multiplicadores térmicos e de carga permanecem. Não são dados de testes de pneus reais.
- Pit stop: entrada observada, trânsito de entrada, espera, serviço exclusivo por equipe (FIFO por tick e ID), troca efetiva de composto, reinício de desgaste, trânsito de saída e retorno à pista. A perda de trânsito equivale a tempo de parada no progresso, sem geometria real de pit lane. Não há reabastecimento.
- Estratégia por regra de composto/clima/desgaste, com comando enfileirado e proteção de ordem manual. Ainda não é um simulador probabilístico completo de undercut/overcut.
- Classificação baseada em distância, chegada e abandono; falta de combustível pode produzir DNF. Não há colisão geométrica, regras completas de Safety Car, incidentes, bandeiras e penalidades.

### Gestão e integração

- Cadastro de 20 etapas/24 pilotos/12 equipes. Pontos 25–18–15–12–10–8–6–4–2–1. Cada resultado de GP é transacional, ligado a token congelado de etapa, e não pode ser registrado duas vezes.
- Departamento de engenharia dispõe de 14 dias de gameplay entre etapas; projeto, protótipo, teste e fabricação consomem tempo; capacidade de trabalho por departamento é limitada. Cada kit gera duas peças individuais. Instalação troca os IDs físicos no carro, mantém as peças removidas no inventário e só então modifica as especificações de corrida. Focos de desempenho, equilíbrio e durabilidade introduzem diferenças de potência, drag/downforce e sensibilidade à quilometragem. O modelo é uma abstração, não validação de engenharia real.
- Staff usa catálogo, contratos e Soul Staff do projeto original. Chefe de mecânica altera duração do serviço, estrategista altera cadência de avaliação, engenheiro/chefe de aero altera duração de P&D. Contratações custam bônus e salário; cada GP reduz duração do contrato. Rivais usam o serviço de desenvolvimento já existente, refletido nas especificações do cenário seguinte.
- Os arquivos `user://hyper_career_20.bin` e `user://hyper_engine_20_checkpoint.bin` são separados dos saves Core 2. Temporário + verificação de hash + backup anterior + rename. Checkpoint é retomável no mesmo modelo; não migra gravações 1.3 para a física 2.0. Ao repetir a temporada 2012 após completá-la, a carreira preserva um arquivo de até 20 temporadas anteriores. Essa repetição de temporada ainda não é universo histórico com evolução de eras.

## 3. Testes nativos e resultados

Os logs brutos estão em `qa/hyper/logs/`. Os testes não usam saves reais do usuário. O runner `tools/run_hyper_validation.sh` usa XDG_DATA_HOME temporário.

- Legado: `test_kernel` (525), `test_pit_queue` (97), `test_vehicle_11` (31), `test_driver_12` (51), `test_racecraft_13` (37): **741 verificações PASS**. O comportamento anterior e o menu original foram preservados nesses testes; isto não é a bateria integral de todos os testes do Core 2.
- `test_hyper`: **24 verificações PASS** (wake, V21, batch/single ticks, snapshot, checkpoint, fila de dois carros, mudança efetiva de pneus e retorno). A fila de dois carros é fixture controlada.
- `test_calendar`: **PASS**, 20 pistas × 20 ticks, 24 carros por pista; 12 equipes com dois pilotos identificados. Não equivale a terminar 20 GPs.
- `test_manual_wet`: **PASS**. Fernando Alonso, chuva programada no tick 1.500, primeira entrada e primeiro serviço na volta 21, sem parada antecipada; DRS desativado em pista molhada.
- `test_career`: **34 verificações PASS**, inclui GP completo da Austrália, resultado persistido, 101 pontos, contrato e folha, instalação antes da corrida, quilometragem, bloqueio de alteração durante GP, reabertura do save, resultado duplicado rejeitado. Um GP completo não equivale a carreira de 20 etapas homologada.
- `test_persistence`: **PASS**, corrupção proposital do arquivo principal e recuperação do backup.
- `test_ui` e `test_menu`: **PASS**; menu original abre janela independente, 20 pistas e 12 equipes, central de temporada, mapa com 24 linhas, checkpoint restaura hash idêntico. Capturas 1600×900 e 1920×1080 executadas em Godot real com renderização por software. Não representam FPS de GPU dedicada.

### Corridas completas (seed 2026)

| Circuito/clima | Voltas | Ticks | Classificados que completaram | Abandonos | Boxes | Ultrapassagens confirmadas | Tempo esportivo |
|---|---:|---:|---:|---:|---:|---:|---:|
| Monza seco | 53 | 26.158 | 24 | 0 | 48 | 70 | 5.231,6 s |
| Silverstone chuva intensa | 52 | 35.029 | 24 | 0 | 72 | 9 | 7.005,8 s |
| Austrália, carreira seca | 58 | 31.665 | GP concluído | ver teste | ver resultado da carreira | ver teste | 6.333 s |

Monza e Silverstone passaram a restauração de checkpoint no meio da corrida com 50 ticks reproduzidos e hash idêntico. Na primeira calibração, antes de reajustar desgaste e otimização, foram 108/168 paradas em Monza/Silverstone; logs preservados. A execução inicial com conversão de combustível incorreta foi interrompida após diagnóstico (INCONCLUSIVE). Não usar as estatísticas de uma seed como prova de balanceamento histórico.

### Benchmark isolado de fila

Em uma fixture com 3.000 registros (2.999 concluídos e um pendente) e 5.000 chamadas de `due`, fila original: 2.234.593 μs; fila indexada: 6.533 μs. A ordem e o ledger exportado após settle foram idênticos. Trata-se de um benchmark de uma rotina, não de um ganho de FPS do jogo. As corridas recalibradas também ficaram mais rápidas na máquina de teste, porém há diferenças de carga esportiva, combustível e pneus; não é um A/B isolado da engine inteira.

## 4. Limitações, riscos e testes não realizados

- **Alpha 1:** não é substituição homologada do Core 2. 3D, TV Director e HUD original seguem na linha oficial, sem integração com esta engine. A nova interface é 2D.
- Geometria e corredores sintéticos; DRS não usa mapas oficiais certificados de 2012. Sem CFD, dinâmica de guinada, colisão 3D, freios/suspensão por roda ou calibração por telemetria real.
- Tráfego circular limita seguimento, mas não há sistema completo de bandeira azul e ultrapassagem de retardatários. Faltam SC, penalidades e neutralizações, falhas mecânicas detalhadas e procedimentos de relargada. O modelo de fim faz todos os carros ativos completarem a distância; não replica toda a regra de bandeirada e retardatários da FIA.
- Estratégia heurística, previsão de clima imperfeita e cálculo completo de undercut/overcut não implementados na Hyper. A percepção existente do Driver Brain ainda é uma aproximação.
- Sistema de P&D inclui etapas e custos, mas o teste/protótipo é uma fase temporal, não ensaio físico de bancada/CFD. Oficina completa por mecânico, reparos detalhados, negociação de pilotos, academia, criação de equipes, patrocinadores e carreira histórica multiera não foram integrados à Hyper. A gestão existente do Core 2 permanece no pacote.
- **NOT_RUN:** temporada Hyper inteira, 5/10/20 temporadas completas, corridas completas nas outras 17 pistas, equilíbrio estatístico com muitas seeds, todos os testes Core 2, exportação Windows/Linux, hardware real, GPU, FPS em 3D, auditoria de todas as regras esportivas 2012, CI GitHub. A restauração 1.3 → 2.0 não é suportada.
- A janela de laboratório mantém a carreira oficial intacta, mas ainda requer testes no PC de destino. O modelo de save usa formato binário Godot local sem objetos; o hash detecta corrupção acidental, não é assinatura criptográfica de autoria.

## 5. Rollback e próximos passos

Extraia sempre em pasta distinta. Para regressar à versão anterior, feche o laboratório ou abra o ZIP original intacto. Não copie os saves Hyper sobre os saves antigos. A tag e o release GitHub não foram modificados. A próxima homologação deve focar equivalência com o motor oficial, adaptador 3D passivo, regras 2012 e calibração de resultados por circuito/seed antes de tornar a Hyper o motor padrão.
