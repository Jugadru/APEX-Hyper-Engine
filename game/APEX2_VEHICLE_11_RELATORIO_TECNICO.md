# APEX 2 — NEXT ENGINE 1.1: VEHICLE DYNAMICS
## Relatório técnico da versão experimental — 16/11/2026

**Base integral**: `APEX_MOTORSPORT_MANAGER_v0.6.6.8.2_APEX2_PRIMARY_COMPAT_COMPLETO.zip`.
**Política**: Core 2 continua executando a física oficial; APEX 2 primary compat permanece selecionado. Nenhum código da HUD, física Core 2, replay oficial, Pit Wall, carreira ou salvamentos foi alterado. A Vehicle Dynamics 1.1 é exercitada somente por testes independentes.

### Implementação comprovada

- `experimental/apex2/vehicle_dynamics.gd`: integrador longitudinal discreto de 200 ms, representação em inteiros (mm, ms, g, W, N, temperatura centesimal), força de tração sujeita à potência e aderência, resistência aerodinâmica, resistência ao rolamento, carga aerodinâmica, frenagem antecipada pela distância necessária até curvas e integração de distância.
- Pneus: aderência por composto (Macio, Médio, Duro, Intermediário, Chuva), temperatura, desgaste acumulado por distância/solicitação lateral/frenagem, condições molhadas. Modelo de desgaste simplificado e **não calibrado**.
- Combustível: consumo proporcional à energia mecânica utilizada, poder calorífico e eficiência assumida; massa influencia aceleração e curva. Coeficientes físicos são hipóteses explícitas de engenharia, **não telemetria certificada de Fórmula 1 de 2012**.
- Geometria: leitura das polilinhas normalizadas já existentes em `data/season_2012.json`; comprimento normalizado e raio circunscrito calculados e escalados ao comprimento oficial. É uma geometria **sintética derivada de referência visual**, não dados topográficos medidos, e não serve para homologar tempos de volta.
- `experimental/apex2/vehicle_kernel_11.gd`: herda o kernel 1.0, substitui somente o hook de movimento, mantém Command Queue, eventos, hashing, checkpoint/replay; adiciona validação da dimensão física no restore.
- Núcleo 1.0 preservado: só a lógica de movimento constante foi extraída para `_advance_reference_car` com corpo idêntico; hash legado verificado.
- `scenario_adapter.gd`: adicionada apenas a chave `geometry_points`, sem modificar o Core 2.

### Verificações realizadas

- 31 verificações de causalidade e integridade física: **PASS**.
- 45 verificações de determinismo em GBR/BEL/ITA/SIN, incluindo comparação de tick agrupado/individual, checkpoints e replay isolado: **PASS**.
- Spa, ordem manual V21 em chuva intensa, cenário experimental de um carro, cruzamento observado no tick **38.931**, sem execução antecipada: **PASS**. A implementação **só observa a entrada no pit**, não executa troca de pneus/serviço/saída.
- Testes herdados: kernel (525), fila (97), replay (1.622), controlador oficial (86), HUD (unitário, 34 de integração, 30 de ordens pendentes): **PASS**.
- Godot 4.7.2 headless import: **PASS**. Testes nativos em `qa/apex2_vehicle_11/logs`.

### Microbenchmark headless (24 carros, 120 ticks, seed 6701)

| Pista | Tempo kernel 1.0, µs/tick | Vehicle Dynamics 1.1, µs/tick |
|---|---:|---:|
| GBR / Seco | 35.4 | 1054.3 |
| BEL / Chuva intensa | 37.4 | 945.2 |
| ITA / Seco | 36.0 | 944.8 |
| SIN / Chuva intensa | 48.0 | 1015.9 |

O Vehicle 1.1 é consideravelmente mais custoso que o integrador de referência, porque calcula forças e curvas. O microbenchmark não representa FPS nem corrida completa. A memória RSS dos processos é compartilhada por Godot e recursos do projeto.

### A/B com Core 2 (120 ticks por cenário, mesmo grid; cobertura de regras NÃO equivalente)

| Pista | Core 2 µs/tick | Vehicle 1.1 µs/tick | Comparabilidade |
|---|---:|---:|---|
| GBR / Seco | 6982.1 | 1040.1 | NÃO |
| BEL / Chuva intensa | 6914.6 | 935.3 | NÃO |
| ITA / Seco | 6991.5 | 996.5 | NÃO |
| SIN / Chuva intensa | 6864.2 | 994.4 | NÃO |


A Vehicle 1.1 processa apenas forças longitudinais, pneus e consumo; o Core 2 calcula combate, decisões, pit completo, regras e muito mais. Não se pode afirmar que o Next é superior em desempenho. A tentativa de medir RSS internamente retornou `-1` (indisponível); não há valor confiável de memória isolada por engine.

### Limitações obrigatórias

- Driver Brain, Racecraft Resolver, Strategy Brain, pit stop completo, incidentes, danos, KERS/DRS, duração realista de corrida e clima evolutivo **não implementados no modelo 1.1**. A chuva é observada no início, como condição fixada para o ensaio.
- Não há correlação física com topografia, largura efetiva das curvas ou dados de sensores históricos. Tempos de volta e desgaste acumulados ainda **não estão calibrados**.
- Os parâmetros de pneus e coeficientes são aproximações causais para teste de arquitetura, não grandezas exatas de engenharia.
- O movimento dos 24 carros não inclui interação dinâmica, overtakes ou tráfego. A seed integra o contrato mas o modelo Vehicle 1.1 ainda é determinístico sem eventos aleatórios.
- Checkpoints experimentais do modelo 1.1 possuem estado adicional e **não substituem os saves/replays oficiais**.
- Não foi medida melhora de FPS em GPU real. A HUD 3D aprovada pelo usuário foi preservada, não redesenhada.

### Próximas condições de aprovação

Calibrar velocidades setoriais e desgaste com dados verificáveis, adicionar testes de eventos de pit completo e interação com tráfego nas versões futuras, medir em computador-alvo e validar paridade de regras antes de qualquer seleção como física oficial.

### Rollback

Feche o jogo; execute novamente o ZIP intocado da v0.6.6.8.2 em uma pasta separada. Não há migração de save. `project.godot`, `scripts/`, cenas da HUD e diretório de usuário permanecem originais.
