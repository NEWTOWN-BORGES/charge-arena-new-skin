# 3.45.0 (versionCode 74)

Junta a atualização heroica 3.44.0 (robôs redesenhados, interface, materiais, habilidades, cenário) com as batalhas 3 contra 3 e o trabalho de desempenho. A 3.44.0 já tinha sido usada duas vezes para coisas diferentes; este número separa-as.

## Novo desde a 3.44.0 heroica
- **3 contra 3** no painel PvP: arena com o dobro do comprimento e da largura, a flutuar no céu da Aurora; 3 trilhos por base (o arco e dois laterais), 300 tijolos por equipa, pilares, paredes defletoras, obstáculos que deslizam e que andam em círculo, boosts dourados e até 7 ricochetes por bala.
- **Jogar com as IA** (líder azul mais 2 IA contra 3) ou **ver as 6 IA** a jogar.
- Os 6 robôs usam habilidades e a ultimate do seu robô; os efeitos saem do robô que os lançou; em cada partida nova as IA jogam com robôs escolhidos ao acaso entre os 11 com ultimate.
- **Mais leve no telemóvel**: sem sombras, cenário parado (nuvens, relva, peixes e asteroides), cores fixas, tijolos de muralha em versão leve, antisserrilhado limitado a 2x.
- **Aurora**: paisagem pintada em 2D com névoa lá em baixo, serras assentes nela; sem o vazio branco nem a linha no horizonte do céu.
- Espetáculo de luzes ao abrir a baliza e golo, e robôs que festejam, ficam tristes, ajoelham e dançam.
- Cálculo das balas ~3x mais barato (grelha de tijolos e pré-seleção por caixa).

Testes novos: `tests/test_squad.gd`, `tests/test_squad_powers.gd`, `tests/benchmark_squad.gd`, `tests/capture_squad.gd`.
