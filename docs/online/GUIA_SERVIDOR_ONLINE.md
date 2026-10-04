# PvP online: pôr o servidor a funcionar (grátis)

O jogo e o servidor já estão prontos e testados. Falta uma máquina na internet onde o servidor corra sempre. Este guia usa a **Oracle Cloud "Always Free"**, que é grátis para sempre.

Tempo estimado: 30 a 45 minutos, uma única vez.

## O que já está feito

- **Servidor (`scripts/network/online_server.gd`):**
  - fila de partida rápida;
  - salas com código de 4 letras para jogar com amigos;
  - árbitro de cada partida, com as mesmas regras do jogo.
- **Jogo:** secção **ONLINE** no menu PvP:
  - PARTIDA RÁPIDA ONLINE;
  - CRIAR SALA PARA UM AMIGO;
  - ENTRAR NA SALA.
- **Sem rival:** se ninguém aparecer em 20 s, o jogo oferece "JOGAR COM IA AGORA". A IA nunca se faz passar por pessoa.
- **Teste automático (`tests/regression/test_online.gd`):** um servidor e dois jogos reais ligados entre si, com fila, salas, fim de partida e saída de um jogador.
- **Medições feitas** (`tests/benchmarks/bench_online_server.gd`):
  - cada partida gasta cerca de 2 % de um núcleo de processador;
  - cada jogador recebe cerca de 16 KB/s (cerca de 1 MB por minuto de jogo).
  - Por isso, um servidor aceita até 40 partidas ao mesmo tempo (80 jogadores).

Enquanto o servidor não estiver ligado, o menu mostra "Brevemente" e os botões online ficam desligados. Nada se parte.

## Passo 1: criar a conta Oracle Cloud

1. Ir a <https://www.oracle.com/cloud/free/> e escolher **Start for free**.
2. **Home region:** escolher uma região europeia perto dos jogadores, por exemplo Madrid, Frankfurt, Paris ou Milão. **Não dá para mudar depois.**
3. O cartão serve só para verificar a identidade. As máquinas "Always Free" não são cobradas.

## Passo 2: criar a máquina

1. Menu ☰ › **Compute › Instances › Create instance**.
2. Nome: `charge-arena`.
3. **Image:** Ubuntu (a versão mais recente).
4. **Shape:** *Ampere* › `VM.Standard.A1.Flex`, com 1 OCPU e 6 GB. Chega e sobra, e fica dentro do grátis.
5. **SSH keys:** escolher *Save private key* e guardar o ficheiro.
6. **Create.** Esperar que fique verde (*Running*) e copiar o **Public IP address**.

> Se aparecer "Out of capacity", tentar outra *Availability domain* ou repetir mais tarde. Acontece nas máquinas grátis.

## Passo 3: abrir a porta do jogo na consola

1. Na página da máquina, ir a **Subnet** › **Security Lists** › a lista *Default*.
2. **Add Ingress Rules** com estes valores:
   - Source CIDR: `0.0.0.0/0`
   - IP Protocol: **UDP**
   - Destination port: `27941`
3. Gravar.

## Passo 4: instalar o servidor (um comando)

1. Na página da máquina, abrir o terminal: **Cloud Shell**, ou SSH com a chave do passo 2.
2. Pôr na máquina o ficheiro `charge-arena-server.tar.gz`, que o Claude gera com `tools/build_server_bundle.sh`.
3. Correr:

```bash
tar -xzf charge-arena-server.tar.gz
sudo bash charge-arena-server/install.sh
```

O script trata de tudo:
- instala o Godot;
- cria o serviço, que arranca sozinho e se reinicia se cair;
- abre a porta na firewall da máquina.

Termina com **PRONTO**.

## Passo 5: ligar o jogo ao servidor

Dar o **IP público** ao Claude. Ele:
- põe o IP em `SERVER_HOST`, em `scripts/network/online.gd`;
- gera os APK novos;
- confirma com dois telemóveis.

## Manutenção

- **Ver se está a correr:** `systemctl status charge-arena-server`.
- **Ver o registo:** `journalctl -u charge-arena-server -f`.
  - De minuto a minuto aparece `ONLINE_STATS`, com jogadores, fila, salas e partidas.
  - Não ficam guardados IP nem dados pessoais.
- **Atualizar** quando o jogo mudar o protocolo: novo pacote, os mesmos dois comandos do passo 4.
  - Os jogos antigos recebem o aviso "Há uma versão nova do jogo".
- **Máquina parada:** a Oracle pode recuperar máquinas grátis que fiquem quase paradas durante 7 dias. Para evitar isso sem pagar nada, passar a conta para **Pay As You Go** (Billing › Upgrade). Os recursos "Always Free" continuam grátis.

## Custos

| Coisa | Custo |
|---|---|
| Máquina ARM (1 OCPU, 6 GB) | 0 € (Always Free) |
| Tráfego: 10 TB por mês incluídos | 0 € |
| Firebase Hosting para a política de privacidade | 0 € (plano Spark) |
