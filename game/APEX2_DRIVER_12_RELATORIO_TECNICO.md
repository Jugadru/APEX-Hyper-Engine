# APEX 2 — Next Engine 1.2: Driver Brain
## Relatório técnico — experimental (16/11/2026)

**Base verificada:** `APEX_MOTORSPORT_MANAGER_APEX2_NEXT_ENGINE_1.1_VEHICLE_DYNAMICS_EXPERIMENTAL_COMPLETO.zip` (SHA-256 `66fbf719d5098dbe9948348bf9dab94edd2b4f1effca7baaf257fc005013a6a4`).

**Regra de isolamento:** `project.godot`, cenas, scripts de produção do Core 2, HUD ReBroadcast, replay oficial, Pit Wall, 3D e saves são exatamente os bytes da versão 1.1. Nenhuma opção de substituir a física principal foi criada. A física da corrida jogável continua sendo Core 2 sob o controlador APEX2 primary compat.

### Código implementado e responsabilidades

1. `experimental/apex2/driver_brain.gd`: perfis individuais **sintéticos** por seed e ID, com agressividade, paciência, percepção imperfeita, tolerância a risco, obediência (estresse em ordens manuais), confiança e fadiga. Os valores não representam dados biográficos reais de pilotos de 2012.
2. Observação simultânea do grid em intervalos de **20 ticks = 4 segundos esportivos**, sem ler renderização, FPS ou RNG global. O piloto detecta carro à frente/atrás, gap e velocidade relativa. O erro perceptivo é limitado por awareness e reproduzível.
3. Processo causal: observação → avaliação de risco → intenção tática `HOLD`, `PREPARE_ATTACK`, `COVER_THREAT`, `PRESERVE` ou `RECOVER` → pedido de alteração de ritmo via Command Queue → validação no tick futuro → efeito longitudinal via `vehicle_dynamics.gd` → evento / hash / checkpoint.
4. `experimental/apex2/driver_kernel_12.gd`: herda integralmente o Vehicle Kernel 1.1. O comando manual `set_pace` entra em modo MANUAL permanente nesta prova de conceito; IA não pode substituí-lo, mesmo com comando simultâneo no mesmo tick. Ordens de pit V21 continuam protegidas.
5. O modelo não gera automaticamente pit stops, ultrapassagens, defesa lateral, danos, acidentes ou mensagens de rádio. **Intenção não é evento de overtaking**. A apresentação 3D de produção permanece desacoplada.
6. Checkpoint/replay experimental: schema de Driver Brain adicional verificado de maneira transacional com hash. Não substitui saves oficiais.

### Testes nativos realizados no Godot 4.7.2

| Suíte | Execução | Resultado |
|---|---|---|
| Driver Brain 1.2 | 51 verificações | **PASS** |
| Determinismo Driver 1.2 | 53 verificações / 4 pistas | **PASS** |
| Stress Monza Driver 1.2 | 10.000 ticks, 24 carros, 285 eventos, 26 comandos | **PASS** |
| Kernel legado | 525 verificações | **PASS** |
| Queue legada | 97 verificações | **PASS** |
| Replay legado | 1.622 verificações | **PASS** |
| Vehicle Dynamics 1.1 | 31 físicas + 45 determinismo | **PASS** |
| Spa V21 Vehicle 1.1 | Entrada no tick 38.931 sem antecipação | **PASS** |
| Controlador principal oficial | 86 contrato + 17 cena | **PASS** |
| HUD ReBroadcast | unitário + 34 integração + 30 ordens pendentes | **PASS** |
| Editor headless 4.7.2 | Importação | **PASS** |

Determinismo Driver 1.2: as execuções em lote e tick individual obtiveram hashes internos idênticos em Silverstone seco, Spa chuva intensa, Monza seco e Singapura chuva intensa. Checkpoints preservaram o estado e o replay independente não alterou a corrida original.

### Benchmark headless experimental — CPU

24 carros por cenário; **3 amostras de 180 ticks cronometrados**, após 20 ticks de aquecimento. Valores medianos do ensaio:

| Circuito | Vehicle 1.1 (µs/tick) | Driver 1.2 (µs/tick) | Diferença no ensaio |
|---|---:|---:|---:|
| GBR / Seco | 1013.26 | 1356.93 | +33.92% |
| BEL / Chuva intensa | 2863.88 | 6507.71 | +127.23% |
| ITA / Seco | 2144.53 | 2172.94 | +1.32% |
| SIN / Chuva intensa | 1110.83 | 1238.64 | +11.51% |

**Classificação da conclusão de desempenho: INCONCLUSIVE.** As amostras variaram acentuadamente no ambiente compartilhado (inclusive diferenças de vários múltiplos na mesma pista). Como o Driver 1.2 executa decisões a cada 20 ticks e o Vehicle 1.1 não, o trabalho por tick também difere por construção. O JSON apresenta as três amostras de cada rota, os hashes, a quantidade de eventos e as medianas. Não são FPS, não são medidas de GPU e não implicam superioridade sobre Core 2.

### Limitações e riscos restantes

- Sem Racecraft Resolver 1.3: não existem ataques laterais ou ultrapassagens causadas pelo Driver Brain. O modo `COVER_THREAT` apenas influencia o ritmo longitudinal.
- A modelagem de personalidade é sintética, com coeficientes de protótipo e limites conservadores. Não é avaliação psicológica nem dados de pilotos reais.
- A posição no grid pode mudar pelo integrador cinemático simplificado, mas **não** representa disputa física entre carros.
- Manual `set_pace` trava a automação desse piloto até nova corrida; reabilitação AUTOMÁTICA durante a prova exigirá um comando versionado na futura fila, não foi criada interface cenográfica.
- Não há DRS/KERS, comunicação de equipe, incidentes, aprendizado persistente entre corridas, tática de pit, geometria aferida ou física completa da Next Engine.
- Não foi reexecutada corrida **oficial completa** Monza 53 voltas nesta versão; motor oficial foi preservado byte a byte e regressões curtas passaram.
- Testes em GPU real, longas carreiras e equivalência esportiva com Core 2 não foram realizados.

### Incidente de infraestrutura na primeira importação limpa

- **FAIL** — uma tentativa de importação do ZIP extraído com `godot --headless --editor --quit` retornou código **139 (segmentation fault)** durante importação de assets, com mensagem do Godot `propagate_notification()` em thread incorreta. Não há evidência de que o erro foi causado pelo Driver Brain, nem é adequado ocultá-lo.
- **PASS** — repetição no mesmo diretório com `--single-threaded-scene` concluiu a importação e permitiu executar os testes em uma cópia extraída.
- **PASS** — importação **nova, em outro diretório limpo**, usando `godot --headless --single-threaded-scene --editor --quit` concluiu sem erros; assim o sucesso não dependeu do cache anterior.
- Esse incidente torna o fluxo padrão de importação headless **não homologado no ambiente de execução usado**. Não substitui a necessidade de testar a abertura gráfica no PC do usuário.

### Condições antes de promover o Driver Brain ao jogo oficial

Precisamos de resolver de disputas e interação em pista validados, calibração da inteligência contra casos reproduzíveis, resultados completos e determinísticos de corrida, testes longos de CPU/RSS e medição gráfica no PC. Nenhuma chave de ativação em produção foi adicionada nesta versão.

### Rollback

Extraia a v1.1 original em uma pasta nova, sem substituir saves. Para a corrida jogável não há rollback esportivo necessário: nenhuma alteração foi feita no motor oficial.
