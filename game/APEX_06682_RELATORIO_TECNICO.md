# Relatório técnico — APEX v0.6.6.8.2 Primary Compatibility

**Data:** 16/11/2026. **Motor:** Godot 4.7.2.

## Decisão e limitação central

A Next Engine 1.0 não substitui Core 2 em modelo físico: não possui temperatura e desgaste completo de pneus, consumo causal, IA e Racecraft, pit stop/retorno e dinâmica de chuva. Trocar toda a física quebraria funcionalidades. Esta v0.6.6.8.2 implementa **o agendamento principal de ticks em APEX 2**, com o Core 2 como *adaptador esportivo oficial*. A mudança é real e jogável, mas **não é um novo modelo físico completo**.

## Alterações de código

- `project.godot`: habilita controlador APEX 2 por padrão e altera identidade da versão.
- `scripts/main.gd`: usa SessionFactory no restabelecimento da sessão e atualiza título.
- `scripts/apex_race_session_controller.gd`: sessões novas usam APEX 2 por padrão, cabeçalho indica Core 2 como física preservada.
- `experimental/apex2/production_scheduler.gd`: despacho 0,20 segundo/tick, limites de CPU e backlog, zero skipping de ticks.
- `experimental/apex2/primary_session.gd`: integridade de transição de tick e compatibilidade de replay.
- `experimental/apex2/session_factory.gd`: padrão APEX 2 e opção de retorno Core2 sem alterar saves.

## Integridade A/B

Quatro cenários com seed 6701: GBR seco, BEL chuva intensa, ITA seco, SIN chuva intensa. **86 verificações PASS** com 220 ticks por cenário, comandos e todos os hashes iguais, inclusive horários de quadro 0,02 ×10 versus 0,20 ×1. Replay ao vivo exportado para leitor Core2 e leitor APEX2 com busca não destrutiva.

## Situações especiais

- **Pit Wall V21 no Spa molhado:** 2504 ticks até a 5ª volta, plano manual V21 íntegro, sem pit precoce.
- **Monza 53 voltas:** 24431 ticks, 24 carros classificados, hash histórico `2a7e27179177858b8754a0c65666b325499e4aa13d423de060181b11d9ae1c4b`. Checkpoints: 9, seek validado nos ticks 10000, 20000 e 24431. Conforme relatório nativo `qa/apex2_primary_06682/monza_53_primary_validation.json`.
- **HUD:** integração de 34 verificações PASS; cena real APEX 2 com 17 verificações PASS; renderizações 3D 1600×900 e 2D 1920×1080 feitas no Godot com Mesa llvmpipe.
- **Retorno seguro:** `primary_controller=false` seleciona o controlador Core 2 tradicional.

## Desempenho

Benchmark headless de **160 ticks em 4 pistas**, mesma física e mesma quantidade de regras: veja `APEX_06682_BENCHMARK_AB.json`. Medições isoladas têm ruído; ganho de FPS no PC do usuário **não foi medido**. Testes anteriores da Next Engine experimental simplificada NÃO são usados para alegar vantagem.

## Testes e limitações

Resumo: **{'PASS': 13, 'FAIL': 0, 'INCONCLUSIVE': 1, 'BLOCKED': 1, 'NOT_RUN': 4}**. A tentativa de capturar imagem no renderizador headless falhou em acesso à textura; repetida com sucesso em Xvfb gráfico. Teste de GPU física do usuário não executado. Ainda não há equivalência física nativa de APEX 2; a v0.6.6.8.2 é uma etapa intermediária de migração compatível. Corridas completas nas outras três pistas, testes de 20 temporadas e comparativo real de FPS permanecem pendentes.

## Integridade e rollback

Projetos Core 2, Pit Wall, replay, HUD, fábrica e carreira não foram refatorados. Original preservado integralmente salvo os três arquivos de bootstrap identificados. Desligar o controlador APEX 2 em `project.godot` ou restaurar a pasta anterior é suficiente para rollback do código. Backups de saves são recomendados antes de qualquer atualização, embora o schema de saves não tenha sido alterado.
