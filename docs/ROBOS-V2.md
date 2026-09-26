# Robôs v2: o kit mecânico

Os robôs v2 são máquinas primeiro e humanoides depois. Cada peça mostra como se liga, roda e
aguenta o peso. O kit está em `tools/blender/mech_kit.py`, é chamado por `robot_kit.py` e
exporta para o mesmo `art/robots/kit.glb`.

## Regras de construção

- **Três camadas**: blindagem pintada (`shell`, `trim`, `team`) sobre um chassis escuro
  (`dark`), com as juntas em metal (`metal`) e os vedantes e cabos em borracha (`rubber`).
- **Nada colado**: há sempre uma fenda escura entre painéis e uma folga maior à volta de cada
  articulação, onde se vê o eixo.
- **Articulações legíveis**:
  - pescoço: placas, veio, rolamento, vedante, conduta e batente;
  - ombro: rolamento no suporte do tronco, tambor, garfo e pino;
  - cotovelo e joelho: dobradiça com garfo, cilindro, eixo e tampas;
  - pulso: placa de fim, rolamento, colar e placa da mão;
  - cintura: coluna, rolamento de guinada, fole e estabilizadores;
  - anca: alojamento na bacia, eixo e tambor com tampa;
  - tornozelo: garfo, eixo, discos e amortecedor.
- **Parafusos com função**: anéis de parafusos à volta das juntas e parafusos nos cantos das
  tampas, nunca soltos.
- **Mãos de três ou quatro dedos**, com falanges e pinos, e um polegar oposto.
- **Pés em camadas**: sola de borracha, chapa de metal, blindagem, calcanhar, dedos articulados
  e estabilizadores.

## Peças de base

`frame`, `sub` e `at` (referenciais locais), `mbox`, `mtube`, `mring`, `rod`, `piston`, `cable`,
`bolts`, `screw`, `vents`, `hinge`, `bearing`, `finger`, `hand` e `foot`.

## Receita de um robô v2 (`art/robots/roster.json`)

- **`hip`**: onde ficam os pivôs das pernas (as pernas v2 são mais altas).
- **`muzzle`**: a boca da arma. O nó `Gun/Flash` fica aqui e os efeitos partem daqui.
- **Pernas**: `<nome>_l` e `<nome>_r`, uma de cada lado. `robots.gd` usa-as quando existem, porque
  uma perna mecânica tem um lado de fora (tampas, ventilação).
- **Grupo `gun`**: só o cano. É o que recua para dentro da caixa do antebraço.
- **`callouts` e `design_note`**: para a folha de design.

## BIT v2

Robô de série do circuito, com 4,7 cabeças de altura:

- cabeça-sensor horizontal com o ecrã recuado 4 cm atrás da moldura, anel de retenção,
  telémetro, lidar e antena;
- ombros baixos com ombreiras de duas placas;
- antebraço esquerdo grande com mão de três dedos;
- canhão integrado no antebraço direito;
- pernas curtas e fortes, pés largos.

## Folha de design

```sh
python3 tools/blender/design_sheet.py BIT folha.png            # folha completa (Cycles)
python3 tools/blender/design_sheet.py BIT vista.png --quick    # só a vista 3/4
```

A folha mostra:

- as vistas 3/4 de frente, frente, costas, os dois lados e 3/4 de costas;
- a silhueta a preto;
- os pormenores de cada articulação;
- uma vista explodida com os painéis de blindagem afastados do chassis.
