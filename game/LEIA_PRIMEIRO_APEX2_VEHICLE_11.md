# APEX 2 — Vehicle Dynamics 1.1 (experimental)

O jogo continua funcionando com a versão v0.6.6.8.2 e física Core 2. A Next Engine 1.1 é uma camada de testes **separada**, não uma opção de substituição no menu principal. Não é necessário mudar o seletor `[apex2] primary_controller=true`.

## Como testar (Godot 4.7.2 / Linux Mint)

Abra o `project.godot` no Godot 4.7.2 para jogar normalmente. Para experimentar a física técnica independente, abra um terminal na pasta do projeto e execute:

```bash
godot --headless --editor --path . --import --quit
for test in test_vehicle_11 test_vehicle_determinism_11 test_vehicle_pit_11 benchmark_vehicle_11 benchmark_core_vehicle_11; do
  godot --headless --path . --script "res://tests/apex2/$test.gd"
done
```

Os resultados do benchmark são escritos em `qa/APEX2_VEHICLE_11_BENCHMARK.json` e a cópia da entrega fica em `qa/apex2_vehicle_11/benchmark.json`. Relatório, changelog, matriz de testes e logs estão incluídos.

## Rollback

Use a pasta ZIP anterior `APEX_MOTORSPORT_MANAGER_v0.6.6.8.2_APEX2_PRIMARY_COMPAT_COMPLETO.zip` como versão do jogo oficial. Não sobrescreva a pasta em uso nem os dados em `user://`. Nenhum save migrou nesta versão.
