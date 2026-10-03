# Robôs 3.44.0 — recuperação dos desenhos anteriores

Revisão de 3 de outubro de 2026, a pedido do jogador. Base: charge-arena-new-skin. Os modelos foram construídos no Blender 5.2.2 LTS e capturados com os materiais reais do Godot 4.7.1.

- Eclipse recupera o corpo E8 anterior: peito em cunha, gola alta, ombreiras maciças, garra e grevas. Conserva a cabeça orbital nova, ajustada à gola e com visor rubro. Continua a ser um vilão.
- Rosca recupera o mecânico R2/R3: casco fundido em tambor, óculos de soldador, lupa articulada, garra, rebitadora, rodas e ferramentas.
- Batida recupera o DJ B11: cabeça de rádio, auscultadores, colunas, tronco em pipo, subwoofer, gira-discos e megafone.

As melhorias são discretas: fixações e guardas, leitura de metal/tinta/borracha, cores mais encorpadas e bacias compactas sólidas sem a armação em U. Os corpos e temas anteriores são conservados. Triângulos medidos no Godot (incluindo auxiliares): Eclipse 17 668; Rosca 28 192; Batida 33 550.

As receitas 5/6/8 usam o GLB adicional. O kit original e os restantes robôs permanecem disponíveis. Rosca usa rosca12_hull para a face do casco fundido, sem cabeça separada; os metadados e joelhos são exportados com as peças.

Validação final: 96 lançamentos e 24 verificações de origem de habilidades/ultimates, zero falhas; 177 verificações de gráficos/áudio, zero falhas. Os dois processos Godot terminaram com código 0. O runner genérico marca reprovação pelas mensagens ambientais de certificados e limpeza de recursos do helper; não houve falhas nas asserções nem erros de scripts. Os testes usam projetos/saves descartáveis.

As imagens robos-recuperados mostram os modelos reais antes dos builds. robos-redesenhados.blend preserva as peças e os três robôs montados. Reconstrução: blender --background --python tools/blender/heroic_cast.py.

Esta revisão é distribuída em Android LAB/ALFA, versionCode 74, e Windows. Não foi medida a taxa de FPS nem instalada a app num telemóvel real.
