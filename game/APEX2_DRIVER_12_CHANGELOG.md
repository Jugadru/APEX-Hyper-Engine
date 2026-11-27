# Changelog — APEX 2 Next Engine 1.2 Driver Brain

- **ADDED:** `experimental/apex2/driver_brain.gd` com observações imperfeitas, perfil determinístico e máquina de intenções de ritmo.
- **ADDED:** `experimental/apex2/driver_kernel_12.gd`, adaptador isolado sobre Vehicle 1.1; fila existente valida comandos futuros.
- **ADDED:** três testes nativos: causalidade, determinismo em quatro pistas e stress de 10.000 ticks.
- **ADDED:** microbenchmark 1.1 vs 1.2 com três amostras por cenário.
- **UNCHANGED:** todas as cenas, scripts e configuração de produção, física Core 2, HUD, Pit Wall, replay e salvamentos.
- **KNOWN LIMIT:** 1.2 não tem resolvedor de ultrapassagem nem deve ser selecionado como motor oficial.
