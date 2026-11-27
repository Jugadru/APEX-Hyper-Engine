# Changelog — APEX 2 Next Engine 1.3 / Racecraft Resolver

- Adicionado `racecraft_resolver.gd` para a sequência observação → aproximação → preparação → ataque/defesa → lado a lado → resolução/recuo → recuperação.
- Adicionado `racecraft_kernel_13.gd` para estado de duelos, ordem dos eventos, checkpoints e confirmação de ultrapassagem via cruzamento longitudinal real.
- Vehicle Dynamics 1.1: adicionado campo **opcional** `traffic_speed_cap_mm_s` para limitar velocidade de um carro seguindo outro no mesmo corredor. Ausente nas versões herdadas.
- Adicionados testes unitários, determinismo em quatro circuitos, corrida longa sintética de Monza e benchmark A/B.
- A corrida oficial continua com o Core 2, a HUD ReBroadcast original e o controlador APEX 2 da v0.6.6.8.2.
- Não foram introduzidas funcionalidades de rádio, estratégia, 3D ou carreira.
