# LEIA PRIMEIRO — APEX 2 Racecraft Resolver 1.3 Experimental

Este ZIP contém o **jogo completo** com projeto Godot 4.7.2 (`project.godot`) e módulos isolados de corrida experimental. Não substitui Core 2. A tela principal continuará usando a HUD/3D e as regras esportivas validadas da versão anterior.

## Como testar no Linux

1. Extraia o ZIP em uma pasta nova, sem sobrescrever a versão 1.2.
2. Abra `project.godot` no Godot 4.7.2 e execute o jogo normalmente.
3. Para executar os testes experimentais no terminal, dentro da pasta do projeto:

```bash
GODOT=godot # ou caminho para o Godot 4.7.2
$GODOT --headless --path . --script res://tests/apex2/test_racecraft_13.gd
$GODOT --headless --path . --script res://tests/apex2/test_racecraft_determinism_13.gd
$GODOT --headless --path . --script res://tests/apex2/test_racecraft_stress_13.gd
$GODOT --headless --path . --script res://tests/apex2/test_racecraft_long_13.gd
```

Caso o editor headless acione problema de threads do ambiente, use `--single-threaded-scene` na importação; isso não comprova ausência de falha em outros ambientes.

## Rollback

Feche o Godot. Preserve os saves e volte para a pasta do ZIP `APEX_MOTORSPORT_MANAGER_APEX2_NEXT_ENGINE_1.2_DRIVER_BRAIN_EXPERIMENTAL_COMPLETO.zip`. Como a 1.3 **não modifica** saves e configuração oficiais, o retorno não requer migração de dados.

## O que esta versão ainda não faz

Os duelos são simulação experimental em corredores abstratos; ainda não há corpos laterais 3D nem impactos físicos, penalidades, pit stop completo ou substituição da simulação oficial. Veja `APEX2_RACECRAFT_13_RELATORIO_TECNICO.md` e `qa/apex2_racecraft_13/test_matrix.json`.
