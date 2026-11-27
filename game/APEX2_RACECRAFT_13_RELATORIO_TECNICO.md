# APEX 2 — Next Engine 1.3 / Racecraft Resolver — Relatório técnico

**Base auditada:** APEX 2 Driver Brain 1.2 Experimental (`b5dad47f0e0ab5e38317c8adfb4302749cfa6bbf87f62511ac4174fcc749cb44`).  
**Motor:** Godot 4.7.2 / GDScript — Linux.  
**Escopo:** módulo **experimental**, isolado, sem alterar o Core 2, a HUD, as cenas ou o controlador principal do jogo.

## O que existe de fato

- `experimental/apex2/racecraft_resolver.gd`: observa progressão longitudinal, velocidade, fases de duelo, intenção do Driver Brain e perfil sintético da pista. Produz estados e limites de velocidade de tráfego; não escreve posições.
- `experimental/apex2/racecraft_kernel_13.gd`: avança em ticks determinísticos, aplica o plano do resolver, recebe o avanço do Vehicle Kernel 1.1, confirma ultrapassagem **somente se um carro ultrapassar longitudinalmente outro**, em corredor diferente, e emite evento esportivo com lacuna medida.
- `experimental/apex2/vehicle_dynamics.gd`: pequena extensão opcional que usa `traffic_speed_cap_mm_s` no limite de velocidade/frenagem, **apenas quando o campo existe**. Não altera o comportamento antigo 1.1/1.2 nem scripts oficiais.
- Fases: `CRUISE`, `APPROACH`, `PREPARE`, `ATTACK`, `SIDE_BY_SIDE`, `DEFEND`, `ABORT`, `RECOVER`. Sem mudança arbitrária de posições.
- Corredores laterais sintéticos `CENTER`, `LEFT`, `RIGHT`, uma única manobra de defesa até recuperar, vedação de ataque onde a curvatura sintética não deixa espaço e restrição de passagem em corredor ocupado.
- Headway: quando dois carros dividem corredor próximo, o mais atrás recebe um limite de velocidade de seguimento; o líder não recebe aumento artificial de velocidade.
- Histórico de eventos, contador de tentativas, abortos e passes, checkpoint compatível com o schema experimental 1.3, validação transacional e replay independente.

## Limitações explícitas

A física 1.1 usa silhuetas de pista e modelos de ponto material. Os corredores NÃO são largura real da pista nem movimentos laterais contínuos; o jogo oficial 3D permanece conectado ao **Core 2**. O sistema não oferece dinâmica de guinada, arrasto aerodinâmico de ar sujo calibrado, danos por contato, penalidades completas, detecção geométrica de rodas ou demonstração de fidelidade histórica. Intenções do Driver Brain 1.2 continuam sendo aproximações, não percepção perfeita.

**Não ativar o Racecraft 1.3 na corrida oficial**, nem divulgar melhoria de FPS; é um componente de laboratório até calibração e equivalência.

## Testes efetivamente realizados

- Testes novos: **37** verificações de comportamento, ultrapassagem medida, limite de tráfego, restauração e V21; **53** de determinismo, incluindo Silverstone seco, Spa chuva intensa, Monza seco e Singapura chuva intensa.
- Monza, 24 carros: ensaio de 2,200 ticks, **2** ataques e **2** ultrapassagens confirmadas, **25** abortos; continuação do checkpoint reproduzível.
- Monza prolongada, 24 carros: 8,000 ticks, **2** ataques, **2** ultrapassagens confirmadas, replay com hash idêntico após mais 100 ticks. Não equivale a uma corrida oficial completa de 53 voltas.
- Regressões herdadas: kernel, Command Queue, Vehicle Dynamics 1.1, Driver Brain 1.2, HUD ReBroadcast e a cena principal passaram. A importação headless com `--single-threaded-scene` passou na pasta de desenvolvimento. Na extração limpa final, a **primeira** importação apresentou `segmentation fault` (FAIL), mas a repetição terminou com código 0 (PASS); o incidente foi preservado na matriz e requer homologação no PC de destino.
- O teste extenso do contrato A/B foi interrompido pelo limite de execução e está **INCONCLUSIVE**. A corrida oficial completa e os testes visuais desta release estão **NOT_RUN**.

## Benchmark A/B headless — 24 carros, 160 ticks por cenário

| Pista | Driver 1.2 (ms/tick) | Racecraft 1.3 (ms/tick) | Razão de custo |
|---|---:|---:|---:|
| GBR / Seco | 1.163 | 2.120 | 1.82x |
| BEL / Chuva intensa | 1.069 | 2.238 | 2.09x |
| ITA / Seco | 1.171 | 2.691 | 2.30x |
| SIN / Chuva intensa | 1.482 | 3.001 | 2.02x |

Estes números são de uma única bateria curta em ambiente virtual; não determinam FPS e os modelos não têm cobertura igual ao Core 2. **Racecraft 1.3 custou mais CPU que 1.2**, e sua otimização/escala são pendências abertas.

## Preservação

A comparação SHA-256 por arquivo comprovou que **2.932 dos 2.933 arquivos de base estavam byte a byte iguais**, e a única alteração era em `experimental/apex2/vehicle_dynamics.gd`. Nenhum `scripts/` oficial, `project.godot`, cena, asset ou save foi alterado. Arquivos adicionais estão apenas em `experimental/apex2/`, `tests/apex2/`, `qa/apex2_racecraft_13/` e relatórios da release.

## Próximas dependências

1. Validar cenário de três ou mais carros com corredores ocupados e tráfego de retardatários.
2. Perfil de largura e geometria realmente calibrados por setor; sensores e janelas de disputa por curva.
3. Calibrar incidência de ultrapassagens, tempo lado a lado, defesa e risco; observabilidade por setor.
4. Otimizar o planejamento de tráfego e medir em hardware real.
5. Somente após estabilização, estudar adaptação ao Core 2 com testes de equivalência, sem remover o rollback.

**Status:** versão experimental testável, não pronta para substituir a física ou a IA oficial.
