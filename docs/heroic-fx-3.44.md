# Charge Arena 3.44.0 — texturas e efeitos heroicos

Segunda passagem gráfica na branch `codex/3.44-arena-heroica` do repositório correto NEWTOWN-BORGES/charge-arena-new-skin. Mantém as regras e o modo 3v3 da base a820bad.

## Alterações

- Placas de arena maiores, juntas escuras, carbono no perfil Alto e emblema dourado.
- Grão filtrado de pintura/metal nos robôs no perfil Alto; Leve e Médio dispensam essa amostra de textura.
- Relevo de texturas mais subtil, verniz em painéis/cerâmica no perfil Alto.
- Disparos com núcleo compacto e borda de cor; partículas direcionais e estrelas nítidas.
- Fumo menor, em volumes recortados, e fragmentos com faces claras/escuras.
- Explosão angular, faíscas analíticas, eletricidade em zigzag, cura em cruz e feixes compactos. Perfil Leve omite pormenores adicionais.
- Escudos com centro transparente e bordas hexagonais definidas.

## Verificação

Godot 4.7.1, Windows/Compatibility, GTX 1650. Capturas reais de lobby, robôs, arena, 3v3 e cinco momentos de combate em Alto/Leve. Sem erros de compilação de shaders/scripts.

Regras 44/44, vídeo 35/35, controlos/FX, low-end, squad e feedback aprovados. Pools de partículas mantêm seis batches com capacidades fixas; impactos não criam novos emissores. Premium mantém quatro falhas conhecidas da base (três expectativas antigas de materiais e uma de sons). O teste controls_fx emite avisos de recursos no encerramento; o ambiente emite aviso de certificados.

Presets Android identificam 3.44.0-heroica-fx, código 71, mantendo os pacotes e a assinatura de instalação local. LAB usa open_test e ALFA a progressão normal. Capturas e logs estão na pasta de entrega; instalação/FPS em telemóvel não foram testados.
