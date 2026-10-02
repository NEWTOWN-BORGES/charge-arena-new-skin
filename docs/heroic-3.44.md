# Charge Arena 3.44.0 — direção visual heroica

Repositório: NEWTOWN-BORGES/charge-arena-new-skin.
Base: a820badd10aad39cff97da6c39944895e7fcbd17 (modo 3v3).
Branch: codex/3.44-arena-heroica.

Cores de equipa azul elétrico/vermelho, menus azul escuro com texto claro e ações douradas, pintura dos robôs sem mistura pastel, luz de contorno, acabamento de verniz e sombreamento simplificado no perfil Leve. Arena com escudo/coroa original dourada e pulsos suaves nas juntas. Os presets identificam 3.44.0-heroica, código 70; os identificadores de pacote existentes foram preservados.

Referências de direção artística: Brawl Stars e Clash Royale. Os modelos e personagens continuam a ser do Charge Arena.

## Validação

Godot 4.7.1, Windows, Compatibility/OpenGL, NVIDIA GTX 1650.

- Regras: 44/44.
- Vídeo: 35/35.
- Refinado: aprovado.
- Squad e poderes de squad: zero falhas.
- Capturas reais: lobby, arena, perfil Leve, robô e 3v3 com seis jogadores. Sem erros de compilação de shader.
- Premium: quatro falhas já presentes na base, reproduzidas antes e depois: três expectativas antigas sobre texturas de materiais e uma expectativa sobre os 83 efeitos sonoros. Não foram ocultadas nem alteradas.
- O ambiente Windows emite um aviso de leitura do armazenamento de certificados.

`antes-*.png` e `depois-*.png` usam o mesmo roteiro de captura, resolução e semente. Não foi medido FPS em telemóvel nem produzido APK nesta entrega.

O ficheiro `charge-arena-heroica.patch` aplica-se à base acima com `git apply`. O relatório e as capturas permitem rever a alteração.
