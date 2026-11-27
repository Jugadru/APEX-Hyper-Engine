# APEX MOTORSPORT MANAGER v0.6.6.8.2 — APEX 2 PRIMARY COMPAT

**Leia antes de jogar:** a nova camada APEX 2 é agora o CONTROLADOR PRINCIPAL de ticks nas corridas novas, mas utiliza o Core 2 como adaptador de dinâmica esportiva para preservar a física, pneus, chuva, IA, pit stops, Racecraft e regras históricas completas. **Não significa que o integrador experimental da Next Engine 1.0 substituiu a física oficial.**

## Abrir

1. Extraia o ZIP numa pasta NOVA e preserve o ZIP da v0.6.6.8.1 e o ZIP Next Engine 1.0.
2. Abra `project.godot` no Godot 4.7.2 e execute a cena principal.
3. A corrida começa em 3D 1× no modo automático; 10×, 16× e 32× alternam para mapa 2D; preferência manual prevalece.
4. A HUD ReBroadcast não foi redesenhada. Ao iniciar um GP, cabeçalho informa `APEX 2 / CORE 2 física compatível`.
5. Saves permanecem no caminho original; não sobrescreva ou apague os existentes.

## Arquitetura

- `experimental/apex2/production_scheduler.gd`: novo despachante principal de ticks fixos em sessão ao vivo.
- `experimental/apex2/primary_session.gd`: controlador primário de replay/comandos, preserva o protocolo e valida avanço unitário de tick.
- `experimental/apex2/session_factory.gd`: única fábrica de seleção, com retorno seguro ao controlador Core 2.
- `scripts/race_engine.gd` e `scripts/core/race_replay_0660.gd`: **sem qualquer alteração**.
- Módulos `simulation_kernel.gd` / `command_queue.gd` da Next Engine 1.0: continuam experimentais e testados; NÃO são usados como física oficial.

## Reverter a seleção do controlador, sem reinstalar o jogo

Feche o Godot. Em `project.godot`, altere:

```ini
[apex2]
primary_controller=false
```

Reabra o Godot: uma nova corrida usará o controlador Core 2 anterior. Isso não muda hashes esportivos ou arquivos de saves. Para rollback integral, extraia novamente o ZIP anterior em outra pasta e abra seu `project.godot`.

## Testes

```bash
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/apex2/primary_06682_contract.gd
godot --headless --path . --script res://tests/apex2/primary_06682_scene.gd
godot --headless --path . --script res://tests/apex2/primary_06682_pit_v21_wet.gd
godot --headless --path . --script res://tests/apex2/primary_06682_benchmark.gd
godot --headless --path . --script res://tests/apex2/primary_06682_monza_full.gd
```

A captura real 3D exige um display funcional: o ambiente de teste usou Mesa/Xvfb. Consulte `APEX_06682_MATRIZ_TESTES.json` e `APEX_06682_RELATORIO_TECNICO.md` para limitações.
