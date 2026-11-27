# APEX 2 — Next Engine 1.2 Driver Brain (experimental)

Este ZIP contém **todo o projeto Godot**, não apenas exemplos. Abra `project.godot` com o Godot **4.7.2**. A corrida jogável permanece no Core 2, sob o controlador APEX 2 compat da versão anterior. A nova inteligência **não está habilitada na corrida principal** e não altera a HUD 3D já aprovada.

## Como executar os testes experimentais no Linux

Abra o terminal na raiz do projeto extraído e execute:

```bash
godot --headless --single-threaded-scene --path . --editor --quit
godot --headless --path . --script res://tests/apex2/test_driver_12.gd
godot --headless --path . --script res://tests/apex2/test_driver_determinism_12.gd
godot --headless --path . --script res://tests/apex2/test_driver_stress_12.gd
godot --headless --path . --script res://tests/apex2/benchmark_driver_12.gd
```

Se o binário se chamar `Godot_v4.7.2-stable_linux.x86_64`, substitua `godot` por `./Godot_v4.7.2-stable_linux.x86_64` ou pelo caminho do executável instalado.

Os testes geram PASS/FAIL no terminal. O benchmark grava `qa/apex2_driver_12/benchmark_driver_12.json`; não o interprete como FPS.

## Rollback

Mantenha o ZIP 1.1 em outra pasta, extraia-o para retornar à versão anterior. Não há migração de saves neste release. **Não copie scripts experimentais sobre o Core 2.**

Leia `APEX2_DRIVER_12_RELATORIO_TECNICO.md`, `APEX2_DRIVER_12_TESTES.json` e `APEX2_DRIVER_12_CHANGELOG.md` para evidências e limitações.

### Observação sobre a primeira importação no Linux headless

O Godot 4.7.2 apresentou um `segmentation fault` em uma primeira importação no ambiente virtual sem `--single-threaded-scene`. O mesmo projeto foi importado com sucesso em duas tentativas usando a opção acima, incluindo uma segunda pasta extraída do zero. No seu PC, tente a importação normal no editor gráfico; se ocorrer problema de thread em modo headless, use a opção documentada e compartilhe o log. Isso não é uma alteração do código esportivo.
