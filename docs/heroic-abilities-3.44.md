# Charge Arena 3.44 — habilidades e ultimates

Revisão na branch codex/3.44-arena-heroica de NEWTOWN-BORGES/charge-arena-new-skin.

- Assinaturas para 24 habilidades, 11 ultimates de skins e 13 ultimates básicas: 48 IDs, 32 símbolos por função e marcas para as variantes amplificadas.
- Ativação e preparação centradas no chassis real do personagem, acompanhando recuo, movimento, rotação e escala; o caster do companheiro no 3v3 é resolvido antes de atualizar a vista. Impactos mantêm as posições de jogo.
- Preparação de dois segundos fecha um anel com o símbolo da ultimate; libertação mais intensa que uma habilidade. As regras e os tempos originais continuam iguais.
- Efeitos específicos de gelo no alvo, EMP, tiro certeiro, fragmentação, morteiro, absorção e imunidade. Vórtice com correntes de acreção e fragmentos.
- Energia com cores mais definidas e núcleo solar mais estreito. Leve dispensa as amostras de ruído de volume; os feixes persistentes respeitam a troca de perfil.
- Botões distinguem pronto, recarga e preparação; ultimate com aro dourado e temporizadores mais legíveis. Hitboxes preservadas.
- Pool de 28 cartões, limites 8/18/28 por perfil. Um selo por equipa é construído antes da partida, sem criação contínua de objetos para os símbolos.

## Verificação

Godot 4.7.1, Windows, GPU GTX 1650/Compatibility. Capturas reais via regras, eventos e callbacks dos poderes, nos perfis Alto e Leve; preparação e HUD fotografados. Sem falhas de compilação de shaders/scripts.

Teste novo: 96 casts reais e 24 casos de origem no corpo, zero falhas; inclui seis pilotos nos perfis Alto/Leve, transformação da armadura, preparação e alteração do caster depois de emitir o release; estado autoritativo inalterado pelas atualizações de apresentação; cada cartão regressa uma vez ao pool. Pico 13 no Alto e 8 no Leve.

Powers, ultimates, new_powers, second_shelf, squad_powers, controls_fx, feedback e vídeo aprovados. Premium mantém quatro falhas antigas. power_kit tem duas expectativas antigas de tamanho/classificação do catálogo. Portrait tem uma expectativa de retorno do joystick, reproduzida na versão anterior. Logs preservam estas limitações. Alguns testes emitem avisos de recursos no encerramento; o ambiente emite aviso de certificados.

Android: 3.44.0-heroica-poderes, código72. LAB desbloqueado para testes; ALFA com progressão normal. As assinaturas locais de instalação são mantidas para atualizar as versões anteriores. Não foi medida taxa de frames nem feita instalação física em telemóvel.
