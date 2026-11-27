# Changelog 0.6.6.8.2 — APEX 2 Primary Compatibility

- Novo despachante de ticks fixos e orquestrador de sessão de corrida APEX 2. Padrão `apex2/primary_controller=true`.
- Rota de rollback integrada para controlador Core 2 por `apex2/primary_controller=false`.
- Estado esportivo, física, pit, rádio, estratégias, RNG, saves, replay e HUD original preservados; nenhuma nova física nativa implantada.
- Integridade verificada em quatro circuitos com hashes idênticos entre controladores nos mesmos ticks.
- Capturas gráficas reais da HUD 3D e do minimapa 2D.
- Regressão integral de Monza e replay de checkpoints, com hash histórico de referência.
- Testes adicionais para proteção da parada manual V21 sob chuva intensa, e replay entre controladores.
- Documentação explícita da diferença entre controlador novo e física nova.
