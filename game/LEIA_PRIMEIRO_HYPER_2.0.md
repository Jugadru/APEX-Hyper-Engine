# APEX Motorsport Manager — Next Engine 2.0 Hyper Evolution / Alpha 1

## Como jogar

1. Extraia o ZIP completo em uma pasta nova. Não sobrescreva a versão 1.3 original.
2. Abra `project.godot` no Godot **4.7.2**. Execute F6/F5 conforme necessário; F5 inicia o jogo oficial.
3. No menu principal, escolha **NEXT ENGINE 2.0 → ABRIR LAB**. O modo Standard/Core 2 original continua disponível.
4. No laboratório, selecione circuito, equipe, clima, seed e acerto. Clique **INICIAR**. As velocidades de 1× a 64× são alvos; o painel também informa a velocidade efetivamente alcançada. Nenhum tick esportivo é pulado.
5. Escolha um dos dois pilotos, um composto e uma volta; use **AGENDAR BOX**, **CANCELAR BOX** ou os modos de ritmo. A ordem manual aceita é protegida da IA. O checkbox de IA de boxes vale para o próximo GP; as ordens de ritmo manuais mantêm a autoridade durante o GP.
6. **SALVAR CHECKPOINT / CARREGAR** preserva o estado experimental e verifica o hash. O carregamento pode recuperar o backup anterior se o arquivo principal estiver inválido.
7. Abra **TEMPORADA / P&D / STAFF** para criar uma carreira independente com calendário 2012, contratar profissionais, desenvolver e instalar peças, iniciar a próxima etapa e registrar seu resultado após a bandeirada.

Também é possível executar diretamente a nova interface, sem abrir o Core 2:

```bash
/path/para/Godot_v4.7.2-stable_linux.x86_64 --path . res://experimental/hyper/console.tscn --rendering-method gl_compatibility
```

### Carreira Hyper

- Selecione equipe e seed no laboratório antes de criar a temporada.
- Os 14 dias abstratos entre etapas são um orçamento de tempo de engenharia. Avance dias para concluir projeto, protótipo, teste e fabricação. O kit só altera o carro depois da instalação.
- A janela de GP congela o cenário. Nenhuma alteração de fábrica/contrato durante a etapa. Se fechar o jogo sem salvar checkpoint, o GP reservado poderá ser reiniciado com o mesmo cenário.
- Após a bandeirada, abra a Central e registre o resultado. A operação aplica classificação, pontos, receita fictícia, folha de pagamento, quilometragem de componentes e desenvolvimento rival uma única vez.
- O arquivo de carreira é independente (`user://hyper_career_20.bin`), assim como o checkpoint (`user://hyper_engine_20_checkpoint.bin`). Os arquivos originais de carreira Core 2 não são substituídos pela Hyper.

## Status

**Alpha experimental jogável**, não uma release estável ou uma implementação completa do Plano Mestre. A física é longitudinal com geometria sintética; os corredores laterais e zonas de DRS são aproximações de gameplay, não dados oficiais de pista. Os boxes usam atraso equivalente e fila por equipe, não uma pit lane 3D física. A tela Hyper tem mapa 2D; o renderizador 3D/Director TV original continua no Core 2. O campeonato Hyper usa a base 2012, inclusive se uma nova temporada for criada; não simula mudanças históricas de regulamento.

Consulte `APEX_HYPER_2.0_RELATORIO.md`, os logs em `qa/hyper/logs/` e `APEX_HYPER_2.0_MANIFESTO.json`.

## Testes

```bash
GODOT_BIN=/path/para/Godot_v4.7.2-stable_linux.x86_64 bash tools/run_hyper_validation.sh
```

O runner usa diretório de dados temporário e executa testes legados e novos, incluindo corridas completas. Não requer serviços externos. Os testes gráficos são executados à parte (ver relatório).
