# Guia Completo do Servidor Online PvP - Charge Arena

O Charge Arena possui arquitetura de partidas online cliente-servidor de alta precisão (UDP/ENet). O servidor funciona como árbitro neutro da partida, sincronizando snapshots a 60 ticks/s com consumo mínimo de banda e CPU (suporta mais de 80 jogadores simultâneos em uma máquina básica).

---

## 1. Testando e Jogando Localmente (Windows / Mac / Linux)

### No Windows:
1. Vá até a pasta `tools/` e dê dois cliques no arquivo:
   `tools/run_online_server.bat`
2. O servidor iniciará em modo headless na porta UDP **27941**.
3. Abra o jogo, vá na aba **ONLINE** no menu PvP:
   - Digite `127.0.0.1` e clique em **LIGAR IP**.
   - Os botões "PARTIDA RÁPIDA", "CRIAR SALA" e "ENTRAR NA SALA" serão ativados instantaneamente!

### No Linux / macOS / WSL:
Execute no terminal:
```bash
bash tools/run_online_server.sh
```

---

## 2. Hospedando em Nuvem com Docker (1 Comando)

Se você possui uma VPS (DigitalOcean, AWS, Oracle Cloud, Linode, Contabo, etc.):

1. Clone o repositório na VPS:
   ```bash
   git clone https://github.com/NEWTOWN-BORGES/charge-arena-new-skin.git
   cd charge-arena-new-skin/server
   ```
2. Suba o container com Docker Compose:
   ```bash
   docker compose up -d
   ```
3. O servidor estará rodando em segundo plano e reiniciará automaticamente em caso de reboot.
4. Lembre-se de abrir a porta **27941 UDP** na firewall da nuvem (Security Groups / Ingress Rules).

---

## 3. Hospedando na Oracle Cloud "Always Free" (Grátis para Sempre)

Siga o passo a passo detalhado em `docs/online/GUIA_SERVIDOR_ONLINE.md`:
1. Crie uma instância Ubuntu ARM na Oracle Cloud Free.
2. Abra a porta UDP `27941`.
3. Rode o script de instalação automática:
   ```bash
   sudo bash server/install.sh
   ```
4. O serviço `charge-arena-server.service` será criado no systemd e ficará ativo 24/7.

