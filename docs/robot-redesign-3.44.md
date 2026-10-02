# Eclipse, Rosca e Batida — revisão 3.44.0

Os três modelos foram construídos no Blender 5.2.2 LTS, exportados em GLB e capturados com os materiais reais do Godot 4.7.1.

- Eclipse é um vilão orbital alto e esguio: armadura negra, visor rubro estreito, núcleo de singularidade, escudo lateral assimétrico e canhão magnético.
- Rosca é um marinheiro de estaleiro e irmão afastado do pirata Gancho. A referência de Gancho orienta a pipa arredondada e a cúpula integrada. Rosca tem azul naval, metal claro e latão, vigia, hélice peitoral, guincho de corda, pinça e lança-arpão.
- Batida tem peito triangular com subwoofer protegido, visor em barra, ombros circulares, canhão de ressonância e pernas digitígradas.

As três ancas são sólidas/compactas, sem a armação em U rejeitada. As proporções, pernas, cabeças e armas são distintas. Triângulos medidos no Godot, incluindo auxiliares: Eclipse 11 772; Rosca 23 422; Batida 18 966.

As habilidades e ultimates continuam a nascer no centro da armadura animada de cada personagem, incluindo companheiros em 3v3. O teste de origem usa explicitamente Eclipse, Rosca e Batida como líderes e companheiros, nos perfis Refinado e Leve.

Exportações Android: 3.44.0-robos-variados-lab/alfa, versionCode 73. LAB mantém org.chargearena.sentinellab; ALFA mantém org.chargearena.prototype. As assinaturas são verificadas com apksigner e a identificação com aapt. A versão LAB é entregue primeiro.

Resultados finais: tests/test_abilities_heroic.gd aprovou 96 lançamentos e 24 verificações de origem, com zero falhas; tests/test_premium.gd aprovou 177 verificações, com zero falhas. O smoke da versão Windows também terminou sem falhas.

Validação dos gráficos inclui geometria finita/articulações de 22 skins, reversibilidade dos perfis, limites de VFX, textura e reflexos conforme o orçamento GPU e cobertura/variações de áudio. As expectativas antigas que proibiam texturas/clearcoat e exigiam um total fixo de 83 sons foram atualizadas para verificar o comportamento atual.

As imagens robos-finais mostram a geometria real antes dos APKs. O ficheiro robos-redesenhados.blend preserva as peças e os três robôs montados para edição. O ZIP de fontes é complementar ao repositório, não um projeto independente.

Para reconstruir: blender --background --python tools/blender/heroic_cast.py. O exportador usa detalhe 0.75 e atualiza apenas as receitas 5/6/8, os metadados e art/robots/heroic_cast.glb. O kit original permanece disponível para os restantes personagens.

O helper de habilidades também emite três avisos de warmup sobre nós fora da árvore e avisos de recursos no encerramento; as asserções funcionais passam.

O ambiente Windows emite um aviso local sobre a loja de certificados; não é uma falha de script. Não se mediu desempenho nem instalação em telemóvel.
