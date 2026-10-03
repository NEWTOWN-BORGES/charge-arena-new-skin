# Correções PC — 3.44.0 r74

Data: 3 de outubro de 2026. Base: codex/3.44-arena-heroica, após 44c066d (inclui manutenção, cenários e instalador anteriores).

## Botão de skins

Uma janela 1280×720 podia exceder a área útil de um ecrã quando se somavam barra de tarefas e moldura. O arranque Windows passa a reduzir proporcionalmente e centrar a janela na área útil; fullscreen e Android mantêm os seus modos.

O hangar recalcula o espaço do modelo quando os mínimos dos containers/textos se estabilizam. EQUIPAR/VOLTAR ficam no rodapé e as descrições continuam a deslocar-se dentro da coluna. A ajuda distingue rato e toque.

Na primeira execução, o tutorial do lobby podia abrir após 1,2 segundos por cima do hangar e capturar cliques. Agora a apresentação fica pendente enquanto existir um painel, taça ou partida; retoma ao voltar ao lobby.

## Câmara

Os gestos de partida antes só tinham caminho de toque. CONTROLOS inclui agora Vista geral, Vista próxima e 3.ª pessoa. No PC: C alterna, Home repõe, roda do rato aproxima/afasta, arrastar com botão direito/meio roda, Q/E rodam e +/- ajustam zoom. Clique esquerdo continua a disparar. Mouse emulado por toque é ignorado para evitar comandos duplicados.

O enquadramento mantém a pose de terceira pessoa durante layouts do HUD e segue o jogador correto no PvP. A vista é aplicada imediatamente, incluindo seleção nas opções. Preferências antigas de zoom/chase são migradas e preservadas. Guardar a vista não reinicia os dedos/joystick ativos.

## Validação

- Câmara PC, gestos antigos e mapa: 63 asserções, zero falhas.
- Hangar/clique de EQUIPAR pela GUI: 36 verificações em 1280×720, 1024×600, 800×600, 1920×1080 e 720×1280, zero falhas.
- Tutorial de primeira execução: 13 verificações GPU, zero falhas; inclui timer real, EQUIPAR/VOLTAR/skip por eventos de rato e retorno da partida.
- Capturas GPU das três vistas e das opções: concluídas.
- Modelos recuperados: 96 lançamentos, 24 origens e 177 verificações gráficas, zero falhas de asserção.
- Verificador de recursos: 574 caminhos, 168 UIDs, zero erros. Referência de Gancho migrada e quatro UIDs antigos duplicados removidos.

Validação no Godot 4.7.1 local. O log que o jogador trouxe indica 4.7.2 noutro ambiente; esse executável não estava disponível aqui. O motor emite um erro ambiental da loja de certificados no Windows; os processos funcionais terminam com código 0. O helper de habilidades mantém avisos de limpeza no encerramento.

Builds: LAB e ALFA Android code74, com os identificadores de pacote atuais do repositório, e Windows LAB com instalador EXE/ZIP. A assinatura Android e o recurso GLB importado são conferidos após exportar. Builds, chaves, saves e caches ficam fora do Git.
