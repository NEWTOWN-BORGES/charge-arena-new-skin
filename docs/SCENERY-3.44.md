# Acabamento exterior das arenas — 2 outubro 2026

O piso de jogo, o shader `court.gdshader`, a direção de cor em `art_style.gd` e as plataformas existentes foram preservados. A revisão trabalha os objetos exteriores e a composição do cenário.

- Aurora: duas unidades de ventilação com turbinas, grelhas e proteções metálicas. Carga alinhada, espaço reservado para as máquinas e limite de dois conjuntos de sucata; menos repetição de silhuetas grandes.
- Terrestre: até duas estações de energia em terreno plano, com cápsulas, cintas, consola e cobertura ventilada. A plantação reserva a projeção das copas para manter os equipamentos visíveis.
- Submarino: módulos de pressão com vigias opacas e dois conjuntos de recife próximos da arena. Os corais/rochas compostos substituem exemplares dispersos.
- Cidade: galerias exteriores com armação, cobertura, vidro opaco, sinalização e ripas.
- Órbita: módulos de acoplagem com blindagem, suportes, grelhas e radiadores.
- Perímetro: frisos e pequenas placas de serviço, fora do contorno de colisão.

As adições são opacas e estáticas, com cores partilhadas e agregadas pelo sistema de geometria existente. Não acrescentam luzes, animação por frame, transparência ou ficheiros de textura. Os cilindros decorativos usam 8–12 lados. Galerias e acoplagens têm no máximo seis conjuntos; os detalhes menores são omitidos se a arena for construída no perfil Leve.

## Verificação

Godot 4.7.1, OpenGL Compatibility, GeForce 210, captura 1000×760. Antes: commit a7971ee. Depois: alterações locais desta revisão. A ferramenta `tests/captures/capture_map_polish.gd` foi executada em cópias isoladas com saves de teste.

| Mundo | Draw calls antes/depois | Primitivas antes/depois |
|---|---:|---:|
| Aurora | 93 / 99 | 667904 / 663804 |
| Terrestre | 99 / 106 | 974668 / 980073 |
| Submarino | 89 / 96 | 587705 / 593533 |
| Órbita | 86 / 89 | 415278 / 423822 |
| Cidade | 92 / 93 | 609401 / 617177 |

Esses números medem complexidade renderizada no quadro capturado, não FPS em Android. Não foi feita medição num S23 ou A15. O perfil Leve também foi renderizado sem erros. `test_map_view`, `test_premium` e `test_video` passaram; o verificador de referências encontrou zero erros. As últimas correções de composição foram verificadas por novas capturas com o renderer real.

Capturas comparativas ficam fora do projeto, em `../map-scenery-previews/before` e `../map-scenery-previews/after`, evitando incluí-las no APK.
