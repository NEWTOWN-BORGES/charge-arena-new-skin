# Revisão técnica e visual da base 3.44.0

Data: 1 de outubro de 2026. Repositório: `NEWTOWN-BORGES/charge-arena-new-skin`. Base: `a820badd10aad39cff97da6c39944895e7fcbd17`. Trabalho preparado numa branch separada, sem substituir a branch da outra implementação nem a release `apk`.

## Direção visual

Arena de combate estilizada, com cores fortes e leitura clara à distância. Mantêm-se os robôs e a identidade própria do jogo; não foram importados modelos ou imagens de Brawl Stars/Clash Royale.

- Pigmentos menos esbranquiçados nos shaders reais dos robôs (`robot_paint` e variante leve).
- Separação entre tinta, metal e borracha por rugosidade, reflexos e iluminação; contorno luminoso económico para recortar a silhueta.
- Azul de equipa, vermelho rival e dourado mais definidos. Armadura branca sem saturação global excessiva.
- Piso com placas maiores e juntas discretas, centro com marca dourada e menor competição visual com os projéteis.
- Menu e coleção com fundos azul-escuros, texto claro, títulos Rubik e cantos menos arredondados. Removido o slogan que se sobrepunha ao nome do piloto.
- Perfis Alto/Equilibrado/Leve preservados. Sem adicionar luzes dinâmicas ou passes de pós-processamento aos telemóveis. A variante leve continua sem iluminação por píxel nos robôs.

## Correções

### Consumo e pausa

O limite de FPS já não substitui o antialiasing configurado. A galeria deixa de forçar MSAA 8x. Uma política comum aplica os limites por perfil e plataforma, incluindo nos subviewports da história. A preferência de sombras volta a ser restaurada corretamente.

Em segundo plano, a simulação e os descendentes da sessão são desativados, os comandos mantidos são limpos e o áudio é silenciado sem perder o estado anterior do volume. No PvP, os dois jogadores suspendem a mesma partida quando um deles sai da aplicação, e retomam quando regressa. O transporte continua responsável por detetar uma desconexão real. A suspensão exige ambos os clientes nesta revisão, por acrescentar um RPC ao protocolo.

O ajuste automático reduz FPS sem mudar a resolução gráfica. A alternativa de 45 FPS é usada apenas no escalão correspondente a ecrãs de 90 Hz, evitando escolhê-la para um ecrã de 120 Hz.

### Rede e entrada

O validador de snapshots aceitava apenas quatro tipos de projétil, apesar de o jogo emitir oito. Agora aceita os oito e rejeita tipos/valores inválidos antes de alterar o estado. Efeitos enviados pela rede têm um limite estrito de 80 eventos por lote; a desconexão limpa efeitos e comandos pendentes.

Soltar o dedo liberta sempre o joystick/disparo, mesmo quando outra área da interface também trata esse evento. O HUD deixa de voltar a mostrar a arena atrás do ecrã de história. O aquecimento adiado de shaders ignora arenas já retiradas da árvore, evitando erros ao mudar rapidamente de mapa.

### Manutenção

Scripts e testes foram agrupados por responsabilidade; os caminhos e UIDs foram atualizados/preservados. As capturas históricas passaram para `docs/archive/previews`. Documentação, ferramentas e testes têm `.gdignore` e são excluídos dos presets Android.

Removidos o renderer antigo sem utilizadores, quatro geradores de áudio sem chamadas, uma LUT abandonada e pequenos auxiliares comprovadamente sem referências. As músicas, skins, controlos, regras e formatos de progresso existentes foram conservados. Dois testes dependentes de um commit ausente de uma versão antiga foram retirados; os restantes foram ajustados à estrutura e ao catálogo atuais.

O novo executor isola os saves por teste, guarda logs/JSON e verifica erros do motor além do código de saída. Os testes que abrem uma porta local são serializados. A exportação Android deixa de ignorar erros.

## Validação

Os resultados finais e as capturas estão registados nesta secção após a execução da suite. O ambiente de validação é Godot 4.7.1 no Windows, com testes de lógica headless e capturas reais em OpenGL Compatibility.

## Limites conhecidos

- Não foi medido consumo, temperatura ou FPS num Galaxy S23/A15 nesta revisão. Os testes não demonstram saúde da bateria nem garantem 60/120 FPS nesses aparelhos.
- A prova de PvP é local entre dois processos, não uma sessão em duas redes móveis. Snapshots grandes continuam a poder exceder o MTU do ENet e provocar fragmentação; redes com perdas precisam de validação específica antes de uma release.
- A revisão prepara código e presets da base 3.44.0. Não constitui uma nova release Android nem altera o APK instalado.
- A lógica de campanha, o equilíbrio de combate, os modelos geométricos e a composição das músicas não foram redesenhados nesta passagem de manutenção e acabamento.
